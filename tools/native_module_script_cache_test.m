// SPDX-License-Identifier: BSD-2-Clause
// Include the implementation to exercise eviction and rooting, not just output.
#import "../browserjs/module_loader_darwin.m"
#include <assert.h>

typedef struct {
    __unsafe_unretained NSString *source;
    bool value;
    unsigned fetched;
} Supply;

static NSString *padded(NSString *source)
{
    return [@"/*" stringByAppendingFormat:@"%@*/%@",
        [@"x" stringByPaddingToLength:5000 withString:@"x" startingAtIndex:0], source];
}
static void evaluated(void *owner, const char *url, unsigned int length, bool starting)
{
    (void)owner; (void)url; (void)length; (void)starting;
}
static JSValueRef supply(JSContextRef raw, JSObjectRef function, JSObjectRef receiver,
    size_t count, const JSValueRef *args, JSValueRef *exception)
{
    (void)receiver;
    assert(count == 3);
    Supply *state = JSObjectGetPrivate(function);
    state->fetched++;
    JSStringRef key = JSValueToStringCopy(raw, args[0], exception);
    size_t capacity = JSStringGetMaximumUTF8CStringSize(key);
    char *url = malloc(capacity);
    size_t length = JSStringGetUTF8CString(key, url, capacity) - 1;
    JSStringRelease(key);
    NSString *text = strstr(url, "/dep.js") ?
        padded(@"export let x=globalThis.seed+1;export const increment=()=>++x;") : state->source;
    JSValueRef result;
    if (state->value) {
        JSContext *context = [JSContext contextWithJSGlobalContextRef:(JSGlobalContextRef)raw];
        JSValue *source = [JSValue valueWithObject:text inContext:context];
        result = vox_module_loader_supply_value((JSGlobalContextRef)raw, (JSObjectRef)args[1],
            source.JSValueRef, url, length, false, exception);
    } else {
        result = vox_module_loader_supply((JSGlobalContextRef)raw, (JSObjectRef)args[1],
            text.UTF8String, strlen(text.UTF8String), url, length, exception);
    }
    free(url);
    return result;
}
static void *install(JSGlobalContextRef raw, Supply *state)
{
    JSClassDefinition definition = kJSClassDefinitionEmpty;
    definition.callAsFunction = supply;
    JSClassRef type = JSClassCreate(&definition);
    JSObjectRef fetch = JSObjectMake(raw, type, state);
    JSClassRelease(type);
    void *loader = vox_module_loader_install(raw, fetch, NULL, evaluated);
    assert(loader);
    return loader;
}
static void evaluate(JSGlobalContextRef raw, const char *url, bool rejected)
{
    JSValueRef error = NULL;
    JSValueRef promise = vox_module_loader_evaluate(raw, url, strlen(url), &error);
    assert(promise && !error);
    JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
    context[@"result"] = [JSValue valueWithJSValueRef:promise inContext:context];
    [context evaluateScript:@"result.then(()=>globalThis.done=true,()=>globalThis.failed=true)"];
    assert(!context.exception);
    assert([context[rejected ? @"failed" : @"done"] toBool]);
    assert(![context[rejected ? @"done" : @"failed"] toBool]);
    JSValueUnprotect(raw, promise);
}
static void clear_cache(void)
{
    pthread_once(&vox_module_cache_once, vox_module_cache_initialize);
    void *cache = pthread_getspecific(vox_module_cache_key);
    assert(!pthread_setspecific(vox_module_cache_key, NULL));
    if (cache) vox_module_cache_destroy(cache);
}
static void test_realms(bool value)
{
    clear_cache();
    JSContextGroupRef group = JSContextGroupCreate();
    NSString *source = padded(@"export const value=globalThis.seed; function f(x){return x+value;}"
        "globalThis.answer=f(2);globalThis.later=()=>import('./dep.js').then(m=>globalThis.answer=m.x);");
    Supply first = {source, value, 0}, second = {source, value, 0};
    JSGlobalContextRef a = JSGlobalContextCreateInGroup(group, NULL);
    JSGlobalContextRef b = JSGlobalContextCreateInGroup(group, NULL);
    JSContext *ca = [JSContext contextWithJSGlobalContextRef:a];
    JSContext *cb = [JSContext contextWithJSGlobalContextRef:b];
    ca[@"seed"] = @10; cb[@"seed"] = @20;
    void *la = install(a, &first), *lb = install(b, &second);
    evaluate(a, "https://cache.test/root.js", false);
    evaluate(b, "https://cache.test/root.js", false);
    assert([ca[@"answer"] toInt32] == 12 && [cb[@"answer"] toInt32] == 22);
    VoxPreparedModuleCache *cache = vox_module_cache(cb);
    assert(cache->hits == 1 && first.fetched == 1 && second.fetched == 1);
    vox_module_loader_close(a, la); ca = nil; JSGlobalContextRelease(a);
    JSGarbageCollect(b);
    [cb evaluateScript:@"later()"];
    assert(!cb.exception && [cb[@"answer"] toInt32] == 21 && second.fetched == 2);
    vox_module_loader_close(b, lb); JSGlobalContextRelease(b);
    clear_cache(); JSContextGroupRelease(group);
}
static void test_identity_and_failures(void)
{
    clear_cache();
    JSContextGroupRef group = JSContextGroupCreate();
    // Every navigation must fetch again, even after an identical cache hit.
    for (unsigned i = 0; i < 6; i++) { @autoreleasepool {
        NSString *source = padded(i == 3 ? @"export const = ;" : i < 3 ?
            @"globalThis.answer=1;" : @"globalThis.answer=2;");
        Supply state = {source, i % 2, 0};
        JSGlobalContextRef raw = JSGlobalContextCreateInGroup(group, NULL);
        void *loader = install(raw, &state);
        const char *url = i == 2 ? "https://cache.test/other.js" : "https://cache.test/root.js";
        evaluate(raw, url, i == 3);
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        if (i != 3) assert([context[@"answer"] toInt32] == (i < 3 ? 1 : 2));
        assert(state.fetched == 1);
        vox_module_loader_close(raw, loader); JSGarbageCollect(raw); JSGlobalContextRelease(raw);
    }}
    clear_cache(); JSContextGroupRelease(group);
}
static void test_static_imports(void)
{
    clear_cache();
    JSContextGroupRef group = JSContextGroupCreate();
    NSString *source = padded(@"import {x,increment} from './dep.js';"
        "globalThis.before=x;increment();globalThis.after=x;");
    for (unsigned i = 0; i < 3; i++) { @autoreleasepool {
        JSGlobalContextRef raw = JSGlobalContextCreateInGroup(group, NULL);
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        context[@"seed"] = @(i * 10);
        Supply state = {source, i % 2, 0};
        void *loader = install(raw, &state);
        evaluate(raw, "https://cache.test/root.js", false);
        assert([context[@"before"] toInt32] == (int)i * 10 + 1);
        assert([context[@"after"] toInt32] == (int)i * 10 + 2);
        assert(state.fetched == 2 && vox_module_cache(context)->hits == i * 2);
        vox_module_loader_close(raw, loader); JSGlobalContextRelease(raw);
    }}
    clear_cache(); JSContextGroupRelease(group);
}
static void test_utf16_and_non_string(void)
{
    clear_cache();
    JSContextGroupRef group = JSContextGroupCreate();
    unichar units[] = {0, 233, 256, 55357, 56832, 55296, 65, 57343};
    NSString *literal = [[NSString alloc] initWithCharacters:units length:8];
    NSString *source = padded([NSString stringWithFormat:
        @"globalThis.units=Array.from(\"%@\",c=>c.length===2?[c.charCodeAt(0),c.charCodeAt(1)]:c.charCodeAt(0));", literal]);
    for (unsigned i = 0; i < 3; i++) { @autoreleasepool {
        JSGlobalContextRef raw = JSGlobalContextCreateInGroup(group, NULL);
        Supply state = {source, true, 0};
        void *loader = install(raw, &state);
        evaluate(raw, "https://cache.test/utf16.js", false);
        JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
        assert([[[context evaluateScript:@"JSON.stringify(units)"] toString]
            isEqualToString:@"[0,233,256,[55357,56832],55296,65,57343]"]);
        JSValue *bad = [context evaluateScript:@"({toString(){globalThis.coerced=true;throw 1}})"];
        JSValue *resolve = [context evaluateScript:@"(()=>globalThis.resolved=true)"];
        JSValueRef error = NULL;
        assert(!vox_module_loader_supply_value(raw, (JSObjectRef)resolve.JSValueRef,
            bad.JSValueRef, "https://cache.test/no.js", 24, false, &error));
        assert(!error && ![context[@"coerced"] toBool] && ![context[@"resolved"] toBool]);
        if (i) assert(vox_module_cache(context)->hits == i);
        vox_module_loader_close(raw, loader); JSGarbageCollect(raw); JSGlobalContextRelease(raw);
    }}
    clear_cache(); JSContextGroupRelease(group);
#if !__has_feature(objc_arc)
    [literal release];
#endif
}
static void test_eviction(void)
{
    clear_cache();
    JSGlobalContextRef raw = JSGlobalContextCreate(NULL);
    JSContext *context = [JSContext contextWithJSGlobalContextRef:raw];
    VoxPreparedModuleCache *cache = vox_module_cache(context);
    NSString *source = padded(@"export const x=1;");
    JSScript *backing = [JSScript scriptOfType:1 withSource:source
        andSourceURL:[NSURL URLWithString:@"https://cache.test/0.js"]
        andBytecodeCache:nil inVirtualMachine:context.virtualMachine error:NULL];
    VoxReusableModuleScript *retired = (VoxReusableModuleScript *)[cache remember:backing
        source:source utf8:NULL length:0 url:@"https://cache.test/0.js"];
#if !__has_feature(objc_arc)
    [retired retain];
#endif
    assert([retired jsSourceCode]);
    for (unsigned i = 1; i <= vox_module_cache_max_entries; i++) { @autoreleasepool {
        NSString *url = [NSString stringWithFormat:@"https://cache.test/%u.js", i];
        [cache remember:backing source:source utf8:NULL length:0 url:url];
    }}
    assert(cache->entries.count == vox_module_cache_max_entries);
    assert(![cache entryForURL:@"https://cache.test/0.js"]);
    assert(cache->bytes <= vox_module_cache_max_bytes);
    assert([retired jsSourceCode]); // Evicted wrapper still works without its root.
    vox_module_cache_hit(cache, [cache entryForURL:@"https://cache.test/1.js"], @"https://cache.test/1.js");
    [cache remember:backing source:source utf8:NULL length:0 url:@"https://cache.test/129.js"];
    assert([cache entryForURL:@"https://cache.test/1.js"]);
    assert(![cache entryForURL:@"https://cache.test/2.js"]); // A hit updates LRU order.
    NSString *large = [@"x" stringByPaddingToLength:1000000 withString:@"x" startingAtIndex:0];
    for (unsigned i = 0; i < 8; i++) {
        [cache remember:backing source:large utf8:NULL length:0
            url:[NSString stringWithFormat:@"https://cache.test/large-%u.js", i]];
        assert(cache->bytes <= vox_module_cache_max_bytes);
    }
    NSUInteger count = cache->entries.count;
    assert([cache remember:backing source:@"tiny" utf8:NULL length:0 url:@"tiny"] == backing);
    assert([cache remember:backing source:large utf8:"" length:vox_module_cache_max_bytes url:@"oversized"] == backing);
    assert(cache->entries.count == count);
    clear_cache();
    assert([retired jsSourceCode]);
    JSGarbageCollect(raw); JSGlobalContextRelease(raw);
#if !__has_feature(objc_arc)
    [retired release];
#endif
}
static void *thread_test(void *unused)
{
    (void)unused;
    @autoreleasepool {
        test_realms(false);
        // Leave a rooted source cached to exercise the pthread destructor.
        JSGlobalContextRef raw = JSGlobalContextCreate(NULL);
        Supply state = {padded(@"globalThis.answer=1;"), false, 0};
        void *loader = install(raw, &state);
        evaluate(raw, "https://cache.test/thread.js", false);
        vox_module_loader_close(raw, loader); JSGlobalContextRelease(raw);
    }
    return NULL;
}
int main(void)
{
    @autoreleasepool {
        test_realms(false); test_realms(true);
        test_identity_and_failures(); test_static_imports(); test_utf16_and_non_string(); test_eviction();
        pthread_t thread;
        assert(!pthread_create(&thread, NULL, thread_test, NULL));
        assert(!pthread_join(thread, NULL));
        // A new VM on the main thread must replace, rather than reuse, entries.
        JSGlobalContextRef a = JSGlobalContextCreate(NULL), b = JSGlobalContextCreate(NULL);
        Supply state = {padded(@"globalThis.answer=1;"), false, 0};
        void *loader = install(a, &state);
        evaluate(a, "https://cache.test/vm.js", false);
        VoxPreparedModuleCache *cache = vox_module_cache([JSContext contextWithJSGlobalContextRef:b]);
        assert(!cache->entries.count && !cache->hits);
        vox_module_loader_close(a, loader); clear_cache();
        JSGlobalContextRelease(a); JSGlobalContextRelease(b);
    }
    puts("module source cache: realm isolation, exact sources, UTF-16, rejection, eviction, VM/thread ownership passed");
    return 0;
}
