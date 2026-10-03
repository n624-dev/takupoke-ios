#include "include/CLlamaRecovery.h"
#include "PrivateHeaders/llama.h"
#include <atomic>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <mutex>
#include <new>
#include <string>
#include <vector>
#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IOS
#include <os/proc.h>
#endif
#elif defined(__linux__)
#include <sys/sysinfo.h>
#endif

// ABI pinned to llama.cpp b11371 / 99b95488c. No networking or logging of inputs.
#define TK_LLAMA_FUNCTIONS(X) \
 X(llama_backend_init) X(ggml_backend_load_all_from_path) X(llama_model_default_params) X(llama_context_default_params) \
 X(llama_model_load_from_file) X(llama_init_from_model) X(llama_free) X(llama_model_free) \
 X(llama_model_get_vocab) X(llama_get_memory) X(llama_memory_clear) X(llama_set_abort_callback) \
 X(llama_model_chat_template) X(llama_chat_apply_template) X(llama_tokenize) X(llama_decode) \
 X(llama_batch_get_one) X(llama_vocab_is_eog) X(llama_token_to_piece) \
 X(llama_sampler_chain_default_params) X(llama_sampler_chain_init) X(llama_sampler_chain_add) \
 X(llama_sampler_init_grammar) X(llama_sampler_init_greedy) X(llama_sampler_sample) X(llama_sampler_free)

struct tk_llama_session {
    std::atomic<bool> cancelled{false};
    void *library = nullptr;
    llama_model *model = nullptr;
    llama_context *context = nullptr;
    int context_tokens = 0;
    #define DECLARE(name) decltype(&name) name##_fn = nullptr;
    TK_LLAMA_FUNCTIONS(DECLARE)
    #undef DECLARE
};
static bool abort_decode(void *value) { return static_cast<tk_llama_session *>(value)->cancelled.load(); }
static bool progress(float, void *value) { return !abort_decode(value); }
static std::mutex backend_mutex;

