// A CSS mask/opacity child is created inside each parent raster tile, rather
// than once for the entire image. Compare its image input with independent
// complete child surfaces, including a wider scope and a scrolling viewport.
#ifdef VOX_TEST_OLD_SAVE_LAYER_IMAGE
extern "C" void ladybird_v_skia_set_save_layer_image_raster(double,double,double,double,int) {}
#endif
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto draw=graphite_image_draw();assert(draw);
    ladybird_v_skia_set_raster_layer(0,0,1);
    std::vector<uint8_t> source(37*29*4);
    for(size_t i=0;i<source.size();++i)source[i]=uint8_t(i*37+i/11);
    size_t cases=0;
    for(int scale:{1,2})for(int tile_rows:{32,256,416})for(int scroll:{0,137})
    for(bool wider:{false,true})for(bool planar:{false,true}) {
        double scope_x=wider?2:4,scope_y=wider?217.125:229.09375;
        double scope_w=wider?502:484,scope_h=wider?520.875:483.90625;
        int left=int(std::floor(scope_x*scale)),top=int(std::floor(scope_y*scale));
        int right=int(std::ceil((scope_x+scope_w)*scale)),bottom=int(std::ceil((scope_y+scope_h)*scale));
        int first_x=4*scale,first_y=229*scale,width=484*scale,height=484*scale;
        RasterRegion region {4,229+60-scroll,488,713+60-scroll};
        VoxGraphiteImage image{
            .matrix={float(scale),0,float(-first_x),0,float(scale),float(-first_y),0,0,1},
            .source={2,1,31,27},.destination={4,229,484,484},.clip={4,229,484,484},
            .opacity=.8f,.width=37,.height=29,.pitch=37*4,.flags=planar?4:1,
            .pixels=source.data()
        };
        if(!planar)for(size_t i=0;i<source.size();i+=4){source[i+3]=255;}
        int step=tile_rows-2;auto owner=[step](int y){return y<=step?0:(y-1)/step;};
        // Independent full child targets. The source keeps its page coordinates
        // while the mask's pixel bounds and parent tile determine its device.
        std::vector<uint32_t> expected(size_t(width)*height,0),actual=expected;
        for(int tile=owner(first_y);tile<=owner(first_y+height-1);++tile){
            int child_y=std::max(top,tile*step),child_end=std::min(bottom,tile*step+tile_rows);
            int w=right-left,h=child_end-child_y;assert(w>0 && h>0);
            std::vector<uint32_t> full(size_t(w)*h);
            auto request=image;request.matrix[2]=float(-left);request.matrix[5]=float(-child_y);
            if(tile%2==0)request.flags|=VOX_GRAPHITE_IMAGE_FORCE_MSAA;
            assert(draw(reinterpret_cast<uint8_t*>(full.data()),w,h,w*4,0,&request));
            for(int row=0;row<height;++row)if(owner(first_y+row)==tile){
                int y=first_y+row-child_y;assert(y>=0 && y<h);
                std::copy_n(full.data()+size_t(y)*w+(first_x-left),width,expected.data()+size_t(row)*width);
            }
        }
        std::vector<int> msaa;
        for(int tile=0;tile<=owner(first_y+height-1);++tile)if(tile%2==0)msaa.push_back(tile-(scroll*scale)/step);
        // Pick exact viewport-aligned scrolling below; the explicit tile state
        // is evaluated in projected device coordinates by the native bridge.
        if(scroll)msaa.clear();
        if(scroll){
            // Recompute a no-MSAA oracle for fractional tile/scroll phases.
            for(int tile=owner(first_y);tile<=owner(first_y+height-1);++tile){
                int child_y=std::max(top,tile*step),h=std::min(bottom,tile*step+tile_rows)-child_y,w=right-left;
                std::vector<uint32_t> full(size_t(w)*h);auto request=image;
                request.matrix[2]=float(-left);request.matrix[5]=float(-child_y);
                assert(draw(reinterpret_cast<uint8_t*>(full.data()),w,h,w*4,0,&request));
                for(int row=0;row<height;++row)if(owner(first_y+row)==tile)
                    std::copy_n(full.data()+size_t(first_y+row-child_y)*w+(first_x-left),width,expected.data()+size_t(row)*width);
            }
        }
        ladybird_v_skia_set_msaa_tiles(msaa.data(),int(msaa.size()),tile_rows);
        ladybird_v_skia_set_root_raster_scroll_y(scroll);
        ladybird_v_skia_set_save_layer_image_raster(scope_x,scope_y,scope_w,scope_h,tile_rows);
        assert(draw_chromium_layer_image_tiles(actual,width,height,region,scale,0,60,0,1024,false,image));
        if(actual!=expected){std::fprintf(stderr,"saveLayer image mismatch scale=%d tile_rows=%d scroll=%d wider=%d planar=%d\n",scale,tile_rows,scroll,wider,planar);return 1;}
        assert(image.matrix[2]==-first_x && image.matrix[5]==-first_y);
        ++cases;
    }
    ladybird_v_skia_set_save_layer_image_raster(0,0,0,0,0);
    std::puts("SaveLayer image inputs: 48 exact full-child GPU comparisons passed");
    assert(cases==48);
}
