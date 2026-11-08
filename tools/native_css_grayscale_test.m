#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include "native/include/native_layer_presentation_darwin.h"
#include "native/include/native_bitmap_snapshot_darwin.h"
typedef struct { uint8_t r,g,b,a; } gg__Color;
typedef struct { int unused; } gg__Image;
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
static CGFloat native_svg_mask_backing_scale(void) { return 2; }
#define VOX_TEST_GRAYSCALE_IDENTITY
#include "native_document_canvas_entry_points.inc"

static CGImageRef source_image(int format, int wide, int colored, int decode) {
    size_t width=257,height=256,pitch=width*4+32;
    NSMutableData *pixels=[NSMutableData dataWithLength:pitch*height];
    for(size_t y=0;y<height;++y)for(size_t x=0;x<width;++x){
        uint8_t *p=(uint8_t*)pixels.mutableBytes+y*pitch+x*4;
        p[0]=p[1]=p[2]=MIN(x%256,y);p[3]=y;
    }
    if(colored)((uint8_t*)pixels.mutableBytes)[128*pitch+64*4+1]++;
    CGColorSpaceRef color=CGColorSpaceCreateWithName(wide?kCGColorSpaceDisplayP3:kCGColorSpaceSRGB);
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    CGBitmapInfo info=format ? (kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little)
        : (kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGFloat table[]={1,0,0,1,0,1};
    CGImageRef image=CGImageCreate(width,height,8,32,pitch,color,info,provider,
        decode?table:NULL,false,kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);CGColorSpaceRelease(color);assert(image);return image;
}
static CGImageRef selected;
static int clipped;
static unsigned filter_submissions;
static IMP original_create_image;
static CGImageRef count_create_image(id self, SEL selector, CIImage *image, CGRect rect,
    CIFormat format, CGColorSpaceRef color) {
    ++filter_submissions;
    return ((CGImageRef (*)(id,SEL,CIImage *,CGRect,CIFormat,CGColorSpaceRef))original_create_image)(
        self,selector,image,rect,format,color);
}
static void paint(id view, SEL command, NSRect rect) {
    CGContextRef frame=NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(frame,.15,.3,.6,1);CGContextFillRect(frame,rect);
    if(clipped)CGContextClipToRect(frame,CGRectMake(15.25,29.5,203.5,112.25));
    native_begin_css_filter_layer(257,256);
    CGContextRef input=NSGraphicsContext.currentContext.CGContext;
    CGContextDrawImage(input,CGRectMake(0,0,257,256),selected);
    native_add_css_filter_operation(2,.2,2,0,(gg__Color){0});
    native_add_css_filter_operation(2,1,2,0,(gg__Color){0});
    native_end_css_filter_layer();
}
static NSData *packed(CGImageRef image) {
    CFDataRef data=CGDataProviderCopyData(CGImageGetDataProvider(image));assert(data);
    size_t width=CGImageGetWidth(image),height=CGImageGetHeight(image),pitch=CGImageGetBytesPerRow(image);
    NSMutableData *result=[NSMutableData dataWithLength:width*height*4];
    for(size_t y=0;y<height;++y)memcpy((uint8_t*)result.mutableBytes+y*width*4,CFDataGetBytePtr(data)+y*pitch,width*4);
    CFRelease(data);return result;
}
int main(void){@autoreleasepool{
    setenv("VOX_ENABLE_GRAYSCALE_IDENTITY","1",1);
    NativeCSSFilterOperation operation={.kind=2,.first=1,.second=2};
    NativeCSSFilterLayer layer={.operations=&operation,.operation_count=1};
    for(int format=0;format<2;++format)for(int wide=0;wide<2;++wide)
        for(int colored=0;colored<2;++colored){
            CGImageRef image=source_image(format,wide,colored,0);
            CGContextRef context=CGBitmapContextCreate(NULL,257,256,8,257*4+32,
                CGImageGetColorSpace(image),CGImageGetBitmapInfo(image));
            CGContextDrawImage(context,CGRectMake(0,0,257,256),image);
            CGRect output=CGRectNull;
            assert(native_css_grayscale_is_identity(&layer,context,&output)==(!wide&&!colored));
            if(!wide&&!colored){
                operation.kind=0;assert(!native_css_grayscale_is_identity(&layer,context,&output));operation.kind=2;
                layer.graph_node_count=1;assert(!native_css_grayscale_is_identity(&layer,context,&output));layer.graph_node_count=0;
            }
            CGContextRelease(context);CGImageRelease(image);
        }
    NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,257,256)];
    native_initialize_css_filter_renderer();
    Method method=class_getInstanceMethod(native_css_filter_ci_context.class,
        @selector(createCGImage:fromRect:format:colorSpace:));
    assert(method);
    original_create_image=method_setImplementation(method,(IMP)count_create_image);
    for(int format=0;format<2;++format)for(int colored=0;colored<2;++colored)
        for(clipped=0;clipped<2;++clipped)for(int scale=1;scale<=2;++scale){
            selected=source_image(format,0,colored,0);
            setenv("VOX_DISABLE_GRAYSCALE_IDENTITY","1",1);
            unsigned calls=filter_submissions;
            CGImageRef reference=native_layer_raster_frame(view,scale,(IMP)paint);
            assert(filter_submissions==calls+1);
            unsigned before=native_test_grayscale_identities;
            unsetenv("VOX_DISABLE_GRAYSCALE_IDENTITY");
            calls=filter_submissions;
            CGImageRef candidate=native_layer_raster_frame(view,scale,(IMP)paint);
            assert(filter_submissions==calls+colored);
            assert([packed(candidate)isEqualToData:packed(reference)]);
            if ((native_test_grayscale_identities>before)!=!colored)
                fprintf(stderr,"admission format=%d colored=%d clip=%d scale=%d accepted=%u\n",format,colored,clipped,scale,native_test_grayscale_identities-before);
            assert((native_test_grayscale_identities>before)==!colored);
            CGImageRelease(candidate);CGImageRelease(reference);CGImageRelease(selected);
        }
    method_setImplementation(method,original_create_image);
    puts("Exact grayscale identity: every valid gray/alpha byte, RGBA/BGRA, padded rows, fractional clips, 1x/2x and colored/filter/profile fallbacks passed");
}}
