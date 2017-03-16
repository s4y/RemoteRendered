#import <AppKit/AppKit.h>

#import "../spi/QuartzCoreSPI.h"

@protocol Renderer
- (void)getContextId:(void(^)(uint32_t))cb;
- (void)setSize:(NSSize)size scaleFactor:(CGFloat)scaleFactor fence:(NSCGSFence*)fence cb:(void(^)())cb;
@end
