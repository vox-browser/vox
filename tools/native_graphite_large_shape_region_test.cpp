#include "../native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <dlfcn.h>
#include <vector>

int main(int argc,char** argv)
{
    assert(argc==3 || argc==4);
    auto* before=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);auto* after=dlopen(argv[2],RTLD_NOW|RTLD_LOCAL);
    assert(before&&after);
    auto full=reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(dlsym(before,"vox_graphite_draw_shape_pixels"));
    auto region=reinterpret_cast<decltype(&vox_graphite_draw_shape_region_pixels)>(dlsym(after,"vox_graphite_draw_shape_region_pixels"));
    assert(full&&region);
    int cases=0;
    for(int scale:{1,2}) for(int fill:{0,1,2,6,7}) for(int msaa:{0,1})
    for(int floating:{0,1}) for(int alpha:{128,255}) for(int background:{0,1}) for(int clipped:{0,1})
    for(int crop:{0,1,2}) {
        int width=192*scale,height=128*scale;
        int x=crop==0?0:17*scale,y=crop==0?0:11*scale;
        int w=crop==2?53*scale:width-x,h=crop==2?45*scale:height-y,pitch=w*4+16;
        VoxGraphiteShape shape{};
        shape.matrix[0]=shape.matrix[4]=scale;shape.matrix[8]=1;
        shape.matrix[2]=-.375f;shape.matrix[5]=.25f;
        shape.rect[0]=-5.375f;shape.rect[1]=-3.75f;shape.rect[2]=222.125f;shape.rect[3]=177.5f;
        std::fill_n(shape.rect+4,8,31.25f);
        shape.fill=fill;shape.thickness=3.25f;shape.anti_alias=1;shape.force_msaa=msaa;
        shape.red=73;shape.green=121;shape.blue=43;shape.alpha=alpha;
        shape.has_float_color=floating;
        float color[]{.31f,.67f,.13f,.72f};std::copy_n(color,4,shape.float_color);
        std::fill_n(shape.border_widths,4,3.25f);
        if(fill==7) {
            shape.has_underlay=1;std::copy_n(shape.rect,12,shape.underlay_rect);
            shape.underlay_rgba[0]=30;shape.underlay_rgba[1]=20;shape.underlay_rgba[2]=13;shape.underlay_rgba[3]=160;
        }
        float clips[]{29,17,45,29};shape.clip_outs=clipped?clips:nullptr;shape.clip_out_count=clipped;
        for(int phase:{0,1,2}) {
            std::vector<uint8_t> actual(size_t(pitch)*h,0xAD),reference(size_t(width)*height*4,0);
            for(int row=0;row<h;++row) for(int col=0;col<w;++col) {
                auto* p=actual.data()+row*pitch+col*4;
                p[3]=uint8_t(130+(row+col+phase/2)%120);p[0]=p[3]/2;p[1]=p[3]/3;p[2]=p[3]/4;
                if(background)std::memcpy(reference.data()+((row+y)*width+col+x)*4,p,4);
            }
            VoxGraphitePixelRegion view{x,y,w,h,pitch,actual.data()};
            if(argc==4) {
                if(!std::strcmp(argv[3],"--faults")) {
                    auto seed=actual;
                    for(int i=0;i<8;++i) {
                        actual=seed;shape.matrix[5]=.25f+i*.0625f;
                        setenv("VOX_TEST_LARGE_SHAPE_REGION_FAIL_AFTER_READ","1",1);
                        assert(!region(&view,width,height,background,&shape));assert(actual==seed);
                        unsetenv("VOX_TEST_LARGE_SHAPE_REGION_FAIL_AFTER_READ");
                        reference.assign(size_t(width)*height*4,0);
                        assert(full(reference.data(),width,height,width*4,background,&shape));
                        assert(region(&view,width,height,background,&shape));
                        for(int row=0;row<h;++row)
                            assert(!std::memcmp(actual.data()+row*pitch,reference.data()+((row+y)*width+x)*4,w*4));
                    }
                    std::puts("Large shape regions: 8 queued-readback failures, unchanged outputs and exact retries");return 0;
                }
                auto original=actual;assert(!region(&view,width,height,background,&shape));assert(actual==original);
                std::puts("Disabled large shape regions leave output unchanged");return 0;
            }
            assert(full(reference.data(),width,height,width*4,background,&shape));
            assert(region(&view,width,height,background,&shape));
            for(int row=0;row<h;++row) {
                if(std::memcmp(actual.data()+row*pitch,reference.data()+((row+y)*width+x)*4,w*4)) {
                    std::fprintf(stderr,"Shape view mismatch scale=%d fill=%d msaa=%d float=%d bg=%d clip=%d crop=%d phase=%d\n",scale,fill,msaa,floating,background,clipped,crop,phase);return 1;
                }
                for(int col=w*4;col<pitch;++col)assert(actual[row*pitch+col]==0xAD);
            }
            ++cases;
        }
    }
    std::printf("Large shape regions: %d exact original-target GPU scenes\n",cases);
}
