#include "../native_graphite_bridge.h"
#include <array>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <limits>
#include <vector>

static std::array<float,60> rectangle(float x,float y,float width,float height)
{
    std::array<float,60> p{};
    p[0]=0;p[1]=x;p[2]=y;
    p[12]=1;p[13]=x+width;p[14]=y;
    p[24]=1;p[25]=x+width;p[26]=y+height;
    p[36]=1;p[37]=x;p[38]=y+height;
    p[48]=5;
    return p;
}

int main(int argc,char** argv)
{
    assert(argc==2);
    auto* library=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(library);
    auto draw=reinterpret_cast<decltype(&vox_graphite_draw_svg_pattern_pixels)>(
        dlsym(library,"vox_graphite_draw_svg_pattern_pixels"));assert(draw);
    auto background=rectangle(0,0,20,12), detail=rectangle(6,4,8,4);
    VoxGraphitePath paths[2]{};
    for(int i=0;i<2;++i){
        paths[i].matrix[0]=paths[i].matrix[4]=paths[i].matrix[8]=1;
        paths[i].segments=i?detail.data():background.data();paths[i].segment_count=5;
        paths[i].red=paths[i].green=paths[i].blue=i?177:248;paths[i].alpha=255;
        paths[i].has_float_alpha=1;paths[i].opacity=1;
    }
    constexpr int width=128,height=96,pitch=width*4+13;
    int comparisons=0;
    for(int scale:{1,2}) for(int shift:{0,3,-2}) for(int linear:{0,1}) for(int backdrop:{0,1}) {
        float matrix[9]={float(scale),0,float(shift),0,float(scale),float(shift),0,0,1};
        float tile[4]={3,2,20,12};
        float clip[12]={8,6,40,24};
        std::vector<uint8_t> pixels(size_t(pitch)*height,0xa9);
        for(int y=0;y<height;++y)for(int x=0;x<width;++x){
            auto* p=pixels.data()+y*pitch+x*4;p[0]=37;p[1]=83;p[2]=129;p[3]=255;
        }
        auto original=pixels;
        assert(draw(pixels.data(),width,height,pitch,backdrop,paths,2,matrix,tile,clip,1,linear));
        for(int y=0;y<height;++y)for(int x=0;x<width;++x){
            auto* p=pixels.data()+y*pitch+x*4;
            float local_x=(x+.5f-shift)/scale,local_y=(y+.5f-shift)/scale;
            bool inside=local_x>=8&&local_x<48&&local_y>=6&&local_y<30;
            if(!inside){
                if(backdrop)assert(!std::memcmp(p,original.data()+y*pitch+x*4,4));
                else assert(p[0]==0&&p[1]==0&&p[2]==0&&p[3]==0);
                continue;
            }
            float u=std::fmod(local_x-3+40,20),v=std::fmod(local_y-2+24,12);
            // Linear filtering can blend the boundary texels. Interior and
            // clip coverage remain exact at both backing scales.
            if(linear&&(std::abs(u-6)<1||std::abs(u-14)<1||std::abs(v-4)<1||std::abs(v-8)<1))continue;
            auto color=u>=6&&u<14&&v>=4&&v<8?177:248;
            assert(p[0]==color&&p[1]==color&&p[2]==color&&p[3]==255);
        }
        for(int y=0;y<height;++y)for(int i=width*4;i<pitch;++i)assert(pixels[y*pitch+i]==0xa9);
        ++comparisons;
        for(int defect=0;defect<5;++defect){
            auto saved=pixels;auto bad=paths[0];auto tiles=std::array<float,4>{3,2,20,12};
            if(defect==0)bad.matrix[0]=std::numeric_limits<float>::quiet_NaN();
            if(defect==1)bad.segment_count=0;
            if(defect==2)bad.gradient=1;
            if(defect==3)tiles[2]=std::numeric_limits<float>::infinity();
            if(defect==4)tiles[3]=0;
            assert(!draw(pixels.data(),width,height,pitch,1,&bad,1,matrix,tiles.data(),clip,1,linear));
            assert(pixels==saved);
        }
    }
    std::printf("SVG picture shaders: %d matrix/filter/backdrop cases and 120 unchanged-failure checks passed\n",comparisons);
}
