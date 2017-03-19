#include <AppKit/AppKit.h>

#import "../spi/QuartzCore.h"
#import "../spi/xpc.h"

// Calls the passed block with an empty XPC dictionary, then returns that
// dictionary. Just a concise way to build a message.
static xpc_object_t XPCDict(void(^fill)(xpc_object_t)) {
	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
	fill(message);
	return message;
}

@interface RendererView : NSView
@end

@implementation RendererView {
	xpc_connection_t _connection;
}

- (instancetype)initWithFrame:(NSRect)frame connection:(xpc_connection_t)connection {
	if ((self = [super initWithFrame:frame])) {
		_connection = connection;
		xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
			NSLog(@"incoming: %@", event);
		});
		xpc_connection_resume(_connection);
		self.wantsLayer = YES;
	}
	return self;
}

- (CALayer*)makeBackingLayer {
	CALayerHost* layerHost = [[CALayerHost alloc] init];

	// Using synchronous XPC here and in updateGeometry means that the remote
	// view is never shown in an intermediate state, and avoids the MacViews
	// workaround of making windows invisible until first paint. In both cases,
	// the renderer should do minimal work before it replies — the slow stuff
	// uses CA fences which block as late as possible.
	xpc_object_t reply = xpc_connection_send_message_with_reply_sync(_connection, XPCDict(^(xpc_object_t m) {
		xpc_dictionary_set_bool(m, "getContextId", true);
	}));
	layerHost.contextId = xpc_dictionary_get_uint64(reply, "contextId");
	return layerHost;
}

- (void)setFrameSize:(NSSize)newSize {
	[super setFrameSize:newSize];
	[self updateGeometry];
}

- (void)viewDidChangeBackingProperties {
	[self updateGeometry];
}

- (void)updateGeometry {
	CAContext* context = self.layer.context;

	// The view will only have a context if it's in a window.
	if (context == nil) {
		return;
	}

	const NSSize size = self.frame.size;
	xpc_object_t reply = xpc_connection_send_message_with_reply_sync(_connection, XPCDict(^(xpc_object_t m) {
		xpc_dictionary_set_double(m, "width", size.width);
		xpc_dictionary_set_double(m, "height", size.height);

		// This fence lets the renderer delay the app's commit. The renderer is
		// doing very little layout work in this example, but commenting out
		// these lines and adding usleep(20000) near the bottom of the
		// renderer's event handler effectively demonstrates the failure mode
		// without this fence. CA fences have a ~1s timeout.
		mach_port_t fence = [context createFencePort];
		xpc_dictionary_set_mach_send(m, "fence", fence);
		mach_port_deallocate(mach_task_self(), fence);
	}));

	mach_port_t remote_fence = xpc_dictionary_copy_mach_send(reply, "fence");

	[CATransaction addCommitHandler:^{
		// When this PostCommit handler runs, the app has a fence with the
		// window server (if you pause here in a debugger, you'll see the
		// changes flush to the screen after the ~1s timeout). The renderer's
		// CA fence is signaled here, and it updates in sync with the main
		// process. Signal it earlier, it displays a frame *before* the main
		// process. Signal it later, it'll be a frame behind. This took the
		// longest to figure out, because CAContext has a -setFence: method
		// that can accept a fence from another process, but it signals those
		// fences just before the PreCommit phase, causing the remote content
		// to update ahead of the main process.
		//
		// I'm not sure if that's a bug or just incomplete understanding of
		// this API on my part, but it's worth noting that WebKit uses
		// -setFence:, which explains why Safari window resizing is so glitchy,
		// especially from the left edge.
		mach_port_deallocate(mach_task_self(), remote_fence);
	} forPhase:kCATransactionPhasePostCommit];
}

@end

int main() {
	NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(10, 10, 200, 200)
												   styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable
													 backing:NSBackingStoreBuffered
													   defer:NO];

	xpc_connection_t c = xpc_connection_create("example.renderer", NULL);
	RendererView* rendererView = [[RendererView alloc] initWithFrame:NSZeroRect connection:c];
	window.contentView = rendererView;

	[window makeKeyAndOrderFront:nil];
	[[NSApplication sharedApplication] run];
}
