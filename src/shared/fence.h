#include <mach/mach.h>

#import "../spi/QuartzCore.h"

mach_port_t FenceForCATransactionPhase(CATransactionPhase phase) {
	mach_port_t fence;
	mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &fence);
	mach_port_insert_right(mach_task_self(), fence, fence, MACH_MSG_TYPE_MAKE_SEND);
	mach_port_t previous;
	mach_port_request_notification(mach_task_self(), fence, MACH_NOTIFY_NO_SENDERS, 0, fence, MACH_MSG_TYPE_MAKE_SEND_ONCE, &previous);
	[CATransaction addCommitHandler:^{
		mach_no_senders_notification_t msg = {0};
		mach_msg(&msg.not_header, MACH_RCV_MSG, 0, sizeof(msg), fence, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
		mach_port_destroy(mach_task_self(), fence);
	} forPhase:phase];
	return fence;
}
