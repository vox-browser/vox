#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    std::vector<uint32_t> pixels(64 * 64, 0xff123456);
    auto context = CGBitmapContextCreate(pixels.data(), 64, 64, 8, 64 * 4,
        color_space, static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    assert(context);
    s_chromium_painting = false;
    assert(!ladybird_v_skia_begin_isolated_input(context, 64, 64));
    assert(!ladybird_v_skia_take_isolated_input(context));
    s_chromium_painting = true;
    assert(shared_picture_draw());
    assert(!ladybird_v_skia_begin_isolated_input(context, 0, 64));
    for (bool unsupported : {false, true}) {
        assert(ladybird_v_skia_begin_isolated_input(context, 64, 64));
        auto* mask_canvas = isolated_input_recording_canvas(context);
        SkPaint opaque;
        opaque.setColor(SK_ColorBLACK);
        mask_canvas->drawRect(SkRect::MakeXYWH(8, 8, 16, 16), opaque);
        s_isolated_input_recordings[context]->bounds = SkRect::MakeWH(64, 64);
        auto* mask = ladybird_v_skia_take_isolated_input(context);
        assert(mask && !isolated_input_recording_canvas(context));
        // CoreGraphics may reuse the released mask's address for the content.
        assert(ladybird_v_skia_begin_isolated_input(context, 64, 64));
        auto* content = s_isolated_input_recordings[context].get();
        content->bounds = SkRect::MakeWH(64, 64);
        if (unsupported) ladybird_v_skia_block_shared_clip(context);
        content->recorder.getRecordingCanvas()->clear(SK_ColorRED);
        auto before = pixels;
        int result = ladybird_v_skia_draw_gradient_text(context, mask, context,
            64, 64, 1, 0, 0, 64, 64);
        assert(s_isolated_input_recordings.empty());
        assert(result == !unsupported);
        if (unsupported) {
            assert(before == pixels);
        } else {
            auto* bytes = reinterpret_cast<uint8_t*>(pixels.data());
            assert(bytes[(12 * 64 + 12) * 4] == 255);
            assert(bytes[(12 * 64 + 12) * 4 + 1] == 0);
            assert(pixels[0] == before[0]);
        }
    }
    assert(ladybird_v_skia_begin_isolated_input(context, 64, 64));
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(context));
    assert(s_isolated_input_recordings.empty());
    ladybird_v_skia_discard_isolated_input(nullptr);
    s_shared_clips.erase(context);
    CGContextRelease(context);
    CGColorSpaceRelease(color_space);
    std::cout << "Retained text mask ownership, fallback and GPU composition passed\n";
}
