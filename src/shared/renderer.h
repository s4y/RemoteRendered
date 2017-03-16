#import <AppKit/AppKit.h>

@protocol Renderer
- (void)getContextId:(void(^)(uint32_t))cb;
- (void)setSize:(NSSize)size scaleFactor:(CGFloat)scaleFactor fence:(xpc_object_t)fence cb:(void(^)())cb;
@end
