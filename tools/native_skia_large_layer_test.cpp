// A large logical compositor extent must still publish its bounded viewport.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>
#include <limits>

static void check(int scale, double layer_width, double layer_height, bool valid)
{
    constexpr int width=320,height=240;
    int pitch=width*scale*4;
    std::vector<uint8_t> actual(size_t(pitch)*height*scale),expected(actual);
    auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make=[&](auto& pixels){
        auto c=CGBitmapContextCreate(pixels.data(),width*scale,height*scale,8,pitch,space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
        assert(c);CGContextScaleCTM(c,scale,scale);return c;
    };
    auto destination=make(actual),control=make(expected);CGColorSpaceRelease(space);
    ladybird_v_skia_set_shared_recording(0,width,height);
    ladybird_v_skia_set_root_raster_scroll_y(0);
    ladybird_v_skia_set_raster_layer(0,0,0);
    ladybird_v_skia_set_raster_layer_size(layer_width,layer_height);
    int cell=0;
    ladybird_v_skia_set_msaa_grid(&cell,1,258*scale,258*scale,
        std::isfinite(layer_width)&&layer_width>0?int(std::ceil(layer_width/256)):1);
    ladybird_v_skia_set_layer_shared_recording(1);
    auto* canvas=shared_recording_canvas(destination);assert(canvas);
    SkPaint paint;paint.setColor(SK_ColorRED);
    canvas->drawRect(SkRect::MakeXYWH(16,20,100,40),paint);
    shared_recording_content(destination,SkRect::MakeXYWH(16,20,100,40),0,0);
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_layer_shared_recording(0);
    if(valid){
        CGContextSetRGBFillColor(control,1,0,0,1);
        CGContextFillRect(control,CGRectMake(16,height-20-40,100,40));
    }
    CGContextFlush(destination);CGContextFlush(control);
    if(actual!=expected)std::fprintf(stderr,"Large layer mismatch: scale=%d logical=%g,%g valid=%d\n",
        scale,layer_width,layer_height,valid);
    assert(actual==expected);
    CGContextRelease(destination);CGContextRelease(control);
}

int main()
{
    ladybird_v_skia_set_chromium_painting(1);
    for(int scale:{1,2}){
        check(scale,1024,65,true);
        check(scale,1024,40320,true);
        check(scale,40000,40320,true);
        check(scale,16777216.0/scale,40320,true);
        check(scale,16777216.0/scale+2,40320,false);
        check(scale,1024,0,false);
        check(scale,1024,std::numeric_limits<double>::quiet_NaN(),false);
        check(scale,1024,std::numeric_limits<double>::infinity(),false);
        check(scale,1024,1e30,false);
        check(scale,1024,-10,false);
        check(scale,std::numeric_limits<double>::infinity(),40320,false);
    }
    std::puts("PASS: 22 bounded large-layer publications and invalid-extent controls");
}
