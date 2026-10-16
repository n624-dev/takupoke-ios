#include <onnxruntime_c_api.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <unistd.h>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/resource.h>
#include <vector>
#ifdef __APPLE__
#include <CommonCrypto/CommonDigest.h>
#include <TargetConditionals.h>
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
#if defined(__APPLE__) && TARGET_OS_SIMULATOR && TARGET_OS_IOS
        const auto udid = std::getenv("SIMULATOR_UDID");
        if (!udid || std::string(udid).empty() || getpid() <= 0)
            throw std::runtime_error("Missing actual inference process identity");
        std::cout << "ORT_IOS_INFERENCE_IDENTITY\t" << udid << '\t' << getpid()
            << "\tIOS_SIMULATOR" << std::endl;
#elif defined(__APPLE__) && TARGET_OS_IOS
        // Keep the real C API reachable for the iPhone SDK link check. run.sh
        // executes only the Simulator binary; no physical-phone run is claimed.
#else
        throw std::runtime_error("The native probe requires an Apple iOS target");
#endif
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
        if (inputs != 2 || outputs != 2) throw std::runtime_error("Unexpected recognizer I/O contract");
        OrtAllocator* allocator = nullptr;
        checked(api->GetAllocatorWithDefaultOptions(&allocator));
        for (size_t i = 0; i < 2; ++i) {
            char *inputName = nullptr, *outputName = nullptr;
            checked(api->SessionGetInputName(session, i, allocator, &inputName));
            checked(api->SessionGetOutputName(session, i, allocator, &outputName));
            const std::string in(inputName), out(outputName);
            allocator->Free(allocator, inputName); allocator->Free(allocator, outputName);
            if (in != (i == 0 ? "x" : "valid_width") ||
                out != (i == 0 ? "probabilities" : "reject_probability"))
                throw std::runtime_error("Unexpected ASCII I/O names/order");
        }
        std::ifstream manifest(argv[2]);
        if (!manifest) throw std::runtime_error("Cannot open owned tensor manifest");
        std::cout << "ORT_IOS_READY\t" << version << std::endl;
        size_t calls = 0;
        const auto started = std::chrono::steady_clock::now();
        for (std::string line; std::getline(manifest, line);) {
            const auto fields = split(line);
            if (fields.size() != 5 || fields[0] != std::to_string(calls))
                throw std::runtime_error("Tensor inventory/order mismatch");
            const int width = std::stoi(fields[1]);
            if (width < 320 || width > 960) throw std::runtime_error("Recognizer width bound exceeded");
            auto data = tensor(fields[2], static_cast<size_t>(3 * 48 * width));
            const auto inputHash = sha256(data.data(), data.size() * sizeof(float));
            if (inputHash != fields[3]) throw std::runtime_error("Native input bytes changed");
            const int64_t shape[] = {1, 3, 48, width};
            OrtValue *input = nullptr, *validInput = nullptr;
            OrtValue* output[2] = {nullptr, nullptr};
            checked(api->CreateTensorWithDataAsOrtValue(memory, data.data(), data.size() * sizeof(float),
                shape, 4, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input));
            int64_t valid = std::stoll(fields[4]);
            if (valid < 1 || valid > width) throw std::runtime_error("Invalid native valid_width");
            const int64_t validShape[] = {1};
            checked(api->CreateTensorWithDataAsOrtValue(memory, &valid, sizeof(valid), validShape, 1,
                ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &validInput));
            // Inspect the actual tensor supplied to Run, including shape/type/value.
            OrtTensorTypeAndShapeInfo* validInfo = nullptr;
            checked(api->GetTensorTypeAndShape(validInput, &validInfo));
            ONNXTensorElementDataType validType;
            size_t validRank = 0, validCount = 0;
            int64_t validDimensions[1];
            checked(api->GetTensorElementType(validInfo, &validType));
            checked(api->GetDimensionsCount(validInfo, &validRank));
            checked(api->GetTensorShapeElementCount(validInfo, &validCount));
            if (validType != ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 || validRank != 1 || validCount != 1)
                throw std::runtime_error("Unexpected actual valid_width tensor");
            checked(api->GetDimensions(validInfo, validDimensions, 1));
            if (validDimensions[0] != 1) throw std::runtime_error("Unexpected valid_width shape");
            void* validBytes = nullptr;
            checked(api->GetTensorMutableData(validInput, &validBytes));
            const auto actualValid = *static_cast<int64_t*>(validBytes);
            const auto validHash = sha256(validBytes, sizeof(int64_t));
            const char* inputNames[] = {"x", "valid_width"};
            const OrtValue* inputValues[] = {input, validInput};
            const char* outputNames[] = {"probabilities", "reject_probability"};
            checked(api->Run(session, nullptr, inputNames, inputValues, 2, outputNames, 2, output));
            api->ReleaseTensorTypeAndShapeInfo(validInfo);
            OrtTensorTypeAndShapeInfo* info = nullptr;
            checked(api->GetTensorTypeAndShape(output[0], &info));
            size_t rank = 0, count = 0;
            checked(api->GetDimensionsCount(info, &rank));
            if (rank != 3) throw std::runtime_error("Unexpected output rank");
            int64_t dimensions[3];
            checked(api->GetDimensions(info, dimensions, 3));
            checked(api->GetTensorShapeElementCount(info, &count));
            ONNXTensorElementDataType dtype;
            checked(api->GetTensorElementType(info, &dtype));
            if (dtype != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT || dimensions[0] != 1 ||
                dimensions[1] < 1 || dimensions[2] != 438 ||
                count != static_cast<size_t>(dimensions[1] * dimensions[2]))
                throw std::runtime_error("Unexpected probability shape/type");
            void* bytes = nullptr;
            checked(api->GetTensorMutableData(output[0], &bytes));
            const auto outputHash = sha256(bytes, count * sizeof(float));
            const std::string filename = std::string(argv[3]) + "/" + std::to_string(calls) + ".f32";
            std::ofstream result(filename, std::ios::binary | std::ios::trunc);
            result.write(static_cast<const char*>(bytes), static_cast<std::streamsize>(count * sizeof(float)));
            result.close();
            if (!result) throw std::runtime_error("Cannot write complete native probability tensor");
            OrtTensorTypeAndShapeInfo* rejectInfo = nullptr;
            checked(api->GetTensorTypeAndShape(output[1], &rejectInfo));
            size_t rejectRank = 0, rejectCount = 0;
            ONNXTensorElementDataType rejectType;
            int64_t rejectDimensions[1];
            checked(api->GetDimensionsCount(rejectInfo, &rejectRank));
            checked(api->GetTensorShapeElementCount(rejectInfo, &rejectCount));
            checked(api->GetTensorElementType(rejectInfo, &rejectType));
            if (rejectRank != 1 || rejectCount != 1 || rejectType != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT)
                throw std::runtime_error("Unexpected reject output shape/type");
            checked(api->GetDimensions(rejectInfo, rejectDimensions, 1));
            if (rejectDimensions[0] != 1) throw std::runtime_error("Unexpected reject shape");
            void* rejectBytes = nullptr;
            checked(api->GetTensorMutableData(output[1], &rejectBytes));
            const auto reject = *static_cast<float*>(rejectBytes);
            if (!std::isfinite(reject) || reject < 0 || reject > 1)
                throw std::runtime_error("Invalid reject probability");
            const auto rejectHash = sha256(rejectBytes, sizeof(float));
            const std::string rejectFilename = std::string(argv[3]) + "/" + std::to_string(calls) + ".reject.f32";
            std::ofstream rejectFile(rejectFilename, std::ios::binary | std::ios::trunc);
            rejectFile.write(static_cast<const char*>(rejectBytes), sizeof(float)); rejectFile.close();
            if (!rejectFile) throw std::runtime_error("Cannot write native reject output");
            std::cout << "ORT_IOS_RESULT\t" << calls << '\t' << dimensions[1] << '\t' << dimensions[2]
                << '\t' << inputHash << '\t' << outputHash << '\t' << validHash << '\t' << rejectHash
                << '\t' << actualValid << std::endl;
            api->ReleaseTensorTypeAndShapeInfo(rejectInfo);
            ++calls;
            api->ReleaseTensorTypeAndShapeInfo(info);
            api->ReleaseValue(output[0]); api->ReleaseValue(output[1]);
            api->ReleaseValue(input); api->ReleaseValue(validInput);
        }
        if (!manifest.eof() || calls != 288) throw std::runtime_error("Incomplete native call inventory");
        struct rusage usage {};
        if (getrusage(RUSAGE_SELF, &usage) != 0) throw std::runtime_error("Cannot observe own RSS");
        const double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - started).count();
        std::cout << "ORT_IOS_FINISHED\t" << calls << '\t' << usage.ru_maxrss << '\t' << seconds << std::endl;
        api->ReleaseMemoryInfo(memory); api->ReleaseSession(session);
        api->ReleaseSessionOptions(options); api->ReleaseEnv(env);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "ORT_IOS_ERROR " << error.what() << std::endl;
        return 1;
    }
}
