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
	BOOL _inTransaction;
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

	if (!_inTransaction) {
		[CATransaction begin];
	}

	_inTransaction = YES;

	NSLog(@"begin");

	xpc_connection_send_message_with_reply(_connection, XPCDict(^(xpc_object_t m) {
		const NSSize size = self.frame.size;
		xpc_dictionary_set_double(m, "width", size.width);
		xpc_dictionary_set_double(m, "height", size.height);
	}), dispatch_get_main_queue(), ^(xpc_object_t reply){
		NSLog(@"A");
		[CATransaction addCommitHandler:^{
			NSLog(@"B");
			xpc_object_t ev = xpc_connection_send_message_with_reply_sync(_connection, xpc_dictionary_create_reply(reply));
			xpc_connection_send_message(_connection, xpc_dictionary_create_reply(ev));
			NSLog(@"B.1");
			_inTransaction = NO;
		} forPhase:kCATransactionPhasePostCommit];
		NSLog(@"commit go");
		[CATransaction commit];
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
