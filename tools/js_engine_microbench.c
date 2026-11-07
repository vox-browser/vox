// SPDX-License-Identifier: BSD-2-Clause
// Engine-only workloads through the JavaScriptCore C API.
//
// tools/compare_js_engine_microbench.sh links this program against
// JavaScriptCore and against the V8 backend (browserjs/v8/jsc_on_v8.cpp).
// Each workload runs in a fresh context; the first run is reported separately
// from the median of the warm runs. Output: one JSON object per line.
#include <JavaScriptCore/JavaScript.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static double seconds(void)
{
    static mach_timebase_info_data_t base;
    if (!base.denom) mach_timebase_info(&base);
    return (double)mach_absolute_time() * base.numer / base.denom / 1e9;
}

static JSValueRef run(JSContextRef ctx, const char* source)
{
    JSStringRef script = JSStringCreateWithUTF8CString(source);
    JSValueRef exception = NULL;
    JSValueRef value = JSEvaluateScript(ctx, script, NULL, NULL, 1, &exception);
    JSStringRelease(script);
    if (exception) {
        JSStringRef text = JSValueToStringCopy(ctx, exception, NULL);
        char buffer[512];
        JSStringGetUTF8CString(text, buffer, sizeof(buffer));
        fprintf(stderr, "workload failed: %s\n", buffer);
        exit(1);
    }
    return value;
}

static JSValueRef native_add(JSContextRef ctx, JSObjectRef function, JSObjectRef receiver, size_t count,
    const JSValueRef arguments[], JSValueRef* exception)
{
    (void)function; (void)receiver; (void)exception;
    double sum = 0;
    for (size_t i = 0; i < count; i++) sum += JSValueToNumber(ctx, arguments[i], NULL);
    return JSValueMakeNumber(ctx, sum);
}

typedef struct { const char* name; const char* setup; const char* body; } Workload;

static const Workload workloads[] = {
    { "objects", "",
      "(() => { let s = 0; for (let i = 0; i < 3e6; i++) { const o = {x: i, y: i * 2, z: [i]}; s += o.x + o.y + o.z[0]; } return s; })()" },
    { "strings_regexp", "",
      "(() => { let s = ''; for (let i = 0; i < 2e5; i++) s += 'item-' + i + ';'; return s.split(';').filter(x => /item-\\d*7$/.test(x)).length; })()" },
    { "json", "",
      "(() => { const v = []; for (let i = 0; i < 5e4; i++) v.push({id: i, name: 'n' + i, tags: ['a', 'b'], nested: {ok: true}});"
      " let n = 0; for (let k = 0; k < 6; k++) n += JSON.parse(JSON.stringify(v)).length; return n; })()" },
    { "sort_closures", "",
      "(() => { const a = []; let x = 1; for (let i = 0; i < 4e5; i++) { x = (x * 1103515245 + 12345) & 0x7fffffff; a.push(x); }"
      " a.sort((p, q) => p - q); return a.map(v => v & 255).reduce((p, q) => p + q, 0); })()" },
    { "classes_maps", "",
      "(() => { class P { constructor(x, y) { this.x = x; this.y = y; } add(o) { return new P(this.x + o.x, this.y + o.y); } }"
      " const m = new Map(); let p = new P(0, 0); for (let i = 0; i < 1e6; i++) { p = p.add(new P(1, 2)); if ((i & 1023) === 0) m.set(i, p); } return p.x + m.size; })()" },
    { "parse_compile", "globalThis.bigSource = (() => { let s = ''; for (let i = 0; i < 20000; i++)"
      " s += 'function f' + i + '(a, b) { const c = a + b * ' + i + '; return c > 10 ? [c, a, b].join(\",\") : {c, a}; }\\n'; return s; })();",
      "(() => { const f = new Function(bigSource + 'return f19999(1, 2);'); return f().length; })()" },
    { "native_calls", "",
      "(() => { let s = 0; for (let i = 0; i < 3e5; i++) s += nativeAdd(i, 1); return s; })()" },
};

int main(int argc, char** argv)
{
    int runs = argc > 1 ? atoi(argv[1]) : 5;
    const char* engine =
#ifdef VOX_JAVASCRIPT_ENGINE_V8
        "v8";
#else
        "javascriptcore";
#endif
    JSContextGroupRef group = JSContextGroupCreate();
    for (size_t w = 0; w < sizeof(workloads) / sizeof(workloads[0]); w++) {
        double times[64];
        double result = 0;
        for (int r = 0; r < runs && r < 64; r++) {
            JSGlobalContextRef ctx = JSGlobalContextCreateInGroup(group, NULL);
            JSStringRef name = JSStringCreateWithUTF8CString("nativeAdd");
            JSObjectRef function = JSObjectMakeFunctionWithCallback(ctx, name, native_add);
            JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), name, function, 0, NULL);
            JSStringRelease(name);
            if (*workloads[w].setup) run(ctx, workloads[w].setup);
            double start = seconds();
            JSValueRef value = run(ctx, workloads[w].body);
            times[r] = seconds() - start;
            result = JSValueToNumber(ctx, value, NULL);
            JSGlobalContextRelease(ctx);
#ifdef VOX_JAVASCRIPT_ENGINE_V8
            VoxJavaScriptEndTurn(NULL);
#endif
        }
        // Median of warm runs (all runs after the first).
        int warm = runs - 1;
        double sorted[64];
        memcpy(sorted, times + 1, sizeof(double) * (size_t)warm);
        for (int i = 0; i < warm; i++)
            for (int j = i + 1; j < warm; j++)
                if (sorted[j] < sorted[i]) { double t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t; }
        double median = warm ? (warm % 2 ? sorted[warm / 2] : (sorted[warm / 2 - 1] + sorted[warm / 2]) / 2) : times[0];
        printf("{\"engine\": \"%s\", \"workload\": \"%s\", \"first_ms\": %.3f, \"warm_median_ms\": %.3f, \"runs\": %d, \"result\": %.0f}\n",
            engine, workloads[w].name, times[0] * 1e3, median * 1e3, runs, result);
        fflush(stdout);
    }
    JSContextGroupRelease(group);
    return 0;
}
