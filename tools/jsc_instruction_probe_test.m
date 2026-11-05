#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include "../browserjs/module_loader_darwin.m"

static JSObjectRef recursive;
static volatile unsigned bridge_returns;
static int private_token;
static JSObjectRef named_function;
static JSValueRef bridge(JSContextRef context, JSObjectRef function, JSObjectRef receiver,
    size_t count, const JSValueRef arguments[], JSValueRef *exception)
{
    (void)function; (void)receiver; assert(count == 1);
    JSValueRef result = JSObjectCallAsFunction(context, recursive, NULL, count, arguments, exception);
    ++bridge_returns; // Keep the native callback's call site in this image.
    return result;
}

static JSValueRef class_bridge(JSContextRef context, JSObjectRef function, JSObjectRef receiver,
    size_t count, const JSValueRef arguments[], JSValueRef *exception)
{
    assert(JSObjectGetPrivate(function) == &private_token);
    assert(receiver == JSContextGetGlobalObject(context) && count == 1);
    assert(JSValueToNumber(context, arguments[0], NULL) == 0);
    JSValueRef result = JSObjectCallAsFunction(context, recursive, NULL, count, arguments, exception);
    ++bridge_returns;
    return result;
}

static JSValueRef named_callback(JSContextRef context, JSObjectRef function, JSObjectRef receiver,
    size_t count, const JSValueRef arguments[], JSValueRef *exception)
{
    assert(function == named_function && receiver == JSContextGetGlobalObject(context));
    (void)arguments;
    assert(count == 0 && exception);
    return JSValueMakeNumber(context, 42);
}

static JSValueRef evaluate(JSGlobalContextRef context, const char *text, JSValueRef *exception)
{
    JSStringRef source = JSStringCreateWithUTF8CString(text);
    JSValueRef value = JSEvaluateScript(context, source, NULL, NULL, 1, exception);
    JSStringRelease(source); return value;
}

static void *background(void *unused)
{
    (void)unused;
    JSGlobalContextRef context = JSGlobalContextCreate(NULL);
    JSValueRef exception = NULL;
    assert(JSValueToNumber(context, evaluate(context, "1 + 2", &exception), NULL) == 3 && !exception);
    JSGlobalContextRelease(context); return NULL;
}

int main(void)
{
    @autoreleasepool {
        JSGlobalContextRef context = JSGlobalContextCreate(NULL);
        JSStringRef name = JSStringCreateWithUTF8CString("bridge");
        JSObjectRef callback = JSObjectMakeFunctionWithCallback(context, name, bridge);
        JSObjectSetProperty(context, JSContextGetGlobalObject(context), name, callback, 0, NULL);
        JSStringRelease(name);
        JSValueRef exception = NULL;
        recursive = JSValueToObject(context, evaluate(context,
            "function f(n){return n ? bridge(n-1)+1 : 1}; f", &exception), NULL);
        assert(recursive && !exception);
        JSValueRef argument = JSValueMakeNumber(context, 4);
        JSValueRef value = JSObjectCallAsFunction(context, recursive, NULL, 1, &argument, &exception);
        assert(!exception && JSValueToNumber(context, value, NULL) == 5 && bridge_returns == 4);
        JSObjectRef sentinel = JSObjectMake(context, NULL, NULL);
        name = JSStringCreateWithUTF8CString("sentinel");
        JSObjectSetProperty(context, JSContextGetGlobalObject(context), name, sentinel, 0, NULL);
        JSStringRelease(name);
        JSObjectRef failure = JSValueToObject(context, evaluate(context,
            "function fail(){throw sentinel}; fail", &exception), NULL);
        assert(failure && !exception);
        JSObjectCallAsFunction(context, failure, NULL, 0, NULL, &exception);
        assert(exception == sentinel);
        exception = NULL; evaluate(context, "throw sentinel", &exception);
        assert(exception == sentinel);
        exception = NULL;
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.callAsFunction = class_bridge;
        JSClassRef callable_class = JSClassCreate(&definition);
        JSObjectRef class_function = JSObjectMake(context, callable_class, &private_token);
        JSClassRelease(callable_class);
        argument = JSValueMakeNumber(context, 0);
        value = JSObjectCallAsFunction(context, class_function, NULL, 1, &argument, &exception);
        assert(!exception && JSValueToNumber(context, value, NULL) == 1 && bridge_returns == 5);
        name = JSStringCreateWithUTF8CString("native 🦊");
        named_function = JSObjectMakeFunctionWithCallback(context, name, named_callback);
        JSStringRelease(name);
        name = JSStringCreateWithUTF8CString("namedFunction");
        JSObjectSetProperty(context, JSContextGetGlobalObject(context), name, named_function, 0, NULL);
        JSStringRelease(name);
        evaluate(context, "Object.defineProperty(namedFunction, 'name', {get(){throw sentinel}})", &exception);
        assert(!exception);
        value = JSObjectCallAsFunction(context, named_function, NULL, 0, NULL, &exception);
        assert(!exception && JSValueToNumber(context, value, NULL) == 42);
        pthread_t thread; assert(!pthread_create(&thread, NULL, background, NULL));
        assert(!pthread_join(thread, NULL));
        JSContext *owner = [JSContext contextWithJSGlobalContextRef:context];
        owner.exception = nil;
        JSValue *callable = [JSValue valueWithJSValueRef:recursive inContext:owner];
        assert([[callable callWithArguments:@[@0]] toInt32] == 1 && !owner.exception);
        JSValue *thrower = [JSValue valueWithJSValueRef:failure inContext:owner];
        [thrower callWithArguments:@[]];
        assert(owner.exception.JSValueRef == sentinel);
        owner.exception = nil;
        Class cls = NSClassFromString(@"JSScript");
        assert(cls);
        unsigned valid = 0, invalid = 0, deferred = 0;
        for (NSString *source in @[@"globalThis.probeAnswer=1", @"globalThis.probeAnswer='🦊'", @"function {"]) {
            NSError *error = nil;
            id script = [cls scriptOfType:0 withSource:source
                andSourceURL:[NSURL URLWithString:@"https://probe.test/module.js"]
                andBytecodeCache:nil inVirtualMachine:owner.virtualMachine error:&error];
            if (!script) { assert(error); ++invalid; continue; }
            owner.exception = nil;
            [owner evaluateJSScript:script];
            if (owner.exception) { ++invalid; ++deferred; owner.exception = nil; }
            else ++valid;
        }
        assert(valid == 2 && invalid == 1);
        assert([[owner[@"probeAnswer"] toString] isEqualToString:@"🦊"]);
        JSGlobalContextRelease(context);
        printf("JSC scope fixture passed: recursive=5 original-exceptions=2 scripts=%u/%u deferred-errors=%u\n", valid, invalid, deferred);
    }
    return 0;
}
