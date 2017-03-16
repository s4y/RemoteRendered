#import <AppKit/AppKit.h>

#import "../spi/QuartzCoreSPI.h"

xpc_object_t xpc_mach_send_create(mach_port_t);

@interface RendererView : NSView
@end

@implementation RendererView {
	xpc_connection_t _connection;
}

- (instancetype)initWithFrame:(NSRect)frame connection:(xpc_connection_t)connection {
	if ((self = [super initWithFrame:frame])) {
		self.wantsLayer = YES;
		_connection = connection;

		__weak RendererView* weakSelf = self;
		xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
			uint64_t contextId = xpc_dictionary_get_uint64(event, "contextID");
			if (contextId != 0) {
				((CALayerHost*)self.layer).contextId = contextId;
			}
			[CATransaction flush];
		});
	}
	return self;
}

- (CALayer*)makeBackingLayer {
	return [[CALayerHost alloc] init];
}

- (void)setFrameSize:(NSSize)newSize {
	super.frameSize = newSize;
	mach_port_t fence = [self.layer.context createFencePort];
	const char* keys[] = {
		"width",
		"height",
		"fence",
	};
	xpc_object_t values[] = {
		xpc_double_create(newSize.width),
		xpc_double_create(newSize.height),
		xpc_mach_send_create(fence),
	};
	NSLog(@"Sending fence: %@", values[2]);
	xpc_object_t message = xpc_dictionary_create(keys, values, sizeof(keys)/sizeof(keys[0]));
	xpc_connection_send_message(_connection, message);
	//mach_port_deallocate(mach_task_self(), fence);
}

@end

int main() {
	//dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	CGRect rect = CGRectMake(0, 0, 200, 200);

	xpc_connection_t c = xpc_connection_create("example.renderer", NULL);
	// xpc_connection_set_event_handler(c, ^(xpc_object_t event) {
	// 	CALayerHost* layerHost = [CALayerHost layer];
	// 	uint64_t contextId = xpc_dictionary_get_uint64(event, "contextID");
	// 	layerHost.contextId = contextId;
	// 	NSLog(@"Set contextId to %llu, now %d", contextId, layerHost.contextId);
	// 	window.contentView.layer.sublayers = @[layerHost];
	// 	//dispatch_semaphore_signal(sema);
	// });

	NSWindow* window = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
	RendererView* rendererView = [[RendererView alloc] initWithFrame:NSZeroRect connection:c];
	window.contentView = rendererView;
	xpc_connection_resume(c);

	// xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
	// xpc_connection_send_message(c, message);

	// dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

	[window makeKeyAndOrderFront:nil];
	[[NSApplication sharedApplication] run];
}
