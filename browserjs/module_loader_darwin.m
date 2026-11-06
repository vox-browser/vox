// SPDX-License-Identifier: BSD-2-Clause
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#include "module_loader_darwin.h"
#include <stdio.h>
#include <pthread.h>
#include <string.h>

// These SPI declarations match WebKit's API/JSScript.h and JSContextPrivate.h.
// Availability is checked at installation; unsupported systems keep the
// backend's explicit module-execution error.
@interface JSScript : NSObject
+ (instancetype)scriptOfType:(NSInteger)type withSource:(NSString *)source
    andSourceURL:(NSURL *)url andBytecodeCache:(NSURL *)cache
    inVirtualMachine:(JSVirtualMachine *)vm error:(NSError **)error;
- (NSInteger)type;
- (NSURL *)sourceURL;
// JSC's module-resolution callback consumes this immutable, VM-owned cell.
- (void *)jsSourceCode;
@end
@interface JSContext (VoxModules)
@property(nonatomic, assign) id moduleLoaderDelegate;
- (JSValue *)evaluateJSScript:(JSScript *)script;
@end

// Prepared scripts contain source and parser metadata, not a realm's linked
// namespace, global object or evaluated values. The limit charges source storage;
// JSC owns additional parser/code metadata, so it is not a total heap bound.
// Keep the VM wrapper alive while its scripts are cached (JSScript holds it
// weakly), and confine the cache to its creating thread and one context group.
// Small modules stay with JSC's own code cache; retaining them here would evict
// the larger sources for which conversion and script construction are costly.
static const NSUInteger vox_module_cache_min_units = 4096;
static const NSUInteger vox_module_cache_max_entries = 128;
static const NSUInteger vox_module_cache_max_bytes = 16 * 1024 * 1024;

@interface VoxReusableModuleScript : JSScript {
    JSScript *_backing;
    JSGlobalContextRef _root;
    JSValueRef _source;
}
- (instancetype)initWithScript:(JSScript *)script root:(JSGlobalContextRef)root;
- (void)clearPreparedSource;
@end
@implementation VoxReusableModuleScript
- (instancetype)initWithScript:(JSScript *)script root:(JSGlobalContextRef)root
{
    if ((self = [super init])) {
#if __has_feature(objc_arc)
        _backing = script;
#else
        _backing = [script retain];
#endif
        _root = root;
    }
    return self;
}
- (NSInteger)type { return _backing.type; }
- (NSURL *)sourceURL { return _backing.sourceURL; }
- (void *)jsSourceCode
{
    if (!_root) return [_backing jsSourceCode];
    if (!_source) {
        // JSSourceCode uses VM.sourceCodeStructure, not a page's structure.
        // Its SourceProvider owns the parser's function-body cache. Root that
        // cell in a private context of the same VM, never a retired page.
        _source = (JSValueRef)[_backing jsSourceCode];
        if (_source) JSValueProtect(_root, _source);
    }
    return (void *)_source;
}
- (void)clearPreparedSource
{
    if (_source) JSValueUnprotect(_root, _source);
    _source = NULL;
    _root = NULL;
}
- (void)dealloc
{
    [self clearPreparedSource];
#if !__has_feature(objc_arc)
    [_backing release];
    [super dealloc];
#endif
}
@end

@interface VoxPreparedModule : NSObject {
@public
    VoxReusableModuleScript *script;
    NSData *units;
    NSData *utf8;
    NSUInteger cost;
}
@end
@implementation VoxPreparedModule
- (void)dealloc {
    // A temporary JSC/ObjC argument wrapper may outlive this entry. Stop
    // caching its source cell before the cache releases its rooting context.
    [script clearPreparedSource];
#if !__has_feature(objc_arc)
    [script release]; [units release]; [utf8 release]; [super dealloc];
#endif
}
@end

