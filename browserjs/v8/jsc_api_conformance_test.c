// SPDX-License-Identifier: BSD-2-Clause
// Differential conformance check for the JavaScriptCore C API subset Vox uses.
// tools/test_jsc_on_v8.sh builds this file twice, against JavaScriptCore (with
// module_loader_darwin.m) and against browserjs/v8/jsc_on_v8.cpp, and requires
// identical output. Lines prefixed "engine:" are excluded from the comparison.
#include <JavaScriptCore/JavaScript.h>
#include <JavaScriptCore/JSStringRefCF.h>
#include <CoreFoundation/CoreFoundation.h>
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../module_loader_darwin.h"

static JSGlobalContextRef g_context;
static int g_failures;

static char* utf8(JSContextRef ctx, JSValueRef value)
{
    JSValueRef exception = NULL;
    JSStringRef text = JSValueToStringCopy(ctx, value, &exception);
    if (!text) return strdup("<exception>");
    size_t capacity = JSStringGetMaximumUTF8CStringSize(text);
    char* buffer = malloc(capacity);
    JSStringGetUTF8CString(text, buffer, capacity);
    JSStringRelease(text);
    return buffer;
}

static JSValueRef eval(JSContextRef ctx, const char* source, JSValueRef* exception)
{
    JSStringRef script = JSStringCreateWithUTF8CString(source);
    JSStringRef url = JSStringCreateWithUTF8CString("https://test.example/script.js");
    JSValueRef result = JSEvaluateScript(ctx, script, NULL, url, 1, exception);
    JSStringRelease(script);
    JSStringRelease(url);
    return result;
}

static void print_eval(const char* label, JSContextRef ctx, const char* source)
{
    JSValueRef exception = NULL;
    JSValueRef value = eval(ctx, source, &exception);
    char* text = utf8(ctx, exception ? exception : value);
    printf("%s: %s%s\n", label, exception ? "throws " : "", text);
    free(text);
}

static void expect(bool condition, const char* label)
{
    printf("%s: %s\n", label, condition ? "ok" : "FAILED");
    if (!condition) g_failures++;
}

static void set_global(JSContextRef ctx, const char* name, JSValueRef value)
{
    JSStringRef key = JSStringCreateWithUTF8CString(name);
    JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), key, value, 0, NULL);
    JSStringRelease(key);
}

static void run_loop(double seconds, const char* until)
{
    for (int i = 0; i < (int)(seconds * 100); i++) {
        JSValueRef value = eval(g_context, until, NULL);
        if (value && JSValueToBoolean(g_context, value)) return;
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
    }
}

// --- Host functions --------------------------------------------------------

typedef struct { int calls; const char* label; } HostRecord;

static JSValueRef host_call(JSContextRef ctx, JSObjectRef function, JSObjectRef receiver, size_t count,
    const JSValueRef arguments[], JSValueRef* exception)
{
    HostRecord* record = JSObjectGetPrivate(function);
    record->calls++;
    if (count == 1 && JSValueIsString(ctx, arguments[0])) {
        char* text = utf8(ctx, arguments[0]);
        bool should_throw = !strcmp(text, "throw");
        free(text);
        if (should_throw) {
            JSStringRef message = JSStringCreateWithUTF8CString("host failure");
            JSValueRef argument = JSValueMakeString(ctx, message);
            JSStringRelease(message);
            *exception = JSObjectMakeError(ctx, 1, &argument, NULL);
            return NULL;
        }
    }
    bool receiver_is_global = JSValueIsStrictEqual(ctx, receiver, JSContextGetGlobalObject(ctx));
    double sum = 0;
    for (size_t i = 0; i < count; i++) sum += JSValueToNumber(ctx, arguments[i], NULL);
    JSValueRef parts[3] = { JSValueMakeNumber(ctx, (double)count), JSValueMakeNumber(ctx, sum),
        JSValueMakeBoolean(ctx, receiver_is_global) };
    return JSObjectMakeArray(ctx, 3, parts, NULL);
}

static JSValueRef named_callback(JSContextRef ctx, JSObjectRef function, JSObjectRef receiver, size_t count,
    const JSValueRef arguments[], JSValueRef* exception)
{
    (void)function; (void)receiver; (void)exception;
    return JSValueMakeNumber(ctx, count ? JSValueToNumber(ctx, arguments[0], NULL) * 2 : -1);
}

