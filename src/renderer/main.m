#include <xpc/xpc.h>
#include <AppKit/AppKit.h>
#include <QuartzCore/QuartzCore.h>

#import "../shared/renderer.h"
#import "../spi/QuartzCoreSPI.h"

@interface RendererImpl : NSObject<Renderer>
@end

@implementation RendererImpl {
	CAContext* _context;
	NSView* _view;
}

- (instancetype)init {
	if ((self = [super init])) {
		_view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
		_view.wantsLayer = YES;
		_view.layer.opaque = YES;
		_view.layer.backgroundColor = NSColor.blueColor.CGColor;

		NSButton* button = [NSButton new];
		button.title = @"Legit?";
		button.bezelStyle = NSRoundedBezelStyle;
		[button sizeToFit];
		[_view addSubview:button];

		_context = [CAContext contextWithCGSConnection:CGSMainConnectionID() options:@{
			kCAContextCIFilterBehavior: @"ignore",
		}];
		_context.layer = _view.layer;

		[_view layoutSubtreeIfNeeded];
		[CATransaction flush];
  }
  return self;
}

- (void)getContextId:(void(^)(uint32_t))cb {
  cb(_context.contextId);
}

- (void)setSize:(NSSize)size scaleFactor:(CGFloat)scaleFactor fence:(NSCGSFence*)fence cb:(void(^)())cb {
	NSLog(@"got fence: %@, port: %d, valid: %d", fence, fence.port, fence.isValid);
	mach_port_rights_t srights = -1;
	mach_port_get_srights(mach_task_self(), fence.port, &srights);
	NSLog(@"port has send rights: %d", srights);
	[_context setFencePort:fence.port];
	_view.frameSize = size;
	[CATransaction flush];
	cb();
}

@end

@interface ListenerDelegate : NSObject<NSXPCListenerDelegate>
@end

@implementation ListenerDelegate

- (BOOL)listener:(NSXPCListener * __unused)listener shouldAcceptNewConnection:(NSXPCConnection *)connection {
	connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Renderer)];
  connection.exportedObject = [RendererImpl new];
	[connection resume];
  return YES;
}

@end

#if 0
static void handle_connection(xpc_connection_t peer) {

	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			xpc_transaction_end();
			return;
		}

		xpc_connection_send_message(peer, xpc_dictionary_create((const char*[]){
			"contextID",
		}, (xpc_object_t[]){
			xpc_uint64_create(context.contextId),
		}, 1));
		xpc_transaction_begin();
	});

	xpc_connection_resume(peer);
}
#endif

#import <objc/runtime.h>

int main() {
  class_addProtocol(NSClassFromString(@"NSCGSFence"), @protocol(NSSecureCoding));
	NSXPCListener* listener = [NSXPCListener serviceListener];
	ListenerDelegate* listenerDelegate = [ListenerDelegate new];
	listener.delegate = listenerDelegate;
	[listener resume];
}
