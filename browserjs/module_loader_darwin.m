// SPDX-License-Identifier: BSD-2-Clause
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#include "module_loader_darwin.h"
#include <stdio.h>

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
    void *_owner;
    VoxModuleEvaluationCallback _evaluated;
}
- (instancetype)initWithFetch:(JSValue *)fetch owner:(void *)owner evaluated:(VoxModuleEvaluationCallback)evaluated;
@end
@implementation VoxModuleLoader
- (instancetype)initWithFetch:(JSValue *)fetch owner:(void *)owner evaluated:(VoxModuleEvaluationCallback)evaluated
{
    if ((self = [super init])) {
#if __has_feature(objc_arc)
        _fetch = fetch;
#else
        _fetch = [fetch retain];
#endif
        _owner = owner; _evaluated = evaluated;
    }
    return self;
}
#if !__has_feature(objc_arc)
- (void)dealloc { [_fetch release]; [super dealloc]; }
#endif
// Reentering JS here consumes a pending module exception at the API boundary.
// Notify the embedding directly and leave exception propagation to JSC.
- (void)notifyEvaluation:(NSURL *)key starting:(bool)starting
{
    NSData *bytes = [key.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
    _evaluated(_owner, bytes.bytes, (unsigned int)bytes.length, starting);
}
- (void)willEvaluateModule:(NSURL *)key { [self notifyEvaluation:key starting:true]; }
- (void)didEvaluateModule:(NSURL *)key { [self notifyEvaluation:key starting:false]; }
- (void)context:(JSContext *)context fetchModuleForIdentifier:(JSValue *)identifier
    withResolveHandler:(JSValue *)resolve andRejectHandler:(JSValue *)reject
{
    [_fetch callWithArguments:@[identifier, resolve, reject]];
}
@end

void *vox_module_loader_install(JSGlobalContextRef raw, JSObjectRef fetch, void *owner, VoxModuleEvaluationCallback evaluated)
{
    @autoreleasepool {
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        Class scriptClass = NSClassFromString(@"JSScript");
        if (![context respondsToSelector:@selector(setModuleLoaderDelegate:)] ||
            ![context respondsToSelector:@selector(evaluateJSScript:)] ||
            ![scriptClass respondsToSelector:@selector(scriptOfType:withSource:andSourceURL:andBytecodeCache:inVirtualMachine:error:)])
            return NULL;
        VoxModuleLoader *loader = [[VoxModuleLoader alloc] initWithFetch:
            [JSValue valueWithJSValueRef:fetch inContext:context] owner:owner evaluated:evaluated];
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

static JSValueRef vox_module_loader_supply_string(JSGlobalContextRef raw, JSObjectRef resolve,
    NSString *source, const char *url, size_t urlLength, JSValueRef *exception)
{
    JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
    NSError *error = nil;
    JSScript *script = [JSScript scriptOfType:1 withSource:source
        andSourceURL:[NSURL URLWithString:vox_module_string(url, urlLength)]
        andBytecodeCache:nil inVirtualMachine:context.virtualMachine error:&error];
    if (!script) return NULL;
    JSValue *result = [[JSValue valueWithJSValueRef:resolve inContext:context] callWithArguments:@[script]];
    if (context.exception) { *exception = context.exception.JSValueRef; context.exception = nil; }
    return result.JSValueRef;
}

JSValueRef vox_module_loader_supply(JSGlobalContextRef raw, JSObjectRef resolve,
    const char *source, size_t sourceLength, const char *url, size_t urlLength, JSValueRef *exception)
{
    @autoreleasepool {
        return vox_module_loader_supply_string(raw, resolve, vox_module_string(source, sourceLength),
            url, urlLength, exception);
    }
}

JSValueRef vox_module_loader_supply_value(JSGlobalContextRef raw, JSObjectRef resolve,
    JSValueRef source, const char *url, size_t urlLength, bool diagnostics, JSValueRef *exception)
{
    @autoreleasepool {
        // No author conversion hooks run here. The V caller roots the primitive
        // through construction and any reentrant module evaluation at resolve.
        if (!JSValueIsString(raw, source)) return NULL;
        JSStringRef text = JSValueToStringCopy(raw, source, exception);
        if (!text) return NULL;
        size_t length = JSStringGetLength(text);
        const JSChar *characters = JSStringGetCharactersPtr(text);
        if (length && !characters) { JSStringRelease(text); return NULL; }
        NSString *owned = [[NSString alloc] initWithCharacters:characters length:length];
        JSStringRelease(text);
#if !__has_feature(objc_arc)
        [owned autorelease];
#endif
        if (!owned) return NULL;
        JSValueRef result = vox_module_loader_supply_string(raw, resolve, owned, url, urlLength, exception);
        if (result && diagnostics)
            fprintf(stderr, "Vox module source: supplied rooted UTF-16 string units=%zu\n", length);
        return result;
    }
}
