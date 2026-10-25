#import <Cocoa/Cocoa.h>
#include <assert.h>
#include "../native_layer_presentation_darwin.h"

static NSView *submitted_view;
static unsigned reports;
static uint64_t submitted_tokens[8];
static int64_t submitted_navigations[8];
static unsigned mode;
static NSView *nested_view;

static void submitted(void *target, int64_t navigation, uint64_t installation, uint64_t token) {
    NSView *view = (__bridge NSView *)target;
    assert(view.layer.contents);
    assert(CFGetTypeID((__bridge CFTypeRef)view.layer.contents) == CGImageGetTypeID());
    assert(installation == 9);
    assert(token);
    assert(reports < 8);
    submitted_tokens[reports] = token;
    submitted_navigations[reports++] = navigation;
    submitted_view = view;
}

static void draw(id self, SEL command, NSRect bounds) {
    (void)command;
    CGContextRef bitmap = NSGraphicsContext.currentContext.CGContext;
    assert(bitmap);
    CGContextSetRGBFillColor(bitmap, 1, 0, 0, 1);
    CGContextFillRect(bitmap, bounds);
    if (mode == 0) return; // Chrome-only / resource-gated frame.
    uint64_t token = vox_browser_stage_document_submission(submitted, (__bridge void *)self,
        self == nested_view ? 22 : 11, 9);
    assert(token);
    assert(!vox_browser_stage_document_submission(submitted, (__bridge void *)self, 99, 9));
    assert(!reports || submitted_tokens[reports - 1] != token);
    if (mode == 2) [NSException raise:@"SubmissionTest" format:@"failed draw"];
    if (mode == 3 && self != nested_view) {
        NativeDocumentSubmissionFrame *outer = native_document_submission_current;
        native_layer_present_frame(nested_view, 1, (IMP)draw);
        assert(native_document_submission_current == outer);
        assert(outer->token == token);
    }
}

int main(void) {
    @autoreleasepool {
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        view.wantsLayer = YES;
        nested_view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 2, 2)];
        nested_view.wantsLayer = YES;
        assert(!vox_browser_stage_document_submission(submitted, (__bridge void *)view, 1, 9));
        native_layer_present_frame(view, 1, (IMP)draw);
        assert(reports == 0);
        mode = 1;
        native_layer_present_frame(view, NAN, (IMP)draw);
        native_layer_present_frame(view, 1, NULL);
        assert(reports == 0);
        // Rasterization alone has not submitted the produced image.
        CGImageRef unsubmitted = native_layer_raster_frame(view, 1, (IMP)draw);
        assert(unsubmitted && reports == 0);
        CGImageRelease(unsubmitted);
        mode = 2;
        BOOL caught = NO;
        @try { native_layer_present_frame(view, 1, (IMP)draw); }
        @catch (NSException *exception) { caught = YES; }
        assert(caught && reports == 0 && !native_document_submission_current);
        mode = 1;
        native_layer_present_frame(view, 1, (IMP)draw);
        assert(reports == 1 && submitted_view == view);
        assert(submitted_navigations[0] == 11);
        assert(!native_document_submission_current);
        // Cached image copying never invokes the document callback again.
        native_layer_copying_capture = YES;
        native_layer_draw(view, @selector(drawRect:), view.bounds);
        native_layer_copying_capture = NO;
        assert(reports == 1);
        mode = 3;
        native_layer_present_frame(view, 1, (IMP)draw);
        assert(reports == 3 && submitted_view == view);
        assert(submitted_navigations[1] == 22 && submitted_navigations[2] == 11);
        assert(submitted_tokens[0] != submitted_tokens[1]);
        assert(submitted_tokens[1] != submitted_tokens[2]);
        assert(!native_document_submission_current);
        // A claim cannot be stolen by a different graphics context.
        NativeDocumentSubmissionFrame fake = {.bitmap = (CGContextRef)1, .token = 99};
        native_document_submission_current = &fake;
        assert(!vox_browser_stage_document_submission(submitted, (__bridge void *)view, 1, 9));
        native_document_submission_current = NULL;
        puts("native document submission: 7 cases passed");
    }
    return 0;
}
