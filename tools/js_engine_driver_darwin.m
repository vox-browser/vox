// SPDX-License-Identifier: BSD-2-Clause
// DYLD_INSERT_LIBRARIES driver for engine comparisons (tools/measure_chatgpt_engines.py).
//
// Build it against the same JavaScript C API as the browser it drives: the
// JavaScriptCore framework, or the V8 backend's headers and libVoxJSCOnV8.
// It tracks main-thread global contexts, evaluates probe scripts in the
// top-level realm whose location starts with VOX_JS_DRIVER_ORIGIN, delivers
// native key events to the sokol input view without activating the app, and
// reports the process's own hardware counters.
//
// Protocol: the controller writes VOX_JS_DRIVER_DIR/req-N (first line: command
// name, remainder: payload) and the driver answers with res-N, a JSON object
// {"id", "t" (seconds since process start), "result"}.
//
// `typelat` (payload: interval in ms, newline, text) sends one key per
// interval and reports, per key, the synchronous keyDown handling time and the
// delay until the page view's layer next publishes new contents
// (tools/measure_chatgpt_typing.py). Publication is not physical scanout.
// `shot` (payload: output path) writes the presented page pixels as RGBA rows.
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <objc/runtime.h>
#include "native_test_presented_frame.h"
#include <JavaScriptCore/JavaScript.h>
#include <JavaScriptCore/JSStringRefCF.h>
#include <crt_externs.h>
#include <libproc.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <unistd.h>

// Helpers that inherit DYLD_INSERT_LIBRARIES (the adblock filter process)
// skip the driver.
static const char adblock_helper[] = "VoxAdblockWorker";

enum { kMaximumContexts = 512 };
static JSGlobalContextRef contexts[kMaximumContexts];
static int context_count;
static pthread_mutex_t context_lock = PTHREAD_MUTEX_INITIALIZER;
static JSGlobalContextRef page;
static NSString *origin;
static NSString *directory;
static NSView *input_view;
static double timebase;
static uint64_t process_start;

static void remember(JSGlobalContextRef context)
{
    if (!context || !pthread_main_np()) return;
    pthread_mutex_lock(&context_lock);
    if (context_count < kMaximumContexts) contexts[context_count++] = context;
    pthread_mutex_unlock(&context_lock);
}

static void forget(JSGlobalContextRef context)
{
    pthread_mutex_lock(&context_lock);
    for (int i = 0; i < context_count; i++) {
        if (contexts[i] == context) {
            contexts[i] = contexts[--context_count];
            break;
        }
    }
    if (page == context) page = NULL;
    pthread_mutex_unlock(&context_lock);
}

static JSGlobalContextRef driver_create_in_group(JSContextGroupRef group, JSClassRef klass)
{
    JSGlobalContextRef context = JSGlobalContextCreateInGroup(group, klass);
    remember(context);
    return context;
}

static JSGlobalContextRef driver_create(JSClassRef klass)
{
    JSGlobalContextRef context = JSGlobalContextCreate(klass);
    remember(context);
    return context;
}

static void driver_release(JSGlobalContextRef context)
{
    forget(context);
    JSGlobalContextRelease(context);
}

__attribute__((used)) static struct { const void *replacement, *original; } interposed[]
    __attribute__((section("__DATA,__interpose"))) = {
        { (const void *)driver_create_in_group, (const void *)JSGlobalContextCreateInGroup },
        { (const void *)driver_create, (const void *)JSGlobalContextCreate },
        { (const void *)driver_release, (const void *)JSGlobalContextRelease },
    };

static double now_seconds(void)
{
    return (double)(mach_absolute_time() - process_start) * timebase;
}

static NSString *evaluate(JSGlobalContextRef context, NSString *source, BOOL *threw)
{
    JSStringRef script = JSStringCreateWithCFString((__bridge CFStringRef)source);
    JSValueRef exception = NULL;
    JSValueRef value = JSEvaluateScript(context, script, NULL, NULL, 1, &exception);
    JSStringRelease(script);
    if (threw) *threw = exception != NULL;
    JSValueRef shown = exception ? exception : value;
    if (!shown) return @"null";
    JSStringRef text = JSValueToStringCopy(context, shown, NULL);
    if (!text) return @"<unconvertible>";
    CFStringRef copy = JSStringCopyCFString(kCFAllocatorDefault, text);
    JSStringRelease(text);
    return CFBridgingRelease(copy);
}

