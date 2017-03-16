#import <AppKit/AppKit.h>

#import "../shared/renderer.h"
#import "../spi/QuartzCoreSPI.h"

@interface OS_OBJECT_CLASS(xpc_object)
@end

@interface OS_OBJECT_CLASS(xpc_object)(SecureCoding)<NSSecureCoding>
@end

@implementation OS_OBJECT_CLASS(xpc_object)(SecureCoding)
+ (BOOL)supportsSecureCoding {
  return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder * __unused)aDecoder{return nil;}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  if (![aCoder isKindOfClass:[NSClassFromString(@"NSXPCEncoder") class]]) {
    abort();
  }
  NSLog(@"GOGOGO");
  [(NSXPCEncoder*)aCoder encodeXPCObject:(xpc_object_t)self forKey:@"xpc"];
}
@end

@interface RendererView : NSView
@end

@implementation RendererView {
  id<Renderer> _renderer;
}

- (instancetype)initWithRenderer:(id<Renderer>)renderer {
  if ((self = [super initWithFrame:NSZeroRect])) {
    _renderer = renderer;
    self.wantsLayer = YES;
  }
  return self;
}

- (CALayer*)makeBackingLayer {
  CALayerHost* layerHost = [CALayerHost layer];
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [_renderer getContextId:^(uint32_t contextId) {
    layerHost.contextId = contextId;
    [CATransaction flush];
    dispatch_semaphore_signal(sema);
  }];
	dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  return layerHost;
}

- (void)setFrameSize:(NSSize)newSize {
  super.frameSize = newSize;
  CGFloat scaleFactor = [self convertSize:NSMakeSize(1, 1) toView:nil].width;
  xpc_object_t xfence = xpc_mach_send_create([self.layer.context createFencePort]);
  // mach_port_t fence = [self.layer.context createFencePort];
  // NSLog(@"Created fence: %d", fence);
	// mach_port_rights_t srights = -1;
	// mach_port_get_srights(mach_task_self(), fence, &srights);
	// NSLog(@"port has send rights: %d", srights);
  //dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [_renderer setSize:newSize scaleFactor:scaleFactor fence:xfence cb:^{
    //dispatch_semaphore_signal(sema);
  }];
  //dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
}
@end

int main() {
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