@interface VoxPreparedModuleCache : NSObject {
@public
    JSVirtualMachine *vm;
    NSMutableDictionary *entries;
    NSMutableArray *order;
    NSUInteger bytes, hits;
    JSGlobalContextRef root;
}
- (instancetype)initWithVM:(JSVirtualMachine *)machine;
- (VoxPreparedModule *)entryForURL:(NSString *)url;
- (JSScript *)remember:(JSScript *)script source:(NSString *)source utf8:(const void *)utf8 length:(NSUInteger)length url:(NSString *)url;
@end
@implementation VoxPreparedModuleCache
- (instancetype)initWithVM:(JSVirtualMachine *)machine
{
    if ((self = [super init])) {
#if __has_feature(objc_arc)
        vm = machine;
#else
        vm = [machine retain];
#endif
        entries = [[NSMutableDictionary alloc] init];
        order = [[NSMutableArray alloc] init];
    }
    return self;
}
- (VoxPreparedModule *)entryForURL:(NSString *)url { return entries[url]; }
- (JSScript *)remember:(JSScript *)prepared source:(NSString *)source utf8:(const void *)encoded length:(NSUInteger)encodedLength url:(NSString *)url
{
    NSUInteger length = source.length;
    // Charge the UTF-16 identity plus JSScript's source storage conservatively.
    if (length < vox_module_cache_min_units || length > vox_module_cache_max_bytes / 4) return prepared;
    if (encodedLength > vox_module_cache_max_bytes || url.length > vox_module_cache_max_bytes / 2) return prepared;
    NSUInteger charge = length * 4 + encodedLength + url.length * 2 + 512;
    if (charge > vox_module_cache_max_bytes) return prepared;
    VoxPreparedModule *old = entries[url];
    if (old) { bytes -= old->cost; [entries removeObjectForKey:url]; [order removeObject:url]; }
    while (order.count && (order.count >= vox_module_cache_max_entries || bytes > vox_module_cache_max_bytes - charge)) {
        NSString *key = order[0];
        bytes -= ((VoxPreparedModule *)entries[key])->cost;
        [entries removeObjectForKey:key];
        [order removeObjectAtIndex:0];
    }
    NSMutableData *identity = [[NSMutableData alloc] initWithLength:length * sizeof(unichar)];
    [source getCharacters:identity.mutableBytes range:NSMakeRange(0, length)];
    VoxPreparedModule *entry = [[VoxPreparedModule alloc] init];
    entry->script = [[VoxReusableModuleScript alloc] initWithScript:prepared root:root];
    entry->units = identity;
    entry->utf8 = encoded ? [[NSData alloc] initWithBytes:encoded length:encodedLength] : nil;
    entry->cost = charge;
    entries[url] = entry;
    [order addObject:url];
    bytes += charge;
#if !__has_feature(objc_arc)
    [entry release];
#endif
    return entry->script;
}
- (void)dealloc {
    [entries removeAllObjects];
    if (root) JSGlobalContextRelease(root);
#if !__has_feature(objc_arc)
    [entries release]; [order release]; [vm release]; [super dealloc];
#endif
}
@end

static pthread_key_t vox_module_cache_key;
static pthread_once_t vox_module_cache_once = PTHREAD_ONCE_INIT;
static bool vox_module_cache_ready;
static void vox_module_cache_destroy(void *owner)
{
    @autoreleasepool {
#if __has_feature(objc_arc)
        __unused id cache = (__bridge_transfer id)owner;
#else
        [(id)owner release];
#endif
    }
}
static void vox_module_cache_initialize(void)
{
    vox_module_cache_ready = pthread_key_create(&vox_module_cache_key, vox_module_cache_destroy) == 0;
}
static VoxPreparedModuleCache *vox_module_cache(JSContext *context)
{
    if (getenv("VOX_DISABLE_MODULE_SCRIPT_CACHE")) return nil;
    NSMethodSignature *signature = [JSScript instanceMethodSignatureForSelector:@selector(jsSourceCode)];
    if (!signature || signature.methodReturnLength != sizeof(void *) || signature.methodReturnType[0] != '^') return nil;
    pthread_once(&vox_module_cache_once, vox_module_cache_initialize);
    if (!vox_module_cache_ready) return nil;
    VoxPreparedModuleCache *cache = (__bridge VoxPreparedModuleCache *)pthread_getspecific(vox_module_cache_key);
    JSVirtualMachine *vm = context.virtualMachine;
    if (cache && cache->vm == vm) return cache;
    VoxPreparedModuleCache *replacement = [[VoxPreparedModuleCache alloc] initWithVM:vm];
    replacement->root = JSGlobalContextCreateInGroup(JSContextGetGroup(context.JSGlobalContextRef), NULL);
    if (!replacement->root) {
#if !__has_feature(objc_arc)
        [replacement release];
#endif
        return nil;
    }
#if __has_feature(objc_arc)
    void *owned = (__bridge_retained void *)replacement;
#else
    void *owned = replacement;
#endif
    if (pthread_setspecific(vox_module_cache_key, owned) != 0) { vox_module_cache_destroy(owned); return nil; }
    if (cache) vox_module_cache_destroy((__bridge void *)cache);
    return replacement;
}
static JSScript *vox_module_cache_hit(VoxPreparedModuleCache *cache, VoxPreparedModule *entry, NSString *url)
{
    // Touch only on a full source comparison; URL-only reuse would run stale JS.
    [cache->order removeObject:url];
    [cache->order addObject:url];
    if (++cache->hits == 1 && getenv("VOX_MODULE_SCRIPT_CACHE_DIAGNOSTICS"))
        fprintf(stderr, "Vox module script cache: reused prepared source in its VM\n");
    return entry->script;
}

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

