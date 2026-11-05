// Diagnostic only. Never inject into an instruction acceptance cohort.
// Current-process counters include other threads and instrumentation. Nested
// inclusive scopes overlap; self subtracts only scopes observed by this probe.
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#include <dlfcn.h>
#include <libproc.h>
#include <mach/mach_time.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

enum { slots = 4096, stack_limit = 256, text_limit = 1024 };
struct Row {
    const void *caller;
    unsigned api;
    uint64_t calls, inclusive, self, elapsed, source_units;
    char url[text_limit];
    int truncated;
};
struct Frame { struct Row *row; uint64_t start, children, time; };
static struct Row rows[slots];
static _Thread_local struct Frame stack[stack_limit];
static _Thread_local unsigned depth;
static unsigned faults, maximum_depth;
static int active, started, factory_available, objc_call_available, script_eval_available;
static uint64_t initial_instructions;
static char factory_encoding[256];
static char call_encoding[128];
static char evaluation_encoding[128];
static mach_timebase_info_data_t timebase;
static id (*original_factory)(id, SEL, NSInteger, id, id, id, id, id *);
static id (*original_objc_call)(id, SEL, id);
static id (*original_script_evaluation)(id, SEL, id);

static uint64_t instructions(void)
{
    struct rusage_info_v4 usage = {0};
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&usage) || !usage.ri_instructions) {
        ++faults; active = 0; return 0;
    }
    return usage.ri_instructions;
}

static struct Row *find_row(unsigned api, const void *caller, const char *url)
{
    uint64_t hash = ((uintptr_t)caller >> 2) ^ api;
    for (const unsigned char *p = (const unsigned char *)url; *p; ++p) hash = (hash ^ *p) * UINT64_C(1099511628211);
    unsigned slot = hash % slots;
    for (unsigned n = 0; n < slots; ++n, slot = (slot + 1) % slots) {
        struct Row *row = &rows[slot];
        if (!row->caller) {
            row->caller = caller; row->api = api;
            snprintf(row->url, sizeof(row->url), "%s", url);
            return row;
        }
        if (row->caller == caller && row->api == api && !strcmp(row->url, url)) return row;
    }
    ++faults; active = 0; return NULL;
}

static int enter(unsigned api, const void *caller, const char *url, uint64_t units, int truncated)
{
    // Every mutable counter and table entry belongs to the main thread.
    if (!pthread_main_np() || !active) return 0;
    if (depth == stack_limit) { ++faults; active = 0; return 0; }
    struct Row *row = find_row(api, caller, url);
    if (!row) return 0;
    row->source_units += units; row->truncated |= truncated;
    uint64_t before = instructions();
    if (!active) return 0;
    stack[depth++] = (struct Frame){row, before, 0, mach_absolute_time()};
    if (depth > maximum_depth) maximum_depth = depth;
    return 1;
}

static void leave(int entered)
{
    if (!entered) return;
    struct Frame frame = stack[--depth];
    uint64_t after = instructions(), time = mach_absolute_time() - frame.time;
    if (after < frame.start || after - frame.start < frame.children) { ++faults; active = 0; return; }
    uint64_t count = after - frame.start;
    ++frame.row->calls; frame.row->inclusive += count;
    frame.row->self += count - frame.children;
    frame.row->elapsed += time;
    if (depth) stack[depth - 1].children += count;
}

static JSValueRef counted_eval(JSContextRef context, JSStringRef source, JSObjectRef receiver,
    JSStringRef url, int line, JSValueRef *exception)
{
    const void *caller = __builtin_extract_return_addr(__builtin_return_address(0));
    int entered = enter(1, caller, "", 0, 0);
    JSValueRef result = JSEvaluateScript(context, source, receiver, url, line, exception);
    leave(entered); return result;
}

static JSValueRef counted_call(JSContextRef context, JSObjectRef function, JSObjectRef receiver,
    size_t count, const JSValueRef arguments[], JSValueRef *exception)
{
    const void *caller = __builtin_extract_return_addr(__builtin_return_address(0));
    int entered = enter(2, caller, "", 0, 0);
    JSValueRef result = JSObjectCallAsFunction(context, function, receiver, count, arguments, exception);
    leave(entered); return result;
}

