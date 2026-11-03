// Static Metal meshes must become GPU-readable without a GPU transfer pass.
#include "../native_graphite_darwin.mm"
#include <mach/mach.h>
#include <cassert>

static int64_t graphics_bytes() {
    task_vm_info_data_t info{};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO,
        reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS);
    return info.ledger_tag_graphics_footprint;
}

int main() { @autoreleasepool {
    auto* gpu = context();
    assert(gpu);
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(1728, 480, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    assert(surface);
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(0xffd4e5ff);
    canvas->drawRoundRect(SkRect::MakeXYWH(20, 20, 120, 26), 3, 3, paint);
    int64_t before = graphics_bytes();
    auto recording = recorder->snap();
    assert(recording);
    // Driver allocation may finish asynchronously after encoder creation.
    usleep(50000);
    int64_t growth = graphics_bytes() - before;
    std::printf("Static mesh upload graphics growth: %lld bytes\n", (long long)growth);
    assert(growth < 8 * 1024 * 1024);
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    assert(gpu->insertRecording(insertion) == skgpu::graphite::InsertStatus::kSuccess);
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    gpu->asyncRescaleAndReadPixels(surface.get(), info.makeWH(120, 26),
        SkIRect::MakeXYWH(20, 20, 120, 26), SkImage::RescaleGamma::kSrc,
        SkImage::RescaleMode::kNearest,
        [](void* owner, std::unique_ptr<const SkImage::AsyncReadResult> pixels) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(owner) = std::move(pixels);
        }, &result);
    assert(gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)));
    assert(result && result->count() == 1 && result->rowBytes(0) >= 120 * 4);
    uint64_t hash = 1469598103934665603ull;
    for (int y = 0; y < 26; ++y) for (int x = 0; x < 120 * 4; ++x) {
        hash ^= static_cast<const uint8_t*>(result->data(0))[y * result->rowBytes(0) + x];
        hash *= 1099511628211ull;
    }
    assert(hash == 13950444575854455419ull);
    std::printf("Static vertex/index replay is byte-exact\n");
} }
