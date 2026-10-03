# Core AI recovery runtime

This separate iOS 27 dynamic library uses Apple's `CoreAILM` product from the
official `coreai-models` package, pinned to
`52c84ba874b2c57adcede08a671ce96ed1b3f433`. The application's minimum stays iOS 26.
Its small Objective-C bridge supports iOS 26 and loads the signed app-bundled
runtime only on iOS 27. Xcode 26 builds and simulators can use the other providers.

`tools/prepare-coreai-runtime.py` builds and embeds the runtime during an iPhone
build with the iOS 27 SDK. It owns and deletes all its package/build scratch
directories. It never downloads model weights or accesses school documents.

A model must be exported for Core AI, benchmarked, packaged with an embedded
tokenizer and all resources, then listed in the application's reviewed manifest
with an exact size and SHA-256. No runtime may fetch a tokenizer during recovery.
The official wrapper is used through `LanguageModelSession` and `@Generable`;
the application's independent Validator and explicit adoption remain required.

Native SDK compilation, embedding validation and model export evaluation must
pass before a Core AI model is included in the release catalog. A missing model
or runtime is reported through Provider availability, never as successful recovery.
