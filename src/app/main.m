#import <AppKit/AppKit.h>

#import "../shared/renderer.h"
#import "../spi/QuartzCoreSPI.h"

@interface RendererView : NSView
@end

@implementation RendererView {
  id<Renderer> _renderer;
  CALayerHost* _layerHost;
}

- (instancetype)initWithRenderer:(id<Renderer>)renderer {
  if ((self = [super initWithFrame:NSZeroRect])) {
    _renderer = renderer;
    self.wantsLayer = YES;
    _layerHost = [CALayerHost layer];
    self.layer.sublayers = @[_layerHost];

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_renderer getContextId:^(uint32_t contextId) {
      _layerHost.contextId = contextId;
      [CATransaction flush];
      dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  }
  return self;
}

- (void)setFrameSize:(NSSize)newSize {
  super.frameSize = newSize;
  CGFloat scaleFactor = [self convertSize:NSMakeSize(1, 1) toView:nil].width;
  NSCGSFence* fence = [[NSClassFromString(@"NSCGSFence") alloc] initWithPort:[self.layer.context createFencePort]];
  if (!fence.isValid) {
    return;
  }
  NSLog(@"Created fence: %@", fence);
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [_renderer setSize:newSize scaleFactor:scaleFactor fence:fence cb:^(){
     dispatch_semaphore_signal(sema);
  }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  NSLog(@"Invalidated fence: %u", fence.port);
}
@end

#import <objc/runtime.h>

int main() {
  class_addProtocol(NSClassFromString(@"NSCGSFence"), @protocol(NSSecureCoding));

	CGRect rect = CGRectMake(0, 0, 200, 200);
	NSWindow* window = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];

  NSXPCConnection* connection = [[NSXPCConnection alloc] initWithServiceName:@"example.renderer"];
  connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Renderer)];
  [connection resume];
  id<Renderer> renderer = connection.remoteObjectProxy;

  window.contentView = [[RendererView alloc] initWithRenderer:renderer];

	[window makeKeyAndOrderFront:nil];
	[[NSApplication sharedApplication] run];
}
