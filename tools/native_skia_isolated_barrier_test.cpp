// Execution is deferred at the user's request until the live FPS goal.
#include "../native_skia_text_darwin.cpp"
#include <cassert>

static CGContextRef bitmap()
{
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(nullptr, 64, 64, 8, 256, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    return context;
}

static void pending_parent(CGContextRef parent, bool blocked = false)
{
    ladybird_v_skia_begin_deferred_layer_frame(1);
    ladybird_v_skia_set_deferred_layer_destination(parent, 1);
    auto group = std::make_unique<SharedRootRecording>();
    group->destination = parent;
    group->canvas_width = group->canvas_height = 64;
    group->viewport_width = group->viewport_height = 64;
    group->scale = 1;
    group->layer_width = group->layer_height = 64;
    group->tile_width = group->tile_height = 34;
    group->columns = group->rows = 2;
    group->root = false;
    group->speculative = group->checks_prefix = true;
    group->original_prefix = VoxRasterSnapshot(
        static_cast<uint8_t*>(CGBitmapContextGetData(parent)), 256, 256, 64);
    group->recorder = std::make_unique<SkPictureRecorder>();
    auto* canvas = group->recorder->beginRecording(SkRect::MakeWH(64, 64));
    SkPaint paint;
    paint.setColor(SK_ColorRED);
    canvas->drawRect(SkRect::MakeXYWH(4, 4, 16, 16), paint);
    group->replay_bounds.push_back(SkRect::MakeXYWH(4, 4, 16, 16));
    group->deferred_leaves = 1;
    if (blocked) group->blocked_bounds.push_back(SkRect::MakeWH(64, 64));
    s_shared_root_recording = std::move(group);
}

int main()
{
    auto parent = bitmap(), input = bitmap();
    ladybird_v_skia_set_chromium_painting(1);
    pending_parent(parent);
    assert(ladybird_v_skia_begin_isolated_input(input, 64, 64));
    assert(!s_shared_root_recording && !s_deferred_layer_frame_failed);
    auto* pixels = static_cast<uint8_t*>(CGBitmapContextGetData(parent));
    assert(pixels[8 * 256 + 8 * 4] == 255);
    assert(pixels[8 * 256 + 8 * 4 + 3] == 255);
    assert(pixels[32 * 256 + 32 * 4 + 3] == 0);
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(input));
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // A same-canvas isolated recorder also replaces pixels outside the
    // shared stream. Its parent must be complete before ownership changes.
    pending_parent(parent);
    assert(ladybird_v_skia_begin_isolated_input(parent, 64, 64));
    assert(!s_shared_root_recording && !s_deferred_layer_frame_failed);
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(parent));
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // A speculative root already owns decoration leaves; a second local
    // decoration transaction must not composite those leaves behind its back.
    pending_parent(parent);
    s_speculative_layer_enabled = true;
    assert(!ladybird_v_skia_begin_inset_decorations(parent, 4, 4, 16, 16,
        64, 64, 0, 0));
    assert(!s_inset_decoration_recording && s_shared_root_recording);
    s_shared_root_recording.reset();
    ladybird_v_skia_finish_deferred_layer_frame();

    // A failed parent publication still requests whole-frame ordinary replay.
    pending_parent(parent, true);
    assert(ladybird_v_skia_begin_isolated_input(input, 64, 64));
    assert(!s_shared_root_recording && s_deferred_layer_frame_failed);
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(input));
    assert(!ladybird_v_skia_finish_deferred_layer_frame());

    // Existing non-speculative pictures retain their ordinary owner boundary.
    pending_parent(parent);
    s_shared_root_recording->speculative = false;
    auto* original = s_shared_root_recording.get();
    assert(ladybird_v_skia_begin_isolated_input(input, 64, 64));
    assert(s_shared_root_recording.get() == original);
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(input));
    s_shared_root_recording.reset();
    ladybird_v_skia_finish_deferred_layer_frame();
    ladybird_v_skia_set_chromium_painting(0);
    CGContextRelease(input);
    CGContextRelease(parent);
}
