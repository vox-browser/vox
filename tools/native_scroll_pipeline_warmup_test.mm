// Match the release archive's private container layouts while instrumenting
// this fixture and the included Vox code with ASan/UBSan.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#include "../native_graphite_darwin.mm"
#include "src/gpu/graphite/ContextPriv.h"
#include "src/gpu/graphite/GlobalCache.h"
#include <cassert>

static std::vector<uint8_t> draw_scrolling_mask() {
    int rects[] {0, 0, 64, 64, 0, 20, 64, 4};
    assert(vox_graphite_canvas_begin(rects, 1));
    std::vector<uint8_t> backdrop(64*64*4, 255), mask(128*128, 128);
    assert(vox_graphite_canvas_upload(0, backdrop.data(), 64*4));
    VoxGraphiteCanvasClip clip {};
    clip.matrix[0]=clip.matrix[4]=clip.matrix[8]=1;
    clip.rect[0]=2.25f; clip.rect[1]=2.25f; clip.rect[2]=60; clip.rect[3]=60;
    for (int i=4; i<12; ++i) clip.rect[i]=4;
    clip.antialias=1;
    float color[] {.25f,.5f,.75f,1};
    assert(vox_graphite_canvas_draw_mask(mask.data(), 128, 64, 128, 2, -16, -16, color, &clip, 1));
    VoxGraphitePixelRegion output {0, 0, 64, 64, 64*4, backdrop.data()};
    assert(vox_graphite_canvas_read(&output, 1));
    vox_graphite_canvas_end();
    return backdrop;
}

int main() { @autoreleasepool {
    // First retain a cold reference, using the same actual scroll-strip draw.
    setenv("VOX_DISABLE_SCROLL_PIPELINE_WARMUP","1",1);
    auto expected=draw_scrolling_mask();
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
    assert(pipelines>0 && pipelines<=48);
    canvas_prepare_scroll_pipelines(gpu);
    assert(additions==pipelines);
    auto actual=draw_scrolling_mask();
    assert(actual==expected);
    assert(additions==pipelines);
    gpu_context_last_use-=std::chrono::seconds(3);
    assert(vox_graphite_release_idle_graphics_memory()==1);
    assert(gpu_context.get()==gpu && gpu_context_idle);
    assert(!canvas_recorder && canvas_tiles.empty() && canvas_surface_pool.empty());
    assert(!region_recorder && region_targets.empty() && !full_draw_recorder);
    assert(vox_graphite_release_idle_graphics_memory()==0);
    assert(draw_scrolling_mask()==expected);
    assert(additions==pipelines && !gpu_context_idle);
    assert(vox_graphite_retire_graphics_context()==1);
    assert(!gpu_context && !gpu_frame_queue);
    std::puts("Scroll mask: exact pixels; no first-use compilation; idle raster release, pipeline reuse and full retirement passed");
} }
