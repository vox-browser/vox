// Compare complete native image pictures with independent SkCanvas scenes.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static void image_picture(int scale, int profile_kind, bool rounded, bool cropped,
    bool nearest, bool translucent)
{
    constexpr int width=192,height=160,source_width=32,source_height=24;
    constexpr int source_pitch=source_width*4+8;
    constexpr float x=29.25f,y=31.5f,w=73.5f,h=55.25f;
    std::vector<uint8_t> source(source_pitch*source_height,0xcd);
    for(int row=0;row<source_height;++row) for(int column=0;column<source_width;++column) {
        auto* pixel=source.data()+row*source_pitch+column*4;
        int alpha=translucent?64+(row*17+column*11)%192:255;
        pixel[0]=(column*7%256)*alpha/255;
        pixel[1]=(row*11%256)*alpha/255;
        pixel[2]=((row*19+column*23)%256)*alpha/255;
        pixel[3]=alpha;
    }
    auto color_space=profile_kind==1
        ?SkColorSpace::MakeRGB(SkNamedTransferFn::kSRGB,SkNamedGamut::kDisplayP3)
        :profile_kind==2?SkColorSpace::MakeSRGBLinear():SkColorSpace::MakeSRGB();
    float profile[VOX_IMAGE_COLOR_PROFILE_VALUES];
    assert(vox_store_image_color_space(color_space.get(),profile));
    int pitch=width*scale*4;
    std::vector<uint8_t> actual(size_t(pitch)*height*scale),expected(actual);
    auto native_space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make=[&](auto& bytes) {
        auto context=CGBitmapContextCreate(bytes.data(),width*scale,height*scale,8,pitch,
            native_space,CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
        assert(context);CGContextScaleCTM(context,scale,scale);return context;
    };
    auto destination=make(actual),control=make(expected);
    CGColorSpaceRelease(native_space);
    ladybird_v_skia_set_shared_recording(0,width,height);
    ladybird_v_skia_set_root_raster_scroll_y(0);
    ladybird_v_skia_set_raster_layer(0,0,0);
    ladybird_v_skia_set_raster_layer_size(width,height);
    int cell=0;
    int tile_width=(width+2)*scale,tile_height=(height+2)*scale;
    ladybird_v_skia_set_msaa_grid(&cell,1,tile_width,tile_height,1);
    ladybird_v_skia_set_layer_shared_recording(1);
    // This background exists only in the recording, so an aborted picture
    // cannot accidentally pass by comparing the ordinary fallback image.
    ladybird_v_skia_record_rect(destination,0,0,width,height,9,11,15,255);
    shared_recording_content(destination,SkRect::MakeWH(width,height),0,0);
    float clip[]={x+2,y+1,w-4,h-2,5,5,5,5,5,5,5,5};
    if(!rounded)std::fill(clip+4,clip+12,0);
    float source_x=cropped?3:0,source_y=cropped?2:0;
    float sw=cropped?25:source_width,sh=cropped?18:source_height;
    constexpr float a=.96f,b=.28f,c=-.28f,d=.96f,e=16.125f,f=5.25f;
    ladybird_v_skia_set_image_color_profile(profile_kind?profile:nullptr);
    assert(ladybird_v_skia_draw_rgba_image(destination,source.data(),source_width,source_height,
        source_pitch,x,y,w,h,source_x,source_y,sw,sh,clip[0],clip[1],clip[2],clip[3],
        a,b,c,d,e,f,0,0,0,width,height,.625f,nearest,3,clip+4));
    ladybird_v_skia_set_image_color_profile(nullptr);
    assert(s_shared_root_recording && s_shared_root_recording->blocked_bounds.empty());
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_layer_shared_recording(0);

    auto image_info=SkImageInfo::Make(source_width,source_height,kRGBA_8888_SkColorType,
        kPremul_SkAlphaType,color_space);
    auto image=SkImages::RasterFromPixmapCopy(SkPixmap(image_info,source.data(),source_pitch));
    assert(image);
    SkPictureRecorder recorder;
    auto* canvas=recorder.beginRecording(SkRect::MakeWH(width,height));
    canvas->clear(SkColorSetRGB(9,11,15));
    canvas->setMatrix(SkMatrix::MakeAll(a,c,e,b,d,f,0,0,1));
    auto bounds=SkRect::MakeXYWH(clip[0],clip[1],clip[2],clip[3]);
    if(rounded)canvas->clipRRect(SkRRect::MakeRectXY(bounds,5,5),true);
    else canvas->clipRect(bounds,true);
    SkPaint paint;paint.setAntiAlias(true);paint.setAlphaf(.625f);
    auto sampling=SkSamplingOptions(nearest?SkFilterMode::kNearest:SkFilterMode::kLinear);
    if(cropped) {
        canvas->drawImageRect(image,SkRect::MakeXYWH(3,2,25,18),SkRect::MakeXYWH(x,y,w,h),
            sampling,&paint,SkCanvas::kStrict_SrcRectConstraint);
    } else {
        auto natural=SkRect::MakeWH(source_width,source_height);
        canvas->concat(SkMatrix::RectToRect(natural,SkRect::MakeXYWH(x,y,w,h)));
        canvas->drawImageRect(image,natural,natural,sampling,&paint,
            nearest?SkCanvas::kStrict_SrcRectConstraint:SkCanvas::kFast_SrcRectConstraint);
    }
    SkSerialProcs procs;procs.fImageProc=serialize_shared_picture_image;
    auto bytes=recorder.finishRecordingAsPicture()->serialize(&procs);
    std::vector<uint32_t> tile(size_t(tile_width)*tile_height);
    float matrix[]={float(scale),0,0,0,float(scale),0,0,0,1};
    assert(bytes && shared_picture_draw()(reinterpret_cast<uint8_t*>(tile.data()),
        tile_width,tile_height,tile_width*4,bytes->data(),bytes->size(),matrix));
    std::vector<uint32_t> pixels(size_t(width)*height*scale*scale);
    for(int row=0;row<height*scale;++row)
        std::copy_n(tile.data()+size_t(row)*tile_width,width*scale,pixels.data()+size_t(row)*width*scale);
    composite_pixels(control,std::move(pixels),width*scale,height*scale,0,0,width,height,true);
    CGContextFlush(destination);CGContextFlush(control);
    if(actual!=expected) {
        size_t count=0;for(size_t i=0;i<actual.size();++i)count+=actual[i]!=expected[i];
        std::fprintf(stderr,"Image picture mismatch scale=%d profile=%d rounded=%d cropped=%d nearest=%d alpha=%d channels=%zu\n",
            scale,profile_kind,rounded,cropped,nearest,translucent,count);
    }
    assert(actual==expected);
    CGContextRelease(destination);CGContextRelease(control);
}

int main()
{
    assert(shared_picture_draw());
    ladybird_v_skia_set_chromium_painting(1);
    for(int scale:{1,2}) for(int profile:{0,1,2}) for(bool rounded:{false,true})
        for(bool cropped:{false,true}) for(bool nearest:{false,true}) for(bool alpha:{false,true})
            image_picture(scale,profile,rounded,cropped,nearest,alpha);
    ladybird_v_skia_set_chromium_painting(0);
    std::puts("96 native image pictures match independent GPU scenes across color spaces, clips and sampling modes");
}