static JSGlobalContextRef page_context(void)
{
    if (page) return page;
    NSData *quoted = [NSJSONSerialization dataWithJSONObject:origin options:NSJSONWritingFragmentsAllowed error:nil];
    NSString *probe = [NSString stringWithFormat:
        @"(function(){try{return typeof window==='object'&&window.top===window&&typeof location==='object'"
         "&&String(location.href).indexOf(%@)===0?'1':'0'}catch(e){return '0'}})()",
        [[NSString alloc] initWithData:quoted encoding:NSUTF8StringEncoding]];
    pthread_mutex_lock(&context_lock);
    int count = context_count;
    JSGlobalContextRef candidates[kMaximumContexts];
    memcpy(candidates, contexts, sizeof(JSGlobalContextRef) * (size_t)count);
    pthread_mutex_unlock(&context_lock);
    for (int i = count - 1; i >= 0; i--) {
        if ([evaluate(candidates[i], probe, NULL) isEqualToString:@"1"]) {
            page = candidates[i];
            return page;
        }
    }
    return NULL;
}

static NSView *find_view(NSView *root, NSString *name)
{
    if ([root isKindOfClass:NSClassFromString(name)]) return root;
    for (NSView *child in root.subviews) {
        NSView *found = find_view(child, name);
        if (found) return found;
    }
    return nil;
}

static unsigned short key_code(unichar c)
{
    static const char *letters = "asdfhgzxcv?bqweryt123465=97-80]ou[ip?lj'k;\\,/nm.";
    if (c == ' ') return 49;
    if (c == '\r' || c == '\n') return 36;
    unichar lower = (c >= 'A' && c <= 'Z') ? (unichar)(c + 32) : c;
    const char *at = strchr(letters, (int)lower);
    return at && lower < 128 ? (unsigned short)(at - letters) : 0;
}

static void send_key(NSString *characters)
{
    unichar c = [characters characterAtIndex:0];
    NSWindow *window = input_view.window;
    NSTimeInterval time = NSProcessInfo.processInfo.systemUptime;
    NSEvent *down = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0
        timestamp:time windowNumber:window.windowNumber context:nil characters:characters
        charactersIgnoringModifiers:characters isARepeat:NO keyCode:key_code(c)];
    NSEvent *up = [NSEvent keyEventWithType:NSEventTypeKeyUp location:NSZeroPoint modifierFlags:0
        timestamp:time windowNumber:window.windowNumber context:nil characters:characters
        charactersIgnoringModifiers:characters isARepeat:NO keyCode:key_code(c)];
    [input_view keyDown:down];
    [input_view keyUp:up];
}

// Count page-view layer publications by wrapping its updateLayer.
static NSView *page_view;
static IMP original_update;
static double last_publication;
static unsigned long publication_count;

static void published(id self, SEL selector)
{
    // Keep the previous contents alive while comparing identities.
    __attribute__((objc_precise_lifetime)) id previous = ((NSView *)self).layer.contents;
    ((void (*)(id, SEL))original_update)(self, selector);
    if (previous != ((NSView *)self).layer.contents) {
        last_publication = now_seconds();
        publication_count++;
    }
}

static BOOL hook_page_view(void)
{
    if (original_update) return YES;
    for (NSWindow *window in NSApp.windows) {
        page_view = find_view(window.contentView, @"MyView2");
        if (page_view) break;
    }
    if (!page_view) return NO;
    Method method = class_getInstanceMethod(object_getClass(page_view), @selector(updateLayer));
    if (method) original_update = method_setImplementation(method, (IMP)published);
    return original_update != NULL;
}

static void respond(NSString *identifier, id result, double time);

