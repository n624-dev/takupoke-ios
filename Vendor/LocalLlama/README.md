# LocalLlama

The C bridge uses the ABI of the official llama.cpp **b11371**, commit
`99b95488c`. Private headers are copied from the matching official XCFramework,
under the included MIT license. It loads only the app-bundled signed framework;
it contains no network client and cannot send PDF or prompt data externally.

`tools/prepare-llama-runtime.py` downloads and verifies the exact official
XCFramework during **device builds**, then embeds its iOS framework. The runtime
is 61,784,599 bytes in the download archive, with SHA-256
`328b0e9d20b8c18df19ccb9fb204200844c081a67ac59ec4a1faf3e50fd571c3`.
Model weights are downloaded separately after the user requests installation.

This release has no iOS simulator slice. Simulator recovery uses the other
available providers or reports this runtime unsupported. Host tests can load
the official Linux or macOS runtime using the same C bridge.

The caller serializes load/generate/destruction. Cancellation is thread safe,
interrupts model loading and token decoding, and permanently invalidates that
session. Context, response bytes and generated token counts are bounded. JSON
grammar constrains lesson count, field states and evidence IDs; the application's
independent Validator still decides whether the result can be shown for adoption.
