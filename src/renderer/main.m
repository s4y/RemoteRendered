#include <xpc/xpc.h>
#include <AppKit/AppKit.h>
#include <QuartzCore/QuartzCore.h>

#import "../spi/QuartzCoreSPI.h"

mach_port_t xpc_dictionary_copy_mach_send(xpc_object_t, const char*);

static void handle_connection(xpc_connection_t peer) {
	NSView* view = [[NSView alloc] initWithFrame:NSZeroRect];
	view.wantsLayer = YES;
	view.layer.opaque = YES;
	view.layer.backgroundColor = NSColor.blueColor.CGColor;

	NSButton* button = [NSButton new];
	button.title = @"Legit?";
	button.bezelStyle = NSRoundedBezelStyle;
	[button sizeToFit];
	[button setNeedsDisplay:YES];
	[view addSubview:button];

	CAContext* context = [CAContext contextWithCGSConnection:CGSMainConnectionID()
													 options:@{ kCAContextCIFilterBehavior: @"ignore" }];
	context.layer = view.layer;

	[view layoutSubtreeIfNeeded];
	[CATransaction flush];

	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			return;
		}

		NSLog(@"incoming: %@", event);

		CGFloat width = xpc_dictionary_get_double(event, "width");
		CGFloat height = xpc_dictionary_get_double(event, "height");
		if (width && height) {
			[view setFrameSize:NSMakeSize(width, height)];
		}

		mach_port_t fence = xpc_dictionary_copy_mach_send(event, "fence");
		NSLog(@"we get fence: %d", fence);
		if (fence != MACH_PORT_NULL) {
			struct mach_port_status status = {0};
			mach_msg_type_number_t count = MACH_PORT_RECEIVE_STATUS_COUNT;
			mach_port_get_attributes(mach_task_self(), fence, MACH_PORT_RECEIVE_STATUS, (mach_port_info_t)&status, &count);
			NSLog(@"srights: %d", status.mps_srights);
			NSLog(@"set fence to %d", fence);
			[view.layer.context setFencePort:fence];
		}

		xpc_connection_send_message(peer, xpc_dictionary_create((const char*[]){
			"contextID",
		}, (xpc_object_t[]){
			xpc_uint64_create(context.contextId),
		}, 1));

		[CATransaction flush];
	});

	xpc_connection_resume(peer);
}

int main() {
	xpc_main(handle_connection);
}
