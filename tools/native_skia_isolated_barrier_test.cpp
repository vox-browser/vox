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
    s_speculative_layer_enabled = true;
    s_msaa_grid_columns = 2;
    s_msaa_grid_width = s_msaa_grid_height = 34;
    s_raster_layer_width = s_raster_layer_height = 64;
    s_shared_viewport_width = s_shared_viewport_height = 64;
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
    setenv("VOX_ENABLE_COMPLETE_SPECULATIVE_PICTURES", "1", 1);
    setenv("VOX_ENABLE_RETAINED_LAYER_TILES", "0", 1);
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

    // Supported images become owned picture input without publishing a
    // second ordinary raster. Mutating the caller bytes cannot alter it.
    CGContextClearRect(parent, CGRectMake(0, 0, 64, 64));
    pending_parent(parent);
    uint8_t image[] {0, 255, 0, 255};
    auto draw_image = [&] {
        return ladybird_v_skia_draw_rgba_image(parent, image, 1, 1, 4,
            8, 8, 4, 4, 0, 0, 1, 1, 8, 8, 4, 4,
            1, 0, 0, 1, 0, 0, 0, 0, 0, 64, 64, 1, 1, 1, nullptr);
    };
    assert(draw_image());
    assert(s_shared_root_recording && s_shared_root_recording->deferred_leaves == 2);
    assert(pixels[8 * 256 + 8 * 4 + 3] == 0);
    image[1] = 0; image[2] = 255;
    finish_shared_recording();
    assert(!s_deferred_layer_frame_failed);
    assert(pixels[8 * 256 + 8 * 4 + 1] == 255);
    assert(pixels[8 * 256 + 8 * 4 + 2] == 0);
    assert(pixels[5 * 256 + 5 * 4] == 255);
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // An image with a separate background retains ordinary rendering, after
    // the preceding deferred red rectangle has reached its real backdrop.
    CGContextClearRect(parent, CGRectMake(0, 0, 64, 64));
    pending_parent(parent);
    ladybird_v_skia_set_image_background(255, 255, 255, 255);
    assert(draw_image());
    assert(!s_shared_root_recording && !s_deferred_layer_frame_failed);
    assert(pixels[5 * 256 + 5 * 4] == 255);
    assert(pixels[8 * 256 + 8 * 4 + 2] == 255);
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // Strokes include their cap/join ink before the picture accepts their
    // deferred leaf. They must not paint a separate bitmap behind its back.
    CGContextClearRect(parent, CGRectMake(0, 0, 64, 64));
    pending_parent(parent);
    float line[] {0, 8, 8, 0,0,0,0,0,0,0,0,0,
        1, 18, 8, 0,0,0,0,0,0,0,0,0};
    assert(ladybird_v_skia_draw_svg_path_with_colors(parent, line, 2, 0,
        1, 0, 0, 1, 0, 0, 0, 0, 0, 64, 64,
        0, 0, 0, 0, 0, 0, 0, 255, 255, 1, 4, 2, 0, 4, 0,
        nullptr, 0, 0, 1, nullptr, nullptr));
    assert(s_shared_root_recording && s_shared_root_recording->deferred_leaves == 2);
    assert(pixels[8 * 256 + 10 * 4 + 3] == 0);
    assert(s_shared_root_recording->replay_bounds.back().contains(SkRect::MakeLTRB(6, 6, 20, 10)));
    finish_shared_recording();
    assert(!s_deferred_layer_frame_failed);
    assert(pixels[8 * 256 + 10 * 4 + 2] == 255);
    assert(pixels[5 * 256 + 5 * 4] == 255);
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // A full-width gradient must register its AA publication fringe even
    // without an earlier full-width fill. Otherwise it paints behind the
    // picture because that fringe falls outside the nominal layer bounds.
    CGContextClearRect(parent, CGRectMake(0, 0, 64, 64));
    pending_parent(parent);
    float gradient_rect[] {0, 0, 24, 0,0,0,0,0,0,0,0,0,
        1, 64, 24, 0,0,0,0,0,0,0,0,0,
        1, 64, 40, 0,0,0,0,0,0,0,0,0,
        1, 0, 40, 0,0,0,0,0,0,0,0,0,
        5, 0,0,0,0,0,0,0,0,0,0,0};
    float stops[] {0, 1, 0, 1, 0, 0, 1, 0, 1, 1};
    assert(ladybird_v_skia_draw_clipped_svg_linear_gradient_path(parent,
        gradient_rect, 5, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 64, 64,
        0, 0, 0, 0, 4, 0, 24, 64, 24, 1, 0, 0, 1, 0, 0,
        0, 0, stops, 2, 1, 1, nullptr, nullptr));
    assert(s_shared_root_recording && s_shared_root_recording->deferred_leaves == 2);
    assert(pixels[30 * 256 + 2 * 4 + 3] == 0);
    finish_shared_recording();
    assert(!s_deferred_layer_frame_failed);
    assert(pixels[30 * 256 + 2 * 4 + 1] == 255);
    assert(pixels[8 * 256 + 8 * 4] == 255);
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // A viewport-sized solid background keeps the ordinary cheap fill,
    // after publishing any preceding picture; it creates no scroll tile key.
    CGContextClearRect(parent, CGRectMake(0, 0, 64, 64));
    pending_parent(parent);
    ladybird_v_skia_record_rect(parent, 0, 0, 64, 64, 0, 0, 255, 255);
    assert(!s_shared_root_recording && !s_deferred_layer_frame_failed);
    assert(!ladybird_v_skia_defer_recorded_rect(parent, 0, 0, 64, 64));
    assert(pixels[8 * 256 + 8 * 4] == 255);
    CGContextSetRGBFillColor(parent, 0, 0, 1, 1);
    CGContextFillRect(parent, CGRectMake(0, 0, 64, 64));
    assert(pixels[8 * 256 + 8 * 4 + 2] == 255);
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // A smaller solid fill stays in the owning picture.
    CGContextClearRect(parent, CGRectMake(0, 0, 64, 64));
    pending_parent(parent);
    ladybird_v_skia_record_rect(parent, 0, 32, 32, 32, 0, 0, 255, 255);
    assert(ladybird_v_skia_defer_recorded_rect(parent, 0, 32, 32, 32));
    assert(s_shared_root_recording && s_shared_root_recording->deferred_leaves == 2);
    assert(pixels[8 * 256 + 8 * 4 + 3] == 0);
    finish_shared_recording();
    assert(pixels[8 * 256 + 8 * 4 + 2] == 255);
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

    // A non-deferred segment's ordinary write vetoes that publication, but
    // does not globally decline later independent pictures on the same root.
    pending_parent(parent);
    s_shared_root_recording->deferred_leaves = 0;
    auto declined = s_speculative_declined_layers.size();
    pixels[0] ^= 1;
    finish_shared_recording();
    assert(!s_deferred_layer_frame_failed);
    assert(s_speculative_declined_layers.size() == declined);
    assert(ladybird_v_skia_finish_deferred_layer_frame());

    // A tiny root segment in a tall document preserves the immutable
    // prefix outside its ink, including pixels in the same original GPU tile.
    CGContextSetRGBFillColor(parent, 0, 1, 0, 1);
    CGContextFillRect(parent, CGRectMake(0, 0, 64, 64));
    pending_parent(parent);
    s_shared_root_recording->layer_height = 12000;
    finish_shared_recording();
    assert(!s_deferred_layer_frame_failed);
    assert(pixels[8 * 256 + 8 * 4] == 255);
    assert(pixels[8 * 256 + 8 * 4 + 1] == 0);
    assert(pixels[32 * 256 + 32 * 4] == 0);
    assert(pixels[32 * 256 + 32 * 4 + 1] == 255);
    assert(pixels[32 * 256 + 32 * 4 + 3] == 255);
    assert(ladybird_v_skia_finish_deferred_layer_frame());

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
