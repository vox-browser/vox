#include "../native_graphite_raster_cache.h"
#include <cassert>
#include <cstdio>

int main()
{
    constexpr int width=9,height=7,pitch=width*4+9;
    std::vector<uint8_t> source(4*4*4,127), input(pitch*height,31), result(pitch*height,173);
    VoxGraphiteImage image{};
    image.width=4;image.height=4;image.pitch=16;image.pixels=source.data();
    image.opacity=1;image.matrix[0]=image.matrix[4]=image.matrix[8]=1;
    image.source[2]=image.source[3]=4;image.destination[2]=image.destination[3]=4;
    for(bool background:{false,true}) for(int pattern:{0,1}) {
        VoxGraphiteRasterCache cache;
        if(pattern) for(size_t i=0;i<input.size();++i)input[i]=uint8_t(i*73);
        auto original=input;
        VoxGraphitePixelRegion view{2,3,width,height,pitch,input.data()};
        auto miss=cache.prepare_region(image,16,16,view,background,result.data(),pitch);
        assert(!miss.hit&&miss.pending&&input==original);
        cache.finish(std::move(miss),result.data(),pitch);
        for(bool crop:{false,true}) {
            int x=crop?1:0,y=crop?2:0,w=crop?5:width,h=crop?3:height;
            int in_pitch=w*4+11,out_pitch=w*4+13;
            std::vector<uint8_t> backdrop(in_pitch*h,0xA1), output(out_pitch*h,0xB2);
            for(int row=0;row<h;++row)std::memcpy(backdrop.data()+row*in_pitch,
                original.data()+(row+y)*pitch+x*4,w*4);
            auto preserved=backdrop;
            VoxGraphitePixelRegion request{view.x+x,view.y+y,w,h,in_pitch,backdrop.data()};
            assert(cache.prepare_region(image,16,16,request,background,output.data(),out_pitch).hit);
            assert(backdrop==preserved);
            for(int row=0;row<h;++row) {
                for(int col=0;col<w*4;++col)assert(output[row*out_pitch+col]==173);
                for(int col=w*4;col<out_pitch;++col)assert(output[row*out_pitch+col]==0xB2);
            }
            auto unchanged=output;
            assert(!cache.prepare_region(image,16,16,request,background,output.data(),w*4-1).hit);
            assert(output==unchanged&&backdrop==preserved);
            source[0]^=1;
            assert(!cache.prepare_region(image,16,16,request,background,output.data(),out_pitch).hit);
            assert(output==unchanged&&backdrop==preserved);source[0]^=1;
            if(background) {
                backdrop[0]^=1;
                assert(!cache.prepare_region(image,16,16,request,true,output.data(),out_pitch).hit);
                assert(output==unchanged);
            }
        }
    }
    std::puts("Separate image cache outputs: immutable inputs, exact/contained views, strides and mutation passed");
}
