// A video frame leaf samples the uploaded frame like Chromium's compositor:
// complete resolution, linear filtering, no decode-cache resize or mips.
#include "../native_graphite_bridge.h"
#include "../native_picture_image_transport.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkPicture.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSerialProcs.h"
#include <cassert>
#include <cstdio>
#include <dlfcn.h>
#include <vector>

static decltype(&vox_graphite_draw_image_pixels) image_draw;
static decltype(&vox_graphite_draw_picture_pixels) picture_draw;
static decltype(&vox_graphite_release_unused_graphics_memory) clear_images;

static void compare_frame(int scale, bool rounded, int frame)
{
    constexpr int width=512,height=384,fw=1426,fh=1080;
    std::vector<uint8_t> source(size_t(fw)*fh*4);
    for(int y=0;y<fh;++y) for(int x=0;x<fw;++x) {
        auto* p=source.data()+(size_t(y)*fw+x)*4;
        p[0]=(x*7+frame*13)%256;p[1]=(y*11+frame)%256;p[2]=(x*23+y*19)%256;p[3]=255;
    }
    VoxGraphiteImage image{};
    image.width=fw;image.height=fh;image.pitch=fw*4;image.pixels=source.data();
    image.flags=1|VOX_GRAPHITE_IMAGE_VIDEO_FRAME;image.opacity=1;
    image.matrix[0]=image.matrix[4]=scale;image.matrix[8]=1;
    image.source[2]=fw;image.source[3]=fh;
    image.destination[0]=image.clip[0]=64;image.destination[1]=image.clip[1]=43;
    image.destination[2]=image.clip[2]=326;image.destination[3]=image.clip[3]=247;
    if(rounded)std::fill(image.clip+4,image.clip+12,6);
    clear_images();
    std::vector<uint32_t> actual(size_t(width)*height*scale*scale,0xff090b0f);
    assert(image_draw(reinterpret_cast<uint8_t*>(actual.data()),width*scale,height*scale,
        width*scale*4,1,&image));

    auto info=SkImageInfo::Make(fw,fh,kRGBA_8888_SkColorType,kPremul_SkAlphaType,
        SkColorSpace::MakeSRGB());
    auto raster=SkImages::RasterFromPixmapCopy(SkPixmap(info,source.data(),fw*4));assert(raster);
    SkPictureRecorder recorder;
    auto* canvas=recorder.beginRecording(SkRect::MakeWH(width,height));
    canvas->clear(SkColorSetRGB(9,11,15));
    auto destination=SkRect::MakeXYWH(64,43,326,247);
    if(rounded)canvas->clipRRect(SkRRect::MakeRectXY(destination,6,6),true);
    SkPaint paint;paint.setAntiAlias(true);
    auto natural=SkRect::MakeWH(fw,fh);
    canvas->concat(SkMatrix::RectToRect(natural,destination));
    canvas->drawImage(raster,0,0,SkSamplingOptions(SkFilterMode::kLinear,SkMipmapMode::kNone),&paint);
    SkSerialProcs procs;
    procs.fImageProc=[](SkImage* value,void*) -> sk_sp<SkData const> {return vox_encode_picture_image(value);};
    auto bytes=recorder.finishRecordingAsPicture()->serialize(&procs);assert(bytes);
    float matrix[]={float(scale),0,0,0,float(scale),0,0,0,1};
    std::vector<uint32_t> expected(actual.size());
    assert(picture_draw(reinterpret_cast<uint8_t*>(expected.data()),width*scale,height*scale,
        width*scale*4,bytes->data(),bytes->size(),matrix));
    if(actual!=expected) {
        size_t different=0;for(size_t i=0;i<actual.size();++i)different+=actual[i]!=expected[i];
        std::fprintf(stderr,"Video frame leaf mismatch scale=%d rounded=%d frame=%d pixels=%zu\n",
            scale,rounded,frame,different);
    }
    assert(actual==expected);
}

int main(int argc,char**argv)
{
    assert(argc==3);
    auto metal=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL),dawn=dlopen(argv[2],RTLD_NOW|RTLD_LOCAL);
    assert(metal&&dawn);
    image_draw=reinterpret_cast<decltype(image_draw)>(dlsym(metal,"vox_graphite_draw_image_pixels"));
    picture_draw=reinterpret_cast<decltype(picture_draw)>(dlsym(dawn,"vox_graphite_draw_picture_pixels"));
    clear_images=reinterpret_cast<decltype(clear_images)>(dlsym(metal,"vox_graphite_release_unused_graphics_memory"));
    assert(image_draw&&picture_draw&&clear_images);
    unsigned cases=0;
    for(int scale:{1,2}) for(bool rounded:{false,true}) for(int frame:{0,1}) {
        compare_frame(scale,rounded,frame);
        ++cases;
    }
    std::printf("%u video frame leaves match complete-resolution linear GPU pictures\n",cases);
}
