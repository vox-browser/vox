// Exercise the native rounded-clip bridge against the unchanged Brave card reference.
#include "../native_skia_text_darwin.cpp"
#include <ImageIO/ImageIO.h>
#include <cassert>
#include <cstdio>

int main(int argc, char** argv)
{
    assert(argc == 2);
    constexpr int width = 1024, height = 768, pitch = width * 4;
    std::vector<uint8_t> expected(pitch * height), actual(expected.size());
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto url = CFURLCreateFromFileSystemRepresentation(nullptr,
        reinterpret_cast<UInt8 const*>(argv[1]), std::strlen(argv[1]), false);
    auto source = CGImageSourceCreateWithURL(url, nullptr);
    auto reference = source ? CGImageSourceCreateImageAtIndex(source, 0, nullptr) : nullptr;
    assert(reference && CGImageGetWidth(reference) == width && CGImageGetHeight(reference) == height);
    auto decoded = CGBitmapContextCreate(expected.data(), width, height, 8, pitch, space,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    assert(decoded);
    CGContextDrawImage(decoded, CGRectMake(0, 0, width, height), reference);
    CGContextRelease(decoded);
    CGImageRelease(reference);
    CFRelease(source);
    CFRelease(url);
    auto context = CGBitmapContextCreate(actual.data(), width, height, 8, pitch, space,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context && shared_picture_draw() && graphite_shape_draw());
    ladybird_v_skia_set_chromium_painting(1);
    auto draw = [&](float x, float y, float w, float h, float tr_x, float tr_y,
                   float bl_x, float bl_y, uint8_t gray, int mode) {
        assert(ladybird_v_skia_draw_rounded_rect(context, x, y, w, h,
            0, 0, tr_x, tr_y, 0, 0, bl_x, bl_y,
            1, 0, 0, 1, 0, 0, 0, 0, 0, width, height,
            gray, gray, gray, 255, mode, 0, 1, 1));
    };
    for (int repeat = 0; repeat < 2; ++repeat) {
        std::fill(actual.begin(), actual.end(), 255);
        for (int card = 0; card < 2; ++card) {
            ladybird_v_skia_set_raster_layer(card ? 701 : 0, card ? 672 : 0, !card);
            ladybird_v_skia_set_raster_layer_size(card ? 298 : width, card ? 561 : 2200);
            int tiles[] {0, 1, 2};
            ladybird_v_skia_set_msaa_grid(tiles, card ? 2 : 3,
                card ? 320 : 1024, card ? 416 : 256, 1);
            assert(ladybird_v_skia_begin_deferred_inset_decorations(context,
                2, 2, width - 4, height - 4, width, height, 0, 0));
            float y = card ? 672 : 92, h = card ? 561 : 560;
            draw(701.5, y, 297, h - .5f, 9.5, 10, 9.5, 9.5, 230, 1);
            float widths[] {0, 1, 1, 1};
            ladybird_v_skia_set_rounded_border_widths(widths);
            draw(701, y, 298, h, 10, 10, 10, 10, 204, 8);
            draw(701, y, 298, card ? 30 : 29, 10, 10, 0, 0, 76, 1);
            assert(ladybird_v_skia_end_deferred_inset_decorations(context));
        }
        CGContextFlush(context);
        size_t differences = 0;
        for (size_t pixel = 0; pixel < actual.size() / 4; ++pixel)
            differences += std::memcmp(expected.data() + pixel * 4, actual.data() + pixel * 4, 4) != 0;
        if (differences) {
            std::fprintf(stderr, "Rounded border replay %d: %zu differing pixels\n", repeat, differences);
            CGContextRelease(context);
            return 1;
        }
    }
    // A positioned child can follow another box's background. Keep gap draws
    // on the ordinary destination while the bounded card region is replayed.
    std::fill(actual.begin(), actual.end(), 255);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(width, 2200);
    int root_tiles[] {0, 1, 2};
    ladybird_v_skia_set_msaa_grid(root_tiles, 3, 1024, 256, 1);
    assert(ladybird_v_skia_begin_inset_decorations(context,
        701, 92, 298, height - 92, width, height, 0, 0));
    for (int card = 0; card < 2; ++card) {
        float y = card ? 672 : 92, h = card ? 561 : 560;
        draw(701.5, y, 297, h - .5f, 9.5, 10, 9.5, 9.5, 230, 1);
        float widths[] {0, 1, 1, 1};
        ladybird_v_skia_set_rounded_border_widths(widths);
        draw(701, y, 298, h, 10, 10, 10, 10, 204, 8);
    }
    draw(30, 20, 40, 20, 0, 0, 0, 0, 200, 1);
    draw(701, 92, 298, 29, 10, 10, 0, 0, 76, 1);
    draw(701, 672, 298, 30, 10, 10, 0, 0, 76, 1);
    assert(ladybird_v_skia_end_deferred_inset_decorations(context));
    CGContextFlush(context);
    for (int y = 20; y < 40; ++y) for (int x = 30; x < 70; ++x)
        for (int channel = 0; channel < 3; ++channel)
            expected[(y * width + x) * 4 + channel] = 200;
    assert(expected == actual);
    CGContextRelease(context);
    std::puts("Native partial rounded borders match Brave on cold and repeated draws");
}