static void type_with_latency(NSString *identifier, NSString *text, NSUInteger index, double interval,
    NSMutableArray *rows)
{
    if (index >= text.length) {
        respond(identifier, @{ @"rows" : rows }, now_seconds());
        return;
    }
    unsigned long before = publication_count;
    double sent = now_seconds();
    send_key([text substringWithRange:NSMakeRange(index, 1)]);
    NSMutableDictionary *row = [@{ @"send" : @(sent), @"handled" : @(now_seconds() - sent) } mutableCopy];
    [rows addObject:row];
    __block int polls = 0;
    __block void (^wait)(void);
    wait = ^{
        if (publication_count != before) {
            row[@"present"] = @(last_publication - sent);
        } else if (++polls < 3000) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), dispatch_get_main_queue(), wait);
            return;
        }
        double delay = fmax(sent + interval - now_seconds(), 0);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(),
            ^{ type_with_latency(identifier, text, index + 1, interval, rows); });
        wait = nil;
    };
    dispatch_async(dispatch_get_main_queue(), wait);
}

static NSDictionary *usage(void)
{
    struct rusage_info_v4 info;
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&info)) return @{};
    mach_timebase_info_data_t base;
    mach_timebase_info(&base);
    double scale = (double)base.numer / base.denom / 1e9;
    return @{
        @"instructions" : @(info.ri_instructions),
        @"cycles" : @(info.ri_cycles),
        @"user_seconds" : @(info.ri_user_time * scale),
        @"system_seconds" : @(info.ri_system_time * scale),
        @"resident_bytes" : @(info.ri_resident_size),
        @"peak_footprint_bytes" : @(info.ri_lifetime_max_phys_footprint),
    };
}

static void respond(NSString *identifier, id result, double time)
{
    NSDictionary *response = @{ @"id" : identifier, @"t" : @(time), @"result" : result ?: [NSNull null] };
    NSData *data = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
    NSString *final = [directory stringByAppendingPathComponent:[@"res-" stringByAppendingString:identifier]];
    NSString *temporary = [final stringByAppendingString:@".tmp"];
    [data writeToFile:temporary atomically:NO];
    rename(temporary.fileSystemRepresentation, final.fileSystemRepresentation);
}

// Vox pumps the run loop inside long document work (layout, navigation).
// Running page script there re-enters layout, so commands wait for the
// outermost run-loop level, identified by the stack depth of its observers.
static uintptr_t outer_stack;

static uintptr_t stack_position(void) { return (uintptr_t)__builtin_frame_address(0); }

static void observe_run_loop(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    (void)observer; (void)activity; (void)info;
    uintptr_t position = stack_position();
    if (position > outer_stack) outer_stack = position;
}

static BOOL nested_run_loop(void)
{
    return outer_stack && stack_position() + 8192 < outer_stack;
}

static void execute(NSString *identifier, NSString *command, NSString *payload)
{
    if (nested_run_loop()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * 2), dispatch_get_main_queue(),
            ^{ execute(identifier, command, payload); });
        return;
    }
    double time = now_seconds();
    if ([command isEqualToString:@"eval"]) {
        JSGlobalContextRef context = page_context();
        if (!context) {
            respond(identifier, @{ @"error" : @"no page context" }, time);
            return;
        }
        BOOL threw = NO;
        NSString *value = evaluate(context, payload, &threw);
        respond(identifier, threw ? @{ @"exception" : value } : @{ @"value" : value }, time);
    } else if ([command isEqualToString:@"type"]) {
        // One key per main-queue turn, as separately delivered native events.
        NSUInteger length = payload.length;
        for (NSUInteger i = 0; i < length; i++) {
            NSString *character = [payload substringWithRange:NSMakeRange(i, 1)];
            BOOL last = i + 1 == length;
            dispatch_async(dispatch_get_main_queue(), ^{
                send_key(character);
                if (last) respond(identifier, @{ @"typed" : @(length) }, now_seconds());
            });
        }
        if (!length) respond(identifier, @{ @"typed" : @0 }, time);
    } else if ([command isEqualToString:@"typelat"]) {
        NSRange newline = [payload rangeOfString:@"\n"];
        if (newline.location == NSNotFound || !hook_page_view()) {
            respond(identifier, @{ @"error" : @"typelat needs a page view and an interval line" }, time);
            return;
        }
        type_with_latency(identifier, [payload substringFromIndex:newline.location + 1], 0,
            [[payload substringToIndex:newline.location] doubleValue] / 1000.0, [NSMutableArray array]);
    } else if ([command isEqualToString:@"shot"]) {
        // Raw RGBA rows of the page view's presented contents.
        if (!hook_page_view()) {
            respond(identifier, @{ @"error" : @"no page view" }, time);
            return;
        }
        id contents = page_view.layer.contents;
        CGSize size = native_test_presented_size(contents);
        NSData *pixels = native_test_presented_pixels(contents);
        if (!pixels || ![pixels writeToFile:payload atomically:YES]) {
            respond(identifier, @{ @"error" : @"no presented pixels" }, time);
            return;
        }
        respond(identifier, @{ @"width" : @(size.width), @"height" : @(size.height),
            @"publications" : @(publication_count) }, time);
    } else if ([command isEqualToString:@"pid"]) {
        respond(identifier, @{ @"pid" : @(getpid()) }, time);
    } else if ([command isEqualToString:@"usage"]) {
        respond(identifier, usage(), time);
    } else if ([command isEqualToString:@"quit"]) {
        respond(identifier, usage(), time);
        exit(0);
    } else {
        respond(identifier, @{ @"error" : @"unknown command" }, time);
    }
}

