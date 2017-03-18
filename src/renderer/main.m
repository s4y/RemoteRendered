#include <AppKit/AppKit.h>
#include <QuartzCore/QuartzCore.h>

#import "../spi.h"

void XPCReply(xpc_connection_t conn, xpc_object_t m, void(^f)(xpc_object_t)) {
	xpc_object_t reply = xpc_dictionary_create_reply(m);
	f(reply);
	xpc_connection_send_message(conn, reply);
}

NSButton* MakeButton(NSString* title) {
	NSButton* button = [NSButton new];
	button.translatesAutoresizingMaskIntoConstraints = NO;
	button.title = title;
	button.bezelStyle = NSRoundedBezelStyle;
	[button sizeToFit];
	return button;
}

void xpc_dictionary_set_mach_send(xpc_object_t, const char*, mach_port_t);
mach_port_t xpc_dictionary_copy_mach_send(xpc_object_t, const char*);

static void handle_connection(xpc_connection_t peer) {
	NSView* view = [[NSView alloc] initWithFrame:NSZeroRect];
	view.wantsLayer = YES;
	view.layer.opaque = YES;
	view.layer.backgroundColor = NSColor.blueColor.CGColor;

	{
		NSButton* button = MakeButton(@"A");
		[view addSubview:button];
		[button.topAnchor constraintEqualToAnchor:view.topAnchor].active = YES;
		[button.leadingAnchor constraintEqualToAnchor:view.leadingAnchor].active = YES;
	}

	{
		NSButton* button = MakeButton(@"B");
		[view addSubview:button];
		[button.topAnchor constraintEqualToAnchor:view.topAnchor].active = YES;
		[button.trailingAnchor constraintEqualToAnchor:view.trailingAnchor].active = YES;
	}

	{
		NSButton* button = MakeButton(@"C");
		[view addSubview:button];
		[button.bottomAnchor constraintEqualToAnchor:view.bottomAnchor].active = YES;
		[button.leadingAnchor constraintEqualToAnchor:view.leadingAnchor].active = YES;
	}

	{
		NSButton* button = MakeButton(@"D");
		[view addSubview:button];
		[button.bottomAnchor constraintEqualToAnchor:view.bottomAnchor].active = YES;
		[button.trailingAnchor constraintEqualToAnchor:view.trailingAnchor].active = YES;
	}

	CAContext* context = [CAContext contextWithCGSConnection:CGSMainConnectionID()
													 options:@{ kCAContextCIFilterBehavior: @"ignore" }];
	context.layer = view.layer;

	[CATransaction flush];

	xpc_connection_set_target_queue(peer, dispatch_get_main_queue());
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		// Strong reference for ARC.
		(void)context;

		if (event == XPC_ERROR_CONNECTION_INVALID) {
			return;
		}

		if (xpc_dictionary_get_bool(event, "getContextId")) {
			XPCReply(peer, event, ^(xpc_object_t m) {
				xpc_dictionary_set_uint64(m, "contextId", context.contextId);
			});
			return;
		}

		CGFloat width = xpc_dictionary_get_double(event, "width");
		CGFloat height = xpc_dictionary_get_double(event, "height");
		if (width > 0 && height > 0) {
			[view setFrameSize:NSMakeSize(width, height)];
		}

		XPCReply(peer, event, ^(xpc_object_t m) {
			mach_port_t fence = [context createFencePort];
			xpc_dictionary_set_mach_send(m, "fence", fence);
			mach_port_deallocate(mach_task_self(), fence);
		});

		[view layoutSubtreeIfNeeded];
		[view displayIfNeeded];
	});

	xpc_connection_resume(peer);
}

int main() {
	xpc_main(handle_connection);
}
