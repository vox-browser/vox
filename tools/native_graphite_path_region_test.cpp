#include "../native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>
#include <thread>
#include <chrono>
// Compare compact CPU views with an unchanged full GPU surface. Exercise odd
// pitches, unaligned storage, surface edges, clips, gradients and opacity.
int main(int argc, char** argv)
{
    assert(argc == 3);
    auto a = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto b = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(a && b);
    auto full=reinterpret_cast<decltype(&vox_graphite_draw_path_pixels)>(dlsym(a,"vox_graphite_draw_path_pixels"));
    auto draw=reinterpret_cast<decltype(&vox_graphite_draw_path_region_pixels)>(dlsym(b,"vox_graphite_draw_path_region_pixels"));
    auto finish_a=reinterpret_cast<decltype(&vox_graphite_finish_frame)>(dlsym(a,"vox_graphite_finish_frame"));
    auto finish_b=reinterpret_cast<decltype(&vox_graphite_finish_frame)>(dlsym(b,"vox_graphite_finish_frame"));
    assert(full&&draw&&finish_a&&finish_b);
    constexpr int width=544,height=256;
    constexpr int crops[][4]={{0,0,width,height},{1,1,17,3},{57,23,81,37},{512,220,32,36}};
    size_t comparisons=0;
    for(int scale:{1,2}) for(int bg:{0,1}) for(int gradient:{0,1,2})
    for(int stroke:{0,1}) for(int fractional:{0,1}) for(auto const& crop:crops) for(int pass:{0,1,2}) {
        float segments[]={0,3.25,4.5,0,0,0,0,0,0,0,0,0,
            3,229.5,74.25,232,-4,11,134,0,0,0,0,0,
            1,7.25,96.5,0,0,0,0,0,0,0,0,0,
            5,0,0,0,0,0,0,0,0,0,0,0};
        float stops[]={.9,.1,.3,.8,0,.1,.7,.4,.65,1};
        VoxGraphitePath path{};
        path.segments=segments;path.segment_count=4;
        path.matrix[0]=path.matrix[4]=scale;path.matrix[8]=1;
        path.matrix[2]=fractional?-.375f:0;path.matrix[5]=fractional?.25f:0;
        path.gradient=gradient;path.stops=stops;path.stop_count=2;path.opacity=pass==2?.35f:.8f;
        path.gradient_points[0]=2;path.gradient_points[1]=3;path.gradient_points[2]=gradient==2?1:227;
        path.gradient_points[3]=76;path.gradient_points[4]=125;path.gradient_points[5]=130;
        path.gradient_matrix[0]=path.gradient_matrix[4]=path.gradient_matrix[8]=1;
        path.gradient_matrix[2]=pass*.375f;path.tile_mode=pass;path.linear_color_space=pass==2;
        path.red=35;path.green=167;path.blue=79;path.alpha=190;
        path.stroke=stroke;path.stroke_width=2.25f;path.miter_limit=4;path.line_cap=pass;path.line_join=pass;
        if(pass==1){path.has_clip=1;float clip[]={5,8,210,95,5,4,3,2,4,5,2,3};std::copy_n(clip,12,path.clip);}
        if(pass==2){path.has_ancestor_clip=1;float clip[]={7,13,170,72,4,3,2,1,3,2,1,4};std::copy_n(clip,12,path.ancestor_clip);}
        int x=crop[0],y=crop[1],w=crop[2],h=crop[3],pitch=w*4+13;
        std::vector<uint8_t> actual(1+size_t(pitch)*h,0xA9),expected(size_t(width)*height*4);
        for(int row=0;row<h;++row) for(int col=0;col<w;++col) {
            auto* p=actual.data()+1+size_t(row)*pitch+col*4;
            p[0]=uint8_t(col*17+row*7);p[1]=uint8_t(col*11+row*13);p[2]=uint8_t(col*5+row*19);p[3]=255;
        }
        for(int row=0;row<h;++row)std::memcpy(expected.data()+(size_t(y+row)*width+x)*4,actual.data()+1+size_t(row)*pitch,size_t(w)*4);
        assert(full(expected.data(),width,height,width*4,bg,&path));
        VoxGraphitePixelRegion view{x,y,w,h,pitch,actual.data()+1};
        assert(draw(&view,width,height,bg,&path));
        for(int row=0;row<h;++row) {
            if(std::memcmp(actual.data()+1+size_t(row)*pitch,expected.data()+(size_t(y+row)*width+x)*4,size_t(w)*4)) {
                std::fprintf(stderr,"Mismatch scale=%d bg=%d gradient=%d stroke=%d fractional=%d crop=%d,%d,%d,%d pass=%d\n",scale,bg,gradient,stroke,fractional,x,y,w,h,pass);return 1;
            }
            for(int i=w*4;i<pitch;++i)assert(actual[1+size_t(row)*pitch+i]==0xA9);
        }
        assert(actual[0] == 0xA9);
        ++comparisons;
        finish_a();
        finish_b();
    }
    std::vector<uint8_t> p(64*32*4,71);auto untouched=p;VoxGraphitePixelRegion view{0,0,64,32,256,p.data()};VoxGraphitePath path{};
    assert(!draw(&view,width,height,1,&path));float segments[12]{};path.segments=segments;path.segment_count=1;
    view.x=width;assert(!draw(&view,width,height,1,&path));view.x=0;view.pitch=1;assert(!draw(&view,width,height,1,&path));assert(p==untouched);
    // Vary dimensions beyond the cache entry and byte budgets. Repeated
    // draws change paint and backdrop data so stale surfaces cannot pass.
    auto clear=reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(dlsym(b,"vox_graphite_release_unused_graphics_memory"));
    auto idle=reinterpret_cast<decltype(&vox_graphite_release_idle_graphics_memory)>(dlsym(b,"vox_graphite_release_idle_graphics_memory"));
    assert(clear&&idle);
    for(int n=0;n<100;++n) {
        int w=n==98?1100:64+n*4,h=n==98?1000:48+n*3;
        float segment[]={0,1.25,2.5,0,0,0,0,0,0,0,0,0,
            1,float(w-3),3.25,0,0,0,0,0,0,0,0,0,
            1,5.75,float(h-4),0,0,0,0,0,0,0,0,0,
            5,0,0,0,0,0,0,0,0,0,0,0};
        VoxGraphitePath shape{};shape.segments=segment;shape.segment_count=4;
        shape.matrix[0]=shape.matrix[4]=shape.matrix[8]=1;
        shape.red=89;shape.green=183;shape.blue=211;shape.alpha=167;
        int rw=w-4,rh=h-6,pitch=rw*4+7;
        std::vector<uint8_t> compact(size_t(pitch)*rh,0xBA),whole(size_t(w)*h*4);
        for(int repeat=0;repeat<2;++repeat) {
            std::fill(whole.begin(),whole.end(),0);
            std::fill(compact.begin(),compact.end(),0xBA);
            for(int row=0;row<rh;++row) for(int col=0;col<rw;++col) {
                auto* p=compact.data()+size_t(row)*pitch+col*4;
                p[0]=(row+col+n)%173;p[1]=(row*3+col)%151;p[2]=(row+col*7)%101;p[3]=211;
            }
            for(int row=0;row<rh;++row)std::memcpy(whole.data()+(size_t(row+3)*w+2)*4,compact.data()+size_t(row)*pitch,size_t(rw)*4);
            shape.matrix[2]=repeat*.375f;shape.alpha=uint8_t(167-repeat*43);
            assert(full(whole.data(),w,h,w*4,1,&shape));
            VoxGraphitePixelRegion roi{2,3,rw,rh,pitch,compact.data()};
            assert(draw(&roi,w,h,1,&shape));
            for(int row=0;row<rh;++row) {
                assert(!std::memcmp(compact.data()+size_t(row)*pitch,whole.data()+(size_t(row+3)*w+2)*4,size_t(rw)*4));
                for(int j=rw*4;j<pitch;++j)assert(compact[size_t(row)*pitch+j]==0xBA);
            }
            ++comparisons;finish_a();finish_b();
        }
        if(n==41||n==75)clear();
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(2100));
    assert(idle()==1);assert(idle()==0);
    clear();
    std::printf("Graphite path regions: %zu exact GPU comparisons passed\n",comparisons);
}
