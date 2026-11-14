#include "../native/include/native_rounded_image_clip.h"
static int vox_test_rounded_image_clip(uint8_t *pixels, int size, int scale) {
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context=CGBitmapContextCreate(pixels,size,size,8,size*4,space,
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return 0;
    CGContextSetRGBFillColor(context,1,1,1,1);
    CGContextFillRect(context,CGRectMake(0,0,size,size));
    CGContextTranslateCTM(context,0,size);
    CGContextScaleCTM(context,scale,-scale);
    float radii[8]={8,8,8,8,8,8,8,8};
    int applied=vox_apply_rounded_image_clip(context,CGRectMake(0,0,16,16),radii);
    CGContextSetRGBFillColor(context,0,0,0,1);
    CGContextFillRect(context,CGRectMake(0,0,16,16));
    CGContextRelease(context);
    return applied;
}
