#import <AppKit/AppKit.h>

#import "../spi/QuartzCoreSPI.h"

int main() {
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	CGRect rect = CGRectMake(0, 0, 200, 200);

	NSWindow* window = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.contentView.wantsLayer = YES;

	CGFloat contentsScale = window.backingScaleFactor;
	NSLog(@"contentsScale: %f", contentsScale);

	xpc_connection_t c = xpc_connection_create("example.renderer", NULL);
	xpc_connection_set_event_handler(c, ^(xpc_object_t event) {
		CALayerHost* layerHost = [CALayerHost layer];
		uint64_t contextId = xpc_dictionary_get_uint64(event, "contextID");
		layerHost.contextId = contextId;
		NSLog(@"Set contextId to %llu, now %d", contextId, layerHost.contextId);
		window.contentView.layer.sublayers = @[layerHost];
		dispatch_semaphore_signal(sema);
	});
	xpc_connection_resume(c);
	NSLog(@"Resumed");

	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
	xpc_connection_send_message(c, message);

	dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

	[window makeKeyAndOrderFront:nil];
	[[NSApplication sharedApplication] run];
}
