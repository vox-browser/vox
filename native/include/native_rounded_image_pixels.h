#ifndef VOX_NATIVE_ROUNDED_IMAGE_PIXELS_H
#define VOX_NATIVE_ROUNDED_IMAGE_PIXELS_H
#include <stdint.h>
#include <math.h>
#include <stdlib.h>
extern int32_t vox_document_rounded_image_pixels(uint8_t *, int32_t, int32_t, int32_t,
    uint8_t *, int32_t, int32_t, int32_t, int32_t, float, float, float);
extern int32_t vox_document_image_sample_count(int32_t,int32_t,int32_t,int32_t);

// Use the ordinary document raster boundary for a small, unscaled image.
// V owns color/coverage composition; unsupported sampling and geometry retain
// the platform image path. Only raw, straight RGBA rows are eligible.
static int native_try_v_rounded_image(CGContextRef context, gg__Image *image,
    float x, float y, float width, float height, float sx, float sy, float sw, float sh,
    float cx, float cy, float cw, float ch, float a, float b, float c, float d,
    float e, float f, float page_x, float page_y, float scroll_y,
    float canvas_width, float canvas_height, float opacity,
    const float *radii, int image_flags) {
    if (context != native_font_compositing_context || native_font_compositing_transparency_depth != 0
        || !image || image->path.len || (image->nr_channels != 6 && image->nr_channels != VOX_FLOAT_RGBA_CHANNEL_MARKER) || !radii || image_flags
        || image->width <= 0 || image->height <= 0 || image->width > 32 || image->height > 32
        || image->width * image->height > 256 || opacity != 1 || a != 1 || d != 1 || b || c
        || sx || sy || sw != image->width || sh != image->height
        || width != image->width || height != image->height
        || cx != x || cy != y || cw != width || ch != height
        || !isfinite(radii[0]) || radii[0] <= 0) return 0;
    for (int i=1;i<8;++i) if (radii[i] != radii[0]) return 0;
    // Match the image painter's document-to-canvas translation, including chrome and scroll.
    float left=page_x+x+e, top=page_y-scroll_y+y+f;
    if (!isfinite(left) || !isfinite(top) || left != floorf(left) || top != floorf(top)) return 0;
    int32_t geometry[7]; float scale;
    int prepared=native_text_raster_begin(left,top,left+width,top+height,
        canvas_width,canvas_height,16,geometry,&scale);
    if (prepared == 2) return 1;
    if (prepared != 1 || scale != 1 || !geometry[4]) return 0;
    int samples=vox_document_image_sample_count((int32_t)(left-page_x),
        (int32_t)(top-page_y+scroll_y),image->width,image->height);
    if (!samples) return 0;
    int w=geometry[2], h=geometry[3];
    if (w<=0 || h<=0 || w>64 || h>64) return 0;
    uint8_t *pixels=malloc((size_t)w*h*4);
    if (!pixels) return 0;
    int drawn=native_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale);
    if (drawn) drawn=vox_document_rounded_image_pixels(pixels,w,h,w*4,image->data,
        image->width,image->height,image->nr_channels == VOX_FLOAT_RGBA_CHANNEL_MARKER,samples,left-geometry[0],top-geometry[1],radii[0]);
    if (drawn) drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,
        geometry[5],geometry[6],canvas_height,1);
    free(pixels);
    return drawn;
}

#ifdef VOX_TEST_ROUNDED_IMAGE_PIXELS
static int vox_test_small_rounded_image_pixels(uint8_t *pixels, const void *source, int opaque, int float_source, int page_offset, int background) {
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context=CGBitmapContextCreate(pixels,16,16+page_offset,8,64,space,
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return 0;
    double gray=(double)background/255.0;
    CGContextSetRGBFillColor(context,gray,gray,gray,1);
    CGContextFillRect(context,CGRectMake(0,0,16,16+page_offset));
    CGContextRef previous=native_font_compositing_context;
    int previous_depth=native_font_compositing_transparency_depth;
    native_font_compositing_context=context;
    native_font_compositing_transparency_depth=0;
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO]];
    gg__Image image={0}; image.width=16; image.height=16; image.nr_channels=float_source ? VOX_FLOAT_RGBA_CHANNEL_MARKER : 6; image.data=(void *)source;
    const float radii[8]={8,8,8,8,8,8,8,8};
    int result=native_try_v_rounded_image(context,&image,0,0,16,16,0,0,16,16,
        0,0,16,16,1,0,0,1,0,0,0,page_offset,0,16,16+page_offset,opaque ? 1 : .5f,radii,0);
    [NSGraphicsContext restoreGraphicsState];
    native_font_compositing_context=previous;
    native_font_compositing_transparency_depth=previous_depth;
    CGContextRelease(context);
    return result;
}
#endif

#endif
