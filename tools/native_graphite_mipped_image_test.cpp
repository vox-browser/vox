// Compare the image leaf with Chromium's complete-source mipmapped replay.
#include "../native/include/native_graphite_bridge.h"
#include "../native/include/native_picture_image_transport.h"
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

static void compare_image(int scale, bool alternate_height, bool rounded, bool alpha, bool cropped=false)
{
    constexpr int width=1280,height=800,sw=2606;
    int sh=alternate_height?2483:2482;
    int uw=cropped?(scale==1?652:1303):326*scale;
    int uh=cropped?(scale==1?621:(alternate_height?1242:1241)):(scale==1?311:621);
    std::vector<uint8_t> source(size_t(sw)*sh*4);
    for(int y=0;y<sh;++y) for(int x=0;x<sw;++x) {
        auto* p=source.data()+(size_t(y)*sw+x)*4;
        int a=alpha?64+(x*11+y*17)%192:255;
        p[0]=(x*7%256)*a/255;p[1]=(y*11%256)*a/255;
        p[2]=((x*23+y*19)%256)*a/255;p[3]=a;
    }
    VoxGraphiteImage image{};
    image.width=sw;image.height=sh;image.pitch=sw*4;image.pixels=source.data();
    image.flags=1;image.opacity=.625f;
    image.matrix[0]=image.matrix[4]=scale;image.matrix[8]=1;
    image.source[0]=cropped?17:0;image.source[1]=cropped?23:0;
    image.source[2]=cropped?2000:sw;image.source[3]=cropped?1900:sh;
    image.destination[0]=image.clip[0]=804;image.destination[1]=image.clip[1]=4;
    image.destination[2]=image.clip[2]=273;image.destination[3]=image.clip[3]=260;
    if(rounded)std::fill(image.clip+4,image.clip+12,5);
    clear_images();
    std::vector<uint32_t> actual(size_t(width)*height*scale*scale,0xff090b0f);
    assert(image_draw(reinterpret_cast<uint8_t*>(actual.data()),width*scale,height*scale,
        width*scale*4,1,&image));

    // Fixed decode sizes independently check the odd source dimensions.
    auto info=SkImageInfo::Make(sw,sh,kRGBA_8888_SkColorType,kPremul_SkAlphaType,
        SkColorSpace::MakeSRGB());
    SkPixmap pixels(info,source.data(),sw*4);
    std::vector<uint8_t> resized(size_t(uw)*uh*4);
    SkPixmap upload(info.makeWH(uw,uh),resized.data(),uw*4);
    assert(pixels.scalePixels(upload,SkSamplingOptions(SkFilterMode::kLinear,SkMipmapMode::kNearest)));
    auto raster=SkImages::RasterFromPixmapCopy(upload);assert(raster);
    SkPictureRecorder recorder;
    auto* canvas=recorder.beginRecording(SkRect::MakeWH(width,height));
    canvas->clear(SkColorSetRGB(9,11,15));
    auto destination=SkRect::MakeXYWH(804,4,273,260);
    if(rounded)canvas->clipRRect(SkRRect::MakeRectXY(destination,5,5),true);
    SkPaint paint;paint.setAntiAlias(true);paint.setAlphaf(.625f);
    SkSamplingOptions sampling(SkFilterMode::kLinear,SkMipmapMode::kLinear);
    if(cropped) {
        float sx=float(uw)/sw,sy=float(uh)/sh;
        canvas->drawImageRect(raster,SkRect::MakeXYWH(17*sx,23*sy,2000*sx,1900*sy),
            destination,sampling,&paint,SkCanvas::kStrict_SrcRectConstraint);
    } else {
        auto natural=SkRect::MakeWH(sw,sh);
        canvas->concat(SkMatrix::RectToRect(natural,destination));
        auto adjusted=SkRect::MakeWH(sw*(float(uw)/sw),sh*(float(uh)/sh));
        if(adjusted.contains(SkRect::MakeWH(uw,uh))) {
            canvas->concat(SkMatrix::RectToRect(adjusted,natural));
            canvas->drawImage(raster,0,0,sampling,&paint);
        } else {
            canvas->drawImageRect(raster,adjusted,natural,sampling,&paint,SkCanvas::kStrict_SrcRectConstraint);
        }
    }
    SkSerialProcs procs;
    procs.fImageProc=[](SkImage* value,void*) -> sk_sp<SkData const> {return vox_encode_picture_image(value);};
    auto bytes=recorder.finishRecordingAsPicture()->serialize(&procs);assert(bytes);
    float matrix[]={float(scale),0,0,0,float(scale),0,0,0,1};
    std::vector<uint32_t> expected(actual.size());
    assert(picture_draw(reinterpret_cast<uint8_t*>(expected.data()),width*scale,height*scale,
        width*scale*4,bytes->data(),bytes->size(),matrix));
    if(actual!=expected) {
        size_t different=0;for(size_t i=0;i<actual.size();++i)different+=actual[i]!=expected[i];
        std::fprintf(stderr,"Mipped leaf mismatch scale=%d alternate=%d rounded=%d alpha=%d cropped=%d pixels=%zu\n",
            scale,alternate_height,rounded,alpha,cropped,different);
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
    for(int scale:{1,2}) for(bool alternate:{false,true}) for(bool rounded:{false,true})
        for(bool alpha:{false,true}) for(bool cropped:{false,true})
            compare_image(scale,alternate,rounded,alpha,cropped);
    std::puts("32 mipmapped image leaves match independent complete GPU pictures");
}
