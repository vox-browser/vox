// A background's GPU bitmap tiles drawn in one Graphite pass must match the
// same tiles drawn one at a time, byte for byte, over the same backdrop.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

namespace {

struct Canvas {
    int width, height, pitch;
    std::vector<uint8_t> pixels;
    CGContextRef context;
    Canvas(int scale)
        : width(96 * scale), height(48 * scale), pitch(width * 4 + 16),
          pixels(size_t(pitch) * height)
    {
        for (size_t i = 0; i < pixels.size(); ++i) {
            uint8_t a = (i / 4 * 7 + i / size_t(pitch) * 3) % 256 | 0x80;
            pixels[i] = i % 4 == 3 ? a : uint8_t(a * ((i % 4) * 40 + 60) / 255);
        }
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
            static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
        CGColorSpaceRelease(color);
        assert(context);
        CGContextScaleCTM(context, scale, scale);
    }
    ~Canvas() { CGContextRelease(context); }
};

}

int main()
{
    assert(graphite_image_draw() && graphite_image_tiles_draw());
    ladybird_v_skia_set_chromium_painting(1);
    // A 3x5 straight-alpha image with translucent texels.
    constexpr int image_width = 3, image_height = 5, image_pitch = image_width * 4;
    uint8_t image[image_pitch * image_height];
    for (int i = 0; i < image_pitch * image_height; ++i)
        image[i] = i % 4 == 3 ? uint8_t(90 + i * 11 % 160) : uint8_t(i * 37 % 256);
    int comparisons = 0, batched = 0;
    for (int msaa : {0, 1, 2}) for (int scale : {1, 2}) for (int backdrop : {0, 2}) for (int rounded : {0, 1})
    for (int transform : {0, 1, 2}) for (int nearest : {0, 1}) for (int overlap : {0, 1}) {
        int tile = 0;
        ladybird_v_skia_set_msaa_tiles(msaa ? &tile : nullptr, msaa ? 1 : 0, msaa == 2 ? 32 : 256);
        // Integral repeat-x tiles across a clip whose right edge cuts the last;
        // overlapping tiles share a column with their neighbor.
        std::vector<float> tiles;
        float clip[] {4, 6, 70.5f, 30};
        float step = overlap ? image_width - 1 : image_width;
        for (float x = 4; x < clip[0] + clip[2]; x += step) {
            float width = std::min(float(image_width), clip[0] + clip[2] - x);
            tiles.insert(tiles.end(), {x, 9, width, float(image_height) * 4, 0, 0,
                width, float(image_height)});
        }
        float radii[8] {6, 6, 0, 0, 3.5f, 3.5f, 0, 0};
        float m[6] {1, 0, 0, 1, 0, 0};
        if (transform == 1) { m[0] = 1.25f; m[3] = 0.75f; m[4] = 0.375f; m[5] = 1.5f; }
        // A fractional translation alone still batches.
        if (transform == 2) { m[4] = 0.375f; m[5] = 1.5f; }
        Canvas expected(scale), actual(scale);
        for (size_t tile = 0; tile < tiles.size() / 8; ++tile) {
            float const* t = tiles.data() + tile * 8;
            int drawn = ladybird_v_skia_draw_rgba_image(expected.context, image, image_width,
                image_height, image_pitch, t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7],
                clip[0], clip[1], clip[2], clip[3], m[0], m[1], m[2], m[3], m[4], m[5],
                2, 3, 0, 96, 48, 0.875f, nearest, backdrop, rounded ? radii : nullptr);
            assert(drawn == 1);
        }
        int drawn = ladybird_v_skia_draw_rgba_image_tiles(actual.context, image, image_width,
            image_height, image_pitch, tiles.data(), int(tiles.size() / 8),
            clip[0], clip[1], clip[2], clip[3], m[0], m[1], m[2], m[3], m[4], m[5],
            2, 3, 0, 96, 48, 0.875f, nearest, backdrop, rounded ? radii : nullptr);
        // Scaled or rounded clips, and tiles sharing pixels without a backdrop,
        // are left to the native caller, which draws them one tile at a time.
        // A fractional translation makes neighboring tiles share a column.
        int expected_drawn = !rounded && transform != 1 && (backdrop || (!transform && !overlap)) && !(msaa && transform == 2);
        if (drawn != expected_drawn) {
            std::printf("scale %d backdrop %d rounded %d transform %d nearest %d overlap %d: batched %d\n",
                scale, backdrop, rounded, transform, nearest, overlap, drawn);
            return 1;
        }
        if (!drawn) {
            for (size_t tile = 0; tile < tiles.size() / 8; ++tile) {
                float const* t = tiles.data() + tile * 8;
                ladybird_v_skia_draw_rgba_image(actual.context, image, image_width,
                    image_height, image_pitch, t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7],
                    clip[0], clip[1], clip[2], clip[3], m[0], m[1], m[2], m[3], m[4], m[5],
                    2, 3, 0, 96, 48, 0.875f, nearest, backdrop, rounded ? radii : nullptr);
            }
        }
        batched += drawn;
        CGContextFlush(expected.context);
        CGContextFlush(actual.context);
        if (expected.pixels != actual.pixels) {
            size_t differing = 0;
            for (size_t i = 0; i < expected.pixels.size(); ++i) differing += expected.pixels[i] != actual.pixels[i];
            std::printf("scale %d backdrop %d rounded %d transform %d nearest %d overlap %d: %zu bytes differ\n",
                scale, backdrop, rounded, transform, nearest, overlap, differing);
            return 1;
        }
        ++comparisons;
    }
    std::printf("%d tiled image comparisons PASS (%d batched)\n", comparisons, batched);
    return 0;
}
