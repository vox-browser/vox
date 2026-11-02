#include "../native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

// Compare old admission with canonical admission, including cache reuse of
// render-equivalent paths whose object representations deliberately differ.
int main(int argc, char** argv)
{
    assert(argc == 3);
    auto control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    auto a = reinterpret_cast<decltype(&vox_graphite_draw_path_pixels)>(
        dlsym(control, "vox_graphite_draw_path_pixels"));
    auto b = reinterpret_cast<decltype(&vox_graphite_draw_path_pixels)>(
        dlsym(candidate, "vox_graphite_draw_path_pixels"));
    assert(a && b);
    constexpr int width = 544, height = 256, pitch = width*4+13;
    size_t comparisons = 0;
    for (int scale : {1, 2}) for (int bg : {0, 1}) for (int gradient : {0, 1, 2})
    for (int stroke : {0, 1}) for (int clipped : {0, 1}) for (int linear : {0, 1}) {
        float segments[] {0,3.25,4.5,0,0,0,0,0,0,0,0,0,
            3,229.5,74.25,232,-4,11,134,0,0,0,0,0,
            1,7.25,96.5,0,0,0,0,0,0,0,0,0,
            5,0,0,0,0,0,0,0,0,0,0,0};
        float stops[] {.9f,.1f,.3f,.8f,0,.1f,.7f,.4f,.65f,1};
        VoxGraphitePath path {};
        path.segments=segments; path.segment_count=4;
        path.matrix[0]=path.matrix[4]=float(scale); path.matrix[8]=1;
        path.matrix[2]=-.375f; path.matrix[5]=.25f;
        path.gradient=gradient; path.stop_count=2; path.stops=stops;
        path.gradient_points[0]=2; path.gradient_points[1]=3;
        path.gradient_points[2]=gradient==2?1.f:227.f;
        path.gradient_points[3]=76; path.gradient_points[4]=125; path.gradient_points[5]=130;
        path.gradient_matrix[0]=path.gradient_matrix[4]=path.gradient_matrix[8]=1;
        path.opacity=.8f; path.tile_mode=linear; path.linear_color_space=linear;
        path.red=35; path.green=167; path.blue=79; path.alpha=190;
        path.stroke=stroke; path.stroke_width=2.25f; path.miter_limit=4;
        path.has_clip=clipped; path.has_ancestor_clip=clipped;
        float clip[] {5,8,210,95,5,4,3,2,4,5,2,3};
        float ancestor[] {7,13,170,72,4,3,2,1,3,2,1,4};
        if (clipped) { std::copy_n(clip,12,path.clip); std::copy_n(ancestor,12,path.ancestor_clip); }
        for (int replay=0; replay<4; ++replay) {
            if (replay==3) {
                path.opacity=.27f; path.matrix[2]+=.375f;
                stops[1]+=.125f; segments[3]+=.25f;
            }
            auto equivalent=path;
            auto* bytes=reinterpret_cast<uint8_t*>(&equivalent);
            for (size_t i=sizeof(path.matrix); i<offsetof(VoxGraphitePath,segments); ++i)
                bytes[i]=uint8_t(0x31+replay*23);
            if (!clipped) {
                std::fill_n(equivalent.clip,12,float(replay*17));
                std::fill_n(equivalent.ancestor_clip,12,float(replay*31));
            }
            std::fill_n(equivalent.float_color,4,.125f*replay);
            std::vector<uint8_t> expected(size_t(pitch)*height,0xA9);
            for (int y=0; y<height; ++y) for (int x=0; x<width; ++x) {
                auto* pixel=expected.data()+size_t(y)*pitch+x*4;
                pixel[0]=uint8_t((x*17+y*7)%173); pixel[1]=uint8_t((x*11+y*13)%151);
                pixel[2]=uint8_t((x*5+y*19)%101); pixel[3]=211;
            }
            auto actual=expected;
            assert(a(expected.data(),width,height,pitch,bg,&path));
            assert(b(actual.data(),width,height,pitch,bg,&equivalent));
            assert(actual==expected);
            for (int y=0; y<height; ++y) for (int x=width*4; x<pitch; ++x)
                assert(actual[size_t(y)*pitch+x]==0xA9);
            ++comparisons;
        }
    }
    std::printf("Canonical path admission: %zu exact GPU comparisons passed\n", comparisons);
}
