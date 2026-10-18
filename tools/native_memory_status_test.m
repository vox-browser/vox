#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>
#include <stdlib.h>

static NSView *test_view;
static BOOL test_available = YES;
static id test_notification_window;
static uint64_t test_bytes = 123450000;
static int test_read_result, test_reads, test_document_draws;
static uint64_t test_worker_bytes;
static int test_worker_result, test_worker_reads;
static int test_worker_memory_bytes(uint64_t *bytes) {
    test_worker_reads++; *bytes = test_worker_bytes; return test_worker_result;
}
static int test_memory_bytes(uint64_t *bytes) {
    test_reads++;
    *bytes = test_bytes;
    return test_read_result;
}
static NSView *native_browser_view(void) { return test_view; }
static CGFloat native_layer_effective_scale(NSView *view) { return view.layer.contentsScale; }
#define VOX_MEMORY_STATUS_PARENT_BYTES test_memory_bytes
#define VOX_MEMORY_STATUS_WORKER_BYTES test_worker_memory_bytes
#define VOX_MEMORY_STATUS_VIEW_AVAILABLE(view) ((view) != nil && test_available)
#define VOX_MEMORY_STATUS_OWNER_WINDOW(view) ((NSWindow *)test_notification_window)
#include "../native_memory_status_darwin.m"

#define CHECK(condition) do { if (!(condition)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); exit(1); } } while (0)

@interface TestMemoryDocumentLayer : CALayer
@end
@implementation TestMemoryDocumentLayer
- (void)display { test_document_draws++; [super display]; }
@end

static NSView *make_view(void) {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    view.wantsLayer = YES;
    view.layer = [TestMemoryDocumentLayer layer];
    view.layer.frame = view.bounds;
    view.layer.contentsScale = 1;
    return view;
}
static void check_label_style(VoxStaticMemoryStatusLayer *label) {
    CHECK(label.fontSize == 12);
    CHECK([label.memoryFont.fontName isEqual:[NSFont userFontOfSize:12].fontName]);
    CHECK([label.alignmentMode isEqual:kCAAlignmentRight]);
    CHECK(label.opaque && label.masksToBounds);
    CHECK(CGColorGetNumberOfComponents(label.backgroundColor) == 4);
    const CGFloat *color = CGColorGetComponents(label.backgroundColor);
    CHECK(fabs(color[0] - 30.0/255.0) < .00001);
    CHECK(fabs(color[1] - 41.0/255.0) < .00001);
    CHECK(fabs(color[2] - 59.0/255.0) < .00001);
}

