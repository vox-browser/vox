// Image-only recordings must publish without a vector or text leaf supplying
// their ink metadata. Compare the public image bridges with full child tiles.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static void scene(int scale, bool nearest, bool rotated, bool tiles,
    float page_y, float scroll_y)
{
    constexpr int width=240,height=200,sw=31,sh=23;
    int pitch=width*scale*4;
    std::vector<uint8_t> source(sw*sh*4);
    for(int y=0;y<sh;++y)for(int x=0;x<sw;++x){
        auto* p=source.data()+(y*sw+x)*4;
        int alpha=64+(x*11+y*17)%192;
        p[0]=(x*7%256)*alpha/255;p[1]=(y*11%256)*alpha/255;
        p[2]=((x*23+y*19)%256)*alpha/255;p[3]=alpha;
    }
    std::vector<uint8_t> actual(size_t(pitch)*height*scale),expected(actual);
    auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make=[&](auto& bytes){
        auto context=CGBitmapContextCreate(bytes.data(),width*scale,height*scale,8,pitch,
            space,CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
        assert(context);CGContextScaleCTM(context,scale,scale);return context;
    };
    auto destination=make(actual),control=make(expected);CGColorSpaceRelease(space);
    ladybird_v_skia_set_shared_recording(0,width,height);
    ladybird_v_skia_set_raster_layer(0,0,0);
    ladybird_v_skia_set_raster_layer_size(width,height);
    ladybird_v_skia_set_root_raster_scroll_y(0);
    int cell=0,tw=(width+2)*scale,th=(height+2)*scale;
    ladybird_v_skia_set_msaa_grid(&cell,1,tw,th,1);
    ladybird_v_skia_set_layer_shared_recording(1);
    float a=rotated?.96f:1,b=rotated?.28f:0,c=-b,d=a;
    float rects[]={29.25f,31.5f,73.5f,55.25f,0,0,sw,sh,
        tiles?119.125f:59.125f,58.375f,73.5f,55.25f,0,0,sw,sh};
    if(tiles){
        assert(ladybird_v_skia_draw_rgba_image_tiles(destination,source.data(),sw,sh,sw*4,
            rects,2,0,0,width,height,1,0,0,1,0,0,0,page_y,scroll_y,
            width,height,1,nearest,1,nullptr));
    }else for(int i=0;i<2;++i){
        auto* r=rects+i*8;
        assert(ladybird_v_skia_draw_rgba_image(destination,source.data(),sw,sh,sw*4,
            r[0],r[1],r[2],r[3],0,0,sw,sh,r[0],r[1],r[2],r[3],
            a,b,c,d,0,0,0,page_y,scroll_y,width,height,1,nearest,1,nullptr));
    }
    // Remove the ordinary fallback. An abandoned recording must not pass by
    // accidentally comparing its own fallback image with the GPU reference.
    std::fill(actual.begin(),actual.end(),0);
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_layer_shared_recording(0);

    auto info=SkImageInfo::Make(sw,sh,kRGBA_8888_SkColorType,kPremul_SkAlphaType,
        SkColorSpace::MakeSRGB());
    auto image=SkImages::RasterFromPixmapCopy(SkPixmap(info,source.data(),sw*4));assert(image);
    SkPictureRecorder recorder;
    auto* canvas=recorder.beginRecording(SkRect::MakeWH(width,height));
    canvas->setMatrix(SkMatrix::MakeAll(a,c,0,b,d,0,0,0,1));
    auto sampling=SkSamplingOptions(nearest?SkFilterMode::kNearest:SkFilterMode::kLinear);
    SkPaint paint;paint.setAntiAlias(true);
    for(int i=0;i<2;++i){
        auto* r=rects+i*8;canvas->save();
        canvas->concat(SkMatrix::RectToRect(SkRect::MakeWH(sw,sh),
            SkRect::MakeXYWH(r[0],r[1],r[2],r[3])));
        canvas->drawImageRect(image,SkRect::MakeWH(sw,sh),SkRect::MakeWH(sw,sh),
            sampling,&paint,nearest?SkCanvas::kStrict_SrcRectConstraint:SkCanvas::kFast_SrcRectConstraint);
        canvas->restore();
    }
    SkSerialProcs procs;procs.fImageProc=serialize_shared_picture_image;
    auto bytes=recorder.finishRecordingAsPicture()->serialize(&procs);assert(bytes);
    std::vector<uint32_t> full(size_t(tw)*th),cropped(size_t(width)*height*scale*scale);
    float matrix[]={float(scale),0,0,0,float(scale),0,0,0,1};
    assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(full.data()),tw,th,tw*4,
        bytes->data(),bytes->size(),matrix));
    for(int row=0;row<height*scale;++row)
        std::copy_n(full.data()+size_t(row)*tw,width*scale,cropped.data()+size_t(row)*width*scale);
    assert(composite_pixels(control,std::move(cropped),width*scale,height*scale,
        0,scroll_y-page_y,width,height,true));
    CGContextFlush(destination);CGContextFlush(control);
    if(actual!=expected){
        std::fprintf(stderr,"Image-only picture mismatch scale=%d nearest=%d rotated=%d tiles=%d page_y=%g scroll_y=%g\n",
            scale,nearest,rotated,tiles,page_y,scroll_y);std::abort();
    }
    CGContextRelease(destination);CGContextRelease(control);
}

int main()
{
    assert(shared_picture_draw());ladybird_v_skia_set_chromium_painting(1);
    int cases=0;
    for(int scale:{1,2})for(bool nearest:{false,true})for(bool rotated:{false,true})
    for(bool tiles:{false,true})for(int offset:{0,1,2}){
        if(tiles&&rotated)continue;
        scene(scale,nearest,rotated,tiles,offset==1?60:0,offset?13:0);++cases;
    }
    ladybird_v_skia_set_chromium_painting(0);assert(cases==36);
    std::puts("Image-only pictures: 36 exact full-child GPU comparisons passed");
}
