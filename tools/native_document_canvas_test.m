#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include "native_layer_presentation_darwin.h"
#include "native_bitmap_snapshot_darwin.h"
typedef struct { uint8_t r,g,b,a; } gg__Color;
typedef struct { int unused; } gg__Image;
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
static CGFloat test_scale;
static CGFloat native_svg_mask_backing_scale(void) { return test_scale; }
#define VOX_TEST_CROPPED_CSS_FILTERS
#include "native_document_canvas_entry_points.inc"

static void pattern(CGContextRef c,int width,int height) {
 CGContextSetRGBFillColor(c,0.12,0.71,0.34,0.53);
 CGContextFillEllipseInRect(c,CGRectMake(2.3,4.1,width-7.8,height-9.4));
 CGContextSaveGState(c);
 CGContextClipToRect(c,CGRectMake(3.25,1.7,width-9.1,height-5.8));
 CGContextSetRGBFillColor(c,0.81,0.23,0.57,0.31);
 CGContextFillRect(c,CGRectMake(0,0,width,height));
 CGContextSetRGBStrokeColor(c,0.2,0.3,0.9,0.67);
 CGContextSetLineWidth(c,1.7);
 CGContextStrokeEllipseInRect(c,CGRectMake(0.8,0.4,width-3,height-4));
 CGContextRestoreGState(c);
}
// Compare actual entry points with the ordinary isolated canvas and Quartz
// publication. The real frame allocator is exercised on both paths.
static int reference, scenario, logical_width, logical_height, comparisons;
static BOOL expect_borrow;
static void paint_frame(id view, SEL selector, NSRect rect) {
 (void)view; (void)selector; (void)rect;
 CGContextRef frame = NSGraphicsContext.currentContext.CGContext;
 assert(CGBitmapContextGetBitmapInfo(frame) ==
  (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big));
 NSGraphicsContext *saved = NSGraphicsContext.currentContext;
 if (reference) {
  assert(native_layer_claim_document_bitmap(frame));
  native_begin_css_filter_layer(logical_width, logical_height);
  native_font_compositing_context = NSGraphicsContext.currentContext.CGContext;
  native_font_compositing_transparency_depth = 0;
 } else native_begin_font_compositing_layer(logical_width, logical_height);
 assert(native_css_filter_stack_depth == 1);
 CGContextRef root = NSGraphicsContext.currentContext.CGContext;
 assert((root == frame) == (!reference && expect_borrow));
 assert(!native_layer_claim_document_bitmap(frame));
 int width = logical_width, height = logical_height;
 pattern(root, width, height);
 if (scenario == 1) {
  native_begin_css_filter_layer(width, height);
  assert(NSGraphicsContext.currentContext.CGContext != root);
  pattern(NSGraphicsContext.currentContext.CGContext, width-4, height-3);
  native_add_css_filter_operation(3, 0.5, 0, 0, (gg__Color){0});
  native_end_css_filter_layer();
  assert(NSGraphicsContext.currentContext.CGContext == root);
 }
 if (scenario == 2) native_add_css_filter_operation(0, 1.25, 0, 0, (gg__Color){0});
 if (scenario == 3 || scenario == 4) {
  native_begin_backdrop_filter_layer(width, height, 4, 3, width-12, height-9,
   2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 1, 0, 0, 0, 0, 0, scenario == 4);
  native_add_css_filter_operation(0, 1.5, 0, 0, (gg__Color){0});
  native_end_backdrop_filter_layer(0.61);
  assert(NSGraphicsContext.currentContext.CGContext == root);
 }
 if (scenario == 5) {
  for (int depth=1; depth<=NATIVE_CSS_FILTER_MAX_DEPTH+1; depth++)
   native_begin_css_filter_layer(0, 0);
  for (int depth=1; depth<=NATIVE_CSS_FILTER_MAX_DEPTH+1; depth++)
   native_end_css_filter_layer();
  assert(native_css_filter_stack_depth == 1 && native_css_filter_overflow_depth == 0);
 }
 if (scenario == 6) {
  native_begin_svg_filter_graph(0, 1, 0, 0, width, height, 1, 0, 0, 1, 0, 0, 0, 0);
  native_add_svg_filter_node(0, 4, 1.25, 0.75, 0, 0, 0, 0, (gg__Color){0}, 0, 0, 0);
 }
 if (scenario == 7) {
  // A strip repaint filters only the rows its clip shows; the reference
  // filters and composites the complete layer.
  if (reference) setenv("VOX_DISABLE_CROPPED_CSS_FILTERS", "1", 1);
  int before = native_test_cropped_css_filters;
  CGContextSaveGState(root);
  CGContextClipToRect(root, CGRectMake(0, 13.5, width, 9.25));
  native_begin_css_filter_layer(width, height);
  pattern(NSGraphicsContext.currentContext.CGContext, width-2, height-5);
  native_add_css_filter_operation(2, 0.8, 2, 0, (gg__Color){0});
  native_add_css_filter_operation(3, 40, 0, 0, (gg__Color){0});
  native_end_css_filter_layer();
  CGContextRestoreGState(root);
  unsetenv("VOX_DISABLE_CROPPED_CSS_FILTERS");
  assert(native_test_cropped_css_filters
   == before + (!reference && test_scale == floor(test_scale)));
 }
 CGContextTranslateCTM(root, 3, 4);
 CGContextClipToRect(root, CGRectMake(1, 1, 2, 2));
 CGContextSetAlpha(root, 0.2);
 CGContextSetBlendMode(root, kCGBlendModeMultiply);
 native_end_font_compositing_layer();
 assert(native_css_filter_stack_depth == 0 && native_font_compositing_context == NULL);
 assert(NSGraphicsContext.currentContext == saved);
 assert(CGAffineTransformEqualToTransform(CGContextGetCTM(frame),
  CGAffineTransformMakeScale(test_scale, test_scale)));
 // State must be restored before browser chrome paints.
 CGContextSetRGBFillColor(frame, 0.7, 0.2, 0.5, 1);
 CGContextFillRect(frame, CGRectMake(0, 0, 2, 2));
}
static void compare_frame(NSView *view) {
 reference = 1;
 CGImageRef expected = native_layer_raster_frame(view, test_scale, (IMP)paint_frame);
 assert(expected);
 CFDataRef before = CGDataProviderCopyData(CGImageGetDataProvider(expected));
 reference = 0;
 CGImageRef actual = native_layer_raster_frame(view, test_scale, (IMP)paint_frame);
 assert(actual);
 CFDataRef after = CGDataProviderCopyData(CGImageGetDataProvider(actual));
 assert(before && after && CFEqual(before, after));
 // A later frame must not mutate the previous immutable published image.
 CFDataRef retained = CGDataProviderCopyData(CGImageGetDataProvider(expected));
 assert(retained && CFEqual(before, retained));
 CFRelease(retained); CFRelease(before); CFRelease(after);
 CGImageRelease(expected); CGImageRelease(actual);
 assert(!native_layer_document_bitmap && !native_layer_document_bitmap_claimed);
 comparisons++;
}
static int check_rejections(void) {
  int cases=0;
  for(int scale=1;scale<=2;scale++) for(int kind=0;kind<12;kind++) {
   CGColorSpaceRef color=CGColorSpaceCreateWithName(kind==9?kCGColorSpaceDisplayP3:kCGColorSpaceSRGB);
   CGBitmapInfo info=kind==8 ? kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little:kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big;
   CGContextRef c=CGBitmapContextCreate(NULL,64*scale,48*scale,8,64*scale*4,color,info);CGColorSpaceRelease(color);assert(c);
   CGContextScaleCTM(c,scale,scale);
   native_layer_document_bitmap=kind==0?NULL:c;native_layer_document_bitmap_claimed=kind!=1;
   if(kind==2)CGContextTranslateCTM(c,1,0);
   if(kind==3)CGContextScaleCTM(c,1,0.5);
   if(kind==4)CGContextRotateCTM(c,0.25);
   if(kind==5)CGContextClipToRect(c,CGRectMake(0,0,63,48));
   CGFloat width=kind==6?63.5:64, height=kind==7?47.5:48, s=kind==10?NAN:kind==11?0:scale;
   CGAffineTransform saved=CGContextGetCTM(c);CGRect clip=CGContextGetClipBoundingBox(c);
   assert(!native_layer_begin_document_canvas(c,width,height,s));
   assert(CGAffineTransformEqualToTransform(saved,CGContextGetCTM(c)));
   assert(CGRectEqualToRect(clip,CGContextGetClipBoundingBox(c)));
   CGContextSetRGBFillColor(c,0.2,0.3,0.4,1);CGContextFillRect(c,CGRectMake(0,0,1,1));
   native_layer_document_bitmap=NULL;native_layer_document_bitmap_claimed=NO;CGContextRelease(c);cases++;
  }
  assert(!native_layer_begin_document_canvas(NULL,64,48,1));
 return cases;
}
int main(void) {
 @autoreleasepool {
  const CGFloat scales[] = {1, 1.25, 2};
  for (int scale=0; scale<3; scale++) for (int odd=0; odd<2; odd++) {
   test_scale = scales[scale]; logical_width = 64+odd; logical_height = 48+odd;
   expect_borrow = logical_width*test_scale == ceil(logical_width*test_scale)
    && logical_height*test_scale == ceil(logical_height*test_scale);
   NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, logical_width, logical_height)];
   for (scenario=0; scenario<8; scenario++) compare_frame(view);
  }
  int rejected = check_rejections();
  fprintf(stderr, "PASS %d exact root/nested/CSS/SVG/backdrop/overflow/state/immutable-frame comparisons; %d guarded rejections plus NULL\n", comparisons, rejected);
 }
}
