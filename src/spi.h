#import <QuartzCore/QuartzCore.h>

void xpc_dictionary_set_mach_send(xpc_object_t, const char*, mach_port_t);
mach_port_t xpc_dictionary_copy_mach_send(xpc_object_t, const char*);

typedef uint32_t CGSConnectionID;
CGSConnectionID CGSMainConnectionID(void);

extern NSString * const kCAContextCIFilterBehavior;

@interface CAContext : NSObject
+ (CAContext *)contextWithCGSConnection:(CGSConnectionID)connectionID options:(NSDictionary *)options;
- (mach_port_t)createFencePort;
- (void)setFencePort:(mach_port_t)port;
@property (readonly) uint32_t contextId;
@property (strong) CALayer *layer;
@end

@interface CALayerHost : CALayer
@property uint32_t contextId;
@end

@interface CALayer ()
@property(readonly) CAContext* context;
@end

typedef enum {
    kCATransactionPhasePreLayout,
    kCATransactionPhasePreCommit,
    kCATransactionPhasePostCommit,
} CATransactionPhase;

@interface CATransaction ()
+ (void)addCommitHandler:(void(^)(void))block forPhase:(CATransactionPhase)phase;
@end

