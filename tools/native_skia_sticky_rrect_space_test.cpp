// Equivalent integral translations must record identical layer-local rrects.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>
template<class Function> static Function selected(char const* name, Function fallback) {
    static void* library = []() -> void* {
        auto path=std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
        if(!path)return nullptr;
        auto handle=dlopen(path,RTLD_NOW|RTLD_LOCAL);assert(handle);return handle;
    }();
    if(!library)return fallback;
    auto symbol=dlsym(library,name);assert(symbol);return reinterpret_cast<Function>(symbol);
}
static std::vector<uint8_t> render(int scale, bool translated, bool underlay, bool root) {
    constexpr int width=1024, height=768;
    int pw=width*scale,ph=height*scale;
    std::vector<uint8_t> pixels(size_t(pw)*ph*4);
    auto color_space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context=CGBitmapContextCreate(pixels.data(),pw,ph,8,pw*4,color_space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color_space);assert(context);CGContextScaleCTM(context,scale,scale);
    selected("ladybird_v_skia_set_chromium_painting",&ladybird_v_skia_set_chromium_painting)(1);
    selected("ladybird_v_skia_set_shared_recording",&ladybird_v_skia_set_shared_recording)(0,width,height);
    selected("ladybird_v_skia_set_raster_layer",&ladybird_v_skia_set_raster_layer)(260,61,root);
    selected("ladybird_v_skia_set_raster_layer_size",&ladybird_v_skia_set_raster_layer_size)(764,230);
    int msaa_cell=0;selected("ladybird_v_skia_set_msaa_grid",&ladybird_v_skia_set_msaa_grid)(&msaa_cell,1,768*scale,256*scale,1);
    selected("ladybird_v_skia_set_layer_shared_recording",&ladybird_v_skia_set_layer_shared_recording)(1);
    if(underlay) {
        float data[]{translated?502.0f:762.0f,77,246,44,22,22,22,22,22,22,22,22};
        selected("ladybird_v_skia_set_rounded_rect_underlay",&ladybird_v_skia_set_rounded_rect_underlay)(data,237,243,254,255);
    }
    assert(selected("ladybird_v_skia_draw_rounded_rect",&ladybird_v_skia_draw_rounded_rect)(context,translated?502:762,77,246,44,
        22,22,22,22,22,22,22,22,1,0,0,1,translated?260:0,0,0,0,0,width,height,
        237,243,254,underlay?128:255,1,0,1,0));
    // A nonconvex path makes the shared GPU picture use multisampling,
    // as in a sticky message area containing its vector action icons.
    float path[5*12]{};
    path[1]=110;path[2]=211;
    path[12]=1;path[13]=190;path[14]=291;
    path[24]=1;path[25]=110;path[26]=291;
    path[36]=1;path[37]=190;path[38]=211;path[48]=5;
    assert(selected("ladybird_v_skia_draw_svg_path",&ladybird_v_skia_draw_svg_path)(context,
        path,5,0,1,0,0,1,260,0,0,0,0,width,height,
        21,21,21,255,1,0,0,0,0,0,0,0,0,4,0,nullptr,0,0,0));
    selected("ladybird_v_skia_finish_shared_recording",&ladybird_v_skia_finish_shared_recording)();CGContextFlush(context);
    CGContextRelease(context);selected("ladybird_v_skia_set_layer_shared_recording",&ladybird_v_skia_set_layer_shared_recording)(0);
    selected("ladybird_v_skia_set_msaa_grid",&ladybird_v_skia_set_msaa_grid)(nullptr,0,0,0,0);selected("ladybird_v_skia_set_raster_layer",&ladybird_v_skia_set_raster_layer)(0,0,1);
    return pixels;
}
int main(){assert(shared_picture_draw());int failures=0;
    for(int scale:{1,2})for(bool underlay:{false,true})for(bool root:{false,true}) {
        auto a=render(scale,true,underlay,root),b=render(scale,false,underlay,root);
        int different=0;for(size_t i=0;i<a.size();i+=4)
            if(!std::equal(a.begin()+i,a.begin()+i+4,b.begin()+i))++different;
        std::printf("scale=%d underlay=%d root=%d: %d differing pixels\n",scale,underlay,root,different);
        failures+=different;
    }return failures?1:0;
}
