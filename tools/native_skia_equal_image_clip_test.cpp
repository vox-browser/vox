// Match the independent full-uBO reference, with the authored overflow clip
// retained even when it equals the destination rectangle.
#include "../native_skia_text_darwin.cpp"
#include <ImageIO/ImageIO.h>
#include <cassert>
#include <cstdio>

int main(int argc, char** argv)
{
    assert(argc == 2);
    auto decoder = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL); assert(decoder);
    using Decode = void* (*)(void const*, uint64_t, int32_t*, int32_t*, int32_t*, int32_t*);
    auto decode = reinterpret_cast<Decode>(dlsym(decoder, "vox_avif_decode_yuv"));
    auto release = reinterpret_cast<void (*)(void*)>(dlsym(decoder, "vox_avif_free"));
    assert(decode && release && graphite_image_draw());
    auto encoded = SkData::MakeFromFileName("Tests/Browser/Brave/resources/avif/slate-hero.jpeg");
    assert(encoded);
    int32_t iw=0, ih=0, bytes=0, subsampling=0;
    auto source = static_cast<uint8_t*>(decode(encoded->data(), encoded->size(), &iw, &ih, &bytes, &subsampling));
    assert(source && iw == 585 && ih == 390 && subsampling == 1);
    auto url = CFURLCreateWithFileSystemPath(nullptr,
        CFSTR("Tests/Browser/Brave/expected/equal-image-overflow-clip.png"), kCFURLPOSIXPathStyle, false);
    auto loader = CGImageSourceCreateWithURL(url, nullptr); CFRelease(url); assert(loader);
    auto image = CGImageSourceCreateImageAtIndex(loader, 0, nullptr); CFRelease(loader); assert(image);
    constexpr int width=1024, height=768;
    assert(CGImageGetWidth(image)==width && CGImageGetHeight(image)==height);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    std::vector<uint8_t> expected(width*height*4, 255);
    auto reference = CGBitmapContextCreate(expected.data(), width, height, 8, width*4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    assert(reference); CGContextDrawImage(reference, CGRectMake(0,0,width,height), image);
    CGContextFlush(reference); CGContextRelease(reference); CGImageRelease(image);
    int exact=0;
    for (int toolbar : {0,84}) for (bool grid : {false,true}) for (bool clip : {false,true}) {
        int canvas_height=height+toolbar;
        std::vector<uint8_t> pixels(size_t(width)*canvas_height*4,255);
        auto context=CGBitmapContextCreate(pixels.data(),width,canvas_height,8,width*4,space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(context);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0,width,height);
        ladybird_v_skia_set_raster_layer(232,263,0);
        ladybird_v_skia_set_raster_layer_size(559,373);
        ladybird_v_skia_set_msaa_grid(nullptr,0,576,256,grid?1:0);
        assert(ladybird_v_skia_draw_rgba_image(context,source,iw,ih,iw*4,
            232,263,559,373,0,0,iw,ih,232,263,559,373,1,0,0,1,0,0,0,toolbar,0,
            width,canvas_height,1,0,14|VOX_GRAPHITE_IMAGE_YUV422
                |(clip?VOX_GRAPHITE_IMAGE_EXPLICIT_RECT_CLIP:0),nullptr));
        CGContextFlush(context);
        size_t different=0;
        for(int y=0;y<height;++y) for(int x=0;x<width;++x) {
            auto* a=pixels.data()+((toolbar+height-y-1)*width+x)*4;
            auto* b=expected.data()+((height-y-1)*width+x)*4;
            different+=!std::equal(a,a+4,b);
        }
        std::printf("toolbar=%d grid=%d clip=%d: %zu differing pixels\n",toolbar,grid,clip,different);
        assert((different==0)==(!grid||clip));
        exact+=different==0;
        CGContextRelease(context);
    }
    CFRelease(space); release(source); dlclose(decoder);
    std::printf("Equal image clip: %d exact cases; two unchanged controls differ\n",exact);
    return 0;
}
