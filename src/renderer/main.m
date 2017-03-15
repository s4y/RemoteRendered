#include <xpc/xpc.h>
#include <AppKit/AppKit.h>
#include <QuartzCore/QuartzCore.h>

#import "../spi/QuartzCoreSPI.h"

static void handle_connection(xpc_connection_t peer) {
	CGRect rect = CGRectMake(0, 0, 100, 100);
	NSView* view = [[NSView alloc] initWithFrame:rect];
	view.wantsLayer = YES;
	view.layer.opaque = YES;
	view.layer.backgroundColor = NSColor.blueColor.CGColor;

	CALayer* colorLayer = [CALayer layer];
	colorLayer.bounds = rect;
	colorLayer.backgroundColor = NSColor.blueColor.CGColor;

	CAContext* context = [CAContext contextWithCGSConnection:CGSMainConnectionID()
													 options:@{ @"kCAContextCIFilterBehavior": @"ignore" }];

	xpc_connection_set_event_handler(peer, ^(xpc_object_t event __unused) {
		xpc_connection_send_message(peer, xpc_dictionary_create((const char*[]){
			"contextID",
		}, (xpc_object_t[]){
			xpc_uint64_create(context.contextId),
		}, 1));
	});

	xpc_connection_resume(peer);
}

int main() {
	xpc_main(handle_connection);
}