static int g_deallocated;
static void deallocate(void* bytes, void* context)
{
    (void)context;
    free(bytes);
    g_deallocated++;
}

// --- Modules -----------------------------------------------------------------

typedef struct { const char* url; const char* source; } ModuleSource;
static const ModuleSource g_modules[] = {
    { "https://test.example/root.js",
      "import {value, bump} from 'https://test.example/dep.js'; import './side.js';"
      "globalThis.order.push('root:' + value); bump(); globalThis.after = value;" },
    { "https://test.example/dep.js", "globalThis.order.push('dep'); export let value = 41; export function bump(){ value++; }" },
    { "https://test.example/side.js", "globalThis.order.push('side');" },
    { "https://test.example/tla.js", "globalThis.order.push('tla-start'); await Promise.resolve(); globalThis.order.push('tla-end'); export const ready = true;" },
    { "https://test.example/broken.js", "export const = ;" },
    { "https://test.example/uses-missing.js", "import 'https://test.example/missing.js'; globalThis.order.push('never');" },
    { "https://test.example/dynamic.js", "export default 'dynamic-default'; export const shared = globalThis.order.length;" },
    { "https://test.example/late.js", "export const late = 'late-value';" },
    { "https://test.example/throws.js", "globalThis.order.push('throws'); throw new RangeError('module boom');" },
};

static JSObjectRef g_late_resolve;
static int g_fetches;
static int g_notifications;

static void evaluation_notification(void* owner, const char* url, unsigned length, bool starting)
{
    (void)owner; (void)url; (void)length; (void)starting;
    g_notifications++;
}

static JSValueRef module_fetch(JSContextRef ctx, JSObjectRef function, JSObjectRef receiver, size_t count,
    const JSValueRef arguments[], JSValueRef* exception)
{
    (void)function; (void)receiver;
    assert(count == 3);
    g_fetches++;
    char* url = utf8(ctx, arguments[0]);
    if (!strcmp(url, "https://test.example/late.js")) {
        g_late_resolve = (JSObjectRef)arguments[1];
        JSValueProtect(ctx, g_late_resolve);
        free(url);
        return JSValueMakeUndefined(ctx);
    }
    for (size_t i = 0; i < sizeof(g_modules) / sizeof(g_modules[0]); i++) {
        if (!strcmp(g_modules[i].url, url)) {
            JSValueRef result = vox_module_loader_supply((JSGlobalContextRef)ctx, (JSObjectRef)arguments[1],
                g_modules[i].source, strlen(g_modules[i].source), url, strlen(url), exception);
            free(url);
            return result ? JSValueMakeUndefined(ctx) : NULL;
        }
    }
    free(url);
    JSStringRef message = JSStringCreateWithUTF8CString("module not found");
    JSValueRef argument = JSValueMakeString(ctx, message);
    JSStringRelease(message);
    JSValueRef error = JSObjectMakeError(ctx, 1, &argument, NULL);
    JSObjectCallAsFunction(ctx, (JSObjectRef)arguments[2], NULL, 1, &error, NULL);
    return JSValueMakeUndefined(ctx);
}

static void evaluate_module(const char* label, const char* url)
{
    JSValueRef exception = NULL;
    JSValueRef promise = vox_module_loader_evaluate(g_context, url, strlen(url), &exception);
    if (!promise) {
        printf("%s: no promise\n", label);
        g_failures++;
        return;
    }
    set_global(g_context, "modulePromise", promise);
    JSValueUnprotect(g_context, promise);
    eval(g_context, "globalThis.moduleResult = 'pending'; modulePromise.then(() => moduleResult = 'fulfilled',"
                    " e => moduleResult = 'rejected ' + e.name)", NULL);
    run_loop(1, "moduleResult !== 'pending'");
    print_eval(label, g_context, "moduleResult + ' order=' + order.join(',')");
    eval(g_context, "order = []", NULL);
}

