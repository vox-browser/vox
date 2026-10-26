// Measure address submission -> first changed native publication of the new
// document. Injection is read-only except for ordinary native address input.
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>

static NSView *page;
static IMP original_update;
static double started, ready_since = -1, settle;
static BOOL active, completed;
static NSString *from_url, *to_url, *from_title, *to_title, *output;

static NSView *find_view(NSView *root, NSString *name) {
    if ([root isKindOfClass:NSClassFromString(name)]) return root;
    for (NSView *child in root.subviews) {
        NSView *found = find_view(child, name);
        if (found) return found;
    }
    return nil;
}
static NSTextField *address_field(NSView *root) {
    if ([root isKindOfClass:NSTextField.class] &&
        [[(NSTextField *)root stringValue] isEqualToString:from_url]) return (NSTextField *)root;
    for (NSView *child in root.subviews) {
        NSTextField *found = address_field(child);
        if (found) return found;
    }
    return nil;
}
static void capture(NSString *name) {
    id contents = page.layer.contents;
    if (!contents || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID()) {
        fprintf(stderr, "PAGE_SWITCH_ERROR no CGImage publication\n"); exit(2);
    }
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)contents];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (![png writeToFile:[output stringByAppendingPathComponent:name] atomically:YES]) {
        fprintf(stderr, "PAGE_SWITCH_ERROR cannot save publication\n"); exit(2);
    }
}
static void published(id view, SEL selector) {
    __attribute__((objc_precise_lifetime)) id previous = page.layer.contents;
    double before = CACurrentMediaTime();
    ((void (*)(id, SEL))original_update)(view, selector);
    double now = CACurrentMediaTime();
    if (!active || completed || view != page || previous == page.layer.contents) return;
    if (![page.window.title containsString:to_title]) return;
    completed = YES;
    fprintf(stderr, "PAGE_SWITCH_RESULT navigation_ms=%.6f callback_ms=%.6f scale=%g width=%g height=%g submitted_s=%.9f published_s=%.9f title=%s\n",
        (now-started)*1000, (now-before)*1000, page.window.backingScaleFactor,
        page.bounds.size.width, page.bounds.size.height, started, now, page.window.title.UTF8String);
    capture(@"first-new.png");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        capture(@"settled-new.png");
        fprintf(stderr, "PAGE_SWITCH_DONE\n"); fflush(stderr); exit(0);
    });
}
static void poll(void) {
    if (!page) {
        for (NSWindow *window in NSApp.windows) {
            page = find_view(window.contentView, @"MyView2");
            if (page) break;
        }
    }
    if (page && page.layer.contents && [page.window.title containsString:from_title]) {
        double now = CACurrentMediaTime();
        if (ready_since < 0) ready_since = now;
        if (now-ready_since >= settle) {
            NSTextField *address = address_field(page.window.contentView);
            if (!address || !address.action || !address.target) {
                fprintf(stderr, "PAGE_SWITCH_ERROR native address control unavailable\n"); exit(2);
            }
            Method method = class_getInstanceMethod(page.class, @selector(updateLayer));
            if (!method) { fprintf(stderr, "PAGE_SWITCH_ERROR no updateLayer\n"); exit(2); }
            original_update = method_setImplementation(method, (IMP)published);
            capture(@"hot.png");
            fprintf(stderr, "PAGE_SWITCH_START from=%s to=%s settle=%g title=%s\n",
                from_url.UTF8String, to_url.UTF8String, settle, page.window.title.UTF8String);
            address.stringValue = to_url;
            active = YES;
            started = CACurrentMediaTime();
            if (![NSApp sendAction:address.action to:address.target from:address]) {
                fprintf(stderr, "PAGE_SWITCH_ERROR address submit failed\n"); exit(2);
            }
            return;
        }
    } else ready_since = -1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC/10), dispatch_get_main_queue(), ^{ poll(); });
}
__attribute__((constructor)) static void boot(void) {
    @autoreleasepool {
        const char *names[] = {"VOX_SWITCH_FROM", "VOX_SWITCH_TO", "VOX_SWITCH_FROM_TITLE", "VOX_SWITCH_TO_TITLE", "VOX_SWITCH_OUTPUT"};
        NSString *__strong *values[] = {&from_url, &to_url, &from_title, &to_title, &output};
        for (int i = 0; i < 5; ++i) {
            const char *value = getenv(names[i]);
            if (!value || !*value) { fprintf(stderr, "PAGE_SWITCH_ERROR missing %s\n", names[i]); exit(2); }
            *values[i] = [NSString stringWithUTF8String:value];
        }
        settle = getenv("VOX_SWITCH_SETTLE") ? atof(getenv("VOX_SWITCH_SETTLE")) : 4;
        dispatch_async(dispatch_get_main_queue(), ^{ poll(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 90*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            fprintf(stderr, "PAGE_SWITCH_ERROR timeout title=%s\n", page.window.title.UTF8String); exit(2);
        });
    }
}
