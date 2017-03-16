#import <QuartzCore/QuartzCore.h>

XPC_EXPORT
XPC_TYPE(_xpc_type_mach_send);

XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_mach_send_create(mach_port_t value);

mach_port_t
xpc_mach_send_get_right(xpc_object_t xmach_send);

@interface NSXPCCoder : NSCoder
@end

@interface NSXPCEncoder : NSXPCCoder
- (void)encodeXPCObject:(xpc_object_t)obj forKey:(NSString*)key;
@end

@interface NSXPCDecoder : NSXPCCoder
- (id)decodeXPCObjectOfType:(struct _xpc_type_s *)arg1 forKey:(id)arg2;
@end


typedef uint32_t CGSConnectionID;
CGSConnectionID CGSMainConnectionID(void);

extern NSString * const kCAContextCIFilterBehavior;

@interface CATransaction()
+ (void)synchronize;
@end

@interface CAContext : NSObject
@end

@interface CAContext ()
+ (NSArray *)allContexts;
+ (CAContext *)contextWithCGSConnection:(CGSConnectionID)connectionID options:(NSDictionary *)options;
+ (CAContext *)remoteContextWithOptions:(NSDictionary *)dict;
+ (id)objectForSlot:(uint32_t)name;
- (uint32_t)createImageSlot:(CGSize)size hasAlpha:(BOOL)flag;
- (void)deleteSlot:(uint32_t)name;
- (void)invalidate;
- (void)invalidateFences;
- (mach_port_t)createFencePort;
- (void)setFencePort:(mach_port_t)port;
- (void)setFencePort:(mach_port_t)port commitHandler:(void(^)(void))block;
#if TARGET_OS_IPHONE && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101200
@property uint32_t commitPriority;
#endif
#if TARGET_OS_MAC
@property BOOL colorMatchUntaggedContent;
#endif
@property (readonly) uint32_t contextId;
@property (strong) CALayer *layer;
@property CGColorSpaceRef colorSpace;
@end

@interface CALayerHost : CALayer
@property () uint32_t contextId;
@end

@interface CALayer ()
- (CAContext *)context;
@end
