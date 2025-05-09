#include <objc/runtime.h>
#include <objc/message.h>
#include <Foundation/Foundation.h>

@interface HookInjector : NSObject

+ (void)installHooksFromPlist:(NSDictionary *)plist;

@end

static NSMutableSet *gSwizzledClasses;
static NSMutableDictionary *gHookConfig;
static void swizzleForwardInvocationForClass(Class cls);