// Execution is deferred at the user's request until the live FPS goal.
#include "../native_skia_text_darwin.cpp"
#include <cassert>

int main()
{
    RecordedImageCache cache;
    uint8_t padded[] {255,0,0,255, 0,255,0,255, 0,0,255,255, 99,98,97,96,
        0,0,0,255, 255,255,255,255, 128,0,0,255, 95,94,93,92};
    auto info = SkImageInfo::Make(3, 2, kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    bool reused = true;
    auto first = cache.get(SkPixmap(info, padded, 16), &reused);
    assert(first && !reused);
    uint8_t tight[24];
    std::memcpy(tight, padded, 12); std::memcpy(tight + 12, padded + 16, 12);
    auto same = cache.get(SkPixmap(info, tight, 12), &reused);
    assert(reused && same->uniqueID() == first->uniqueID());
    padded[12] ^= 1; padded[31] ^= 1;
    assert(cache.get(SkPixmap(info, padded, 16))->uniqueID() == first->uniqueID());
    tight[0] = 0;
    auto changed = cache.get(SkPixmap(info, tight, 12), &reused);
    assert(changed && !reused && changed->uniqueID() != first->uniqueID());
    SkPixmap owned;
    assert(first->peekPixels(&owned));
    assert(static_cast<uint8_t const*>(owned.addr())[0] == 255);
    auto linear_info = info.makeColorSpace(SkColorSpace::MakeSRGBLinear());
    assert(cache.get(SkPixmap(linear_info, tight, 12))->uniqueID() != changed->uniqueID());
    assert(cache.get(SkPixmap(info.makeAlphaType(kUnpremul_SkAlphaType), tight, 12))->uniqueID() != changed->uniqueID());

    // Stable owned image identities survive image-rectangle canonicalization.
    auto group = SharedRootRecording {};
    group.canvas_width = group.viewport_width = 64;
    group.canvas_height = group.viewport_height = 64;
    group.scale = 1;
    auto picture = [&](SkSamplingOptions const& sampling) {
        SkPictureRecorder recorder; auto* canvas = recorder.beginRecording(SkRect::MakeWH(64, 64));
        canvas->translate(8, 12);
        canvas->drawImageRect(first, SkRect::MakeWH(3, 2), sampling);
        return recorder.finishRecordingAsPicture();
    };
    auto sampled = picture(SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kLinear));
    RetainedLayerCanvas canonical(group); sampled->playback(&canonical);
    auto result = canonical.finish();
    assert(canonical.valid && result && canonical.draws.size() == 1);
    auto nearest = picture(SkSamplingOptions(SkFilterMode::kNearest, SkMipmapMode::kNone));
    RetainedLayerCanvas other(group); nearest->playback(&other); other.finish();
    assert(other.valid && canonical.draws[0].key != other.draws[0].key);

    // A bounded cache can evict its reference while recorded owners stay valid.
    for (int i = 0; i < 129; ++i) {
        uint8_t pixel[] {uint8_t(i), uint8_t(i >> 8), 0, 255};
        auto small = info.makeWH(1, 1);
        assert(cache.get(SkPixmap(small, pixel, 4)));
    }
    auto again = cache.get(SkPixmap(info, padded, 16));
    assert(again && again->uniqueID() != first->uniqueID());
    cache.clear();
    assert(first->peekPixels(&owned));
    assert(static_cast<uint8_t const*>(owned.addr())[0] == 255);
    assert(result->approximateOpCount() > 0);
}
