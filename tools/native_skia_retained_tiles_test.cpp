// Execution is deferred at the user's request until the live FPS goal.
#include "../native_skia_text_darwin.cpp"
#include <cassert>

static SharedRootRecording group_at(double scroll)
{
    SharedRootRecording group {};
    group.canvas_width = group.viewport_width = 1024;
    group.canvas_height = group.viewport_height = 768;
    group.origin_x = 100; group.origin_y = 200;
    group.layer_width = 512; group.layer_height = 512;
    group.scale = 2; group.scroll_y = scroll;
    group.root = false; group.speculative = true;
    return group;
}

static sk_sp<SkPicture> scene(SharedRootRecording const& group, SkColor color,
    bool clip, bool unsupported = false)
{
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(1024, 768));
    SkPaint paint; paint.setAntiAlias(true); paint.setColor(color);
    canvas->save();
    canvas->clipRect(SkRect::MakeWH(1024, 768));
    canvas->setMatrix(SkMatrix::Translate(0, -group.scroll_y));
    if (clip) canvas->clipRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(100, 200, 80, 80), 5, 7), true);
    canvas->drawRect(SkRect::MakeXYWH(100, 200, 70, 60), paint);
    canvas->restore();
    canvas->setMatrix(SkMatrix::Translate(group.origin_x, group.origin_y - group.scroll_y));
    canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeWH(50, 50), 3, 4), paint);
    if (unsupported) canvas->drawPaint(paint);
    return recorder.finishRecordingAsPicture();
}

int main()
{
    auto first = group_at(20), second = group_at(40);
    auto a = scene(first, SK_ColorRED, true), b = scene(second, SK_ColorRED, true);
    RetainedLayerCanvas ca(first), cb(second);
    a->playback(&ca); b->playback(&cb);
    auto owner_a = ca.finish(), owner_b = cb.finish();
    assert(ca.valid && cb.valid && ca.draws.size() == 2 && cb.draws.size() == 2);
    assert(ca.draws[0].key == cb.draws[0].key && ca.draws[1].key == cb.draws[1].key);
    assert(ca.draws[0].bounds == cb.draws[0].bounds);
    // Browser chrome is outside the document viewport. Its viewport clip
    // moves relative to a layer during scrolling but is applied at publication.
    auto chrome_a = group_at(20), chrome_b = group_at(40);
    chrome_a.page_y = chrome_b.page_y = 112;
    chrome_a.canvas_height = chrome_b.canvas_height = 880;
    auto chrome_picture = [](SharedRootRecording const& group) {
        SkPictureRecorder recorder;
        auto* c = recorder.beginRecording(SkRect::MakeWH(1024, 880));
        c->clipRect(SkRect::MakeXYWH(0, 112, 1024, 768), true);
        c->setMatrix(SkMatrix::Translate(0, 112 - group.scroll_y));
        SkPaint paint; paint.setColor(SK_ColorRED);
        c->drawRect(SkRect::MakeXYWH(100, 200, 70, 60), paint);
        return recorder.finishRecordingAsPicture();
    };
    RetainedLayerCanvas cf(chrome_a), cg(chrome_b);
    chrome_picture(chrome_a)->playback(&cf); chrome_picture(chrome_b)->playback(&cg);
    cf.finish(); cg.finish();
    assert(cf.valid && cg.valid && cf.draws.size() == 1 && cg.draws.size() == 1);
    assert(cf.draws[0].key == cg.draws[0].key);
    // A restored clip must not leak into the following independent primitive.
    auto unclipped = scene(first, SK_ColorRED, false);
    RetainedLayerCanvas cc(first); unclipped->playback(&cc); cc.finish();
    assert(cc.valid && cc.draws[0].key != ca.draws[0].key);
    assert(cc.draws[1].key == ca.draws[1].key);
    auto changed = scene(first, SK_ColorBLUE, true);
    RetainedLayerCanvas cd(first); changed->playback(&cd); cd.finish();
    assert(cd.valid && cd.draws[0].key != ca.draws[0].key);
    auto unsupported = scene(first, SK_ColorRED, true, true);
    RetainedLayerCanvas ce(first); unsupported->playback(&ce); ce.finish();
    assert(!ce.valid);
    // The cache owns both identity and pixels after its caller releases them.
    RetainedLayerTileCache cache;
    auto key = ca.draws[0].key;
    auto pixels = std::make_shared<RetainedLayerTilePixels>(std::vector<uint32_t>(16, 0x12345678), 4, 4);
    cache.insert(key, pixels, owner_a, 0);
    key[0] ^= 1; pixels.reset(); a.reset(); owner_a.reset();
    assert(!cache.find(key));
    auto hit = cache.find(ca.draws[0].key);
    std::vector<uint32_t> decoded(16);
    assert(hit && hit->pixels.copy_to(reinterpret_cast<uint8_t*>(decoded.data()), 16, 16, 4));
    assert(decoded[15] == 0x12345678);
    cache.clear(); assert(!cache.find(ca.draws[0].key));
    assert(hit->pixels.copy_to(reinterpret_cast<uint8_t*>(decoded.data()), 16, 16, 4));
    assert(decoded[0] == 0x12345678);
    // Rendering failures must leave the supplied destination buffer untouched.
    std::vector<uint32_t> target(64, 0x99887766), before = target;
    first.tile_width = first.tile_height = 0;
    assert(!draw_retained_layer_tiles(first, b.get(), target, 8, 8, 0, 0));
    assert(target == before);
}
