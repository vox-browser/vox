// Match the release archive's private container layouts while instrumenting
// this fixture and the included Vox code with ASan/UBSan.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#include "../native_graphite_darwin.mm"
#include "src/gpu/graphite/ContextPriv.h"
#include "src/gpu/graphite/GlobalCache.h"
#include <cassert>

static std::vector<uint8_t> draw_scrolling_mask(float alpha = 1) {
    int rects[] {0, 0, 64, 64, 0, 20, 64, 4};
    assert(vox_graphite_canvas_begin(rects, 1));
    std::vector<uint8_t> backdrop(64*64*4, 255), mask(128*128, 128);
    assert(vox_graphite_canvas_upload(0, backdrop.data(), 64*4));
    VoxGraphiteCanvasClip clip {};
    clip.matrix[0]=clip.matrix[4]=clip.matrix[8]=1;
    clip.rect[0]=2.25f; clip.rect[1]=2.25f; clip.rect[2]=60; clip.rect[3]=60;
    for (int i=4; i<12; ++i) clip.rect[i]=4;
    clip.antialias=1;
    float color[] {.25f,.5f,.75f,alpha};
    assert(vox_graphite_canvas_draw_mask(mask.data(), 128, 64, 128, 2, -16, -16, color, &clip, 1));
    VoxGraphitePixelRegion output {0, 0, 64, 64, 64*4, backdrop.data()};
    assert(vox_graphite_canvas_read(&output, 1));
    vox_graphite_canvas_end();
    return backdrop;
}


// Translucent layer images use a color-image/paint-alpha shader, unlike the
// alpha-only glyph mask above. A covering rounded clip selects its cover pass.
static std::vector<uint8_t> draw_scrolling_opacity_layer(bool msaa = false) {
    int rects[] {0, 0, 64, 64, 0, 20, 64, 4};
    assert(vox_graphite_canvas_begin(rects, 1));
    std::vector<uint8_t> backdrop(64*64*4, 255), pixels(128*128*4, 128);
    assert(vox_graphite_canvas_upload(0, backdrop.data(), 64*4));
    VoxGraphiteCanvasClip clip {};
    clip.matrix[0]=clip.matrix[4]=clip.matrix[8]=1;
    clip.rect[0]=2.25f; clip.rect[1]=2.25f; clip.rect[2]=60; clip.rect[3]=60;
    for (int i=4; i<12; ++i) clip.rect[i]=4;
    clip.antialias=1;
    if (msaa) {
        // SVG strokes make an uploaded scroll tile switch to an MSAA load
        // pass; its following opacity image then needs another pipeline key.
        float segments[24] {0,4,12,0,0,0,0,0,0,0,0,0,
            3,60,44,12,60,56,0,0,0,0,0,0};
        VoxGraphitePath path {};
        path.matrix[0]=path.matrix[4]=path.matrix[8]=1;
        path.segments=segments;path.segment_count=2;path.stroke=1;
        path.stroke_width=1.25f;path.miter_limit=4;
        path.red=35;path.green=90;path.blue=170;path.alpha=255;
        float bounds[] {0,0,64,64};
        assert(vox_graphite_canvas_draw_path(&path,bounds,&clip,1));
    }
    assert(vox_graphite_canvas_draw_layer_pixels(pixels.data(), 128, 128, 128*4,
        -16, -16, &clip, 1, .4f, 0));
    VoxGraphitePixelRegion output {0, 0, 64, 64, 64*4, backdrop.data()};
    assert(vox_graphite_canvas_read(&output, 1));
    vox_graphite_canvas_end();
    return backdrop;
}

int main() { @autoreleasepool {
    // First retain a cold reference, using the same actual scroll-strip draw.
    setenv("VOX_DISABLE_SCROLL_PIPELINE_WARMUP","1",1);
    auto expected=draw_scrolling_mask();
    auto alpha_expected=draw_scrolling_mask(232.f/255);
    auto opacity_expected=draw_scrolling_opacity_layer();
    auto msaa_expected=draw_scrolling_opacity_layer(true);
    assert(vox_graphite_retire_graphics_context());
    unsetenv("VOX_DISABLE_SCROLL_PIPELINE_WARMUP");
    auto* gpu=context(); assert(gpu);
    unsigned additions=0;
    auto* cache=gpu->priv().sharedContext()->globalCache();
    cache->setPipelineCallback(&additions, [](void* value,
        skgpu::graphite::ContextOptions::PipelineCacheOp operation, std::string const&, uint32_t, bool, sk_sp<SkData>) {
        if (operation==skgpu::graphite::ContextOptions::PipelineCacheOp::kAddingPipeline)
            ++*static_cast<unsigned*>(value);
    }, nullptr);
    canvas_prepare_scroll_pipelines(gpu);
    unsigned pipelines=additions;
    std::fprintf(stderr, "Prepared scroll pipelines: %u\n", pipelines);
    assert(pipelines>0 && pipelines<=160);
    canvas_prepare_scroll_pipelines(gpu);
    assert(additions==pipelines);
    auto actual=draw_scrolling_mask();
    assert(actual==expected);
    assert(draw_scrolling_mask(232.f/255)==alpha_expected);
    assert(draw_scrolling_opacity_layer()==opacity_expected);
    assert(draw_scrolling_opacity_layer(true)==msaa_expected);
    assert(additions==pipelines);
    gpu_context_last_use-=std::chrono::seconds(3);
    assert(vox_graphite_release_idle_graphics_memory()==1);
    assert(gpu_context.get()==gpu && gpu_context_idle);
    assert(!canvas_recorder && canvas_tiles.empty() && canvas_surface_pool.empty());
    assert(!region_recorder && region_targets.empty() && !full_draw_recorder);
    assert(vox_graphite_release_idle_graphics_memory()==0);
    assert(draw_scrolling_mask()==expected);
    assert(draw_scrolling_mask(232.f/255)==alpha_expected);
    assert(additions==pipelines && !gpu_context_idle);
    assert(draw_scrolling_opacity_layer()==opacity_expected);
    assert(draw_scrolling_opacity_layer(true)==msaa_expected);
    assert(additions==pipelines);
    assert(vox_graphite_retire_graphics_context()==1);
    assert(!gpu_context && !gpu_frame_queue);
    // Full retirement discards the cache; a replacement context must prepare
    // its own variants even if the allocator reuses the old context address.
    gpu=context(); assert(gpu && !gpu_scroll_pipelines_prepared);
    additions=0;
    gpu->priv().sharedContext()->globalCache()->setPipelineCallback(&additions, [](void* value,
        skgpu::graphite::ContextOptions::PipelineCacheOp operation, std::string const&, uint32_t, bool, sk_sp<SkData>) {
        if (operation==skgpu::graphite::ContextOptions::PipelineCacheOp::kAddingPipeline)
            ++*static_cast<unsigned*>(value);
    }, nullptr);
    canvas_prepare_scroll_pipelines(gpu);
    assert(additions==pipelines && gpu_scroll_pipelines_prepared);
    assert(draw_scrolling_opacity_layer()==opacity_expected);
    assert(draw_scrolling_opacity_layer(true)==msaa_expected);
    assert(draw_scrolling_mask()==expected && additions==pipelines);
    assert(draw_scrolling_mask(232.f/255)==alpha_expected && additions==pipelines);
    assert(vox_graphite_retire_graphics_context()==1);
    std::printf("Scroll mask/opacity: exact pixels; %u prepared pipelines, no first-use compilation; idle reuse and context replacement passed\n", pipelines);
} }
