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

static std::unique_ptr<const SkImage::AsyncReadResult> read_shared(
    skgpu::graphite::Context* gpu, skgpu::graphite::Recorder* recorder, SkSurface* surface,
    SkImageInfo info, SkIRect rect, SkImage::RescaleMode mode = SkImage::RescaleMode::kNearest) {
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    assert(gpu->insertRecording(insertion) == skgpu::graphite::InsertStatus::kSuccess);
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface, info, rect, SkImage::RescaleGamma::kSrc, mode,
        [](void* owner, std::unique_ptr<const SkImage::AsyncReadResult> pixels) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(owner) = std::move(pixels);
        }, &result);
    assert(gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)));
    assert(result && result->count() == 1);
    return result;
}

int main() { @autoreleasepool {
    auto* gpu = context();
    assert(gpu);
    auto recorder = gpu->makeRecorder();
    assert(vox_shared_metal_device(recorder.get()));
    auto info = SkImageInfo::Make(16, 12, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    assert(surface && vox_shared_metal_texture(surface.get()));
    int64_t before = graphics_bytes();
    // A pending GPU clear must finish before a partial CPU backdrop replaces it.
    surface->getCanvas()->clear(SK_ColorBLUE);
    uint32_t backdrop[6] = {0xff20a040, 0xff20a040, 0xdeadbeef,
                           0xff20a040, 0xff20a040, 0xdeadbeef};
    vox_shared_write(gpu, surface, SkPixmap(info.makeWH(2, 2), backdrop, 12), 2, 3);
    // The source and its descriptor die before the GPU consumes the upload.
    uint32_t red[4] = {0xffff0000, 0xffff0000, 0xffff0000, 0xffff0000};
    auto raster = SkImages::RasterFromPixmapCopy(SkPixmap(info.makeWH(2, 2), red, 8));
    auto image = vox_shared_image(recorder.get(), raster, {});
    assert(image);
    raster.reset();
    surface->getCanvas()->drawImage(image, 7, 5);
    auto first = read_shared(gpu, recorder.get(), surface.get(), info, SkIRect::MakeWH(16, 12));
    auto pixel = [&](int x, int y) {
        return reinterpret_cast<uint32_t const*>(static_cast<uint8_t const*>(first->data(0))
            + y * first->rowBytes(0))[x];
    };
    assert(pixel(0, 0) == 0xff0000ff && pixel(2, 3) == 0xff20a040);
    assert(pixel(3, 4) == 0xff20a040 && pixel(4, 4) == 0xff0000ff);
    assert(pixel(7, 5) == 0xffff0000 && pixel(8, 6) == 0xffff0000);
    usleep(50000);
    int64_t growth = graphics_bytes() - before;
    std::printf("Shared upload/render/readback graphics growth: %lld bytes\n", (long long)growth);
    assert(growth < 230 * 1024 * 1024); // Render engine, without a second transfer engine.

    auto nearest = SkImage::RescaleMode::kNearest;
    auto src = SkImage::RescaleGamma::kSrc;
    assert(vox_shared_read_compatible(surface.get(), info.makeWH(2, 2),
        SkIRect::MakeXYWH(2, 3, 2, 2), src, nearest));
    assert(!vox_shared_read_compatible(surface.get(), info.makeWH(2, 2),
        SkIRect::MakeXYWH(-1, 0, 2, 2), src, nearest));
    assert(!vox_shared_read_compatible(surface.get(), info.makeWH(2, 2),
        SkIRect::MakeXYWH(15, 11, 2, 2), src, nearest));
    assert(!vox_shared_read_compatible(surface.get(), info.makeColorType(kRGBA_8888_SkColorType),
        SkIRect::MakeWH(16, 12), src, nearest));
    assert(!vox_shared_read_compatible(surface.get(), info.makeAlphaType(kUnpremul_SkAlphaType),
        SkIRect::MakeWH(16, 12), src, nearest));
    assert(!vox_shared_read_compatible(surface.get(), info.makeColorSpace(SkColorSpace::MakeSRGBLinear()),
        SkIRect::MakeWH(16, 12), src, nearest));
    assert(!vox_shared_read_compatible(surface.get(), info, SkIRect::MakeWH(16, 12),
        SkImage::RescaleGamma::kLinear, nearest));

    // Target reuse must not mutate an already delivered result. An RGBA read
    // exercises the conversion fallback rather than returning unconverted bytes.
    surface->getCanvas()->clear(SK_ColorGREEN);
    auto second = read_shared(gpu, recorder.get(), surface.get(),
        info.makeWH(2, 2).makeColorType(kRGBA_8888_SkColorType), SkIRect::MakeXYWH(2, 3, 2, 2));
    auto* converted = static_cast<uint8_t const*>(second->data(0));
    assert(converted[0] == 0 && converted[1] == 255 && converted[2] == 0 && converted[3] == 255);
    // Scaling also stays on Skia's existing path.
    surface->getCanvas()->clear(SK_ColorRED);
    auto scaled = read_shared(gpu, recorder.get(), surface.get(), info.makeWH(1, 1),
        SkIRect::MakeWH(16, 12), SkImage::RescaleMode::kRepeatedLinear);
    assert(*static_cast<uint32_t const*>(scaled->data(0)) == 0xffff0000);
    image.reset(); surface.reset(); recorder.reset(); gpu_context.reset();
    assert(pixel(2, 3) == 0xff20a040 && pixel(7, 5) == 0xffff0000);
    std::puts("Partial writes, image ownership, region bounds, conversion, scaling and result lifetimes pass");
} }
