#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>
// CoreGraphics clipping still applies during publication, including curved
// clips. A separate library supplies the pre-optimization reference renderer.
int main()
{
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
    assert(path);
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto reference=reinterpret_cast<decltype(&ladybird_v_skia_draw_clipped_svg_linear_gradient_path)>(dlsym(library,"ladybird_v_skia_draw_clipped_svg_linear_gradient_path"));
    auto mode=reinterpret_cast<decltype(&ladybird_v_skia_set_chromium_painting)>(dlsym(library,"ladybird_v_skia_set_chromium_painting"));
    auto layer=reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer)>(dlsym(library,"ladybird_v_skia_set_raster_layer"));
    assert(reference&&mode&&layer&&graphite_path_region_draw());
    size_t comparisons=0;
    for(int scale:{1,2}) for(int root:{0,1}) for(int clip:{0,1,2}) for(int stroke:{0,1})
    for(int fractional:{0,1}) for(int alpha:{97,255}) for(int local_clip:{0,1}) {
        int width=160*scale,height=120*scale,pitch=width*4+16;
        std::vector<uint8_t> expected(size_t(pitch)*height),actual;
        for(size_t i=0;i<expected.size();++i)expected[i]=i%4==3?255:uint8_t(i*17);
        actual=expected;auto color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context=[&](std::vector<uint8_t>& pixels) {
            auto c=CGBitmapContextCreate(pixels.data(),width,height,8,pitch,color,
                static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)|static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));assert(c);
            CGContextScaleCTM(c,scale,scale);
            if(clip==1)CGContextClipToRect(c,CGRectMake(45.25,51.5,31.75,17.25));
            if(clip==2){CGContextAddEllipseInRect(c,CGRectMake(45.25,51.5,31.75,17.25));CGContextClip(c);}return c;
        };
        auto before=context(expected),after=context(actual);CGColorSpaceRelease(color);
        float segments[]={0,3.25,4.5,0,0,0,0,0,0,0,0,0,
            3,129.5,74.25,132,-4,11,114,0,0,0,0,0,
            1,7.25,96.5,0,0,0,0,0,0,0,0,0,
            5,0,0,0,0,0,0,0,0,0,0,0};
        float stops[]={.9,.1,.3,.8,0,.1,.7,.4,.65,1};
        float rounded[]={5,8,115,85,5,4,3,2,4,5,2,3};
        auto draw=[&](CGContextRef c,bool control){
            (control?mode:&ladybird_v_skia_set_chromium_painting)(1);
            (control?layer:&ladybird_v_skia_set_raster_layer)(0,0,root);
            auto fn=control?reference:&ladybird_v_skia_draw_clipped_svg_linear_gradient_path;
            return fn(c,segments,4,0,1,0,0,1,fractional?.375f:0,fractional?-.25f:0,
                0,0,0,160,120,stroke,2.25,1,2,4,
                2,3,127,76,1,0,0,1,.375,0,0,0,stops,2,alpha/255.f,1,
                local_clip?rounded:nullptr,nullptr);
        };
        assert(draw(before,true)&&draw(after,false));CGContextFlush(before);CGContextFlush(after);
        if(expected!=actual){std::cerr<<"Gradient integration mismatch scale="<<scale<<" root="<<root<<" clip="<<clip<<" stroke="<<stroke<<" frac="<<fractional<<" alpha="<<alpha<<" local="<<local_clip<<'\n';return 1;}
        ++comparisons;
        CGContextRelease(before);
        CGContextRelease(after);
        ladybird_v_skia_set_chromium_painting(0);mode(0);
    }
    std::cout<<"Gradient regions: "<<comparisons<<" exact integration comparisons passed\n";
}
