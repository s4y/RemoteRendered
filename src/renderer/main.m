#include <AppKit/AppKit.h>

#import "../shared/fence.h"
#import "../spi/QuartzCore.h"
#import "../spi/xpc.h"

static const CGFloat kStandardPadding = 8;

static void XPCReply(xpc_connection_t conn, xpc_object_t m, void(^f)(xpc_object_t)) {
	xpc_object_t reply = xpc_dictionary_create_reply(m);
	f(reply);
	xpc_connection_send_message(conn, reply);
}

static NSButton* MakeButton(NSString* title) {
	NSButton* button = [NSButton new];
	button.translatesAutoresizingMaskIntoConstraints = NO;
	button.title = title;
	button.bezelStyle = NSRoundedBezelStyle;
	return button;
}

static NSStackView* MakeStackView(void(^f)(NSStackView*)) {
	NSStackView* stackView = [NSStackView new];
	f(stackView);
	return stackView;
}

static void handle_connection(xpc_connection_t peer) {

	// Gratuitous Auto Layout ahead.
	NSStackView* view = MakeStackView(^(NSStackView* stackView){
		stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
		stackView.edgeInsets = NSEdgeInsetsMake(kStandardPadding, kStandardPadding, kStandardPadding, kStandardPadding);
		[stackView addView:MakeStackView(^(NSStackView* stackView){
			[stackView setHuggingPriority:0 forOrientation:NSLayoutConstraintOrientationHorizontal];
			[stackView addView:MakeButton(@"A") inGravity:NSStackViewGravityLeading];
			[stackView addView:MakeButton(@"B") inGravity:NSStackViewGravityTrailing];
		}) inGravity:NSStackViewGravityTop];
		[stackView addView:MakeStackView(^(NSStackView* stackView){
			[stackView setHuggingPriority:0 forOrientation:NSLayoutConstraintOrientationHorizontal];
			[stackView addView:MakeButton(@"C") inGravity:NSStackViewGravityLeading];
			[stackView addView:MakeButton(@"D") inGravity:NSStackViewGravityTrailing];
		}) inGravity:NSStackViewGravityBottom];
	});
	// Now exiting Auto Layout Zone.

	view.wantsLayer = YES;
	view.layer.opaque = YES;
	view.layer.backgroundColor = NSColor.blueColor.CGColor;

	CAContext* context = [CAContext contextWithCGSConnection:CGSMainConnectionID()
													 options:@{ kCAContextCIFilterBehavior: @"ignore" }];
	context.layer = view.layer;
	[CATransaction flush];

	xpc_connection_set_target_queue(peer, dispatch_get_main_queue());
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
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
			mach_port_t fence = FenceForCATransactionPhase(kCATransactionPhasePreCommit);
			xpc_dictionary_set_mach_send(m, "fence", fence);
			mach_port_deallocate(mach_task_self(), fence);
		});

		mach_port_t remote_fence = xpc_dictionary_copy_mach_send(event, "fence");

		[CATransaction addCommitHandler:^{
			mach_port_deallocate(mach_task_self(), remote_fence);
		} forPhase:kCATransactionPhasePostCommit];

		[view layoutSubtreeIfNeeded];
		[view displayIfNeeded];
	});
	xpc_connection_resume(peer);
}

int main() {
	xpc_main(handle_connection);
}
