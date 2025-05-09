#import "420Crackz.h"

static NSString *getCurrentBundleID() {
	return [[NSBundle mainBundle] bundleIdentifier];
}

static NSString *getCurrentAppVersion() {
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

static NSComparisonResult compareVersions(NSString *v1, NSString *v2) {
	return [v1 compare:v2 options:NSNumericSearch];
}

static id lookupPlistReturnValue(NSString *className, NSString *methodName) {
	NSString *bundleID = getCurrentBundleID();
	NSDictionary *classMap = gHookConfig[bundleID][@"Hooks"][@"Class"];
	NSDictionary *methods = classMap[className];

	if (!methods) {
		for (NSString *key in classMap) {
			if ([className containsString:key]) {
				methods = classMap[key];
				break;
			}
		}
	}
	
	id returnValue = methods[methodName];
	return ([returnValue isKindOfClass:[NSNull class]]) ? nil : returnValue;
}

static void (*orig_forwardInvocation)(id, SEL, NSInvocation *) = NULL;

void swizzled_forwardInvocation(id self, SEL _cmd, NSInvocation *invocation) {
	SEL selector = invocation.selector;
	NSString *methodName = NSStringFromSelector(selector);
	NSString *className = NSStringFromClass([self class]);

	id returnValue = lookupPlistReturnValue(className, methodName);
	const char *returnType = invocation.methodSignature.methodReturnType;

	if (strcmp(returnType, @encode(BOOL)) == 0) {
		BOOL val = [returnValue boolValue];
		[invocation setReturnValue:&val];
		return;
	}

	if (strcmp(returnType, @encode(id)) == 0 || returnType[0] == '@') {
		if (!returnValue) returnValue = nil;
		[invocation setReturnValue:&returnValue];
		return;
	}

	if (returnValue) {
		if (strcmp(returnType, @encode(void)) == 0) {
			return;
		} else if (strcmp(returnType, @encode(Class)) == 0) {
			Class val = NSClassFromString(returnValue);
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(SEL)) == 0) {
			SEL val = NSSelectorFromString(returnValue);
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(char *)) == 0) {
			const char *val = [returnValue UTF8String];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(int)) == 0) {
			int val = [returnValue intValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(short)) == 0) {
			short val = [returnValue shortValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(long)) == 0) {
			long val = [returnValue longValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(long long)) == 0) {
			long long val = [returnValue longLongValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(unsigned int)) == 0) {
			unsigned int val = [returnValue unsignedIntValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(unsigned long)) == 0) {
			unsigned long val = [returnValue unsignedLongValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
			unsigned long long val = [returnValue unsignedLongLongValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(float)) == 0) {
			float val = [returnValue floatValue];
			[invocation setReturnValue:&val];
		} else if (strcmp(returnType, @encode(double)) == 0) {
			double val = [returnValue doubleValue];
			[invocation setReturnValue:&val];
		} else {
			NSLog(@"[420Crackz] Unsupported return type %s for [%@ %@]", returnType, className, methodName);
		}
		return;
	}

	if (orig_forwardInvocation) {
		orig_forwardInvocation(self, _cmd, invocation);
	}
}

void swizzleForwardInvocationForClass(Class cls) {
	NSString *bundleID = getCurrentBundleID();

	if ([gSwizzledClasses containsObject:cls]) {
		NSLog(@"[420Crackz] (%@) Class %@ already swizzled", bundleID, cls);
		return;
	}

	[gSwizzledClasses addObject:cls];

	SEL originalSEL = @selector(forwardInvocation:);
	Method originalMethod = class_getInstanceMethod(cls, originalSEL);

	if (originalMethod) {
		orig_forwardInvocation = (void (*)(id, SEL, NSInvocation *))method_getImplementation(originalMethod);
	}

	IMP newIMP = (IMP)swizzled_forwardInvocation;
	const char *types = method_getTypeEncoding(originalMethod);

	class_replaceMethod(cls, originalSEL, newIMP, types);
	NSLog(@"[420Crackz] (%@) Finished swizzling class %@", bundleID, cls);
}

@implementation HookInjector

