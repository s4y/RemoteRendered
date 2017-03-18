#include <AppKit/AppKit.h>
#include <QuartzCore/QuartzCore.h>

#import "../spi.h"

xpc_object_t XPCDict(void(^f)(xpc_object_t)) {
	xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
	f(dict);
	return dict;
}

xpc_object_t XPCSync(xpc_connection_t conn, void(^f)(xpc_object_t)) {
	return xpc_connection_send_message_with_reply_sync(conn, XPCDict(f));
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
	xpc_object_t reply = XPCSync(_connection, ^(xpc_object_t m) {
		xpc_dictionary_set_bool(m, "getContextId", true);
	});
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
	if (context == nil) { return; }

	xpc_object_t reply = XPCSync(_connection, ^(xpc_object_t m) {
		NSSize size = self.frame.size;
		xpc_dictionary_set_double(m, "width", size.width);
		xpc_dictionary_set_double(m, "height", size.height);

		mach_port_t fence = [context createFencePort];
		xpc_dictionary_set_mach_send(m, "fence", fence);
		mach_port_deallocate(mach_task_self(), fence);
	});

	mach_port_t remote_fence = xpc_dictionary_copy_mach_send(reply, "fence");

	[CATransaction addCommitHandler:^{
		mach_port_deallocate(mach_task_self(), remote_fence);
	} forPhase:kCATransactionPhasePostCommit];
}

@end

int main() {
	CGRect rect = CGRectMake(10, 10, 200, 200);

	xpc_connection_t c = xpc_connection_create("example.renderer", NULL);
	NSWindow* window = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
	RendererView* rendererView = [[RendererView alloc] initWithFrame:NSZeroRect connection:c];
	window.contentView = rendererView;

	[window makeKeyAndOrderFront:nil];
	[[NSApplication sharedApplication] run];
}
