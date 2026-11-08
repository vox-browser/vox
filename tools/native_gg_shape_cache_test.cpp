#include "../native/include/native_gg_shape.h"
#include <cassert>
#include <thread>
#include <limits.h>

static unsigned draws;
static int fake(uint8_t* pixels,int width,int height,int pitch,int background,VoxGraphiteShape const* shape) {
    ++draws;
    if (shape->fill==99) {std::memset(pixels,221,size_t(pitch)*height);return 0;}
    for(int y=0;y<height;++y) for(int x=0;x<width;++x) {
        auto* pixel=pixels+size_t(y)*pitch+x*4;
        for(int c=0;c<3;++c) pixel[c]=uint8_t((background ? pixel[c] : 0)+shape->red+x*3+y*5+c);
        pixel[3]=255;
    }
    return 1;
}
static int replacement(uint8_t* p,int w,int h,int pitch,int bg,VoxGraphiteShape const* shape) {
    int result=fake(p,w,h,pitch,bg,shape);if(result)p[0]^=37;return result;
}
static int replacing(uint8_t* p,int w,int h,int pitch,int bg,VoxGraphiteShape const* shape) {
    ladybird_v_skia_set_gg_shape_draw(replacement);return fake(p,w,h,pitch,bg,shape);
}
static int purging(uint8_t* p,int w,int h,int pitch,int bg,VoxGraphiteShape const* shape) {
    clear_gg_shape_raster_cache();return fake(p,w,h,pitch,bg,shape);
}
static VoxGGShapeDraw backend;
static int counted_backend(uint8_t* p,int w,int h,int pitch,int bg,VoxGraphiteShape const* s) {
    ++draws;return backend(p,w,h,pitch,bg,s);
}
static VoxGraphiteShape shape() {
    VoxGraphiteShape s {};s.matrix[0]=s.matrix[4]=s.matrix[8]=1;s.fill=1;
    s.rect[0]=3.25f;s.rect[1]=4.125f;s.rect[2]=31.5f;s.rect[3]=28.75f;
    for(int c=4;c<12;++c)s.rect[c]=4;
    s.red=53;s.green=107;s.blue=181;s.alpha=173;s.anti_alias=1;s.thickness=2.25f;
    return s;
}
static void direct_tests() {
    auto s=shape();ladybird_v_skia_set_gg_shape_draw(fake);
    std::vector<uint8_t> seed(24*4,42),p=seed;
    auto draw=[&] {return gg_draw_shape_pixels(p.data(),4,4,24,1,&s);};
    assert(draw());auto expected=p;unsigned calls=draws;p=seed;
    assert(draw() && draws==calls && p==expected);
    // Padding is excluded from keys and output writes.
    p=seed;p[16]=91;assert(draw() && draws==calls && p[16]==91);
    p=seed;p[24]^=1;assert(draw() && draws==calls+1);
    s.force_msaa=1;p=seed;assert(draw() && draws==calls+2);
    s.has_float_color=1;s.float_color[0]=.21147f;p=seed;assert(draw() && draws==calls+3);
    float cuts[] {1,2,3,4};s.clip_outs=cuts;s.clip_out_count=1;
    p=seed;assert(draw());calls=draws;p=seed;assert(draw() && draws==calls);
    cuts[2]+=.125f;p=seed;assert(draw() && draws==calls+1);
    s.has_underlay=1;s.has_float_underlay_color=1;s.underlay_float_color[0]=.391f;
    p=seed;assert(draw());calls=draws;s.underlay_float_color[0]+=.001f;p=seed;assert(draw() && draws==calls+1);
    setenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE","1",1);calls=draws;
    p=seed;assert(draw());p=seed;assert(draw() && draws==calls+2);
    unsetenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE");
    ladybird_v_skia_set_gg_shape_draw(replacement);p=seed;assert(draw());expected=p;calls=draws;
    p=seed;assert(draw() && p==expected && draws==calls);
#if defined(__APPLE__)
    auto hits=s_gg_shape_cache_hits;auto unchanged=p;
    std::thread worker([&] {assert(!draw());});worker.join();
    assert(draws==calls && p==unchanged && s_gg_shape_cache_hits==hits);
#endif
    ladybird_v_skia_set_gg_shape_draw(replacing);p=seed;assert(draw());calls=draws;
    p=seed;assert(draw() && draws==calls+1); // Pending output belongs to old backend.
    ladybird_v_skia_set_gg_shape_draw(purging);p=seed;assert(draw());calls=draws;
    p=seed;assert(draw() && draws==calls+1); // An in-flight request cannot undo purge.
    ladybird_v_skia_set_gg_shape_draw(nullptr);assert(!draw());
}
static void region_tests() {
    auto s=shape();ladybird_v_skia_set_gg_shape_draw(fake);
    std::vector<uint8_t> a(40*8,42),b(24*8,71);auto seed_a=a,seed_b=b;
    VoxGraphitePixelRegion regions[] {{2,3,8,6,40,a.data()},{12,15,3,5,24,b.data()}};
    assert(gg_draw_rounded_parts_pixels(regions,2,32,32,1,&s));auto expected_a=a,expected_b=b;unsigned calls=draws;
    a=seed_a;b=seed_b;assert(gg_draw_rounded_parts_pixels(regions,2,32,32,1,&s));
    assert(draws==calls && a==expected_a && b==expected_b);
    a=seed_a;b=seed_b;regions[0].x++;
    assert(gg_draw_rounded_parts_pixels(regions,2,32,32,1,&s) && draws==calls+1);
    expected_a=a;expected_b=b;a=seed_a;b=seed_b;
    setenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE","1",1);
    assert(gg_draw_rounded_parts_pixels(regions,2,32,32,1,&s));assert(a==expected_a && b==expected_b);
    unsetenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE");
    // Same packed pixel count and backdrop, different view shape/location.
    std::vector<uint8_t> x(24*4,42),y(40*2,42);
    VoxGraphitePixelRegion first {1,2,4,4,24,x.data()},second {4,5,8,2,40,y.data()};
    assert(gg_draw_shape_region_pixels(&first,32,32,0,&s));calls=draws;
    assert(gg_draw_shape_region_pixels(&second,32,32,0,&s) && draws==calls+1);
    // A late failing member must leave every destination unchanged, even if
    // an earlier member came from the cache or rendered successfully.
    VoxGraphiteShape shapes[] {s,s};shapes[1].fill=99;a=seed_a;b=seed_b;
    assert(!gg_draw_shape_regions_pixels(regions,shapes,2,32,32,1));assert(a==seed_a && b==seed_b);
    a=seed_a;b=seed_b;
    assert(!gg_draw_shape_regions_pixels(regions,shapes,2,32,32,1));assert(a==seed_a && b==seed_b);
    first.x=-1;calls=draws;assert(!gg_draw_shape_region_pixels(&first,32,32,1,&s) && draws==calls);
    // Oversized direct and region views retain the uncached callback policy.
    std::vector<uint8_t> large(200*200*4,17);VoxGraphitePixelRegion big {0,0,200,200,800,large.data()};
    calls=draws;assert(gg_draw_shape_region_pixels(&big,256,256,1,&s));
    assert(gg_draw_shape_region_pixels(&big,256,256,1,&s) && draws==calls+2);
    calls=draws;assert(gg_draw_shape_pixels(large.data(),200,200,800,0,&s));
    assert(gg_draw_shape_pixels(large.data(),200,200,800,0,&s) && draws==calls+2);
}
static void gpu_tests(char const* path) {
    auto* library=dlopen(path,RTLD_NOW|RTLD_LOCAL);assert(library);
    backend=reinterpret_cast<VoxGGShapeDraw>(dlsym(library,"vox_graphite_draw_shape_pixels"));assert(backend);
    Dl_info info {};char actual[PATH_MAX],expected_path[PATH_MAX];
    assert(dladdr(reinterpret_cast<void*>(backend),&info));assert(realpath(info.dli_fname,actual));assert(realpath(path,expected_path));assert(!std::strcmp(actual,expected_path));
    ladybird_v_skia_set_gg_shape_draw(counted_backend);unsigned scenes=0;
    for(int bg:{0,1})for(int msaa:{0,1})for(int floating:{0,1})for(int fill:{0,1,2,6,7,8}) {
        auto s=shape();s.fill=fill;s.force_msaa=msaa;s.has_float_color=floating;
        s.float_color[0]=.21147f;s.float_color[1]=.40221f;s.float_color[2]=.70091f;s.float_color[3]=.6067f;
        s.has_underlay=fill==7;s.underlay_rect[0]=2;s.underlay_rect[1]=3;s.underlay_rect[2]=34;s.underlay_rect[3]=32;
        for(int c=4;c<12;++c)s.underlay_rect[c]=5;
        s.underlay_rgba[0]=190;s.underlay_rgba[1]=130;s.underlay_rgba[2]=70;s.underlay_rgba[3]=211;
        s.border_widths[0]=s.border_widths[2]=s.border_widths[3]=2.25f;
        std::vector<uint8_t> seed(208*48,99);
        for(int row=0;row<48;++row)for(int col=0;col<48;++col)seed[size_t(row)*208+col*4+3]=255;
        auto expected=seed;assert(backend(expected.data(),48,48,208,bg,&s));
        clear_gg_shape_raster_cache();auto pixels=seed;unsigned calls=draws;
        assert(gg_draw_shape_pixels(pixels.data(),48,48,208,bg,&s) && pixels==expected && draws==calls+1);
        pixels=seed;assert(gg_draw_shape_pixels(pixels.data(),48,48,208,bg,&s) && pixels==expected && draws==calls+1);
        // Real GPU regions exercise packed, padded rows and their full-surface
        // clip/sampling origin; disabled cache supplies the independent output.
        std::vector<uint8_t> a(80*5,99),b(40*6,99);auto original_a=a,original_b=b;
        VoxGraphitePixelRegion views[] {{2,4,16,5,80,a.data()},{26,20,8,6,40,b.data()}};
        setenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE","1",1);
        assert(gg_draw_rounded_parts_pixels(views,2,48,48,bg,&s));auto expected_a=a,expected_b=b;
        unsetenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE");clear_gg_shape_raster_cache();
        a=original_a;b=original_b;calls=draws;
        assert(gg_draw_rounded_parts_pixels(views,2,48,48,bg,&s) && a==expected_a && b==expected_b && draws==calls+1);
        a=original_a;b=original_b;
        assert(gg_draw_rounded_parts_pixels(views,2,48,48,bg,&s) && a==expected_a && b==expected_b && draws==calls+1);
        ++scenes;
    }
    ladybird_v_skia_set_gg_shape_draw(nullptr);dlclose(library);
    std::printf("%u real GPU shape/packed-region scenes: exact fresh/cached bytes and padding\n",scenes);
}
int main(int argc,char** argv) {
    unsetenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE");direct_tests();region_tests();
    if(argc==2)gpu_tests(argv[1]);
    std::puts("GG shape cache: full keys, layout identity, ownership, purge, backend replacement, failure transactions and bypass checks passed");
}
