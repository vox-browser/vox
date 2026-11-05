// The linked Skia archive has release TArray layouts. ASan adds an extra
// TArray field when this macro is set, breaking private Graphite offsets.
// Keep those layouts compatible while Clang still instruments this entire
// fixture and the included Vox implementation with ASan/UBSan.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#include "../native_graphite_darwin.mm"
#include <cassert>

static std::vector<uint8_t> read_surface(skgpu::graphite::Context* gpu,
    skgpu::graphite::Recorder* recorder, SkSurface* surface) {
    auto recording = recorder->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        assert(gpu->insertRecording(insertion) == skgpu::graphite::InsertStatus::kSuccess);
    }
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface, surface->imageInfo(),
        SkIRect::MakeWH(surface->width(), surface->height()), SkImage::RescaleGamma::kSrc,
        SkImage::RescaleMode::kNearest,
        [](void* owner, std::unique_ptr<const SkImage::AsyncReadResult> pixels) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(owner) = std::move(pixels);
        }, &result);
    assert(result);
    std::vector<uint8_t> output(size_t(surface->width()) * surface->height() * 4);
    for (int y = 0; y < surface->height(); ++y)
        std::memcpy(output.data() + size_t(y) * surface->width() * 4,
            static_cast<uint8_t const*>(result->data(0)) + size_t(y) * result->rowBytes(0),
            size_t(surface->width()) * 4);
    return output;
}

int main() { @autoreleasepool {
    auto* gpu = context(); assert(gpu);
    auto recorder = gpu->makeRecorder(); assert(recorder);
    for (auto [width, height] : {std::pair{37, 29}, {1024, 512}, {3421, 1906}}) {
        auto info = canvas_info(width, height);
        auto reference = vox_shared_surface(recorder.get(), info);
        auto linear = vox_shared_surface(recorder.get(), info, true);
        assert(reference && linear);
        assert(!vox_shared_metal_texture(reference.get()).buffer);
        auto texture = vox_shared_metal_texture(linear.get());
        assert(texture && texture.buffer && texture.bufferBytesPerRow >= size_t(width) * 4);
        std::vector<uint32_t> backdrop(9 * 5, 0x80306020);
        for (auto* surface : {reference.get(), linear.get()}) {
            surface->getCanvas()->clear(SK_ColorBLUE);
            // Pending GPU writers finish before a padded partial CPU upload.
            vox_shared_write(gpu, surface, SkPixmap(info.makeWH(7, 5), backdrop.data(), 9 * 4), 2, 3);
            auto* canvas = surface->getCanvas();
            SkPaint paint; paint.setAntiAlias(true); paint.setColor(0x9050d030);
            canvas->drawRoundRect(SkRect::MakeXYWH(.25f, .5f, width - 2.75f, height - 3.5f), 5, 7, paint);
            canvas->save();
            canvas->clipRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(5.5f, 6.25f, 20, 16), 3, 4), true);
            paint.setColor(0x70ff2080); canvas->drawCircle(15.25f, 13.5f, 12.75f, paint);
            canvas->restore();
        }
        auto expected = read_surface(gpu, recorder.get(), reference.get());
        auto actual = read_surface(gpu, recorder.get(), linear.get());
        assert(expected == actual);
        linear->getCanvas()->clear(SK_ColorGREEN);
        auto reused = read_surface(gpu, recorder.get(), linear.get());
        assert(actual == expected && reused != expected);
    }
    setenv("VOX_GPU_CANVAS_LINEAR_TEXTURES", "1", 1);
    int rects[] {3, 7, 37, 29, 3, 7, 37, 29, 48, 1, 19, 13, 48, 1, 19, 13};
    assert(vox_graphite_canvas_begin(rects, 2));
    for (size_t index = 0; index < canvas_tiles.size(); ++index) {
        auto const& tile = canvas_tiles[index];
        assert(vox_shared_metal_texture(tile.surface.get()).buffer);
        std::vector<uint32_t> pixels(size_t(tile.width + 3) * tile.height, 0xff20a040 + index);
        assert(vox_graphite_canvas_upload(int(index), reinterpret_cast<uint8_t const*>(pixels.data()), (tile.width + 3) * 4));
    }
    std::vector<uint8_t> first(43 * 4 * 29, 0xa7), second(24 * 4 * 13, 0xa7);
    VoxGraphitePixelRegion views[] {{0, 0, 37, 29, 43 * 4, first.data()},
        {0, 0, 19, 13, 24 * 4, second.data()}};
    assert(vox_graphite_canvas_read_direct(views, 2));
    for (int y = 0; y < 29; ++y) {
        assert(*reinterpret_cast<uint32_t*>(first.data() + y * 43 * 4) == 0xff20a040);
        for (int x = 37 * 4; x < 43 * 4; ++x) assert(first[y * 43 * 4 + x] == 0xa7);
    }
    for (int y = 0; y < 13; ++y) {
        assert(*reinterpret_cast<uint32_t*>(second.data() + y * 24 * 4) == 0xff20a041);
        for (int x = 19 * 4; x < 24 * 4; ++x) assert(second[y * 24 * 4 + x] == 0xa7);
    }
    vox_graphite_canvas_end();
    canvas_reset(); recorder.reset(); gpu_context.reset();
    std::puts("Linear Metal canvas: exact odd/large targets, alpha/AA/clips, pending GPU writes, partial/padded uploads, reuse, buffer lifetime, direct readback and row padding passed");
} }