static void check_lifetimes(void) {
    test_available = YES;
    test_read_result = 0;
    test_bytes = 999999999;
    CHECK([native_memory_status_label(0, YES) isEqual:@"RAM: 0.0 MB"]);
    CHECK([native_memory_status_label(999999999, YES) isEqual:@"RAM: 1000.0 MB"]);
    CHECK([native_memory_status_label(1000000000, YES) isEqual:@"RAM: 1.0 GB"]);
    CHECK([native_memory_status_label(1500000000, YES) isEqual:@"RAM: 1.5 GB"]);
    CHECK([native_memory_status_label(0, NO) isEqual:@"RAM: unavailable"]);
    test_view = make_view();
    CHECK(native_use_static_memory_label(800, 576, 24) == 1);
    VoxStaticMemoryStatusLayer *old = native_static_memory_status_layer;
    dispatch_source_t timer = old.memoryTimer;
    for (int i = 0; i < 60; i++) CHECK(native_use_static_memory_label(800, 576, 24) == 1);
    CHECK(native_static_memory_status_layer == old && old.memoryTimer == timer);
    CHECK(test_view.layer.sublayers.count == 1);
    CHECK(CGRectGetMinY(old.frame) == 0 && CGRectGetHeight(old.frame) == 24);
    CHECK(CGRectGetMaxX(old.frame) == 800);
    check_label_style(old);
    test_view.layer.geometryFlipped = YES;
    test_view.layer.contentsScale = 2;
    CHECK(native_use_static_memory_label(640, 550, 20) == 1);
    CHECK(CGRectGetMinY(old.frame) == 550 && CGRectGetMaxX(old.frame) == 640);
    CHECK(CGRectGetHeight(old.frame) == 20 && old.contentsScale == 2);
    test_view.bounds = NSMakeRect(17, 23, 800, 600);
    test_view.layer.geometryFlipped = YES;
    CHECK(native_use_static_memory_label(640, 550.5, 20) == 1);
    CHECK(CGRectGetMinY(old.frame) == 573.5 && CGRectGetMaxX(old.frame) == 657);
    test_view.layer.geometryFlipped = NO;
    CHECK(native_use_static_memory_label(640, 550.5, 20) == 1);
    CHECK(CGRectGetMinY(old.frame) == 52.5);
    __block int background_result = 1;
    dispatch_semaphore_t completed = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        background_result = native_use_static_memory_label(640, 550, 20);
        native_disable_static_memory_label();
        dispatch_semaphore_signal(completed);
    });
    CHECK(dispatch_semaphore_wait(completed, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)) == 0);
    CHECK(background_result == 0 && old.memoryActive);
    native_disable_static_memory_label();
    CHECK(!old.memoryActive && old.memoryTimer == nil && old.superlayer == nil);
    int reads = test_reads;
    [old sampleMemory];
    CHECK(test_reads == reads);
    CHECK(native_use_static_memory_label(640, 550, 20) == 1);
    CHECK(native_static_memory_status_layer != old);
    VoxStaticMemoryStatusLayer *next = native_static_memory_status_layer;
    test_view = make_view();
    CHECK(native_use_static_memory_label(800, 576, 24) == 1);
    CHECK(!next.memoryActive && next.memoryTimer == nil && next.superlayer == nil);
    next = native_static_memory_status_layer;
    [next removeFromSuperlayer];
    CHECK(!next.memoryActive && next.memoryTimer == nil);
    CHECK(native_use_static_memory_label(NAN, 550, 20) == 0);
    CHECK(native_static_memory_status_layer == nil);
    test_notification_window = [NSObject new];
    CHECK(native_use_static_memory_label(640, 550, 20) == 1);
    VoxStaticMemoryStatusLayer *observed = native_static_memory_status_layer;
    CHECK(observed.memoryWindowObserver != nil);
    [NSNotificationCenter.defaultCenter postNotificationName:NSWindowWillCloseNotification
        object:test_notification_window];
    CHECK(!observed.memoryActive && observed.superlayer == nil && observed.memoryTimer == nil);
    test_notification_window = nil;
    native_disable_static_memory_label();
    __weak NSView *weakOwner;
    __weak VoxStaticMemoryStatusLayer *weakLayer;
    @autoreleasepool {
        NSView *owner = make_view();
        test_view = owner;
        CHECK(native_use_static_memory_label(800, 576, 24) == 1);
        weakOwner = owner;
        weakLayer = native_static_memory_status_layer;
        native_disable_static_memory_label();
        [CATransaction flush];
        test_view = nil;
        owner = nil;
    }
    CHECK(weakOwner == nil && weakLayer == nil);
    @autoreleasepool {
        NSView *owner = make_view();
        test_view = owner;
        CHECK(native_use_static_memory_label(800, 576, 24) == 1);
        weakOwner = owner;
        weakLayer = native_static_memory_status_layer;
        // A live timer and global lookup must not keep the owner or layer alive.
        test_view = nil;
        owner = nil;
        [CATransaction flush];
    }
    CHECK(weakOwner == nil && weakLayer == nil && native_static_memory_status_layer == nil);
    test_view = make_view();
    CHECK(native_use_static_memory_label(800, 576, 24) == 1);
    VoxStaticMemoryStatusLayer *unavailable = native_static_memory_status_layer;
    test_available = NO;
    [unavailable sampleMemory];
    CHECK(!unavailable.memoryActive && unavailable.memoryTimer == nil && unavailable.superlayer == nil);
    native_disable_static_memory_label();
    test_available = YES;
    test_view = nil;
}

