#import <AppKit/AppKit.h>

#import "../shared/renderer.h"
#import "../spi/QuartzCoreSPI.h"

@interface LocalRenderer : NSView
@end

@implementation LocalRenderer {
  CAContext* _context;
  CALayer* _color_layer;
}

- (instancetype)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
		_context = [CAContext contextWithCGSConnection:CGSMainConnectionID() options:@{
			kCAContextCIFilterBehavior: @"ignore",
		}];
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.blueColor.CGColor;
    _color_layer = [CALayer new];
    _color_layer.backgroundColor = NSColor.redColor.CGColor;
    self.layer.sublayers = @[_color_layer];
		_context.layer = self.layer;
  }
  return self;
}

- (void)getContextId:(void(^)(uint32_t))cb {
  cb(_context.contextId);
}
- (void)setSize:(NSSize)size scaleFactor:(CGFloat)scaleFactor fence:(mach_port_t)fence cb:(void(^)(mach_port_t))cb {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [CATransaction begin];
    [CATransaction setAnimationDuration:0];
    [self setFrameSize:NSMakeSize(1000, 1000)];
    _color_layer.bounds = NSMakeRect(0, 0, size.width * 2, size.height * 2);
    mach_port_t fence = [self.layer.context createFencePort];
    [self.layer.context setFencePort:fence commitHandler:^{
      NSLog(@"remote commit handler");
    }];
    // mach_port_deallocate(mach_task_self(), fence);
    cb(fence);
    NSLog(@"remote will commit");
    [CATransaction commit];
    NSLog(@"remote flushed");
  });
}
@end

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
  [CATransaction begin];
  super.frameSize = newSize;
  CGFloat scaleFactor = [self convertSize:NSMakeSize(1, 1) toView:nil].width;
  //NSCGSFence* fence = [[NSClassFromString(@"NSCGSFence") alloc] initWithPort:[self.layer.context createFencePort]];
  // mach_port_t fence = [self.layer.context createFencePort];
  // NSLog(@"Created fence: %d", fence);
	// mach_port_rights_t srights = -1;
	// mach_port_get_srights(mach_task_self(), fence, &srights);
	// NSLog(@"port has send rights: %d", srights);
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  //mach_port_t fence = [self.layer.context createFencePort];
  //[self.layer.context setFencePort:fence commitHandler:^{
  //  NSLog(@"Local commit!!!");
  //}];
  __block mach_port_t fence;
  [(LocalRenderer*)_renderer setSize:newSize scaleFactor:scaleFactor fence:0 cb:^(mach_port_t fenceIn){
    fence = fenceIn;
    dispatch_semaphore_signal(sema);
  }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  [_layerHost.context setFencePort:fence];
  mach_port_mod_refs(mach_task_self(), fence, MACH_PORT_RIGHT_SEND, -1);
  NSLog(@"local unreffed");
  [CATransaction commit];
  NSLog(@"local committed");
}
@end

#import <objc/runtime.h>

int main() {
  class_addProtocol(NSClassFromString(@"NSCGSFence"), @protocol(NSSecureCoding));

	CGRect rect = CGRectMake(0, 0, 200, 200);
	NSWindow* window = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];

  // NSXPCConnection* connection = [[NSXPCConnection alloc] initWithServiceName:@"example.renderer"];
  // connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Renderer)];
  // [connection resume];
  // id<Renderer> renderer = connection.remoteObjectProxy;
  id<Renderer> renderer = (id<Renderer>)[[LocalRenderer alloc] initWithFrame:NSZeroRect];

  window.contentView = [[RendererView alloc] initWithRenderer:renderer];

	[window makeKeyAndOrderFront:nil];
	[[NSApplication sharedApplication] run];
}
