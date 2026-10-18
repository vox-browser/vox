#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <stdint.h>

#ifdef VOX_STATIC_MEMORY_STATUS_TEST_STUB
#include "main_memory_status_test.h"
#else

// These host helpers are defined by the earlier native_capture_darwin.m
// include. The label shares the actual presentation density, including captures.
static NSView *native_browser_view(void);
static CGFloat native_layer_effective_scale(NSView *view);

#ifndef VOX_MEMORY_STATUS_READ_BYTES
#include "processmetrics/memory_darwin.h"
#define VOX_MEMORY_STATUS_READ_BYTES vox_process_memory_bytes
#endif
#ifndef VOX_MEMORY_STATUS_OWNER_WINDOW
#define VOX_MEMORY_STATUS_OWNER_WINDOW(view) ((view).window)
#endif
#ifndef VOX_MEMORY_STATUS_VIEW_AVAILABLE
#define VOX_MEMORY_STATUS_VIEW_AVAILABLE(view) ((view).window != nil)
#endif

static NSString *native_memory_status_label(uint64_t bytes, BOOL available) {
    if (!available) return @"RAM: unavailable";
    if (bytes >= UINT64_C(1000000000))
        return [NSString stringWithFormat:@"RAM: %.1f GB", (double)bytes / 1000000000.0];
    return [NSString stringWithFormat:@"RAM: %.1f MB", (double)bytes / 1000000.0];
}

@interface VoxStaticMemoryStatusLayer : CATextLayer
@property(nonatomic, weak) NSView *memoryOwner;
@property(nonatomic, strong) NSFont *memoryFont;
@property(nonatomic, strong) dispatch_source_t memoryTimer;
@property(nonatomic, strong) id memoryWindowObserver;
@property(nonatomic) BOOL memoryActive;
- (void)sampleMemory;
- (BOOL)startSampling;
- (void)invalidateSampling;
@end

static __weak VoxStaticMemoryStatusLayer *native_static_memory_status_layer;

@implementation VoxStaticMemoryStatusLayer
- (instancetype)initWithLayer:(id)other {
    self = [super initWithLayer:other];
    if (self != nil && [other isKindOfClass:VoxStaticMemoryStatusLayer.class])
        _memoryFont = ((VoxStaticMemoryStatusLayer *)other).memoryFont;
    return self;
}
- (void)invalidateSampling {
    self.memoryActive = NO;
    if (_memoryTimer != nil) {
        dispatch_source_cancel(_memoryTimer);
        _memoryTimer = nil;
    }
    if (_memoryWindowObserver != nil) {
        [NSNotificationCenter.defaultCenter removeObserver:_memoryWindowObserver];
        _memoryWindowObserver = nil;
    }
}
- (void)removeFromSuperlayer {
    [self invalidateSampling];
    [super removeFromSuperlayer];
}
- (void)dealloc {
    // Cancellation is safe even if the last layer reference is released off
    // the main thread. A queued handler holds only a weak layer reference.
    if (_memoryTimer != nil) dispatch_source_cancel(_memoryTimer);
    if (_memoryWindowObserver != nil)
        [NSNotificationCenter.defaultCenter removeObserver:_memoryWindowObserver];
}
- (void)sampleMemory {
    NSView *owner = self.memoryOwner;
    if (!self.memoryActive) return;
    if (owner == nil || self.superlayer != owner.layer || !VOX_MEMORY_STATUS_VIEW_AVAILABLE(owner)) {
        [self removeFromSuperlayer];
        return;
    }
    uint64_t bytes = 0;
    NSString *label = native_memory_status_label(bytes, NO);
    if (VOX_MEMORY_STATUS_READ_BYTES(&bytes) == 0)
        label = native_memory_status_label(bytes, YES);
    if ([self.string isEqual:label]) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.string = label;
    [CATransaction commit];
}
- (BOOL)startSampling {
    if (_memoryTimer != nil) return YES;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
        dispatch_get_main_queue());
    if (timer == nil) return NO;
    self.memoryTimer = timer;
    self.memoryActive = YES;
    __weak VoxStaticMemoryStatusLayer *weakLabel = self;
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
        NSEC_PER_SEC, 20 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        @autoreleasepool { [weakLabel sampleMemory]; }
    });
    NSWindow *window = VOX_MEMORY_STATUS_OWNER_WINDOW(self.memoryOwner);
    if (window != nil) {
        self.memoryWindowObserver = [NSNotificationCenter.defaultCenter
            addObserverForName:NSWindowWillCloseNotification object:window
            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
                (void)notification;
                [weakLabel removeFromSuperlayer];
            }];
    }
    dispatch_resume(timer);
    return YES;
}
- (void)drawInContext:(CGContextRef)context {
    // CoreText paints this small chrome-only layer. It never invokes the V
    // painter, changes the retained document bitmap, or creates a Skia context.
    // An opaque custom backing store must paint its background as well as its
    // text; otherwise its unpainted pixels cover the layer color with black.
    CGContextSetFillColorWithColor(context, self.backgroundColor);
    CGContextFillRect(context, self.bounds);
    NSString *label = [self.string isKindOfClass:NSString.class] ? self.string : @"";
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:label attributes:@{
        NSFontAttributeName: self.memoryFont,
        NSForegroundColorAttributeName: [NSColor colorWithSRGBRed:203.0 / 255.0
            green:213.0 / 255.0 blue:225.0 / 255.0 alpha:1.0]
    }];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    double width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    CGContextSaveGState(context);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextSetTextPosition(context, CGRectGetWidth(self.bounds) - 12.0 - width,
        CGRectGetHeight(self.bounds) - 4.0 - self.memoryFont.ascender);
    CTLineDraw(line, context);
    CGContextRestoreGState(context);
    CFRelease(line);
}
@end

