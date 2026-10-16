#include <onnxruntime_c_api.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/resource.h>
#include <vector>
#ifdef __APPLE__
#include <CommonCrypto/CommonDigest.h>
#endif

// Research executable; no app, parser, oracle, network or adoption capability.
static const OrtApi* api = nullptr;
static void checked(OrtStatus* status) {
    if (!status) return;
    const std::string message = api->GetErrorMessage(status);
    api->ReleaseStatus(status);
    throw std::runtime_error(message);
}
static std::string sha256(const void* bytes, size_t count) {
#ifdef __APPLE__
    if (count > UINT32_MAX) throw std::runtime_error("Hash input too large");
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes, static_cast<CC_LONG>(count), digest);
    static const char hex[] = "0123456789abcdef";
    std::string result;
    for (auto b : digest) { result += hex[b >> 4]; result += hex[b & 15]; }
    return result;
#else
    (void)bytes; (void)count;
    throw std::runtime_error("The native runner must execute on Apple iOS, not a Linux substitute");
#endif
}
static std::vector<std::string> split(const std::string& line) {
    std::vector<std::string> fields;
    std::istringstream stream(line);
    std::string field;
    while (std::getline(stream, field, '\t')) fields.push_back(field);
    return fields;
}
static std::vector<float> tensor(const std::string& path, size_t count) {
    std::ifstream stream(path, std::ios::binary | std::ios::ate);
    if (!stream || stream.tellg() != static_cast<std::streamoff>(count * sizeof(float)))
        throw std::runtime_error("Original tensor byte count mismatch");
    stream.seekg(0);
    std::vector<float> result(count);
    stream.read(reinterpret_cast<char*>(result.data()), static_cast<std::streamsize>(count * sizeof(float)));
    if (!stream) throw std::runtime_error("Cannot read complete tensor");
    return result;
}
int main(int argc, char** argv) {
    try {
        if (argc != 4) throw std::runtime_error("Use model-path manifest-tsv owned-output-directory");
        api = OrtGetApiBase()->GetApi(ORT_API_VERSION);
        if (!api || ORT_API_VERSION != 23) throw std::runtime_error("Unexpected C API");
        const std::string version = OrtGetApiBase()->GetVersionString();
        if (version != "1.23.2") throw std::runtime_error("Unexpected iOS runtime version");
        OrtEnv* env = nullptr; OrtSessionOptions* options = nullptr;
        OrtSession* session = nullptr; OrtMemoryInfo* memory = nullptr;
        checked(api->CreateEnv(ORT_LOGGING_LEVEL_ERROR, "fictional-ios-parity", &env));
        checked(api->DisableTelemetryEvents(env));
        checked(api->CreateSessionOptions(&options));
        checked(api->SetIntraOpNumThreads(options, 2));
        checked(api->SetInterOpNumThreads(options, 1));
        checked(api->SetSessionGraphOptimizationLevel(options, ORT_ENABLE_ALL));
        // Register no optional provider. ORT's default execution provider is CPU.
        checked(api->CreateSession(env, argv[1], options, &session));
        checked(api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &memory));
        size_t inputs = 0, outputs = 0;
        checked(api->SessionGetInputCount(session, &inputs));
        checked(api->SessionGetOutputCount(session, &outputs));
        if (inputs != 1 || outputs != 1) throw std::runtime_error("Unexpected recognizer I/O contract");
        OrtAllocator* allocator = nullptr;
        checked(api->GetAllocatorWithDefaultOptions(&allocator));
        char* outputName = nullptr;
        checked(api->SessionGetOutputName(session, 0, allocator, &outputName));
        std::ifstream manifest(argv[2]);
        if (!manifest) throw std::runtime_error("Cannot open owned tensor manifest");
        std::cout << "ORT_IOS_READY\t" << version << std::endl;
        size_t calls = 0;
        const auto started = std::chrono::steady_clock::now();
        for (std::string line; std::getline(manifest, line);) {
            const auto fields = split(line);
            if (fields.size() != 4 || fields[0] != std::to_string(calls))
                throw std::runtime_error("Tensor inventory/order mismatch");
            const int width = std::stoi(fields[1]);
            if (width < 1 || width > 960) throw std::runtime_error("Recognizer width bound exceeded");
            auto data = tensor(fields[2], static_cast<size_t>(3 * 48 * width));
            const auto inputHash = sha256(data.data(), data.size() * sizeof(float));
            if (inputHash != fields[3]) throw std::runtime_error("Native input bytes changed");
            const int64_t shape[] = {1, 3, 48, width};
            OrtValue* input = nullptr; OrtValue* output = nullptr;
            checked(api->CreateTensorWithDataAsOrtValue(memory, data.data(), data.size() * sizeof(float),
                shape, 4, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input));
            const char* inputNames[] = {"x"};
            const OrtValue* inputValues[] = {input};
            const char* outputNames[] = {outputName};
            checked(api->Run(session, nullptr, inputNames, inputValues, 1, outputNames, 1, &output));
            OrtTensorTypeAndShapeInfo* info = nullptr;
            checked(api->GetTensorTypeAndShape(output, &info));
            size_t rank = 0, count = 0;
            checked(api->GetDimensionsCount(info, &rank));
            if (rank != 3) throw std::runtime_error("Unexpected output rank");
            int64_t dimensions[3];
            checked(api->GetDimensions(info, dimensions, 3));
            checked(api->GetTensorShapeElementCount(info, &count));
            ONNXTensorElementDataType dtype;
            checked(api->GetTensorElementType(info, &dtype));
            if (dtype != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT || dimensions[0] != 1 ||
                dimensions[1] < 1 || dimensions[2] != 18710 ||
                count != static_cast<size_t>(dimensions[1] * dimensions[2]))
                throw std::runtime_error("Unexpected probability shape/type");
            void* bytes = nullptr;
            checked(api->GetTensorMutableData(output, &bytes));
            const auto outputHash = sha256(bytes, count * sizeof(float));
            const std::string filename = std::string(argv[3]) + "/" + std::to_string(calls) + ".f32";
            std::ofstream result(filename, std::ios::binary | std::ios::trunc);
            result.write(static_cast<const char*>(bytes), static_cast<std::streamsize>(count * sizeof(float)));
            result.close();
            if (!result) throw std::runtime_error("Cannot write complete native probability tensor");
            std::cout << "ORT_IOS_RESULT\t" << calls << '\t' << dimensions[1] << '\t' << dimensions[2]
                << '\t' << inputHash << '\t' << outputHash << std::endl;
            ++calls;
            api->ReleaseTensorTypeAndShapeInfo(info);
            api->ReleaseValue(output); api->ReleaseValue(input);
        }
        if (!manifest.eof() || calls != 288) throw std::runtime_error("Incomplete native call inventory");
        struct rusage usage {};
        if (getrusage(RUSAGE_SELF, &usage) != 0) throw std::runtime_error("Cannot observe own RSS");
        const double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - started).count();
        std::cout << "ORT_IOS_FINISHED\t" << calls << '\t' << usage.ru_maxrss << '\t' << seconds << std::endl;
        allocator->Free(allocator, outputName);
        api->ReleaseMemoryInfo(memory); api->ReleaseSession(session);
        api->ReleaseSessionOptions(options); api->ReleaseEnv(env);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "ORT_IOS_ERROR " << error.what() << std::endl;
        return 1;
    }
}
