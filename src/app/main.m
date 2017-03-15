#import <AppKit/AppKit.h>

#import "../spi/QuartzCoreSPI.h"

int main() {

	CAContext* context = [CAContext contextWithCGSConnection:CGSMainConnectionID()
													 options:@{ @"kCAContextCIFilterBehavior": @"ignore" }];
	NSLog(@"context: %@", context);
	NSLog(@"context.layer: %@", context.layer);

	CGRect rect = CGRectMake(0, 0, 200, 200);

	NSView* view = [[NSView alloc] initWithFrame:rect];
	view.wantsLayer = YES;
	view.layer.opaque = YES;
	view.layer.backgroundColor = NSColor.blueColor.CGColor;
	context.layer = view.layer;

	NSButton* button = [NSButton new];
	button.title = @"Legit?";
	button.bezelStyle = NSRoundedBezelStyle;
	[button sizeToFit];
	[button setNeedsDisplay:YES];
	[view addSubview:button];
	[view layoutSubtreeIfNeeded];

	CALayerHost* layerHost = [CALayerHost layer];
	layerHost.contextId = context.contextId;

	NSWindow* window = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.contentView.layer = layerHost;
	window.contentView.wantsLayer = YES;
	[window makeKeyAndOrderFront:nil];

	CGFloat contentsScale = window.backingScaleFactor;
	NSLog(@"contentsScale: %f", contentsScale);

	xpc_connection_t c = xpc_connection_create("example.renderer", NULL);
	xpc_connection_set_event_handler(c, ^(xpc_object_t event) {
		NSLog(@"Event! %@", event);
	});
	xpc_connection_resume(c);
	NSLog(@"Resumed");

	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64(message, "foo", 1);
	xpc_connection_send_message(c, message);
	xpc_release(message);

	[[NSApplication sharedApplication] run];
}
