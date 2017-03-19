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

// Sends an XPC message, then calls the reply handler in the PreLayout phase of
// the current CATransaction. xpc_connection_send_message_with_reply_sync()
// would also work, but this way the app blocks only if the reply hasn't
// arrived by commit time.
static void SendXPCMessageWithReplyBlockingCATransaction(xpc_connection_t conn, xpc_object_t message, void(^handler)(xpc_object_t)) {
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	__block xpc_object_t reply;
	xpc_connection_send_message_with_reply(conn, message, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(xpc_object_t reply_in) {
		reply = reply_in;
		dispatch_semaphore_signal(sema);
	});
	[CATransaction addCommitHandler:^{
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
		handler(reply);
	} forPhase:kCATransactionPhasePreLayout];
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

	// Blocking the CATransaction from here and updateGeometry means that the
	// remote view is never shown in an intermediate state, and avoids the
	// MacViews workaround of making windows invisible until first paint.
	SendXPCMessageWithReplyBlockingCATransaction(_connection, XPCDict(^(xpc_object_t m) {
		xpc_dictionary_set_bool(m, "getContextId", true);
	}), ^(xpc_object_t reply){
		layerHost.contextId = xpc_dictionary_get_uint64(reply, "contextId");
	});
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
	if (context == nil) { return; }

	SendXPCMessageWithReplyBlockingCATransaction(_connection, XPCDict(^(xpc_object_t m) {
		NSSize size = self.frame.size;
		xpc_dictionary_set_double(m, "width", size.width);
		xpc_dictionary_set_double(m, "height", size.height);

		// This fence lets the renderer delay the app's commit. In this
		// example, the renderer is doing very little layout and won't need to,
		// but commenting out these lines and adding usleep(20000) near the
		// bottom of the renderer's event handler effectively demonstrates the
		// failure mode without it. CA fences have a ~1s timeout.
		mach_port_t fence = [context createFencePort];
		xpc_dictionary_set_mach_send(m, "fence", fence);
		mach_port_deallocate(mach_task_self(), fence);
	}), ^(xpc_object_t reply){
		mach_port_t remote_fence = xpc_dictionary_copy_mach_send(reply, "fence");

		[CATransaction addCommitHandler:^{
			// When this PostCommit handler runs, the app has a fence with the
			// window server: if you pause inside it in a debugger, you'll see
			// the changes flush to the screen after the ~1s timeout. The
			// renderer's CA fence is signaled here, which lets it update in
			// sync with the app. Signal it any earlier and displays a frame
			// *ahead* of the app. Signal it later, it's a frame behind. This
			// took the longest to figure out, because CAContext already has a
			// -setFence: method that can accept a fence from another process.
			// But, fences set that way are signaled in the PreCommit phase,
			// so the remote content updates ahead of the rest of the app.
			//
			// I'm not sure if that's a bug or just incomplete understanding of
			// this API, but it's worth noting that WebKit uses -setFence:,
			// which explains why Safari (and Chrome?) window resizing,
			// especially from the left edge, is so glitchy.
			mach_port_deallocate(mach_task_self(), remote_fence);
		} forPhase:kCATransactionPhasePostCommit];
	});
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
