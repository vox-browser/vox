// Image-only recordings must publish without a vector or text leaf supplying
// their ink metadata. Compare the public image bridges with full child tiles.
#include "../native_skia_text_darwin.cpp"
#include <ImageIO/ImageIO.h>
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

// The first image touches the picture origin. Its geometric bounds must not
// add a synthetic raster fringe: moving the GPU picture by two pixels changes
// a rotated sibling's sampling by one byte, despite identical CSS geometry.
static void image_at_picture_origin(int scale)
{
    constexpr int width=1024,height=852,layer_width=441,layer_height=387;
    auto url=CFURLCreateWithFileSystemPath(nullptr,
        CFSTR("Tests/Browser/Brave/resources/image-decode-reused.png"),kCFURLPOSIXPathStyle,false);
    auto loader=CGImageSourceCreateWithURL(url,nullptr);CFRelease(url);assert(loader);
    auto decoded=CGImageSourceCreateImageAtIndex(loader,0,nullptr);CFRelease(loader);
    assert(decoded && CGImageGetWidth(decoded)==500 && CGImageGetHeight(decoded)==500);
    auto info=SkImageInfo::Make(500,500,kRGBA_8888_SkColorType,kPremul_SkAlphaType,
        SkColorSpace::MakeSRGB());
    std::vector<uint8_t> source(1000000);
    auto image_space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto decoder=CGBitmapContextCreate(source.data(),500,500,8,2000,image_space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
    assert(decoder);CGContextTranslateCTM(decoder,0,500);CGContextScaleCTM(decoder,1,-1);
    CGContextDrawImage(decoder,CGRectMake(0,0,500,500),decoded);CGContextFlush(decoder);
    CGContextRelease(decoder);CGColorSpaceRelease(image_space);CGImageRelease(decoded);
    std::vector<uint8_t> actual(size_t(width)*height*scale*scale*4),expected(actual);
    auto blue=[](auto& data){for(size_t i=0;i<data.size();i+=4){data[i]=36;data[i+1]=55;data[i+2]=173;data[i+3]=255;}};
    blue(actual);blue(expected);
    auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make=[&](auto& bytes){auto c=CGBitmapContextCreate(bytes.data(),width*scale,height*scale,
        8,width*scale*4,space,CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
        assert(c);CGContextScaleCTM(c,scale,scale);return c;};
    auto destination=make(actual),control=make(expected);CGColorSpaceRelease(space);
    ladybird_v_skia_set_shared_recording(0,1024,768);
    ladybird_v_skia_set_raster_layer(13,17,0);
    ladybird_v_skia_set_raster_layer_size(layer_width,layer_height);
    ladybird_v_skia_set_msaa_grid(nullptr,0,448*scale,416*scale,1);
    ladybird_v_skia_set_layer_shared_recording(1);
    assert(ladybird_v_skia_draw_rgba_image(destination,source.data(),500,500,2000,
        13,17,311,311,0,0,500,500,13,17,311,311,
        1,0,0,1,0,0,0,60,0,width,height,1,0,3,nullptr));
    assert(ladybird_v_skia_draw_rgba_image(destination,source.data(),500,500,2000,
        0,0,311,311,0,0,500,500,0,0,311,311,
        .992546141147614f,.121869340538979f,-.121869340538979f,.992546141147614f,
        132.085510253906f,57.2298431396484f,0,60,0,width,height,1,0,3,nullptr));
    blue(actual);ladybird_v_skia_finish_shared_recording();ladybird_v_skia_set_layer_shared_recording(0);

    auto premul=info.makeAlphaType(kPremul_SkAlphaType);std::vector<uint8_t> pixels(1000000);
    assert(SkPixmap(info,source.data(),2000).readPixels(premul,pixels.data(),2000));
    auto image=SkImages::RasterFromPixmapCopy(SkPixmap(premul,pixels.data(),2000));assert(image);
    SkPictureRecorder recorder;auto* canvas=recorder.beginRecording(SkRect::MakeWH(width,height));
    auto sampling=SkSamplingOptions(SkFilterMode::kLinear,SkMipmapMode::kLinear);
    SkPaint paint;paint.setAntiAlias(true);
    for(int i=0;i<2;++i){
        canvas->save();
        if(i)canvas->setMatrix(SkMatrix::MakeAll(.992546141147614f,-.121869340538979f,132.085510253906f,
            .121869340538979f,.992546141147614f,117.2298431396484f,0,0,1));
        else canvas->translate(13,77);
        canvas->scale(311.f/500,311.f/500);canvas->drawImage(image,0,0,sampling,&paint);canvas->restore();
    }
    SkSerialProcs procs;procs.fImageProc=serialize_shared_picture_image;
    auto bytes=recorder.finishRecordingAsPicture()->serialize(&procs);assert(bytes);
    int tw=448*scale,th=416*scale;
    std::vector<uint32_t> tile(size_t(tw)*th),cropped(size_t(layer_width)*layer_height*scale*scale);
    float matrix[]={float(scale),0,float(-13*scale),0,float(scale),float(-77*scale),0,0,1};
    assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(tile.data()),tw,th,tw*4,
        bytes->data(),bytes->size(),matrix));
    for(int row=0;row<layer_height*scale;++row)
        std::copy_n(tile.data()+size_t(row)*tw,layer_width*scale,cropped.data()+size_t(row)*layer_width*scale);
    std::vector<uint32_t> backdrop(cropped.size(),0xff2437ad);
    native_composite_opacity_pixels(reinterpret_cast<uint8_t*>(cropped.data()),
        reinterpret_cast<uint8_t*>(backdrop.data()),reinterpret_cast<uint8_t*>(cropped.data()),cropped.size(),1);
    assert(composite_pixels(control,std::move(cropped),layer_width*scale,layer_height*scale,
        13,height-77-layer_height,layer_width,layer_height,true));
    CGContextFlush(destination);CGContextFlush(control);
    if(actual!=expected){std::fprintf(stderr,"Image picture origin mismatch scale=%d\n",scale);std::abort();}
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
    for(int scale:{1,2}){image_at_picture_origin(scale);++cases;}
    ladybird_v_skia_set_chromium_painting(0);assert(cases==38);
    std::puts("Image-only pictures: 38 exact full-child GPU comparisons passed");
}
