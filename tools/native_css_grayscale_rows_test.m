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
#include "native_document_canvas_entry_points.inc"

static CGImageRef selected;
static double amount;
static int clipped, chained, sparse;
static unsigned submissions;
static IMP original_create_image;
static CGImageRef count_create_image(id self, SEL selector, CIImage *image, CGRect rect,
    CIFormat format, CGColorSpaceRef color) {
    ++submissions;
    return ((CGImageRef (*)(id,SEL,CIImage *,CGRect,CIFormat,CGColorSpaceRef))original_create_image)(
        self,selector,image,rect,format,color);
}

static CGImageRef source(int bgra, int wide) {
    const size_t width=269,height=257,pitch=width*4+28;
    NSMutableData *data=[NSMutableData dataWithLength:pitch*height];
    for(size_t y=0;y<height;++y)for(size_t x=0;x<width;++x){
        uint8_t *p=(uint8_t*)data.mutableBytes+y*pitch+x*4;
        unsigned alpha=y%256;
        p[bgra?2:0]=(x*101+79)%(alpha+1);
        p[1]=(x*73+19)%(alpha+1);
        p[bgra?0:2]=(x*37+31)%(alpha+1);p[3]=alpha;
        if(sparse && (x<64 || x>121 || y<71 || y>103)) memset(p,0,4);
    }
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef color=CGColorSpaceCreateWithName(wide?kCGColorSpaceDisplayP3:kCGColorSpaceSRGB);
    CGImageRef image=CGImageCreate(width,height,8,32,pitch,color,bgra?
        kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little:
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big,provider,NULL,false,kCGRenderingIntentDefault);
    CGColorSpaceRelease(color);CGDataProviderRelease(provider);assert(image);return image;
}

static void paint(id view, SEL command, NSRect rect) {
    CGContextRef frame=NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(frame,.15,.3,.6,1);CGContextFillRect(frame,rect);
    if(clipped)CGContextClipToRect(frame,CGRectMake(15.25,29.5,203.5,112.25));
    native_begin_css_filter_layer(269,257);
    CGContextDrawImage(NSGraphicsContext.currentContext.CGContext,CGRectMake(0,0,269,257),selected);
    native_add_css_filter_operation(2,amount,2,0,(gg__Color){0});
    if(chained)native_add_css_filter_operation(2,.35,2,0,(gg__Color){0});
    native_end_css_filter_layer();
}

static void compare(CGImageRef a, CGImageRef b, int bound) {
    assert(CGImageGetWidth(a)==CGImageGetWidth(b)&&CGImageGetHeight(a)==CGImageGetHeight(b));
    CFDataRef aa=CGDataProviderCopyData(CGImageGetDataProvider(a));
    CFDataRef bb=CGDataProviderCopyData(CGImageGetDataProvider(b));assert(aa&&bb);
    for(size_t y=0;y<CGImageGetHeight(a);++y)for(size_t x=0;x<CGImageGetWidth(a)*4;++x){
        int delta=abs(CFDataGetBytePtr(aa)[y*CGImageGetBytesPerRow(a)+x]
            -CFDataGetBytePtr(bb)[y*CGImageGetBytesPerRow(b)+x]);
        if(delta>bound)fprintf(stderr,"grayscale mismatch x=%zu y=%zu delta=%d amount=%g clip=%d chain=%d\n",x,y,delta,amount,clipped,chained);
        assert(delta<=bound);
    }
    CFRelease(aa);CFRelease(bb);
}

