#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include "native_layer_presentation_darwin.h"
#include "native_bitmap_snapshot_darwin.h"
typedef struct { uint8_t r,g,b,a; } gg__Color;
typedef struct { int unused; } gg__Image;
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
static CGFloat test_scale=2;
static CGFloat native_svg_mask_backing_scale(void) { return test_scale; }
#define VOX_TEST_COMPACT_CSS_FILTER_INPUT
#include "native_document_canvas_entry_points.inc"

static CGImageRef selected;
static int clipped, operation_kind, sparse;
static CGFloat canvas_width=257,canvas_height=256;
static double filter_seconds;
static CGImageRef source(int bgra,int wide) {
    const size_t width=257,height=256,pitch=width*4+32;
    NSMutableData *data=[NSMutableData dataWithLength:pitch*height];
    for(size_t y=0;y<height;++y)for(size_t x=0;x<width;++x){
        uint8_t *p=(uint8_t*)data.mutableBytes+y*pitch+x*4;
        p[bgra?2:0]=(x*71+y*3)%(y+1);p[1]=(x*37+19)%(y+1);
        p[bgra?0:2]=(x*11+y*5)%(y+1);p[3]=y;
        if(sparse==2 || (sparse==1 && (x<64 || x>121 || y<71 || y>103))) memset(p,0,4);
    }
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef color=CGColorSpaceCreateWithName(wide?kCGColorSpaceDisplayP3:kCGColorSpaceSRGB);
    CGImageRef image=CGImageCreate(width,height,8,32,pitch,color,bgra?
        kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little:
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big,provider,NULL,false,kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);CGColorSpaceRelease(color);assert(image);return image;
}
static void paint(id view,SEL selector,NSRect rect) {
    CGContextRef frame=NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(frame,.15,.3,.6,1);CGContextFillRect(frame,rect);
    if(clipped)CGContextClipToRect(frame,CGRectMake(15.25,29.5,203.5,112.25));
    native_begin_css_filter_layer(canvas_width,canvas_height);
    CGContextDrawImage(NSGraphicsContext.currentContext.CGContext,CGRectMake(0,0,257,256),selected);
    if(operation_kind==0){
        native_add_css_filter_operation(2,.65,2,0,(gg__Color){0});
        native_add_css_filter_operation(2,.25,3,0,(gg__Color){0});
    }else if(operation_kind==1)native_add_css_filter_operation(3,33,0,0,(gg__Color){0});
    else if(operation_kind==2)native_add_css_filter_operation(0,2,0,0,(gg__Color){0});
    else native_add_css_filter_operation(2,operation_kind==4?.4:1.4,
        operation_kind==3?1:operation_kind==4?4:operation_kind==5?5:operation_kind==6?6:0,0,(gg__Color){0});
    double start=CACurrentMediaTime();native_end_css_filter_layer();
    filter_seconds=CACurrentMediaTime()-start;
}
static NSData *packed(CGImageRef image) {
    CFDataRef data=CGDataProviderCopyData(CGImageGetDataProvider(image));assert(data);
    size_t width=CGImageGetWidth(image),height=CGImageGetHeight(image),pitch=CGImageGetBytesPerRow(image);
    NSMutableData *result=[NSMutableData dataWithLength:width*height*4];
    for(size_t y=0;y<height;++y)memcpy((uint8_t*)result.mutableBytes+y*width*4,
        CFDataGetBytePtr(data)+y*pitch,width*4);
    CFRelease(data);return result;
}
int main(int argc,char **argv){@autoreleasepool{
    setenv("VOX_COMPACT_CSS_FILTER_INPUT","1",1);
    NativeCSSFilterOperation operation={.kind=2,.first=.5,.second=2};
    for(int bgra=0;bgra<2;++bgra)for(int wide=0;wide<2;++wide){
        selected=source(bgra,wide);
        CGContextRef input=CGBitmapContextCreate(NULL,257,256,8,257*4+32,
            CGImageGetColorSpace(selected),CGImageGetBitmapInfo(selected));assert(input);
        CGContextDrawImage(input,CGRectMake(0,0,257,256),selected);
        NSData *before=[NSData dataWithBytes:CGBitmapContextGetData(input) length:(257*4+32)*256];
        CGContextClipToRect(input,CGRectMake(15.25,29.5,203.5,112.25));
        NativeCSSFilterLayer layer={.destination=input,.canvas_width=257,.canvas_height=256,
            .scale=1,.operations=&operation,.operation_count=1};
        CGRect rect=CGRectNull;
        CGImageRef copy=native_compact_css_filter_input(&layer,input,&rect);assert(copy);
        assert(CGImageGetBytesPerRow(copy)==CGImageGetWidth(copy)*4);
        assert(CFEqual(CGImageGetColorSpace(copy),CGImageGetColorSpace(selected)));
        assert(!memcmp(before.bytes,CGBitmapContextGetData(input),before.length));
        CFDataRef pixels=CGDataProviderCopyData(CGImageGetDataProvider(copy));assert(pixels);
        size_t pitch=CGImageGetBytesPerRow(copy),height=CGImageGetHeight(copy);
        assert(CFDataGetLength(pixels)==pitch*height);
        size_t left=rect.origin.x,top=256-CGRectGetMaxY(rect);
        CGContextRelease(input);CGImageRelease(selected); // The compact provider owns its rows.
        for(size_t y=0;y<height;++y)assert(!memcmp(CFDataGetBytePtr(pixels)+y*pitch,
            (uint8_t*)before.bytes+(top+y)*(257*4+32)+left*4,pitch));
        CFRelease(pixels);CGImageRelease(copy);
    }
    if(argc>1){
        canvas_width=1708;canvas_height=953;clipped=1;operation_kind=0;selected=source(0,0);
        NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,canvas_width,canvas_height)];
        for(int round=0;round<6;++round)for(int compact=0;compact<2;++compact){
            if(compact)unsetenv("VOX_DISABLE_COMPACT_CSS_FILTER_INPUT");else setenv("VOX_DISABLE_COMPACT_CSS_FILTER_INPUT","1",1);
            CGImageRef frame=native_layer_raster_frame(view,2,(IMP)paint);assert(frame);CGImageRelease(frame);
            printf("filter diagnostic round=%d compact=%d end_filter_us=%.3f\n",round,compact,filter_seconds*1e6);
        }
        CGImageRelease(selected);return 0;
    }
    NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,257,256)];unsigned cases=0;
    for(int tight=0;tight<2;++tight)for(sparse=0;sparse<3;++sparse)
    for(int bgra=0;bgra<2;++bgra)for(int wide=0;wide<2;++wide)for(clipped=0;clipped<2;++clipped)
        for(int scale=1;scale<=2;++scale)for(operation_kind=0;operation_kind<8;++operation_kind){
            if(tight)setenv("VOX_TIGHT_CSS_FILTER_INPUT","1",1);else unsetenv("VOX_TIGHT_CSS_FILTER_INPUT");
            test_scale=scale;
            selected=source(bgra,wide);setenv("VOX_DISABLE_COMPACT_CSS_FILTER_INPUT","1",1);
            CGImageRef reference=native_layer_raster_frame(view,scale,(IMP)paint);assert(reference);
            unsigned before=native_test_compact_css_filter_inputs;unsetenv("VOX_DISABLE_COMPACT_CSS_FILTER_INPUT");
            CGImageRef candidate=native_layer_raster_frame(view,scale,(IMP)paint);assert(candidate);
            assert([packed(candidate)isEqualToData:packed(reference)]);
            if (!tight) assert((native_test_compact_css_filter_inputs>before)==(clipped&&operation_kind!=2));
            else if(operation_kind==2) assert(native_test_compact_css_filter_inputs==before);
            else if(sparse) assert(native_test_compact_css_filter_inputs>before);
            ++cases;CGImageRelease(reference);CGImageRelease(candidate);CGImageRelease(selected);
            // Bound the many distinct Core Image target sizes in this corpus;
            // the tested arithmetic and the production cache policy are unchanged.
            if(cases%8==0)[native_css_filter_ci_context clearCaches];
        }
    printf("Compact CSS inputs: %u exact real frames; owned tight rows, RGBA/BGRA, alpha, padding, profiles, fractional clips, 1x/2x and non-pointwise fallback passed\n",cases);
}}
