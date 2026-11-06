#include "../native_skia_text_darwin.cpp"
#include <cassert>

static std::vector<uint8_t> draw_case(int scale, bool unclamped)
{
    constexpr int width=1024,height=768,sw=2392,sh=1690;
    std::vector<uint8_t> source(size_t(sw)*sh*4);
    for(int y=0;y<sh;++y)for(int x=0;x<sw;++x){
        auto* p=source.data()+(size_t(y)*sw+x)*4;int alpha=64+(x*11+y*17)%192;
        p[0]=(x*7%256)*alpha/255;p[1]=(y*11%256)*alpha/255;
        p[2]=((x*23+y*19)%256)*alpha/255;p[3]=alpha;
    }
    int pitch=width*scale*4;
    std::vector<uint8_t> actual(size_t(pitch)*height*scale),expected(actual);
    auto blue=[](auto& pixels){for(size_t i=0;i<pixels.size();i+=4){pixels[i]=36;pixels[i+1]=55;pixels[i+2]=173;pixels[i+3]=255;}};blue(actual);blue(expected);
    auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make=[&](auto& bytes){auto c=CGBitmapContextCreate(bytes.data(),width*scale,height*scale,
        8,pitch,space,CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
        assert(c);CGContextScaleCTM(c,scale,scale);return c;};
    auto destination=make(actual),control=make(expected);CGColorSpaceRelease(space);
    ladybird_v_skia_set_shared_recording(0,width,height);
    ladybird_v_skia_set_raster_layer(0,0,0);
    ladybird_v_skia_set_raster_layer_size(width,height);
    int tile_width=width*scale,tile_height=256*scale;
    ladybird_v_skia_set_msaa_grid(nullptr,0,tile_width,tile_height,1);
    ladybird_v_skia_set_layer_shared_recording(1);
    ladybird_v_skia_set_shared_layer_backdrop(1);
    ladybird_v_skia_set_opaque_layer_continuation(1);
    int flags=1|(unclamped?VOX_GRAPHITE_IMAGE_UNCLAMPED_SOURCE:0);
    assert(ladybird_v_skia_draw_rgba_image(destination,source.data(),sw,sh,sw*4,
        404,134,568,401,0,0,sw,sh,404,134,600,401,
        1,0,0,1,0,0,0,0,0,width,height,1,0,flags,nullptr));
    blue(actual);
    ladybird_v_skia_finish_shared_recording();ladybird_v_skia_set_layer_shared_recording(0);ladybird_v_skia_set_shared_layer_backdrop(0);

    int level=scale==1?2:1,uw=vox_image_decode_axis(sw,level),uh=vox_image_decode_axis(sh,level);
    VoxGraphiteImage input{};input.width=sw;input.height=sh;input.pitch=sw*4;input.flags=1;input.pixels=source.data();
    std::vector<uint8_t> resized(size_t(uw)*uh*4);assert(graphite_image_resize()(&input,resized.data(),uw,uh,uw*4));
    auto info=SkImageInfo::Make(uw,uh,kRGBA_8888_SkColorType,kPremul_SkAlphaType,SkColorSpace::MakeSRGB());
    auto bitmap=SkImages::RasterFromPixmapCopy(SkPixmap(info,resized.data(),uw*4));assert(bitmap);
    auto src=SkRect::MakeWH(sw*(float(uw)/sw),sh*(float(uh)/sh));
    if(scale==1)assert(src.height()<uh); // 422.999969482421875 instead of423.
    auto natural=SkRect::MakeWH(sw,sh),target=SkRect::MakeXYWH(404,134,568,401);
    SkPictureRecorder recorder;auto* canvas=recorder.beginRecording(SkRect::MakeWH(width,height));
    std::vector<uint32_t> background(size_t(width)*height*scale*scale,0xff2437ad);
    auto bg_info=SkImageInfo::Make(width*scale,height*scale,kBGRA_8888_SkColorType,kPremul_SkAlphaType,SkColorSpace::MakeSRGB());
    auto bg=SkImages::RasterFromPixmapCopy(SkPixmap(bg_info,background.data(),size_t(width)*scale*4));
    canvas->save();canvas->scale(1.f/scale,1.f/scale);canvas->drawImage(bg,0,0);canvas->restore();
    canvas->clipRect(SkRect::MakeXYWH(404,134,600,401),true);
    canvas->concat(SkMatrix::RectToRect(natural,target));SkPaint paint;paint.setAntiAlias(true);
    auto sampling=SkSamplingOptions(SkFilterMode::kLinear,SkMipmapMode::kLinear);
    if(src.contains(SkRect::MakeWH(uw,uh))){
        canvas->concat(SkMatrix::RectToRect(src,natural));canvas->drawImage(bitmap,0,0,sampling,&paint);
    }else canvas->drawImageRect(bitmap,src,natural,sampling,&paint,
        unclamped?SkCanvas::kFast_SrcRectConstraint:SkCanvas::kStrict_SrcRectConstraint);
    SkSerialProcs procs;procs.fImageProc=serialize_shared_picture_image;
    auto bytes=recorder.finishRecordingAsPicture()->serialize(&procs);assert(bytes);
    std::vector<uint32_t> cropped(size_t(width)*height*scale*scale);
    VoxChromiumRasterGrid grid{tile_width,tile_height,1,(height*scale-2+tile_height-3)/(tile_height-2)};
    assert(vox_draw_chromium_raster_grid(cropped,width*scale,height*scale,0,0,grid,
        [&](auto& tile,long x,long y,int){
            float matrix[]={float(scale),0,float(x),0,float(scale),float(y),0,0,1};
            return shared_picture_draw()(reinterpret_cast<uint8_t*>(tile.data()),tile_width,tile_height,
                tile_width*4,bytes->data(),bytes->size(),matrix);
        }));
    assert(composite_pixels(control,std::move(cropped),width*scale,height*scale,0,0,width,height,true));
    CGContextFlush(destination);CGContextFlush(control);
    if(actual!=expected){std::fprintf(stderr,"Whole-tile filtering mismatch scale=%d unclamped=%d\n",scale,int(unclamped));std::abort();}
    CGContextRelease(destination);CGContextRelease(control);return actual;
}

int main()
{
    assert(shared_picture_draw());ladybird_v_skia_set_chromium_painting(1);
    for(int scale:{1,2}){
        auto strict=draw_case(scale,false),unclamped=draw_case(scale,true);
        if(scale==1)assert(strict!=unclamped);
    }
    ladybird_v_skia_set_chromium_painting(0);
    std::puts("4 whole-tile and strict-source picture controls passed");
}