static id counted_factory(id object, SEL selector, NSInteger type, id source,
    id url, id cache, id vm, id *error)
{
    const void *caller = __builtin_extract_return_addr(__builtin_return_address(0));
    char name[text_limit] = {0}; int truncated = 0;
    // Foundation values are native bridge arguments. No JavaScript property,
    // function name, getter or source string is inspected or evaluated here.
    if (pthread_main_np() && active && url) {
        const char *text = [[url absoluteString] UTF8String];
        if (text) truncated = snprintf(name, sizeof(name), "%s", text) >= (int)sizeof(name);
    }
    uint64_t units = pthread_main_np() && active && source ? [source length] : 0;
    int entered = enter(3, caller, name, units, truncated);
    id result = original_factory(object, selector, type, source, url, cache, vm, error);
    leave(entered); return result;
}

static id counted_objc_call(id object, SEL selector, id arguments)
{
    const void *caller = __builtin_extract_return_addr(__builtin_return_address(0));
    int entered = enter(4, caller, "", 0, 0);
    id result = original_objc_call(object, selector, arguments);
    leave(entered); return result;
}

static id counted_script_evaluation(id object, SEL selector, id script)
{
    const void *caller = __builtin_extract_return_addr(__builtin_return_address(0));
    int entered = enter(5, caller, "", 0, 0);
    id result = original_script_evaluation(object, selector, script);
    leave(entered); return result;
}

static void quoted(const char *text)
{
    fputc('"', stderr);
    for (const unsigned char *p = (const unsigned char *)(text ? text : ""); *p; ++p) {
        if (*p == '"' || *p == '\\') fputc('\\', stderr);
        if (*p < 32) fprintf(stderr, "\\u%04x", *p); else fputc(*p, stderr);
    }
    fputc('"', stderr);
}

static void report(void)
{
    if (!started || !pthread_main_np()) return;
    active = 0;
    uint64_t end = instructions();
    if (end < initial_instructions) ++faults;
    char executable[PROC_PIDPATHINFO_MAXSIZE] = {0};
    if (proc_pidpath(getpid(), executable, sizeof(executable)) <= 0) ++faults;
    fprintf(stderr, "VOX_JSC_SCOPE_META {\"pid\":%d,\"faults\":%u,\"open_frames\":%u,\"maximum_depth\":%u,\"factory_available\":%s,\"process_instructions\":%llu,\"executable\":",
        getpid(), faults, depth, maximum_depth, factory_available ? "true" : "false",
        (unsigned long long)(end >= initial_instructions ? end - initial_instructions : 0));
    quoted(executable); fputs(",\"factory_encoding\":", stderr); quoted(factory_encoding);
    fprintf(stderr, ",\"objc_call_available\":%s,\"call_encoding\":", objc_call_available ? "true" : "false");
    quoted(call_encoding);
    fprintf(stderr, ",\"script_eval_available\":%s,\"evaluation_encoding\":", script_eval_available ? "true" : "false");
    quoted(evaluation_encoding); fputs("}\n", stderr);
    static const char *names[] = {"", "JSEvaluateScript", "JSObjectCallAsFunction", "JSScriptFactory", "JSValue.callWithArguments", "JSContext.evaluateJSScript"};
    for (unsigned i = 0; i < slots; ++i) {
        struct Row *row = &rows[i]; if (!row->calls) continue;
        Dl_info info = {0};
        if (!dladdr(row->caller, &info)) memset(&info, 0, sizeof(info));
        fprintf(stderr, "VOX_JSC_SCOPE {\"pid\":%d,\"api\":\"%s\",\"calls\":%llu,\"inclusive_instructions\":%llu,\"self_instructions\":%llu,\"elapsed_ns\":%llu,\"source_utf16_units\":%llu,\"url_truncated\":%s,\"caller\":%llu,\"caller_offset\":%llu,\"image_base\":%llu,\"image\":",
            getpid(), names[row->api], (unsigned long long)row->calls,
            (unsigned long long)row->inclusive, (unsigned long long)row->self,
            (unsigned long long)(((__uint128_t)row->elapsed * timebase.numer) / timebase.denom),
            (unsigned long long)row->source_units, row->truncated ? "true" : "false",
            (unsigned long long)(uintptr_t)row->caller,
            (unsigned long long)((uintptr_t)row->caller - (uintptr_t)info.dli_fbase),
            (unsigned long long)(uintptr_t)info.dli_fbase);
        quoted(info.dli_fname); fputs(",\"nearest_symbol\":", stderr); quoted(info.dli_sname);
        fputs(",\"url\":", stderr); quoted(row->url); fputs("}\n", stderr);
    }
    fflush(stderr);
}

