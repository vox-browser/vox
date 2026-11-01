/* Diagnostic only: never inject into an instruction acceptance cohort.
 * Validate nonzero counts on the same binary before interpreting zero counts. */
#include <JavaScriptCore/JavaScriptCore.h>
#include <stdatomic.h>
#include <stdio.h>
#include <unistd.h>
static _Atomic unsigned long contexts, groups, evaluations;
static JSGlobalContextRef probe_context(JSClassRef cls) {
    atomic_fetch_add(&contexts, 1);
    return JSGlobalContextCreate(cls);
}
static JSGlobalContextRef probe_group_context(JSContextGroupRef group, JSClassRef cls) {
    atomic_fetch_add(&contexts, 1);
    return JSGlobalContextCreateInGroup(group, cls);
}
static JSContextGroupRef probe_group(void) {
    atomic_fetch_add(&groups, 1);
    return JSContextGroupCreate();
}
static JSValueRef probe_eval(JSContextRef ctx, JSStringRef script, JSObjectRef object,
                            JSStringRef url, int line, JSValueRef *exception) {
    atomic_fetch_add(&evaluations, 1);
    return JSEvaluateScript(ctx, script, object, url, line, exception);
}
#define INTERPOSE(replacement, original) \
    __attribute__((used)) static struct { const void *replacement; const void *original; } \
    interpose_##original __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(unsigned long)&replacement, (const void *)(unsigned long)&original }
INTERPOSE(probe_context, JSGlobalContextCreate);
INTERPOSE(probe_group_context, JSGlobalContextCreateInGroup);
INTERPOSE(probe_group, JSContextGroupCreate);
INTERPOSE(probe_eval, JSEvaluateScript);
__attribute__((destructor)) static void report(void) {
    fprintf(stderr, "JSC_PROBE pid=%d contexts=%lu groups=%lu evaluations=%lu\n",
            getpid(), atomic_load(&contexts), atomic_load(&groups), atomic_load(&evaluations));
}
