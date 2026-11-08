// Preserve the release Skia archive's private container layouts under ASan.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#include "../native_graphite_darwin.mm"
#include <cassert>

static std::vector<uint8_t> render_readback_layout(int width, int height,
    bool optimized, bool msaa)
{ @autoreleasepool {
    if (optimized) setenv("VOX_GPU_OPTIMIZED_READBACK_TEXTURES", "1", 1);
    else unsetenv("VOX_GPU_OPTIMIZED_READBACK_TEXTURES");
    auto* gpu = context(); assert(gpu);
    auto recorder = gpu->makeRecorder(); assert(recorder);
    auto info = canvas_info(width, height);
    auto surface = vox_shared_surface(recorder.get(), info); assert(surface);
    auto texture = vox_shared_metal_texture(surface.get());
    assert(texture && bool(texture.allowGPUOptimizedContents) == optimized);
    int pitch = (width + 3) * 4;
    std::vector<uint8_t> backdrop(size_t(pitch) * height, 0xa5);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* pixel = backdrop.data() + size_t(y) * pitch + x * 4;
        pixel[0] = uint8_t(x % 79); pixel[1] = uint8_t(y % 83);
        pixel[2] = uint8_t((x + y) % 97); pixel[3] = 191;
    }
    surface->getCanvas()->clear(SK_ColorBLUE);
    vox_shared_write(gpu, surface, SkPixmap(info, backdrop.data(), pitch), 0, 0);
    auto* canvas = surface->getCanvas();
    if (msaa) force_msaa_render_pass(canvas, width, height);
    canvas->save();
    canvas->clipRRect(SkRRect::MakeRectXY(SkRect::MakeLTRB(1.25f, 2.5f,
        width - 1.5f, height - 2.25f), 5, 7), SkClipOp::kIntersect, true);
    SkPaint paint; paint.setAntiAlias(true); paint.setColor(0x9070a030);
    canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeLTRB(.375f, .25f,
        width - 3.75f, height - 2.5f), 7, 9), paint);
    paint.setStyle(SkPaint::kStroke_Style); paint.setStrokeWidth(1.25f);
    paint.setColor(0xff20a0c0);
    SkPathBuilder curve;
    curve.moveTo(2, 6).cubicTo(width / 4.f, height - 2.f,
        width - 3.f, 0, width - 2.f, height / 2.f);
    canvas->drawPath(curve.detach(), paint);
    canvas->restore();
    auto recording = recorder->snap(); assert(recording);
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    assert(gpu->insertRecording(insertion) == skgpu::graphite::InsertStatus::kSuccess);
    // Read a view after pending writers; leave the destination padding intact.
    auto rect = SkIRect::MakeXYWH(1, 2, width - 3, height - 4);
    auto view = info.makeDimensions(rect.size());
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface.get(), view, rect, SkImage::RescaleGamma::kSrc,
        SkImage::RescaleMode::kNearest,
        [](void* owner, std::unique_ptr<const SkImage::AsyncReadResult> pixels) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(owner) = std::move(pixels);
        }, &result);
    assert(result);
    std::vector<uint8_t> pixels(size_t(pitch) * rect.height(), 0xa5);
    for (int row = 0; row < rect.height(); ++row)
        std::memcpy(pixels.data() + size_t(row) * pitch,
            static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0),
            size_t(rect.width()) * 4);
    canvas->clear(SK_ColorRED);
    uint32_t red = 0xffff0000;
    vox_shared_write(gpu, surface, SkPixmap(info.makeWH(1, 1), &red, 4), 0, 0);
    for (int row = 0; row < rect.height(); ++row) {
        assert(!std::memcmp(pixels.data() + size_t(row) * pitch,
            static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0),
            size_t(rect.width()) * 4));
        for (int byte = rect.width() * 4; byte < pitch; ++byte)
            assert(pixels[size_t(row) * pitch + byte] == 0xa5);
    }
    return pixels;
} }

int main() { @autoreleasepool {
    unsigned cases = 0;
    for (auto size : {SkISize::Make(37, 29), SkISize::Make(515, 259),
            SkISize::Make(1400, 900)}) for (bool msaa : {false, true}) {
        auto expected = render_readback_layout(size.width(), size.height(), true, msaa);
        auto actual = render_readback_layout(size.width(), size.height(), false, msaa);
        assert(actual == expected); ++cases;
    }
    assert(vox_graphite_retire_graphics_context());
    auto replacement = render_readback_layout(37, 29, false, true);
    assert(replacement == render_readback_layout(37, 29, true, true)); ++cases;
    unsetenv("VOX_GPU_OPTIMIZED_READBACK_TEXTURES");
    assert(vox_graphite_retire_graphics_context());
    std::printf("CPU readback layout: %u exact cases, clipped AA/MSAA, padded partial views, pending writers and context replacement passed\n", cases);
} }
