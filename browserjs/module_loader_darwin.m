// SPDX-License-Identifier: BSD-2-Clause
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#include "module_loader_darwin.h"

// These SPI declarations match WebKit's API/JSScript.h and JSContextPrivate.h.
// Availability is checked at installation; unsupported systems keep the
// backend's explicit module-execution error.
@interface JSScript : NSObject
+ (instancetype)scriptOfType:(NSInteger)type withSource:(NSString *)source
    andSourceURL:(NSURL *)url andBytecodeCache:(NSURL *)cache
    inVirtualMachine:(JSVirtualMachine *)vm error:(NSError **)error;
@end
@interface JSContext (VoxModules)
@property(nonatomic, assign) id moduleLoaderDelegate;
- (JSValue *)evaluateJSScript:(JSScript *)script;
@end

@interface VoxModuleLoader : NSObject {
    JSValue *_fetch;
    JSValue *_evaluated;
}
- (instancetype)initWithFetch:(JSValue *)fetch evaluated:(JSValue *)evaluated;
@end
@implementation VoxModuleLoader
- (instancetype)initWithFetch:(JSValue *)fetch evaluated:(JSValue *)evaluated
{
    if ((self = [super init])) {
#if __has_feature(objc_arc)
        _fetch = fetch; _evaluated = evaluated;
#else
        _fetch = [fetch retain]; _evaluated = [evaluated retain];
#endif
    }
    return self;
}
#if !__has_feature(objc_arc)
- (void)dealloc { [_fetch release]; [_evaluated release]; [super dealloc]; }
#endif
- (void)willEvaluateModule:(NSURL *)key { [_evaluated callWithArguments:@[key.absoluteString, @YES]]; }
- (void)didEvaluateModule:(NSURL *)key { [_evaluated callWithArguments:@[key.absoluteString, @NO]]; }
- (void)context:(JSContext *)context fetchModuleForIdentifier:(JSValue *)identifier
    withResolveHandler:(JSValue *)resolve andRejectHandler:(JSValue *)reject
{
    [_fetch callWithArguments:@[identifier, resolve, reject]];
}
@end

void *vox_module_loader_install(JSGlobalContextRef raw, JSObjectRef fetch, JSObjectRef evaluated)
{
    @autoreleasepool {
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        Class scriptClass = NSClassFromString(@"JSScript");
        if (![context respondsToSelector:@selector(setModuleLoaderDelegate:)] ||
            ![context respondsToSelector:@selector(evaluateJSScript:)] ||
            ![scriptClass respondsToSelector:@selector(scriptOfType:withSource:andSourceURL:andBytecodeCache:inVirtualMachine:error:)])
            return NULL;
        VoxModuleLoader *loader = [[VoxModuleLoader alloc] initWithFetch:
            [JSValue valueWithJSValueRef:fetch inContext:context] evaluated:
            [JSValue valueWithJSValueRef:evaluated inContext:context]];
        context.moduleLoaderDelegate = loader;
#if __has_feature(objc_arc)
        return (__bridge_retained void *)loader;
#else
        return loader;
#endif
    }
}

void vox_module_loader_close(JSGlobalContextRef raw, void *owner)
{
    @autoreleasepool {
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
#if __has_feature(objc_arc)
        VoxModuleLoader *loader = (__bridge_transfer VoxModuleLoader *)owner;
        if (context.moduleLoaderDelegate == loader) context.moduleLoaderDelegate = nil;
#else
        if (context.moduleLoaderDelegate == (id)owner) context.moduleLoaderDelegate = nil;
        [(VoxModuleLoader *)owner release];
#endif
    }
}

static NSString *vox_module_string(const char *bytes, size_t length)
{
    NSString *result = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
#if __has_feature(objc_arc)
    return result;
#else
    return [result autorelease];
#endif
}

JSValueRef vox_module_loader_evaluate(JSGlobalContextRef raw, const char *url, size_t length, JSValueRef *exception)
{
    @autoreleasepool {
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        // evaluateJSScript imports by URL. Its source is intentionally empty:
        // the delegate supplies the original root as well as its dependencies.
        JSScript *script = [JSScript scriptOfType:1 withSource:@""
            andSourceURL:[NSURL URLWithString:vox_module_string(url, length)]
            andBytecodeCache:nil inVirtualMachine:context.virtualMachine error:NULL];
        JSValue *result = script ? [context evaluateJSScript:script] : nil;
        if (context.exception) { *exception = context.exception.JSValueRef; context.exception = nil; }
        if (result) JSValueProtect(raw, result.JSValueRef);
        return result.JSValueRef;
    }
}

JSValueRef vox_module_loader_supply(JSGlobalContextRef raw, JSObjectRef resolve,
    const char *source, size_t sourceLength, const char *url, size_t urlLength, JSValueRef *exception)
{
    @autoreleasepool {
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        NSError *error = nil;
        JSScript *script = [JSScript scriptOfType:1 withSource:vox_module_string(source, sourceLength)
            andSourceURL:[NSURL URLWithString:vox_module_string(url, urlLength)]
            andBytecodeCache:nil inVirtualMachine:context.virtualMachine error:&error];
        if (!script) return NULL;
        JSValue *result = [[JSValue valueWithJSValueRef:resolve inContext:context] callWithArguments:@[script]];
        if (context.exception) { *exception = context.exception.JSValueRef; context.exception = nil; }
        return result.JSValueRef;
    }
}
