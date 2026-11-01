#define VOX_TEST_DEFERRED_LAYERS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

struct Result {std::vector<uint8_t> pixels; unsigned deferred; bool completed;};
static Result render(int scale, float scroll, bool fractional_clip, bool enabled,
    bool registered = true, bool fail = false, bool unsupported = false)
{
    constexpr int w = 320, h = 240, layer_x = 24, layer_y = 30;
    int width=w*scale, height=h*scale, pitch=width*4+16;
    std::vector<uint8_t> pixels(size_t(pitch)*height,0xa5);
    for(int y=0;y<height;++y) for(int x=0;x<width*4;++x) pixels[size_t(y)*pitch+x]=0;
    auto color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context=CGBitmapContextCreate(pixels.data(),width,height,8,pitch,color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);assert(context);CGContextScaleCTM(context,scale,scale);
    if(fractional_clip) CGContextClipToRect(context,CGRectMake(5.25,7.25,300,220));
    ladybird_v_skia_begin_deferred_layer_frame(enabled);
    if(registered) ladybird_v_skia_set_deferred_layer_destination(context,1);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0,w,h);
    ladybird_v_skia_set_root_raster_scroll_y(scroll);
    ladybird_v_skia_set_raster_layer(layer_x,layer_y,0);
    ladybird_v_skia_set_raster_layer_size(240,400);
    int cell=0;ladybird_v_skia_set_msaa_grid(&cell,1,242*scale,256,1);
    ladybird_v_skia_set_layer_shared_recording(1);
    // The shadow supplies the same complete-picture metadata as native replay.
    assert(ladybird_v_skia_draw_outer_box_shadow(context,
        36,60,162,102, 9,9,9,9,9,9,9,9,
        40,64,154,94, 9,9,9,9,9,9,9,9,
        1,0,0,1,0,-scroll,0,0,0,w,h,12,31,67,103,173,0));
    assert(ladybird_v_skia_draw_rounded_rect(context,
        40,64,154,94,9,9,9,9,9,9,9,9,
        1,0,0,1,0,-scroll,0,0,0,w,h,37,117,193,210,1,0,1,0));
    auto* group=s_shared_root_recording.get();assert(group);
    unsigned omitted=group->deferred_leaves;
    if(enabled && registered && !fractional_clip) assert(omitted>0);
    else assert(!omitted);
    if(unsupported) ladybird_v_skia_block_shared_recording(context);
    s_test_fail_deferred_layer=fail;
    ladybird_v_skia_finish_shared_recording();
    s_test_fail_deferred_layer=false;
    bool completed=ladybird_v_skia_finish_deferred_layer_frame();
    assert(completed==!(omitted&&(fail||unsupported)));
    assert(!s_shared_root_recording);
    CGContextFlush(context);CGContextRelease(context);
    ladybird_v_skia_set_msaa_grid(nullptr,0,0,0,0);
    for(int y=0;y<height;++y) for(int x=width*4;x<pitch;++x) assert(pixels[size_t(y)*pitch+x]==0xa5);
    return {std::move(pixels),omitted,completed};
}
int main()
{
    unsetenv("VOX_DISABLE_DEFERRED_LAYERS");unsigned cases=0;
    for(int scale:{1,2}) for(float scroll:{0.f,17.5f,66.25f})
    for(bool clip:{false,true}) {
        auto control=render(scale,scroll,clip,false);
        auto candidate=render(scale,scroll,clip,true);
        assert(control.pixels==candidate.pixels);++cases;
        assert(control.pixels==render(scale,scroll,clip,true,false).pixels);++cases;
    }
    for(int scale:{1,2}) for(bool fail:{false,true}) {
        auto result=render(scale,0,false,true,true,fail,!fail);
        assert(!result.completed && result.deferred);++cases;
        // A fresh ordinary replay remains available after the failed frame.
        auto retry=render(scale,0,false,false);
        assert(retry.completed && !retry.deferred);++cases;
    }
    std::cout<<cases<<" deferred-layer scenes preserve pixels, capability/clip guards and failure signaling\n";
}
