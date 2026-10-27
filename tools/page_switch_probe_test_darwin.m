// Deterministic publications: destination text, late image, then chrome only.
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>

@interface MyView2 : NSView
@property int phase;
@property int chrome;
@end
@implementation MyView2
- (void)updateLayer {
    CGFloat scale = self.window.backingScaleFactor;
    size_t width = (size_t)llround(self.bounds.size.width*scale);
    size_t height = (size_t)llround(self.bounds.size.height*scale);
    size_t top = (size_t)llround(60*scale), bottom = (size_t)llround(24*scale);
    NSMutableData *pixels = [NSMutableData dataWithLength:width*height*4];
    UInt8 *bytes = pixels.mutableBytes;
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            size_t i = (y*width+x)*4;
            bytes[i] = y < top || y >= height-bottom ? (UInt8)(20+self.chrome*40) : (UInt8)(50+self.phase*70);
            bytes[i+3] = 255;
        }
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bytes, width, height, 8, width*4, space,
                                                (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGImageRef image = CGBitmapContextCreateImage(context);
    self.layer.contents = (__bridge id)image;
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
}
@end

@interface Controller : NSObject
@property(nonatomic, strong) MyView2 *view;
- (void)navigate:(id)sender;
@end
@implementation Controller
- (void)paint:(int)phase chrome:(int)chrome {
    self.view.phase = phase;
    self.view.chrome = chrome;
    double before = CACurrentMediaTime();
    [self.view updateLayer];
    fprintf(stderr, "FIXTURE_PAINT phase=%d chrome=%d before=%.9f after=%.9f\n",
            phase, chrome, before, CACurrentMediaTime());
}
- (void)navigate:(id)sender {
    (void)sender;
    self.view.window.title = @"new destination";
    // A title can change before the destination's first paint. An AppKit
    // update of the old document, even with different chrome, must not count.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self paint:0 chrome:1];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC/10), dispatch_get_main_queue(), ^{
        [self paint:1 chrome:0];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 350*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self paint:2 chrome:0];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 600*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self paint:2 chrome:1];
    });
}
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        __attribute__((objc_precise_lifetime)) NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,64,148)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        MyView2 *view = [[MyView2 alloc] initWithFrame:window.contentView.bounds];
        view.wantsLayer = YES;
        [window.contentView addSubview:view];
        __attribute__((objc_precise_lifetime)) Controller *controller = [Controller new];
        controller.view = view;
        NSTextField *address = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,20,20)];
        address.stringValue = @"https://old.reddit.com/r/example/";
        address.target = controller;
        address.action = @selector(navigate:);
        [window.contentView addSubview:address];
        window.title = @"hot source";
        [view updateLayer];
        // No window is shown and no physical input is sent.
        [NSApp run];
        (void)controller;
    }
    return 1;
}
