#include "../native_graphite_raster_cache.h"
#include "../native_graphite_shape_region_policy.h"
#include <cassert>
#include <cstdio>

int main(int argc, char** argv)
{
    if (argc==3 && !std::strcmp(argv[1],"--policy")) {
        assert(vox_large_shape_regions_enabled()==(argv[2][0]=='1'));return 0;
    }
    assert(argc==1);
    VoxGraphiteRasterCache cache;
    VoxGraphiteShape shape{};shape.matrix[0]=shape.matrix[4]=shape.matrix[8]=1;
    shape.rect[0]=20;shape.rect[1]=30;shape.rect[2]=100;shape.rect[3]=80;
    shape.fill=1;shape.alpha=255;
    std::vector<uint8_t> input(8*4,31), painted(8*4,173);
    auto packed=cache.prepare_patches(shape,256,256,8,true,input.data());
    assert(!packed.hit&&packed.pending);cache.finish(std::move(packed),painted.data(),8*4);
    // The same word count and backdrop are a different layout of device texels.
    // A view at (0,0) must never reuse the packed ink at (20,30).
    VoxGraphitePixelRegion view{0,0,8,1,8*4,input.data()};
    auto region=cache.prepare_shape_region(shape,256,256,view,true);
    assert(!region.hit&&region.pending);assert(input==std::vector<uint8_t>(8*4,31));
    std::fill(painted.begin(),painted.end(),83);cache.finish(std::move(region),painted.data(),8*4);
    assert(cache.prepare_shape_region(shape,256,256,view,true).hit);
    assert(input==painted);
    std::fill(input.begin(),input.end(),31);
    assert(cache.prepare_patches(shape,256,256,8,true,input.data()).hit);
    assert(input==std::vector<uint8_t>(8*4,173));
    std::fill(input.begin(),input.end(),31);view.x=1;
    assert(!cache.prepare_shape_region(shape,256,256,view,true).hit);
    view.x=0;view.y=1;assert(!cache.prepare_shape_region(shape,256,256,view,true).hit);
    view.y=0;view.pitch=31;assert(!cache.prepare_shape_region(shape,256,256,view,true).hit);
    view.pitch=32;input[0]^=1;assert(!cache.prepare_shape_region(shape,256,256,view,true).hit);
    std::puts("Shape region cache: packed layout, origin, stride and backdrop identity passed");
}