static void check_software_layer_capture(VoxStaticMemoryStatusLayer *label) {
    for (int scale = 1; scale <= 2; scale++) {
        test_view.layer.contentsScale = scale;
        CHECK(native_use_static_memory_label(800, 576, 24) == 1);
        CHECK(label.contentsScale == scale);
        size_t width = (size_t)ceil(label.bounds.size.width * scale), height = 24 * scale;
        uint8_t *pixels = calloc(width * height, 4);
        CHECK(pixels != NULL);
        CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4,
            color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CHECK(context != NULL);
        CGContextScaleCTM(context, scale, scale);
        [label displayIfNeeded];
        [label renderInContext:context];
        size_t text_pixels = 0, foreground_pixels = 0, background_pixels = 0;
        for (size_t index = 0; index < width * height; index++) {
            uint8_t *pixel = pixels + index * 4;
            CHECK(pixel[3] == 255);
            if (pixel[0] > 60 && pixel[1] > 70 && pixel[2] > 80) text_pixels++;
            if (abs(pixel[0] - 203) < 3 && abs(pixel[1] - 213) < 3 && abs(pixel[2] - 225) < 3)
                foreground_pixels++;
            if (abs(pixel[0] - 30) < 2 && abs(pixel[1] - 41) < 2 && abs(pixel[2] - 59) < 2)
                background_pixels++;
        }
        if (!(text_pixels > (size_t)(40 * scale) && background_pixels > width * height / 2))
            fprintf(stderr, "scale=%d text=%zu bg=%zu first=%u,%u,%u,%u\n", scale,
                text_pixels, background_pixels, pixels[0], pixels[1], pixels[2], pixels[3]);
        CHECK(text_pixels > (size_t)(40 * scale) && background_pixels > width * height / 2);
        CHECK(foreground_pixels > 5);
        CGContextRelease(context);
        CGColorSpaceRelease(color);
        free(pixels);
    }
}

static void check_owned_child_accounting(void) {
    uint64_t bytes=0;
    test_read_result=test_worker_result=0;test_bytes=100000000;test_worker_bytes=0;
    CHECK(native_browser_memory_bytes(&bytes)==0&&bytes==100000000);
    test_worker_bytes=25000000;
    CHECK(native_browser_memory_bytes(&bytes)==0&&bytes==125000000);
    test_worker_bytes=0;
    CHECK(native_browser_memory_bytes(&bytes)==0&&bytes==100000000);
    test_worker_result=-1;CHECK(native_browser_memory_bytes(&bytes)!=0);
    test_worker_result=0;test_read_result=-1;CHECK(native_browser_memory_bytes(&bytes)!=0);
    test_read_result=0;test_bytes=UINT64_MAX;test_worker_bytes=1;
    CHECK(native_browser_memory_bytes(&bytes)!=0);
    test_worker_bytes=0;CHECK(native_browser_memory_bytes(&bytes)==0&&bytes==UINT64_MAX);
    test_bytes=123450000;
}
int main(void) {
    @autoreleasepool {
        check_owned_child_accounting();
        check_lifetimes();
        test_bytes = 123450000;
        test_view = make_view();
        uint32_t pixel = 0xff123456;
        CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
        CGContextRef bitmap = CGBitmapContextCreate(&pixel, 1, 1, 8, 4, color,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        CGImageRef image = CGBitmapContextCreateImage(bitmap);
        test_view.layer.contents = (__bridge id)image;
        CHECK(native_use_static_memory_label(800, 576, 24) == 1);
        VoxStaticMemoryStatusLayer *label = native_static_memory_status_layer;
        CHECK([label.string isEqual:@"RAM: 123.5 MB"]);
        check_software_layer_capture(label);
        test_view.needsDisplay = NO;
        [test_view.layer displayIfNeeded];
        test_document_draws = 0;
        int initial_reads = test_reads;
        test_bytes = 200000000;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            CHECK(test_reads > initial_reads);
            CHECK([label.string isEqual:@"RAM: 200.0 MB"]);
            CHECK(test_view.layer.contents == (__bridge id)image);
            CHECK(!test_view.needsDisplay && !test_view.layer.needsDisplay && test_document_draws == 0);
            test_bytes = 1500000000;
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            CHECK(test_reads >= initial_reads + 2);
            CHECK([label.string isEqual:@"RAM: 1.5 GB"]);
            [label displayIfNeeded];
            CHECK(test_view.layer.contents == (__bridge id)image);
            CHECK(!test_view.needsDisplay && !test_view.layer.needsDisplay && test_document_draws == 0);
            test_read_result = -1;
            [label sampleMemory];
            CHECK([label.string isEqual:@"RAM: unavailable"]);
            native_disable_static_memory_label();
            CHECK(label.memoryTimer == nil);
            CFRelease(image);
            CGContextRelease(bitmap);
            CGColorSpaceRelease(color);
            puts("PASS native memory label: real timer, parent bitmap/draw stability, style, density, reuse, lifecycle");
            exit(0);
        });
    }
    // Keep the original Cocoa main thread alive. dispatch_main() retires it,
    // which is unlike the browser's AppKit loop and changes isMainThread.
    CFRunLoopRun();
    return 1;
}