static void *poll_requests(void *unused)
{
    (void)unused;
    NSFileManager *files = NSFileManager.defaultManager;
    for (;;) {
        @autoreleasepool {
            NSArray *names = [files contentsOfDirectoryAtPath:directory error:nil];
            for (NSString *name in [names sortedArrayUsingSelector:@selector(compare:)]) {
                if (![name hasPrefix:@"req-"] || [name containsString:@"."]) continue;
                NSString *path = [directory stringByAppendingPathComponent:name];
                NSString *claimed = [path stringByAppendingString:@".claimed"];
                if (rename(path.fileSystemRepresentation, claimed.fileSystemRepresentation)) continue;
                NSString *text = [NSString stringWithContentsOfFile:claimed encoding:NSUTF8StringEncoding error:nil];
                NSRange newline = [text rangeOfString:@"\n"];
                NSString *command = newline.location == NSNotFound ? text : [text substringToIndex:newline.location];
                NSString *payload = newline.location == NSNotFound ? @"" : [text substringFromIndex:newline.location + 1];
                NSString *identifier = [name substringFromIndex:4];
                dispatch_async(dispatch_get_main_queue(), ^{ execute(identifier, command, payload); });
            }
        }
        usleep(20000);
    }
    return NULL;
}

static void wait_for_window(void)
{
    for (NSWindow *window in NSApp.windows) {
        input_view = find_view(window.contentView, @"_sapp_macos_view");
        if (input_view) break;
    }
    if (!input_view) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 20), dispatch_get_main_queue(),
            ^{ wait_for_window(); });
        return;
    }
    respond(@"window", @{ @"window" : @YES }, now_seconds());
    pthread_t thread;
    pthread_create(&thread, NULL, poll_requests, NULL);
    pthread_detach(thread);
}

__attribute__((constructor)) static void boot(void)
{
    if (!strcmp(getprogname(), adblock_helper)) return;
    // Script-worker children re-execute Vox with private --vox-* arguments.
    char **arguments = *_NSGetArgv();
    for (int i = 1; arguments[i]; i++)
        if (!strncmp(arguments[i], "--vox-", 6)) return;
    const char *path = getenv("VOX_JS_DRIVER_DIR");
    const char *wanted = getenv("VOX_JS_DRIVER_ORIGIN");
    if (!path || !wanted) return;
    directory = [NSString stringWithUTF8String:path];
    origin = [NSString stringWithUTF8String:wanted];
    mach_timebase_info_data_t base;
    mach_timebase_info(&base);
    timebase = (double)base.numer / base.denom / 1e9;
    struct rusage_info_v4 info;
    process_start = proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&info) ? mach_absolute_time()
                                                                                       : info.ri_proc_start_abstime;
    CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0,
        observe_run_loop, NULL);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    dispatch_async(dispatch_get_main_queue(), ^{ wait_for_window(); });
}
