#import <QuartzCore/QuartzCore.h>

@interface NSCGSFence : NSObject <NSCoding, NSCopying>

+ (BOOL)supportsSecureCoding;
+ (id)fence;
@property(readonly) unsigned int port;
@property(readonly, getter=isValid) BOOL valid;
- (void)invalidate;
- (void)set;
- (void)dealloc;
- (void)encodeWithCoder:(id)arg1;
- (id)initWithCoder:(id)arg1;
- (id)copyWithZone:(struct _NSZone *)arg1;
- (id)initWithPort:(unsigned int)arg1;
- (id)init;

@end

typedef uint32_t CGSConnectionID;
CGSConnectionID CGSMainConnectionID(void);

extern NSString * const kCAContextCIFilterBehavior;

@interface CATransaction()
+ (void)synchronize;
+ (CATransaction*)currentTransaction;
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
