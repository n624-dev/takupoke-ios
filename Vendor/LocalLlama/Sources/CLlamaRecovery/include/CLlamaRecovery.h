#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct tk_llama_session tk_llama_session;
/* Calls on a session must be serial, except cancel, which is thread safe.
 * Only signed, application-bundled runtime libraries may be supplied. */
tk_llama_session *tk_llama_create(void);
int tk_llama_load(tk_llama_session *, const char *library_path, const char *model_path, int use_metal, int context_tokens);
int tk_llama_generate(tk_llama_session *, const char *system, const char *prompt, const char *grammar, int max_tokens, char **output);
void tk_llama_cancel(tk_llama_session *);
void tk_llama_destroy(tk_llama_session *);
void tk_llama_free_output(char *);
uint64_t tk_llama_available_memory(void);
/* 0 success, 1 cancelled, 2 unavailable/runtime error, 3 limit/invalid output */
#ifdef __cplusplus
}
#endif