void native_disable_static_memory_label(void) {
    if (![NSThread isMainThread]) return;
    VoxStaticMemoryStatusLayer *label = native_static_memory_status_layer;
    native_static_memory_status_layer = nil;
    [label removeFromSuperlayer];
}

int native_use_static_memory_label(float width, float status_y, float height) {
    if (![NSThread isMainThread]) return 0;
    NSView *view = native_browser_view();
    CALayer *parent = view.layer;
    if (view == nil || parent == nil || !VOX_MEMORY_STATUS_VIEW_AVAILABLE(view)
        || !isfinite(width) || !isfinite(status_y) || !isfinite(height)
        || width <= 0 || height <= 0) {
        native_disable_static_memory_label();
        return 0;
    }
    VoxStaticMemoryStatusLayer *label = native_static_memory_status_layer;
    BOOL created = label == nil || label.memoryOwner != view || label.superlayer != parent;
    if (created) {
        native_disable_static_memory_label();
        label = [VoxStaticMemoryStatusLayer layer];
        label.memoryOwner = view;
        label.memoryFont = [NSFont userFontOfSize:12] ?: [NSFont systemFontOfSize:12];
        label.font = (__bridge CFTypeRef)label.memoryFont.fontName;
        label.fontSize = 12;
        label.alignmentMode = kCAAlignmentRight;
        label.opaque = YES;
        label.masksToBounds = YES;
        label.geometryFlipped = NO;
        label.backgroundColor = [NSColor colorWithSRGBRed:30.0 / 255.0
            green:41.0 / 255.0 blue:59.0 / 255.0 alpha:1.0].CGColor;
        [parent addSublayer:label];
        native_static_memory_status_layer = label;
        if (![label startSampling]) {
            native_disable_static_memory_label();
            return 0;
        }
    }
    // A fixed maximum label width lets timer ticks change only the string.
    // Even the largest uint64 footprint fits without resizing the parent.
    CGFloat label_width = ceil([@"RAM: 18446744073.7 GB" sizeWithAttributes:@{
        NSFontAttributeName: label.memoryFont
    }].width) + 24.0;
    label_width = MIN((CGFloat)width, label_width);
    CGFloat y = parent.geometryFlipped ? view.bounds.origin.y + status_y
        : NSMaxY(view.bounds) - status_y - height;
    CGFloat scale = native_layer_effective_scale(view);
    if (!isfinite(scale) || scale <= 0) scale = 1;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    label.frame = CGRectMake(view.bounds.origin.x + width - label_width, y, label_width, height);
    label.contentsScale = scale;
    [CATransaction commit];
    if (created) [label sampleMemory];
    return 1;
}
#endif
