#ifndef VOX_NATIVE_ROUNDED_IMAGE_CLIP_H
#define VOX_NATIVE_ROUNDED_IMAGE_CLIP_H
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
extern int32_t vox_document_rounded_image_clip_mask(uint8_t *, int32_t, int32_t, float);

// A device-aligned uniform rounded clip. V supplies its alpha coverage; this
// boundary installs that coverage into the platform image drawing context.
static int vox_apply_rounded_image_clip(CGContextRef context, CGRect rect, const float *radii) {
    if (!context || !radii || !isfinite(radii[0]) || radii[0] <= 0) return 0;
    for (int i=1; i<8; ++i) if (radii[i] != radii[0]) return 0;
    CGAffineTransform matrix=CGContextGetCTM(context);
    if (matrix.b != 0 || matrix.c != 0 || matrix.a <= 0 || matrix.d >= 0
        || fabs(matrix.a + matrix.d)>1e-6) return 0;
    CGRect device=CGRectStandardize(CGContextConvertRectToDeviceSpace(context,rect));
    if (!isfinite(device.origin.x) || !isfinite(device.origin.y)
        || !isfinite(device.size.width) || !isfinite(device.size.height)
        || device.size.width<=0 || device.size.height<=0
        || device.size.width>1024 || device.size.height>1024) return 0;
    double values[]={device.origin.x,device.origin.y,device.size.width,device.size.height};
    for (int i=0;i<4;++i) if (fabs(values[i]-round(values[i]))>1e-6) return 0;
    int width=(int)device.size.width, height=(int)device.size.height;
    uint8_t *mask=malloc((size_t)width*height);
    if (!mask) return 0;
    int drawn=vox_document_rounded_image_clip_mask(mask,width,height,(float)(radii[0]*matrix.a));
    if (!drawn) { free(mask); return 0; }
    CFDataRef data=CFDataCreate(NULL,mask,(CFIndex)width*height);
    free(mask);
    if (!data) return 0;
    CGDataProviderRef provider=CGDataProviderCreateWithCFData(data);
    CFRelease(data);
    if (!provider) return 0;
    const CGFloat decode[2]={1,0};
    CGImageRef image=CGImageMaskCreate(width,height,8,8,width,provider,decode,false);
    CGDataProviderRelease(provider);
    if (!image) return 0;
    CGContextClipToMask(context,rect,image);
    CGImageRelease(image);
    return 1;
}
#endif