__attribute__((constructor)) static void initialize(void)
{
    const char *enabled = getenv("VOX_JSC_INSTRUCTION_PROBE");
    if (!enabled || !*enabled || !pthread_main_np()) return;
    started = 1; mach_timebase_info(&timebase);
    initial_instructions = instructions();
    Class cls = objc_lookUpClass("JSScript");
    SEL selector = sel_registerName("scriptOfType:withSource:andSourceURL:andBytecodeCache:inVirtualMachine:error:");
    Method method = cls ? class_getClassMethod(cls, selector) : NULL;
    snprintf(factory_encoding, sizeof(factory_encoding), "%s", method ? method_getTypeEncoding(method) : cls ? "missing selector" : "missing class");
    if (method && method_getNumberOfArguments(method) == 8) {
        // Verify the private SPI ABI before installing the diagnostic wrapper.
        const char *types[] = {"@", ":", @encode(NSInteger), "@", "@", "@", "@", "^@"};
        char encoding[32]; int valid = 1;
        method_getReturnType(method, encoding, sizeof(encoding)); valid &= !strcmp(encoding, "@");
        for (unsigned i = 0; i < 8; ++i) {
            method_getArgumentType(method, i, encoding, sizeof(encoding));
            // The SDK marks NSError** as an out parameter. That qualifier
            // does not change the pointer ABI; retain every pointee check.
            valid &= !strcmp(encoding, types[i]) || (i == 7 && !strcmp(encoding, "o^@"));
        }
        if (valid) {
            original_factory = (void *)method_setImplementation(method, (IMP)counted_factory);
            factory_available = original_factory != NULL;
        }
    }
    cls = objc_lookUpClass("JSValue");
    selector = sel_registerName("callWithArguments:");
    method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    snprintf(call_encoding, sizeof(call_encoding), "%s", method ? method_getTypeEncoding(method) : "missing method");
    if (method && method_getNumberOfArguments(method) == 3) {
        const char *types[] = {"@", ":", "@"}; char encoding[32]; int valid = 1;
        method_getReturnType(method, encoding, sizeof(encoding)); valid &= !strcmp(encoding, "@");
        for (unsigned i = 0; i < 3; ++i) {
            method_getArgumentType(method, i, encoding, sizeof(encoding)); valid &= !strcmp(encoding, types[i]);
        }
        if (valid) {
            original_objc_call = (void *)method_setImplementation(method, (IMP)counted_objc_call);
            objc_call_available = original_objc_call != NULL;
        }
    }
    cls = objc_lookUpClass("JSContext");
    selector = sel_registerName("evaluateJSScript:");
    method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    snprintf(evaluation_encoding, sizeof(evaluation_encoding), "%s", method ? method_getTypeEncoding(method) : "missing method");
    if (method && method_getNumberOfArguments(method) == 3) {
        const char *types[] = {"@", ":", "@"}; char encoding[32]; int valid = 1;
        method_getReturnType(method, encoding, sizeof(encoding)); valid &= !strcmp(encoding, "@");
        for (unsigned i = 0; i < 3; ++i) {
            method_getArgumentType(method, i, encoding, sizeof(encoding)); valid &= !strcmp(encoding, types[i]);
        }
        if (valid) {
            original_script_evaluation = (void *)method_setImplementation(method, (IMP)counted_script_evaluation);
            script_eval_available = original_script_evaluation != NULL;
        }
    }
    active = faults == 0;
    atexit(report);
}

__attribute__((used)) static struct { const void *replacement, *original; }
interposers[] __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)counted_eval, (const void *)JSEvaluateScript},
    {(const void *)counted_call, (const void *)JSObjectCallAsFunction},
};
