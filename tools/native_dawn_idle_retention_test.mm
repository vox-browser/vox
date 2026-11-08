// Match the release Skia containers while checking this bridge with ASan.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#include "../native_graphite_dawn_darwin.mm"
#include "include/core/SkPictureRecorder.h"
#include <cassert>
#include <thread>

static std::vector<uint8_t> picture_pixels() {
    SkPictureRecorder recorder;
    auto* canvas=recorder.beginRecording(SkRect::MakeWH(128,96));
    SkPaint paint;paint.setAntiAlias(true);paint.setColor(0xc34b85d7);
    canvas->drawRoundRect(SkRect::MakeXYWH(3.25f,7.5f,119,81),13.5f,8.25f,paint);
    auto data=recorder.finishRecordingAsPicture()->serialize();assert(data);
    std::vector<uint8_t> pixels(128*96*4,0);
    float identity[]{1,0,0,0,1,0,0,0,1};
    assert(vox_graphite_draw_picture_region_pixels(pixels.data(),128,96,128*4,
        0,0,128,96,data->data(),data->size(),identity));
    return pixels;
}

int main() { @autoreleasepool {
    setenv("VOX_REUSE_DAWN_REGION_RECORDER","1",1);
    setenv("VOX_REUSE_DAWN_REGION_TARGET","1",1);
    unsetenv("VOX_DISABLE_IDLE_DAWN_RETENTION");
    auto expected=picture_pixels();
    auto* owner=gpu_context.get();assert(owner && regional_recorder && regional_surface);
    assert(vox_graphite_picture_release_idle_graphics_memory()==-1);
    std::thread worker([] {assert(vox_graphite_picture_release_idle_graphics_memory()==0);});
    worker.join();assert(gpu_context.get()==owner);
    gpu_context_last_use-=std::chrono::seconds(3);
    assert(vox_graphite_picture_release_idle_graphics_memory()==1);
    assert(gpu_context.get()==owner && gpu_context_idle);
    assert(!regional_surface && !regional_recorder);
    assert(owner->currentPurgeableBytes()==0);
    assert(vox_graphite_picture_release_idle_graphics_memory()==0);
    assert(picture_pixels()==expected);
    assert(gpu_context.get()==owner && !gpu_context_idle);
    assert(vox_graphite_picture_retire_graphics_context()==1);
    assert(!gpu_context && !gpu_context_attempted && !gpu_context_idle);
    assert(vox_graphite_picture_retire_graphics_context()==0);
    // Preserve a controlled comparison with the previous retirement policy.
    setenv("VOX_DISABLE_IDLE_DAWN_RETENTION","1",1);
    assert(picture_pixels()==expected);
    gpu_context_last_use-=std::chrono::seconds(3);
    assert(vox_graphite_picture_release_idle_graphics_memory()==1);
    assert(!gpu_context);
    std::puts("Dawn idle: device retained; raster resources purged; exact resumed pixels; worker ownership, legacy policy and full retirement passed");
} }
