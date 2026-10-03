#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^TKCoreAILoadCompletion)(NSError * _Nullable);
typedef void (^TKCoreAICompletion)(NSString * _Nullable, NSError * _Nullable);
/// Load only the application's bundled signed iOS 27 runtime. No external code.
void * _Nullable tk_coreai_create(NSString *bundledRuntimePath);
void tk_coreai_load(void *bridge, NSString *modelPath, TKCoreAILoadCompletion completion);
void tk_coreai_recover(void *bridge, NSString *prompt, TKCoreAICompletion completion);
void tk_coreai_cancel(void *bridge);
void tk_coreai_release(void *bridge);
NS_ASSUME_NONNULL_END
