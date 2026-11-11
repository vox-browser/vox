#define VOX_TEST_DEFERRED_LAYERS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

struct ContourResult { std::vector<uint8_t> pixels; unsigned deferred; bool completed; };
// 1: ordinary deferred frame; 2: a frame stored for scroll reuse, where only
// compositor-layer pictures may supply deferred leaves.
static int s_test_frame_mode=1;
static bool s_test_speculative_group=false;
static ContourResult scene(int scale, float scroll, int mode, bool enabled,
    bool registered=true, bool fractional=false, bool blocked=false,
    bool fail=false, bool root=false, bool edge=false, float extra_scroll=0)
{
    constexpr int w=320,h=240;
    int width=w*scale,height=h*scale,pitch=width*4+16;
    std::vector<uint8_t> pixels(size_t(pitch)*height,0xa5);
    for(int y=0;y<height;++y)std::memset(pixels.data()+size_t(y)*pitch,0,size_t(width)*4);
    auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context=CGBitmapContextCreate(pixels.data(),width,height,8,pitch,space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);assert(context);CGContextScaleCTM(context,scale,scale);
    if(fractional)CGContextClipToRect(context,CGRectMake(5.25,7.25,300,220));
    ladybird_v_skia_begin_deferred_layer_frame(s_test_frame_mode);
    if(registered)ladybird_v_skia_set_deferred_layer_destination(context,1);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(root,w,h);
    ladybird_v_skia_set_root_raster_scroll_y(scroll);
    ladybird_v_skia_set_raster_layer(24,30,root);
    ladybird_v_skia_set_raster_layer_size(240,400);
    int tile=0;ladybird_v_skia_set_msaa_grid(&tile,1,242*scale,256,1);
    ladybird_v_skia_set_layer_shared_recording(1);
    s_speculative_layer_enabled=s_test_speculative_group;
    if(blocked){assert(shared_recording_canvas(context));ladybird_v_skia_block_shared_recording(context);}
    float target[]{edge?24.f:64.f,96,140,40,14,14,14,14,14,14,14,14};
    float affine[]{1,0,0,1,0,-scroll},shape[]{1.1f,1.1f,1.1f,1.1f};
    if(mode==1)ladybird_v_skia_set_rounded_rect_underlay(target,255,255,255,255);
    if(enabled)unsetenv("VOX_DISABLE_CONTOURED_LEAF_DEFER");
    else setenv("VOX_DISABLE_CONTOURED_LEAF_DEFER","1",1);
    assert(ladybird_v_skia_draw_contoured_box(context,target,shape,mode==2?target:nullptr,
        affine,0,0,extra_scroll,w,h,23,81,143,173,mode,mode==1?2:mode==2?6:0,0));
    assert(!s_has_rounded_rect_underlay && !s_has_contoured_box_reference);
    auto* group=s_shared_root_recording.get();assert(group);
    unsigned omitted=group->deferred_leaves;
    bool eligible=enabled&&registered&&!fractional&&!blocked&&!root&&!edge
        &&!(s_test_frame_mode==2&&s_test_speculative_group);
    assert((omitted!=0)==eligible);
    s_test_fail_deferred_layer=fail;
    ladybird_v_skia_finish_shared_recording();s_test_fail_deferred_layer=false;
    bool completed=ladybird_v_skia_finish_deferred_layer_frame();
    assert(completed==!(omitted&&fail));assert(!s_shared_root_recording);
    CGContextFlush(context);CGContextRelease(context);
    s_speculative_layer_enabled=false;
    ladybird_v_skia_set_msaa_grid(nullptr,0,0,0,0);
    ladybird_v_skia_set_shared_recording(0,0,0);
    for(int y=0;y<height;++y)for(int x=width*4;x<pitch;++x)assert(pixels[size_t(y)*pitch+x]==0xa5);
    return {std::move(pixels),omitted,completed};
}
int main()
{
    unsetenv("VOX_DISABLE_DEFERRED_LAYERS");unsigned cases=0;
    for(int scale:{1,2})for(float scroll:{0.f,17.5f,66.25f})for(int mode:{0,1,2}){
        auto control=scene(scale,scroll,mode,false);
        assert(control.pixels==scene(scale,scroll,mode,true).pixels);++cases;
        for(int guard=0;guard<5;++guard){
            bool registered=guard!=0,fractional=guard==1,blocked=guard==2,root=guard==3,edge=guard==4;
            auto before=scene(scale,scroll,mode,false,registered,fractional,blocked,false,root,edge);
            auto after=scene(scale,scroll,mode,true,registered,fractional,blocked,false,root,edge);
            assert(before.pixels==after.pixels && !after.deferred);++cases;
        }
        auto failed=scene(scale,scroll,mode,true,true,false,false,true);
        assert(failed.deferred && !failed.completed);++cases;
        auto retry=scene(scale,scroll,mode,false);
        assert(control.pixels==retry.pixels && retry.completed && !retry.deferred);++cases;
        // Additional bridge scrolling is separate from the root scroll
        // already encoded in the display-list matrix.
        auto explicit_control=scene(scale,scroll,mode,false,true,false,false,false,false,false,5.25f);
        auto explicit_candidate=scene(scale,scroll,mode,true,true,false,false,false,false,false,5.25f);
        assert(explicit_control.pixels==explicit_candidate.pixels && explicit_candidate.deferred);++cases;
    }
    // Mode 2 defers leaves into compositor-layer pictures exactly like mode 1,
    // but never into speculative pictures, which publish after the frame's
    // scroll-reuse pixels are stored, nor into deferred gradient-text inputs.
    s_test_frame_mode=2;
    for(int scale:{1,2})for(int mode:{0,1,2}){
        auto control=scene(scale,17.5f,mode,false);
        auto layered=scene(scale,17.5f,mode,true);
        assert(control.pixels==layered.pixels && layered.deferred && layered.completed);++cases;
        auto failed=scene(scale,17.5f,mode,true,true,false,false,true);
        assert(failed.deferred && !failed.completed);++cases;
        s_test_speculative_group=true;
        auto speculative_control=scene(scale,17.5f,mode,false);
        auto speculative=scene(scale,17.5f,mode,true);
        s_test_speculative_group=false;
        assert(speculative_control.pixels==speculative.pixels && !speculative.deferred);++cases;
    }
    setenv("VOX_DEFER_GRADIENT_TEXT_INPUTS","1",1);
    s_gradient_text_deferral_abandoned=false;
    ladybird_v_skia_begin_deferred_layer_frame(2);
    assert(begin_deferred_gradient_text_input()==0);
    assert(ladybird_v_skia_finish_deferred_layer_frame());
    ladybird_v_skia_begin_deferred_layer_frame(1);
    uint64_t epoch=begin_deferred_gradient_text_input();
    assert(epoch!=0);finish_deferred_gradient_text_input(epoch,true);
    assert(ladybird_v_skia_finish_deferred_layer_frame());
    unsetenv("VOX_DEFER_GRADIENT_TEXT_INPUTS");++cases;
    s_test_frame_mode=1;
    unsetenv("VOX_DISABLE_CONTOURED_LEAF_DEFER");
    std::printf("Contoured deferred raster: %u exact scenes, clip/capability/bounds guards and failure/retry checks passed\n",cases);
}
