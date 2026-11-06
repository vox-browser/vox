// SVG pattern bitmaps share compatible decodes across differently sized uses.
#include "../native_skia_text_darwin.cpp"
#include <ImageIO/ImageIO.h>
#include <array>
#include <cassert>
#include <cstdio>

static std::vector<uint8_t> star_pixels()
{
    auto url=CFURLCreateWithFileSystemPath(nullptr,
        CFSTR("Tests/Browser/Brave/resources/discord-star.png"),kCFURLPOSIXPathStyle,false);
    auto loader=CGImageSourceCreateWithURL(url,nullptr);CFRelease(url);assert(loader);
    auto image=CGImageSourceCreateImageAtIndex(loader,0,nullptr);CFRelease(loader);
    assert(image&&CGImageGetWidth(image)==37&&CGImageGetHeight(image)==38);
    std::vector<uint8_t> pixels(37*38*4);
    auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context=CGBitmapContextCreate(pixels.data(),37,38,8,37*4,space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
    assert(context);CGColorSpaceRelease(space);
    CGContextTranslateCTM(context,0,38);CGContextScaleCTM(context,1,-1);
    CGContextDrawImage(context,CGRectMake(0,0,37,38),image);CGContextFlush(context);
    CGContextRelease(context);CGImageRelease(image);return pixels;
}

static bool scene(int scale,int variant)
{
    constexpr int width=192,height=96;
    auto source=star_pixels();auto small_source=source;
    if(variant==2){auto* pixel=small_source.data()+(19*37+18)*4;std::fill_n(pixel,4,127);}
    int pitch=width*scale*4;
    std::vector<uint8_t> actual(size_t(pitch)*height*scale),expected(actual);
    for(auto* bytes:{&actual,&expected})for(size_t i=0;i<bytes->size();i+=4){
        (*bytes)[i]=26;(*bytes)[i+1]=32;(*bytes)[i+2]=129;(*bytes)[i+3]=255;
    }
    auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make=[&](auto& bytes){auto c=CGBitmapContextCreate(bytes.data(),width*scale,height*scale,
        8,pitch,space,CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
        assert(c);CGContextScaleCTM(c,scale,scale);return c;};
    auto destination=make(actual),control=make(expected);CGColorSpaceRelease(space);
    std::array<float,60> segments{};segments[0]=0;
    segments[12]=1;segments[13]=37;segments[24]=1;segments[25]=37;segments[26]=38;
    segments[36]=1;segments[38]=38;segments[48]=5;
    float inner[]={1,0,0,1,0,0},tile[]={0,0,37,38},target[]={0,0,37,38};
    auto path=path_from_serialized_segments(segments.data(),5);
    auto source_info=SkImageInfo::Make(37,38,kRGBA_8888_SkColorType,kPremul_SkAlphaType,
        SkColorSpace::MakeSRGB());
    SkPictureRecorder recorder;auto* canvas=recorder.beginRecording(SkRect::MakeWH(width*scale,height*scale));
    canvas->clear(SkColorSetRGB(26,32,129));canvas->scale(scale,scale);
    s_image_decode_cache.clear();
    ladybird_v_skia_begin_image_decode_frame(destination,1,1);
    ladybird_v_skia_set_shared_recording(0,width,height);ladybird_v_skia_set_raster_layer(0,0,1);
    ladybird_v_skia_set_msaa_grid(nullptr,0,0,0,0);
    auto draw=[&](bool large,float x,float y,char const* identity,int level,
        std::vector<uint8_t> const& pixels){
        float size=large?20:14;float outer[]={size/37,0,0,size/38,x,y};
        ladybird_v_skia_set_image_resource_identity(identity,int(std::strlen(identity)));
        assert(ladybird_v_skia_draw_svg_image_pattern(destination,pixels.data(),37,38,37*4,1,
            segments.data(),5,0,outer,inner,tile,target,target,0,0,0,width,height,1,0));
        int uw=vox_image_decode_axis(37,level),uh=vox_image_decode_axis(38,level);
        std::vector<uint8_t> resized;
        auto* data=pixels.data();
        if(level){
            resized.resize(size_t(uw)*uh*4);VoxGraphiteImage input{};
            input.width=37;input.height=38;input.pitch=37*4;input.flags=1;input.pixels=data;
            assert(graphite_image_resize()(&input,resized.data(),uw,uh,uw*4));data=resized.data();
        }
        auto bitmap=SkImages::RasterFromPixmapCopy(SkPixmap(source_info.makeWH(uw,uh),data,uw*4));assert(bitmap);
        SkPictureRecorder tile_recorder;auto bounds=SkRect::MakeWH(37,38);
        auto* content=tile_recorder.beginRecording(bounds);
        content->scale(37.f/uw,38.f/uh);
        bool mips=37.f*size/37*scale<uw&&38.f*size/38*scale<uh;
        content->drawImage(bitmap,0,0,SkSamplingOptions(SkFilterMode::kLinear,
            mips?SkMipmapMode::kLinear:SkMipmapMode::kNone));
        auto picture=tile_recorder.finishRecordingAsPicture();
        auto shader=picture->makeShader(SkTileMode::kRepeat,SkTileMode::kRepeat,SkFilterMode::kLinear,
            nullptr,&bounds);assert(shader);
        SkPaint paint;paint.setAntiAlias(true);paint.setShader(std::move(shader));
        canvas->save();canvas->concat(SkMatrix::MakeAll(outer[0],0,x,0,outer[3],y,0,0,1));
        canvas->drawPath(path,paint);canvas->restore();
    };
    int small=scale==1?1:0;
    if(variant==4)draw(false,8.375f,12.5f,"url:pattern-a",small,source);
    if(variant!=5)draw(true,40.25f,12.5f,"url:pattern-a",0,source);
    if(variant==3)ladybird_v_skia_begin_image_decode_frame(destination,2,1);
    int selected=(variant==1||variant==2||variant==4||variant==5)?small:0;
    draw(false,80.375f,12.5f,variant==1?"url:pattern-b":"url:pattern-a",selected,small_source);
    ladybird_v_skia_set_image_resource_identity(nullptr,0);
    auto picture=recorder.finishRecordingAsPicture();SkSerialProcs procs;procs.fImageProc=serialize_shared_picture_image;
    auto bytes=picture->serialize(&procs);assert(bytes);
    std::vector<uint32_t> result(size_t(width)*height*scale*scale);float matrix[]={1,0,0,0,1,0,0,0,1};
    assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(result.data()),width*scale,height*scale,
        pitch,bytes->data(),bytes->size(),matrix));
    assert(composite_pixels(control,std::move(result),width*scale,height*scale,0,0,width,height,true));
    CGContextFlush(destination);CGContextFlush(control);
    size_t different=0;for(size_t i=0;i<actual.size();i+=4)different+=!std::equal(actual.begin()+i,actual.begin()+i+4,expected.begin()+i);
    std::printf("SVG pattern decode scale=%d variant=%d: %zu differing pixels\n",scale,variant,different);
    CGContextRelease(destination);CGContextRelease(control);return !different;
}

int main()
{
    assert(shared_picture_draw());ladybird_v_skia_set_chromium_painting(1);
    bool exact=true;int cases=0;
    for(int scale:{1,2})for(int variant=0;variant<6;++variant){exact=scene(scale,variant)&&exact;++cases;}
    ladybird_v_skia_set_chromium_painting(0);
    if(!exact)return 1;
    std::printf("SVG pattern decode reuse: %d exact GPU scenes passed\n",cases);
}