int main(void){@autoreleasepool{
    setenv("VOX_ENABLE_CPU_GRAYSCALE_FILTERS","1",1);
    unsetenv("VOX_ENABLE_GRAYSCALE_IDENTITY");
    // Direct row checks exercise the native BGRA input, padding, ownership and
    // profile/operation rejection before real publication normalizes its input.
    NativeCSSFilterOperation operation={.kind=2,.first=.8,.second=2};
    NativeCSSFilterLayer layer={.operations=&operation,.operation_count=1};
    for(int bgra=0;bgra<2;++bgra)for(int wide=0;wide<2;++wide){
        selected=source(bgra,wide);
        size_t pitch=269*4+28;
        CGContextRef input=CGBitmapContextCreate(NULL,269,257,8,pitch,
            CGImageGetColorSpace(selected),CGImageGetBitmapInfo(selected));assert(input);
        CGContextDrawImage(input,CGRectMake(0,0,269,257),selected);
        NSData *before=[NSData dataWithBytes:CGBitmapContextGetData(input) length:pitch*257];
        CGRect rect=CGRectNull;
        CGImageRef result=native_css_filter_grayscale_rows(&layer,input,&rect);
        assert((result!=NULL)==!wide);
        assert(!memcmp(before.bytes,CGBitmapContextGetData(input),before.length));
        if(result){
            native_initialize_css_filter_renderer();
            CGImageRef original=CGBitmapContextCreateImage(input);
            CIImage *output=native_apply_css_filter_layer(&layer,original);
            CGImageRef reference=[native_css_filter_ci_context createCGImage:output
                fromRect:CGRectMake(0,0,269,257) format:kCIFormatRGBA8 colorSpace:native_css_filter_color_space];
            // Normalize BGRA to compare against Core Image's RGBA output.
            CGColorSpaceRef color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef normalized=CGBitmapContextCreate(NULL,269,257,8,269*4,color,
                kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
            CGContextDrawImage(normalized,CGRectMake(0,0,269,257),result);
            CGImageRef rgba=CGBitmapContextCreateImage(normalized);compare(rgba,reference,1);
            CGImageRelease(rgba);CGContextRelease(normalized);CGColorSpaceRelease(color);
            CGImageRelease(reference);CGImageRelease(original);CGImageRelease(result);
            operation.kind=0;assert(!native_css_filter_grayscale_rows(&layer,input,&rect));operation.kind=2;
            operation.first=NAN;assert(!native_css_filter_grayscale_rows(&layer,input,&rect));operation.first=.8;
            layer.graph_node_count=1;assert(!native_css_filter_grayscale_rows(&layer,input,&rect));layer.graph_node_count=0;
        }
        CGContextRelease(input);CGImageRelease(selected);
    }
    NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,269,257)];
    Method method=class_getInstanceMethod(native_css_filter_ci_context.class,
        @selector(createCGImage:fromRect:format:colorSpace:));assert(method);
    original_create_image=method_setImplementation(method,(IMP)count_create_image);
    unsigned cases=0;
    for(int bgra=0;bgra<2;++bgra)for(sparse=0;sparse<2;++sparse)for(clipped=0;clipped<2;++clipped)
        for(int scale=1;scale<=2;++scale)for(chained=0;chained<2;++chained)
        for(NSNumber *value in @[@0,@.2,@.5,@.8,@1]){
            amount=value.doubleValue;selected=source(bgra,0);
            setenv("VOX_DISABLE_CPU_GRAYSCALE_FILTERS","1",1);
            unsigned before=submissions;
            CGImageRef reference=native_layer_raster_frame(view,scale,(IMP)paint);
            assert(submissions==before+1);
            unsetenv("VOX_DISABLE_CPU_GRAYSCALE_FILTERS");before=submissions;
            CGImageRef candidate=native_layer_raster_frame(view,scale,(IMP)paint);
            assert(submissions==before);compare(candidate,reference,1);++cases;
            CGImageRelease(reference);CGImageRelease(candidate);CGImageRelease(selected);
        }
    method_setImplementation(method,original_create_image);
    printf("Grayscale rows: %u real frames <=1 channel level; zero CI submissions; RGBA/BGRA, alpha, padded/odd rows, clips, scale, chained amounts, rejection and immutable input passed\n",cases);
}}
