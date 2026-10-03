#import "include/CCoreAIRecovery.h"
#import <dlfcn.h>
@protocol TKCoreAISelectors
- (void)loadModel:(NSString *)path completion:(TKCoreAILoadCompletion)completion;
- (void)recoverCell:(NSString *)prompt completion:(TKCoreAICompletion)completion;
- (void)cancel;
@end

void *tk_coreai_create(NSString *path) {
    if (@available(iOS 27.0, macOS 27.0, *)) {
        // Runtime code is signed and bundled at build time. Keep dlopen's handle
        // for process lifetime: Swift/Objective-C types cannot safely be unloaded.
        if (!dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL)) return NULL;
        Class type = NSClassFromString(@"TakupokeCoreAIRecoveryBridge");
        if (!type || ![type instancesRespondToSelector:@selector(loadModel:completion:)] ||
            ![type instancesRespondToSelector:@selector(recoverCell:completion:)] ||
            ![type instancesRespondToSelector:@selector(cancel)]) return NULL;
        id object = [[type alloc] init];
        return (void *)CFBridgingRetain(object);
    }
    return NULL;
}
void tk_coreai_load(void *bridge, NSString *path, TKCoreAILoadCompletion completion) {
    [(__bridge id<TKCoreAISelectors>)bridge loadModel:path completion:completion];
}
void tk_coreai_recover(void *bridge, NSString *prompt, TKCoreAICompletion completion) {
    [(__bridge id<TKCoreAISelectors>)bridge recoverCell:prompt completion:completion];
}
void tk_coreai_cancel(void *bridge) { [(__bridge id<TKCoreAISelectors>)bridge cancel]; }
void tk_coreai_release(void *bridge) { tk_coreai_cancel(bridge); CFRelease(bridge); }
