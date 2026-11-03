#include "../native_graphite_dawn_darwin.mm"
#include "include/core/SkPictureRecorder.h"
#include <cassert>
#include <iostream>

static VoxSharedPicturePixelsRegistry shared_pixels;
static uint64_t shared_token;
static unsigned acquisitions;
extern "C" int vox_picture_pixels_acquire(uint64_t token, VoxSharedPicturePixelsLease* lease)
{
    ++acquisitions;
    return shared_pixels.acquire(token, lease);
}

static sk_sp<SkData> picture(float phase, bool image, bool shared = false)
{
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(128, 96));
    SkPaint paint; paint.setAntiAlias(true); paint.setColor(0xa94895df);
    canvas->drawRoundRect(SkRect::MakeXYWH(3.25f + phase, 7.5f, 101.5f, 72.25f), 9, 13, paint);
    paint.setColor(0x831da26f);
    canvas->drawCircle(56.25f, 43.75f, 27.125f, paint);
    if (image) {
        std::vector<uint32_t> pixels(32 * 32, 0xffc47628);
        auto info = SkImageInfo::MakeN32Premul(32, 32);
        auto source = SkImages::RasterFromPixmapCopy(SkPixmap(info, pixels.data(), 128));
        assert(source); canvas->drawImage(source, 13.25f + phase, 19.5f);
    }
    SkSerialProcs procs;
    procs.fImageProc = [](SkImage* source, void* context) -> sk_sp<const SkData> {
        auto bytes = vox_encode_picture_image(source);
        if (!context || !bytes) return bytes;
        auto owner = std::make_shared<std::vector<uint8_t>>(
            static_cast<uint8_t const*>(bytes->data()), static_cast<uint8_t const*>(bytes->data()) + bytes->size());
        shared_token = shared_pixels.insert(owner, owner->data(), owner->size());
        assert(shared_token);
        VoxSharedPicturePixelsToken token; token.token = shared_token;
        return SkData::MakeWithCopy(&token, sizeof(token));
    };
    procs.fImageCtx = shared ? &shared_token : nullptr;
    return recorder.finishRecordingAsPicture()->serialize(&procs);
}

int main()
{
    unsigned cases = 0;
    for (bool background : {false, true}) for (bool batch : {false, true})
    for (bool image : {false, true}) for (float phase : {0.f, .25f, .5f, .75f}) {
        if (background && !batch) continue;
        picture_raster_cache.clear();
        auto bytes = picture(phase, image); assert(bytes);
        std::vector<uint8_t> pixels(80 * 64 * 4 + 64, 73);
        VoxGraphitePictureRegion regions[2] {};
        for (int i = 0; i < 2; ++i) {
            regions[i].output = {i * 16, i * 8, 32, 24, 32 * 4 + 8,
                pixels.data() + i * 4096};
            regions[i].bytes = bytes->data(); regions[i].size = bytes->size();
            regions[i].matrix[0] = regions[i].matrix[4] = regions[i].matrix[8] = 1;
            regions[i].matrix[2] = phase; regions[i].matrix[5] = -phase;
        }
        auto invoke = [&] {
            if (batch) return draw_picture_regions_pixels(regions, 2, 128, 96, background);
            auto const& out = regions[0].output;
            return vox_graphite_draw_picture_region_pixels(out.pixels, 128, 96,
                out.pitch, out.x, out.y, out.width, out.height, bytes->data(), bytes->size(), regions[0].matrix);
        };
        auto input = pixels;
        setenv("VOX_DISABLE_PICTURE_RASTER_CACHE", "1", 1);
        assert(invoke()); auto expected = pixels;
        pixels = input;
        unsetenv("VOX_DISABLE_PICTURE_RASTER_CACHE");
        assert(invoke() && pixels == expected);
        assert(picture_raster_cache.size() == 1);
        // A hit must remain exact after destroying the actual GPU context.
        gpu_context_last_use = std::chrono::steady_clock::now() - std::chrono::seconds(3);
        assert(vox_graphite_picture_release_idle_graphics_memory() == 1 && !gpu_context);
        pixels = input;
        assert(invoke() && pixels == expected && !gpu_context);
        if (background) {
            pixels = input; pixels[1]++;
            auto changed_input = pixels;
            setenv("VOX_DISABLE_PICTURE_RASTER_CACHE", "1", 1);
            assert(invoke()); auto changed_expected = pixels;
            unsetenv("VOX_DISABLE_PICTURE_RASTER_CACHE");
            pixels = changed_input;
            assert(invoke() && pixels == changed_expected && gpu_context);
        }
        ++cases;
    }
    // A cache entry must not keep a shared-image lease alive or bypass token
    // validation after retirement, even when Skia accepts a missing image.
    picture_raster_cache.clear();
    auto bytes = picture(0, true, true); assert(bytes && shared_token);
    std::vector<uint8_t> pixels(128 * 96 * 4, 0);
    float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
    auto invoke = [&] {
        return vox_graphite_draw_picture_pixels(pixels.data(), 128, 96, 128 * 4,
            bytes->data(), bytes->size(), identity);
    };
    assert(invoke() && acquisitions);
    auto valid = pixels;
    assert(picture_raster_cache.size() == 1);
    gpu_context_last_use = std::chrono::steady_clock::now() - std::chrono::seconds(3);
    assert(vox_graphite_picture_release_idle_graphics_memory() == 1);
    assert(invoke() && pixels == valid && !gpu_context);
    shared_pixels.retire(shared_token);
    assert(shared_pixels.live_bytes() == 0);
    setenv("VOX_DISABLE_PICTURE_RASTER_CACHE", "1", 1);
    std::fill(pixels.begin(), pixels.end(), 0);
    auto uncached_status = invoke(); auto missing = pixels;
    unsetenv("VOX_DISABLE_PICTURE_RASTER_CACHE");
    std::fill(pixels.begin(), pixels.end(), 0);
    assert(invoke() == uncached_status && pixels == missing);
    assert(!uncached_status || missing != valid);
    std::cout << cases << " picture raster replay cases match uncached GPU pixels after context retirement\n";
}
