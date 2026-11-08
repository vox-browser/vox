// Frozen CPU upload hashes from Chromium's pinned Skia revision
// 29ed1e87a0a50f3d8347e988842d9d59e7573efa. No Skia ABI crosses the test boundary.
#include "../native/include/native_graphite_bridge.h"
#include <algorithm>
#include <array>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

using Resize = decltype(&vox_graphite_resize_rgba_pixels);
static constexpr std::array<uint64_t, 24> expected = {
    0x36ebf7ed72d783ffULL,
    0xc3e29577ee29df52ULL,
    0x36ebf7ed72d783ffULL,
    0xc3e29577ee29df52ULL,
    0x36ebf7ed72d783ffULL,
    0xc3e29577ee29df52ULL,
    0xb8a8238ceff26528ULL,
    0x9795107584dc2c49ULL,
    0xb8a8238ceff26528ULL,
    0x9795107584dc2c49ULL,
    0xb8a8238ceff26528ULL,
    0x9795107584dc2c49ULL,
    0xf1c1cc7f21de3db3ULL,
    0xbb7c8c08d5137e14ULL,
    0xf1c1cc7f21de3db3ULL,
    0xbb7c8c08d5137e14ULL,
    0xf1c1cc7f21de3db3ULL,
    0xbb7c8c08d5137e14ULL,
    0x99499ca3632858edULL,
    0x6664318c95cd2382ULL,
    0x99499ca3632858edULL,
    0x6664318c95cd2382ULL,
    0x99499ca3632858edULL,
    0x6664318c95cd2382ULL,
};

static uint64_t scene(Resize resize, int geometry, int profile, bool alpha)
{
    const int sizes[][4] = {{31,23,16,12}, {1191,690,596,345}, {32,24,8,6}, {9,7,1,1}};
    auto size = sizes[geometry];
    int width=size[0], height=size[1], out_width=size[2], out_height=size[3];
    int pitch=width*4+12, out_pitch=out_width*4+20;
    std::vector<uint8_t> source(size_t(pitch)*height,0xcd);
    for (int y=0;y<height;++y) for (int x=0;x<width;++x) {
        auto* pixel=source.data()+size_t(y)*pitch+x*4;
        int a=alpha?32+(x*11+y*17)%224:255;
        pixel[0]=uint8_t((x*71+y*13)%256*a/255);
        pixel[1]=uint8_t((x*19+y*137)%256*a/255);
        pixel[2]=uint8_t((x*97+y*43)%256*a/255);
        pixel[3]=uint8_t(a);
    }
    auto original=source;
    VoxGraphiteImage image{};
    image.pixels=source.data(); image.width=width; image.height=height;
    image.pitch=pitch; image.flags=1;
    // The numerical ICC profile from a tagged odd-sized PNG, and linear sRGB.
    const float tagged[]={-1,2.4000001f,.947867274f,.0521326996f,.0773993805f,.0404499993f,0,0,
        .472671509f,.355941772f,.135604858f,.238647461f,.694824219f,.0665130615f,
        .00791931152f,.106185913f,.711105347f};
    const float linear[]={-1,1,1,0,0,0,0,0,
        .436065674f,.385147095f,.143066406f,.222488403f,.716873169f,.06060791f,
        .013916016f,.097076416f,.714096069f};
    image.has_color_profile=profile!=0;
    if (profile) std::copy_n(profile==1?tagged:linear,VOX_IMAGE_COLOR_PROFILE_VALUES,image.color_profile);
    std::vector<uint8_t> output(size_t(out_pitch)*out_height+32,0xa5);
    assert(resize(&image,output.data()+16,out_width,out_height,out_pitch));
    assert(source==original);
    uint64_t hash=1469598103934665603ULL;
    for(int y=0;y<out_height;++y) {
        auto* row=output.data()+16+size_t(y)*out_pitch;
        for(int x=0;x<out_width*4;++x) {hash^=row[x];hash*=1099511628211ULL;}
        for(int x=out_width*4;x<out_pitch;++x) assert(row[x]==0xa5);
    }
    for(int i=0;i<16;++i) assert(output[i]==0xa5 && output[output.size()-1-i]==0xa5);
    return hash;
}

int main(int argc, char** argv)
{
    assert(argc==2);
    auto* library=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    if(!library) {std::fprintf(stderr,"%s\n",dlerror());return 1;}
    auto resize=reinterpret_cast<Resize>(dlsym(library,"vox_graphite_resize_rgba_pixels"));
    assert(resize);
    size_t index=0;
    for(int geometry=0;geometry<4;++geometry) for(int profile=0;profile<3;++profile)
        for(bool alpha:{false,true}) {
            auto hash=scene(resize,geometry,profile,alpha);
            if(hash!=expected[index]) std::fprintf(stderr,"scene %zu: %016llx\n",index,(unsigned long long)hash);
            assert(hash==expected[index]);
            ++index;
        }
    std::vector<uint8_t> source(4*4*4,0x80), output(4*4*4,0xa5);
    VoxGraphiteImage image{};
    image.pixels=source.data(); image.width=4; image.height=4; image.pitch=16; image.flags=1;
    assert(resize(&image,output.data(),4,4,16));
    assert(output==source);
    auto original=image;
    int rejected=0;
    auto reject=[&](VoxGraphiteImage const* input,uint8_t* pixels,int w,int h,int pitch) {
        std::fill(output.begin(),output.end(),0xa5);
        assert(!resize(input,pixels,w,h,pitch));
        assert(std::all_of(output.begin(),output.end(),[](auto value){return value==0xa5;}));
        ++rejected;
    };
    reject(nullptr,output.data(),2,2,8);
    reject(&image,nullptr,2,2,8);
    for(int value:{0,-1,16385,2147483647}) {
        image=original;image.width=value;reject(&image,output.data(),2,2,8);
        image=original;image.height=value;reject(&image,output.data(),2,2,8);
    }
    image=original;image.width=4096;image.height=4096;image.pitch=16384;
    reject(&image,output.data(),2,2,8);
    image=original;image.pixels=nullptr;reject(&image,output.data(),2,2,8);
    for(int flags:{0,4,5}) {image=original;image.flags=flags;reject(&image,output.data(),2,2,8);}
    for(int pitch:{0,-1,15}) {image=original;image.pitch=pitch;reject(&image,output.data(),2,2,8);}
    image=original;
    for(int value:{0,-1,5,2147483647}) {
        reject(&image,output.data(),value,2,8);
        reject(&image,output.data(),2,value,8);
    }
    for(int pitch:{0,-1,7}) reject(&image,output.data(),2,2,pitch);
    std::printf("24 frozen Chromium resize scenes, identity, padding, immutable inputs and %d rejected descriptors passed\n",rejected);
}