static JSValueRef vox_module_loader_resolve_script(JSGlobalContextRef raw, JSObjectRef resolve,
    JSScript *script, JSValueRef *exception)
{
    JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
    if (!script) return NULL;
    JSValue *result = [[JSValue valueWithJSValueRef:resolve inContext:context] callWithArguments:@[script]];
    if (context.exception) { *exception = context.exception.JSValueRef; context.exception = nil; }
    return result.JSValueRef;
}

JSValueRef vox_module_loader_supply(JSGlobalContextRef raw, JSObjectRef resolve,
    const char *source, size_t sourceLength, const char *url, size_t urlLength, JSValueRef *exception)
{
    @autoreleasepool {
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        NSString *key = vox_module_string(url, urlLength);
        VoxPreparedModuleCache *cache = vox_module_cache(context);
        VoxPreparedModule *entry = [cache entryForURL:key];
        JSScript *script = nil;
        if (entry && entry->utf8 && entry->utf8.length == sourceLength
            && (!sourceLength || !memcmp(entry->utf8.bytes, source, sourceLength)))
            script = vox_module_cache_hit(cache, entry, key);
        if (!script) {
            NSString *text = vox_module_string(source, sourceLength);
            if (!text) return NULL;
            script = [JSScript scriptOfType:1 withSource:text andSourceURL:[NSURL URLWithString:key]
                andBytecodeCache:nil inVirtualMachine:context.virtualMachine error:NULL];
            if (script && cache) script = [cache remember:script source:text utf8:source length:sourceLength url:key];
        }
        return vox_module_loader_resolve_script(raw, resolve, script, exception);
    }
}

JSValueRef vox_module_loader_supply_value(JSGlobalContextRef raw, JSObjectRef resolve,
    JSValueRef source, const char *url, size_t urlLength, bool diagnostics, JSValueRef *exception)
{
    @autoreleasepool {
        // No author conversion hooks run here. The V caller roots the primitive
        // through construction and any reentrant module evaluation at resolve.
        if (!JSValueIsString(raw, source)) return NULL;
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        JSStringRef text = JSValueToStringCopy(raw, source, exception);
        if (!text) return NULL;
        size_t length = JSStringGetLength(text);
        const JSChar *characters = JSStringGetCharactersPtr(text);
        if (length && !characters) { JSStringRelease(text); return NULL; }
        NSString *key = vox_module_string(url, urlLength);
        VoxPreparedModuleCache *cache = vox_module_cache(context);
        VoxPreparedModule *entry = [cache entryForURL:key];
        JSScript *script = nil;
        if (entry && entry->units.length == length * sizeof(JSChar)
            && (!length || !memcmp(entry->units.bytes, characters, length * sizeof(JSChar))))
            script = vox_module_cache_hit(cache, entry, key);
        if (!script) {
            NSString *owned = [[NSString alloc] initWithCharacters:characters length:length];
            if (owned) {
                script = [JSScript scriptOfType:1 withSource:owned andSourceURL:[NSURL URLWithString:key]
                    andBytecodeCache:nil inVirtualMachine:context.virtualMachine error:NULL];
                if (script && cache) script = [cache remember:script source:owned utf8:NULL length:0 url:key];
            }
#if !__has_feature(objc_arc)
            [owned release];
#endif
        }
        JSStringRelease(text);
        JSValueRef result = vox_module_loader_resolve_script(raw, resolve, script, exception);
        if (result && diagnostics)
            fprintf(stderr, "Vox module source: supplied rooted UTF-16 string units=%zu\n", length);
        return result;
    }
}