int main(void)
{
    JSContextGroupRef group = JSContextGroupCreate();
    g_context = JSGlobalContextCreateInGroup(group, NULL);
    JSContextRef ctx = g_context;

    print_eval("arithmetic", ctx, "1 + 2");
    print_eval("string", ctx, "'a' + 'β' + '😀'");
    print_eval("engine syntax error", ctx, "var = ;");
    print_eval("engine type error", ctx, "null.x");
    print_eval("thrown", ctx, "throw new TypeError('x')");
    {
        JSValueRef exception = NULL;
        JSValueRef value = eval(ctx, "throw {custom: 7}", &exception);
        expect(!value && exception && JSValueIsObject(ctx, exception), "thrown object");
    }

    // Value kinds and conversions.
    JSValueRef number = eval(ctx, "42.5", NULL);
    expect(JSValueIsNumber(ctx, number) && JSValueToNumber(ctx, number, NULL) == 42.5, "number");
    expect(JSValueIsUndefined(ctx, eval(ctx, "undefined", NULL)), "undefined");
    expect(JSValueIsNull(ctx, eval(ctx, "null", NULL)), "null");
    expect(JSValueIsBoolean(ctx, eval(ctx, "true", NULL)) && JSValueToBoolean(ctx, eval(ctx, "true", NULL)), "boolean");
    expect(!JSValueToBoolean(ctx, eval(ctx, "''", NULL)) && JSValueToBoolean(ctx, eval(ctx, "'0'", NULL)), "string truthiness");
    expect(JSValueIsArray(ctx, eval(ctx, "[1,2]", NULL)) && !JSValueIsArray(ctx, eval(ctx, "({})", NULL)), "array");
    expect(JSValueGetType(ctx, eval(ctx, "Symbol('s')", NULL)) == kJSTypeSymbol, "symbol type");
    expect(JSValueIsStrictEqual(ctx, eval(ctx, "'abc'", NULL), eval(ctx, "'ab' + 'c'", NULL)), "strict string equality");
    expect(!JSValueIsStrictEqual(ctx, eval(ctx, "({})", NULL), eval(ctx, "({})", NULL)), "distinct objects");
    expect(JSValueIsStrictEqual(ctx, JSValueMakeUndefined(ctx), JSValueMakeUndefined(ctx)), "undefined identity");
    {
        JSValueRef exception = NULL;
        JSValueToNumber(ctx, eval(ctx, "({valueOf(){throw 1}})", NULL), &exception);
        expect(exception != NULL, "number conversion exception");
    }

    // Object identity: one handle per object.
    eval(ctx, "globalThis.shared = {name: 'shared'}", NULL);
    JSValueRef first = eval(ctx, "shared", NULL);
    JSValueRef second = eval(ctx, "shared", NULL);
    expect(first == second, "object identity");

    // Properties and attributes.
    JSObjectRef object = JSObjectMake(ctx, NULL, NULL);
    JSStringRef key = JSStringCreateWithUTF8CString("fixed");
    JSObjectSetProperty(ctx, object, key, JSValueMakeNumber(ctx, 5),
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum | kJSPropertyAttributeDontDelete, NULL);
    JSObjectSetProperty(ctx, object, key, JSValueMakeNumber(ctx, 6), 0, NULL);
    expect(JSValueToNumber(ctx, JSObjectGetProperty(ctx, object, key, NULL), NULL) == 5, "read-only property");
    expect(!JSObjectDeleteProperty(ctx, object, key, NULL), "non-deletable property");
    JSStringRelease(key);
    set_global(ctx, "attributed", object);
    print_eval("descriptor", ctx, "JSON.stringify(Object.getOwnPropertyDescriptor(attributed, 'fixed'))");
    JSValueRef array = eval(ctx, "['x', 'y', 'z']", NULL);
    char* element = utf8(ctx, JSObjectGetPropertyAtIndex(ctx, (JSObjectRef)array, 1, NULL));
    printf("index property: %s\n", element);
    free(element);
    {
        JSStringRef name = JSStringCreateWithUTF8CString("value");
        JSObjectRef target = JSObjectMake(ctx, NULL, NULL);
        set_global(ctx, "setterTarget", target);
        eval(ctx, "Object.defineProperty(setterTarget, 'value', {set(v){ this.seen = v * 3 }, configurable: true})", NULL);
        JSObjectSetProperty(ctx, target, name, JSValueMakeNumber(ctx, 2), kJSPropertyAttributeDontEnum, NULL);
        JSStringRelease(name);
        print_eval("existing setter", ctx, "setterTarget.seen");
    }

    // Prototypes.
    JSObjectRef child = JSObjectMake(ctx, NULL, NULL);
    JSObjectSetPrototype(ctx, child, eval(ctx, "({inherited: 'yes'})", NULL));
    set_global(ctx, "child", child);
    print_eval("prototype", ctx, "child.inherited");

    // Host functions.
    HostRecord record = { 0, "host" };
    JSClassDefinition definition = kJSClassDefinitionEmpty;
    definition.callAsFunction = host_call;
    JSClassRef host_class = JSClassCreate(&definition);
    JSObjectRef host = JSObjectMake(ctx, host_class, &record);
    JSClassRelease(host_class);
    set_global(ctx, "host", host);
    expect(JSObjectIsFunction(ctx, host) && !JSObjectIsConstructor(ctx, host), "host function kind");
    expect(JSObjectGetPrivate(host) == &record, "host private data");
    print_eval("host typeof", ctx, "typeof host");
    print_eval("host call", ctx, "JSON.stringify(host(1, 2, 3))");
    print_eval("engine host method receiver", ctx, "JSON.stringify(host.apply({}, [4]))");
    print_eval("host throws", ctx, "try { host('throw'); 'no' } catch (e) { e instanceof Error ? e.message : typeof e }");
    print_eval("host construct", ctx, "try { new host(); 'constructed' } catch (e) { e.name }");
    printf("engine host calls: %d\n", record.calls);
    {
        JSStringRef name = JSStringCreateWithUTF8CString("double");
        JSObjectRef function = JSObjectMakeFunctionWithCallback(ctx, name, named_callback);
        JSStringRelease(name);
        set_global(ctx, "double", function);
        print_eval("named callback", ctx, "double(21) + ':' + double.name");
        JSValueRef argument = JSValueMakeNumber(ctx, 4);
        JSValueRef result = JSObjectCallAsFunction(ctx, function, NULL, 1, &argument, NULL);
        expect(JSValueToNumber(ctx, result, NULL) == 8, "call host from native");
    }

    // Calling script functions.
    JSValueRef add = eval(ctx, "(function(a, b) { 'use strict'; return [a + b, this === globalThis]; })", NULL);
    JSValueRef add_arguments[2] = { JSValueMakeNumber(ctx, 2), JSValueMakeNumber(ctx, 3) };
    JSValueRef added = JSObjectCallAsFunction(ctx, (JSObjectRef)add, NULL, 2, add_arguments, NULL);
    char* added_text = utf8(ctx, added);
    printf("call script function: %s\n", added_text);
    free(added_text);
    {
        JSValueRef exception = NULL;
        JSValueRef thrower = eval(ctx, "(() => { throw new SyntaxError('called') })", NULL);
        JSValueRef value = JSObjectCallAsFunction(ctx, (JSObjectRef)thrower, NULL, 0, NULL, &exception);
        char* text = utf8(ctx, exception);
        printf("call exception: %s %s\n", value ? "value" : "null", text);
        free(text);
    }

    // Compiled functions and syntax checks.
    {
        JSStringRef names[2] = { JSStringCreateWithUTF8CString("a"), JSStringCreateWithUTF8CString("b") };
        JSStringRef body = JSStringCreateWithUTF8CString("return a * b;");
        JSStringRef name = JSStringCreateWithUTF8CString("multiply");
        JSObjectRef function = JSObjectMakeFunction(ctx, name, 2, names, body, NULL, 1, NULL);
        set_global(ctx, "multiply", function);
        print_eval("made function", ctx, "multiply(6, 7) + ':' + multiply.name");
        JSStringRelease(names[0]); JSStringRelease(names[1]); JSStringRelease(body); JSStringRelease(name);
        JSStringRef good = JSStringCreateWithUTF8CString("function ok() { return 1 }");
        JSStringRef bad = JSStringCreateWithUTF8CString("function bad( {");
        JSValueRef exception = NULL;
        expect(JSCheckScriptSyntax(ctx, good, NULL, 1, NULL), "syntax ok");
        expect(!JSCheckScriptSyntax(ctx, bad, NULL, 1, &exception) && exception, "syntax rejected");
        JSStringRelease(good); JSStringRelease(bad);
    }

    // Intrinsic constructors.
    {
        JSValueRef argument = JSValueMakeNumber(ctx, 86400000);
        JSObjectRef date = JSObjectMakeDate(ctx, 1, &argument, NULL);
        set_global(ctx, "madeDate", date);
        print_eval("date", ctx, "madeDate.toISOString()");
        JSStringRef message = JSStringCreateWithUTF8CString("made error");
        JSValueRef error_argument = JSValueMakeString(ctx, message);
        JSStringRelease(message);
        JSObjectRef error = JSObjectMakeError(ctx, 1, &error_argument, NULL);
        set_global(ctx, "madeError", error);
        print_eval("error", ctx, "madeError instanceof Error && madeError.message");
    }

    // JSON.
    {
        JSStringRef json = JSStringCreateWithUTF8CString("{\"a\":[1,true,null,\"s\"]}");
        JSValueRef parsed = JSValueMakeFromJSONString(ctx, json);
        JSStringRelease(json);
        set_global(ctx, "parsed", parsed);
        print_eval("json", ctx, "parsed.a.length + ':' + parsed.a[3]");
        JSStringRef broken = JSStringCreateWithUTF8CString("{");
        expect(JSValueMakeFromJSONString(ctx, broken) == NULL, "invalid json");
        JSStringRelease(broken);
    }

    // Promises and microtask draining at the outermost API boundary.
    {
        JSObjectRef resolve = NULL, reject = NULL;
        JSObjectRef promise = JSObjectMakeDeferredPromise(ctx, &resolve, &reject, NULL);
        set_global(ctx, "deferred", promise);
        eval(ctx, "globalThis.settled = 'no'; deferred.then(v => settled = 'yes:' + v)", NULL);
        print_eval("before resolve", ctx, "settled");
        JSValueRef value = JSValueMakeNumber(ctx, 9);
        JSObjectCallAsFunction(ctx, resolve, NULL, 1, &value, NULL);
        print_eval("after resolve", ctx, "settled");
        eval(ctx, "globalThis.microtask = 'no'; Promise.resolve().then(() => microtask = 'yes')", NULL);
        print_eval("microtask drained", ctx, "microtask");
    }

    // Typed arrays.
    {
        unsigned char* bytes = malloc(4);
        memcpy(bytes, "\x01\x02\x03\x04", 4);
        JSObjectRef view = JSObjectMakeTypedArrayWithBytesNoCopy(ctx, kJSTypedArrayTypeUint8Array, bytes, 4,
            deallocate, NULL, NULL);
        set_global(ctx, "view", view);
        print_eval("typed array", ctx, "Array.from(view).join(',')");
        expect(JSValueGetTypedArrayType(ctx, view, NULL) == kJSTypedArrayTypeUint8Array, "typed array type");
        expect(JSObjectGetTypedArrayBytesPtr(ctx, view, NULL) == bytes, "typed array bytes");
        expect(JSObjectGetTypedArrayLength(ctx, view, NULL) == 4, "typed array length");
        JSValueRef offset_buffer = eval(ctx, "globalThis.offsetBuffer = new ArrayBuffer(16)", NULL);
        JSValueRef offset_view = eval(ctx, "new Uint8Array(offsetBuffer, 4, 8)", NULL);
        expect(JSObjectGetTypedArrayBytesPtr(ctx, (JSObjectRef)offset_view, NULL)
            == JSObjectGetArrayBufferBytesPtr(ctx, (JSObjectRef)offset_buffer, NULL), "typed array bytes are the buffer base");
        JSValueRef sub = eval(ctx, "new Int16Array(new ArrayBuffer(16), 4, 3)", NULL);
        expect(JSObjectGetTypedArrayByteOffset(ctx, (JSObjectRef)sub, NULL) == 4
            && JSObjectGetTypedArrayByteLength(ctx, (JSObjectRef)sub, NULL) == 6
            && JSObjectGetTypedArrayLength(ctx, (JSObjectRef)sub, NULL) == 3, "typed array geometry");
        JSValueRef buffer = eval(ctx, "new ArrayBuffer(12)", NULL);
        expect(JSValueGetTypedArrayType(ctx, buffer, NULL) == kJSTypedArrayTypeArrayBuffer
            && JSObjectGetArrayBufferByteLength(ctx, (JSObjectRef)buffer, NULL) == 12, "array buffer");
        JSObjectRef floats = JSObjectMakeTypedArrayWithArrayBuffer(ctx, kJSTypedArrayTypeFloat32Array,
            (JSObjectRef)buffer, NULL);
        expect(JSObjectGetTypedArrayLength(ctx, floats, NULL) == 3, "array on buffer");
        JSObjectRef zeroed = JSObjectMakeTypedArray(ctx, kJSTypedArrayTypeUint32Array, 5, NULL);
        set_global(ctx, "zeroed", zeroed);
        print_eval("made typed array", ctx, "zeroed.constructor.name + zeroed.length + zeroed[4]");
        JSValueRef data_view = eval(ctx, "new DataView(new ArrayBuffer(8), 2)", NULL);
        expect(JSValueGetTypedArrayType(ctx, data_view, NULL) == kJSTypedArrayTypeNone, "data view type");
        expect(JSObjectGetTypedArrayByteLength(ctx, (JSObjectRef)data_view, NULL) == 6, "data view length");
    }

    // Strings.
    {
        JSStringRef text = JSStringCreateWithUTF8CString("h\xc3\xa9llo \xf0\x9f\x98\x80");
        printf("utf16 length: %zu\n", JSStringGetLength(text));
        JSValueRef value = JSValueMakeString(ctx, text);
        set_global(ctx, "unicode", value);
        print_eval("unicode", ctx, "unicode.length + ':' + unicode.codePointAt(6).toString(16)");
        JSStringRelease(text);
        JSChar lone[] = { 'a', 0xD800, 'b' };
        JSStringRef surrogate = JSStringCreateWithCharacters(lone, 3);
        char buffer[16];
        size_t written = JSStringGetUTF8CString(surrogate, buffer, sizeof(buffer));
        printf("lone surrogate bytes: %zu\n", written);
        JSStringRelease(surrogate);
        JSStringRef a = JSStringCreateWithUTF8CString("same"), b = JSStringCreateWithUTF8CString("same");
        expect(JSStringIsEqual(a, b), "string equality");
        JSStringRelease(a); JSStringRelease(b);
        CFStringRef cf = CFSTR("core foundation");
        JSStringRef from_cf = JSStringCreateWithCFString(cf);
        printf("cf length: %zu\n", JSStringGetLength(from_cf));
        JSStringRelease(from_cf);
    }

    // Protected values survive turns and collections.
    {
        JSValueRef kept = eval(ctx, "({kept: 'alive'})", NULL);
        JSValueProtect(ctx, kept);
        JSStringRef kept_string_source = JSStringCreateWithUTF8CString("protected string");
        JSValueRef kept_string = JSValueMakeString(ctx, kept_string_source);
        JSStringRelease(kept_string_source);
        JSValueProtect(ctx, kept_string);
#ifdef VOX_JAVASCRIPT_ENGINE_V8
        VoxJavaScriptEndTurn(ctx);
#endif
        eval(ctx, "for (let i = 0; i < 200000; i++) globalThis.garbage = {i, s: 'x' + i}", NULL);
        JSGarbageCollect(ctx);
        set_global(ctx, "kept", kept);
        print_eval("protected object", ctx, "kept.kept");
        char* kept_text = utf8(ctx, kept_string);
        printf("protected string: %s\n", kept_text);
        free(kept_text);
        JSValueUnprotect(ctx, kept);
        JSValueUnprotect(ctx, kept_string);
        // An unprotected object stays valid while reachable from JavaScript.
        JSValueRef reachable = eval(ctx, "globalThis.reachable = {r: 1}; reachable", NULL);
#ifdef VOX_JAVASCRIPT_ENGINE_V8
        VoxJavaScriptEndTurn(ctx);
#endif
        eval(ctx, "for (let i = 0; i < 200000; i++) globalThis.garbage = {i, s: 'y' + i}", NULL);
        expect(JSValueIsStrictEqual(ctx, reachable, eval(ctx, "reachable", NULL)), "reachable identity across turns");
    }

    // Global object with a class: its own automatic prototype.
    {
        JSClassDefinition global_definition = kJSClassDefinitionEmpty;
        global_definition.className = "DedicatedWorkerGlobalScope";
        JSClassRef global_class = JSClassCreate(&global_definition);
        JSGlobalContextRef worker = JSGlobalContextCreateInGroup(group, global_class);
        JSClassRelease(global_class);
        print_eval("classed global", worker,
            "const p = Object.getPrototypeOf(globalThis); [p !== Object.prototype, Object.getPrototypeOf(p) === Object.prototype].join()");
        JSGlobalContextRelease(worker);
        JSGlobalContextRef plain = JSGlobalContextCreate(NULL);
        print_eval("separate group", plain, "typeof shared");
        JSGlobalContextRelease(plain);
    }

    // Asynchronous engine work completes on the run loop.
    eval(ctx, "globalThis.wasm = 'pending'; WebAssembly.compile(new Uint8Array([0,97,115,109,1,0,0,0]))"
              ".then(m => wasm = m instanceof WebAssembly.Module ? 'compiled' : 'other', e => wasm = 'error ' + e)", NULL);
    run_loop(5, "wasm !== 'pending'");
    print_eval("async wasm", ctx, "wasm");

    // Modules.
    {
        JSClassDefinition fetch_definition = kJSClassDefinitionEmpty;
        fetch_definition.callAsFunction = module_fetch;
        JSClassRef fetch_class = JSClassCreate(&fetch_definition);
        JSObjectRef fetch = JSObjectMake(ctx, fetch_class, NULL);
        JSClassRelease(fetch_class);
        void* loader = vox_module_loader_install(g_context, fetch, NULL, evaluation_notification);
        expect(loader != NULL, "module loader");
        eval(ctx, "globalThis.order = []", NULL);
        evaluate_module("static graph", "https://test.example/root.js");
        print_eval("live binding", ctx, "after");
        evaluate_module("cached graph", "https://test.example/root.js");
        evaluate_module("top-level await", "https://test.example/tla.js");
        evaluate_module("syntax error", "https://test.example/broken.js");
        evaluate_module("missing dependency", "https://test.example/uses-missing.js");
        evaluate_module("evaluation error", "https://test.example/throws.js");
        eval(ctx, "globalThis.dynamicResult = 'pending'; import('https://test.example/dynamic.js')"
                  ".then(m => dynamicResult = m.default + ':' + typeof m.shared, e => dynamicResult = 'error ' + e)", NULL);
        run_loop(1, "dynamicResult !== 'pending'");
        print_eval("dynamic import", ctx, "dynamicResult");
        eval(ctx, "globalThis.lateResult = 'pending'; import('https://test.example/late.js')"
                  ".then(m => lateResult = m.late, e => lateResult = 'error ' + e)", NULL);
        print_eval("deferred fetch before supply", ctx, "lateResult");
        if (g_late_resolve) {
            const char* source = "export const late = 'late-value';";
            const char* url = "https://test.example/late.js";
            vox_module_loader_supply(g_context, g_late_resolve, source, strlen(source), url, strlen(url), NULL);
            JSValueUnprotect(ctx, g_late_resolve);
        }
        run_loop(1, "lateResult !== 'pending'");
        print_eval("deferred fetch after supply", ctx, "lateResult");
        printf("module fetches: %d\n", g_fetches);
        printf("evaluation notifications: %s\n", g_notifications > 0 ? "yes" : "no");
        vox_module_loader_close(g_context, loader);
    }

#ifdef VOX_JAVASCRIPT_ENGINE_V8
    printf("engine: %s %s\n", VoxJavaScriptEngineName(), VoxJavaScriptEngineVersion());
#else
    printf("engine: javascriptcore\n");
#endif
    JSGlobalContextRelease(g_context);
    JSContextGroupRelease(group);
    printf("engine deallocated: %d\n", g_deallocated > 0 ? 1 : 0);
    printf("failures: %d\n", g_failures);
    return g_failures ? 1 : 0;
}