tk_llama_session *tk_llama_create(void) { return new (std::nothrow) tk_llama_session(); }
int tk_llama_load(tk_llama_session *s, const char *library_path, const char *model_path, int metal, int context_tokens) {
    if (!s || !library_path || !model_path || s->model || context_tokens < 512 || context_tokens > 4096) return 2;
    if (s->cancelled.load()) return 1;
    s->library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (!s->library) return 2;
    #define LOAD(name) s->name##_fn = reinterpret_cast<decltype(&name)>(dlsym(s->library, #name)); if (!s->name##_fn) return 2;
    TK_LLAMA_FUNCTIONS(LOAD)
    #undef LOAD
    {
        std::lock_guard<std::mutex> lock(backend_mutex);
        std::string path(library_path);
        size_t separator = path.find_last_of('/');
        if (separator != std::string::npos) s->ggml_backend_load_all_from_path_fn(path.substr(0, separator).c_str());
        s->llama_backend_init_fn();
    }
    auto mp = s->llama_model_default_params_fn();
    mp.n_gpu_layers = metal ? -1 : 0;
    mp.progress_callback = progress; mp.progress_callback_user_data = s;
    s->model = s->llama_model_load_from_file_fn(model_path, mp);
    if (s->cancelled.load()) return 1;
    if (!s->model) return 2;
    auto cp = s->llama_context_default_params_fn();
    cp.n_ctx = context_tokens; cp.n_batch = 256; cp.n_ubatch = 256;
    cp.n_threads = 2; cp.n_threads_batch = 2;
    cp.abort_callback = abort_decode; cp.abort_callback_data = s;
    s->context = s->llama_init_from_model_fn(s->model, cp);
    if (s->cancelled.load()) return 1;
    s->context_tokens = context_tokens;
    return s->context ? 0 : 2;
}
int tk_llama_generate(tk_llama_session *s, const char *system, const char *prompt, const char *grammar, int limit, char **output) {
    if (output) *output = nullptr;
    if (!s || !s->context || !system || !prompt || !grammar || !output || limit < 1 || limit > 1024) return 2;
    if (s->cancelled.load()) return 1;
    if (strlen(system) > 4096 || strlen(prompt) > 8192 || strlen(grammar) > 32768) return 3;
    const llama_vocab *vocab = s->llama_model_get_vocab_fn(s->model);
    // Use the model's own supported template; unsupported templates safely fail.
    llama_chat_message messages[] = {{"system", system}, {"user", prompt}};
    auto tmpl = s->llama_model_chat_template_fn(s->model, nullptr);
    if (!tmpl) return 2;
    int size = s->llama_chat_apply_template_fn(tmpl, messages, 2, true, nullptr, 0);
    if (size <= 0 || size > 32768) return 3;
    std::vector<char> formatted(size + 1);
    if (s->llama_chat_apply_template_fn(tmpl, messages, 2, true, formatted.data(), size) != size) return 2;
    // Qwen reasoning is explicitly disabled before constrained JSON generation.
    std::string text(formatted.data(), size);
    if (strstr(tmpl, "<think>")) text += "<think>\n\n</think>\n\n";
    int needed = s->llama_tokenize_fn(vocab, text.c_str(), text.size(), nullptr, 0, true, true);
    if (needed >= 0 || -needed + limit >= s->context_tokens) return 3;
    std::vector<llama_token> tokens(-needed);
    if (s->llama_tokenize_fn(vocab, text.c_str(), text.size(), tokens.data(), tokens.size(), true, true) != static_cast<int>(tokens.size())) return 2;
    s->llama_memory_clear_fn(s->llama_get_memory_fn(s->context), true);
    for (size_t offset = 0; offset < tokens.size(); offset += 256) {
        if (s->cancelled.load()) return 1;
        int n = static_cast<int>(std::min<size_t>(256, tokens.size() - offset));
        if (s->llama_decode_fn(s->context, s->llama_batch_get_one_fn(tokens.data() + offset, n))) return s->cancelled.load() ? 1 : 2;
    }
    auto sampler = s->llama_sampler_chain_init_fn(s->llama_sampler_chain_default_params_fn());
    auto constraint = s->llama_sampler_init_grammar_fn(vocab, grammar, "root");
    if (!sampler || !constraint) { if (sampler) s->llama_sampler_free_fn(sampler); return 2; }
    s->llama_sampler_chain_add_fn(sampler, constraint);
    s->llama_sampler_chain_add_fn(sampler, s->llama_sampler_init_greedy_fn());
    std::string result; int status = 3;
    for (int i = 0; i < limit; ++i) {
        if (s->cancelled.load()) { status = 1; break; }
        llama_token token = s->llama_sampler_sample_fn(sampler, s->context, -1);
        if (s->llama_vocab_is_eog_fn(vocab, token)) { status = 0; break; }
        char piece[256]; int n = s->llama_token_to_piece_fn(vocab, token, piece, sizeof(piece), 0, false);
        if (n < 0 || result.size() + n > 16384) break;
        result.append(piece, n);
        if (s->llama_decode_fn(s->context, s->llama_batch_get_one_fn(&token, 1))) { status = s->cancelled.load() ? 1 : 2; break; }
    }
    s->llama_sampler_free_fn(sampler);
    if (status == 0) { *output = static_cast<char *>(malloc(result.size() + 1)); if (!*output) return 2; memcpy(*output, result.c_str(), result.size() + 1); }
    return status;
}
void tk_llama_cancel(tk_llama_session *s) { if (s) s->cancelled.store(true); }
void tk_llama_destroy(tk_llama_session *s) {
    if (!s) return;
    if (s->context) s->llama_free_fn(s->context);
    if (s->model) s->llama_model_free_fn(s->model);
    if (s->library) dlclose(s->library);
    delete s;
}
void tk_llama_free_output(char *p) { free(p); }
uint64_t tk_llama_available_memory(void) {
#if defined(__APPLE__) && TARGET_OS_IOS
    return os_proc_available_memory();
#elif defined(__linux__)
    struct sysinfo memory;
    if (sysinfo(&memory) == 0) return static_cast<uint64_t>(memory.freeram) * memory.mem_unit;
    return 0;
#else
    return 0; // Unknown memory is never represented as unlimited capacity.
#endif
}