+ (void)installHooksFromPlist:(NSDictionary *)plist {
	gHookConfig = [plist mutableCopy];
	gSwizzledClasses = [NSMutableSet set];

	NSString *bundleID = getCurrentBundleID();
	NSDictionary *bundleHooks = plist[bundleID];

	NSLog(@"[420Crackz] (%@) Installing hooks from plist", bundleID);

	if (!bundleHooks) {
		NSLog(@"[420Crackz] (%@) No hooks found", bundleID);
		return;
	}

	NSDictionary *classes = bundleHooks[@"Hooks"][@"Class"];
	[classes enumerateKeysAndObjectsUsingBlock:^(NSString *className, NSDictionary *methods, BOOL *stop) {
		Class cls = NSClassFromString(className);
		if (!cls) {
			NSLog(@"[420Crackz] (%@) Class %@ not found", bundleID, className);
			return;
		}
		NSLog(@"[420Crackz] (%@) Class %@ found", bundleID, className);

		NSLog(@"[420Crackz] (%@) Swizzling class %@", bundleID, className);
		swizzleForwardInvocationForClass(cls);

		[methods enumerateKeysAndObjectsUsingBlock:^(NSString *methodName, id returnValue, BOOL *stop) {
			NSString *bundleID = getCurrentBundleID();

			SEL selector = NSSelectorFromString(methodName);
			Method m = class_getInstanceMethod(cls, selector);
			const char *types = NULL;

			if (m) {
				types = method_getTypeEncoding(m);
				IMP forwardIMP = (IMP)_objc_msgForward;

				NSLog(@"[420Crackz] (%@) Replacing method %@ on %@ with IMP %p", bundleID, methodName, className, forwardIMP);
				class_replaceMethod(cls, selector, forwardIMP, types);
				NSLog(@"[420Crackz] (%@) Replaced existing method %@ on %@", bundleID, methodName, className);
			}
		}];
	}];
}

@end

%hook AppDelegate

- (void)application:(id)application didFinishLaunchingWithOptions:(id)options {
	%orig;

	NSDictionary *plist = @{
		@"com.maplepop.bmcx": @[
			@{ @"maxVersion": @"5.8.2",
			   @"Hooks": @{
				   @"Class": @{
					   @"AccountManager": @{
						   @"iapPurchased": @YES
					   }
				   }
			   }
			},
		],
		@"com.getonswitch.OnSwitch": @[
			@{ @"maxVersion": @"4.1.8",
			   @"Hooks": @{
				   @"Class": @{
					   @"AppDelegate": @{
						   @"isUserSubscribed": @YES,
						   @"isUserActuallySubscribed": @YES,
					   }
				   }
			   }
			},
		],
	};

	NSString *bundleID = getCurrentBundleID();
	NSString *currentVersion = getCurrentAppVersion();
	id bundleConfigs = plist[bundleID];

	NSLog(@"[420Crackz] (%@) Loaded", bundleID);

	NSDictionary *selectedConfig = nil;
	if ([bundleConfigs isKindOfClass:[NSArray class]]) {
		for (NSDictionary *config in bundleConfigs) {
			NSString *maxVersion = config[@"maxVersion"];
			if (!maxVersion || compareVersions(currentVersion, maxVersion) != NSOrderedDescending) {
				if (!selectedConfig || compareVersions(maxVersion, selectedConfig[@"maxVersion"]) == NSOrderedAscending) {
					selectedConfig = config;
				}
			}
		}
		if (selectedConfig) {
			NSLog(@"[420Crackz] (%@) Compatible config found with maxVersion %@ for app version %@", bundleID, selectedConfig[@"maxVersion"], currentVersion);
			NSDictionary *injectPlist = @{ bundleID: selectedConfig };
			[HookInjector installHooksFromPlist:injectPlist];
		} else {
			NSLog(@"[420Crackz] (%@) No compatible config found for app version %@", bundleID, currentVersion);
		}
	} else if ([bundleConfigs isKindOfClass:[NSDictionary class]]) {
		NSString *maxVersion = bundleConfigs[@"maxVersion"];

		if (!maxVersion || compareVersions(currentVersion, maxVersion) != NSOrderedDescending) {
			NSLog(@"[420Crackz] (%@) Compatible config found with maxVersion %@ for app version %@", bundleID, maxVersion, currentVersion);

			NSDictionary *injectPlist = @{ bundleID: bundleConfigs };
			[HookInjector installHooksFromPlist:injectPlist];
		} else {
			NSLog(@"[420Crackz] (%@) No compatible config found for app version %@", bundleID, currentVersion);
		}
	}
}

%end