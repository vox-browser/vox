#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static std::vector<uint8_t> render(int scale, float sigma, int offset, int alpha, bool shadow, bool clipped)
{
    constexpr int w = 96, h = 64;
    int width = w * scale, height = h * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa9);
    std::vector<uint8_t> input(size_t(width) * height * 4);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[0] = (x * 7 + y * 13) % (alpha + 1); p[1] = x % (alpha + 1);
        p[2] = y % (alpha + 1); p[3] = alpha;
        auto* q = input.data() + (size_t(y) * width + x) * 4;
        q[3] = x >= (20 + offset) * scale && x < (60 + offset) * scale
            && y >= 9 * scale && y < 49 * scale ? 173 : 0;
        q[0] = (x * 7 + y * 13) % (q[3] + 1);
        q[1] = (x * 11) % (q[3] + 1); q[2] = (y * 3) % (q[3] + 1);
    }
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto source = CGBitmapContextCreate(input.data(), width, height, 8, width * 4, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    auto destination = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(source && destination);
    auto image = CGBitmapContextCreateImage(source); assert(image);
    CGContextScaleCTM(destination, scale, scale);
    if (clipped) {
        // The complete source is replayed at the same raster position, even
        // when unrelated background damage clips the final publication.
        CGRect rects[] {CGRectMake(30, h - 20 - 13, 23, 13), CGRectMake(0, 0, w, 2)};
        CGContextClipToRects(destination, rects, 2);
    }
    ladybird_v_skia_set_chromium_painting(1);
    if (shadow) {
        float data[] {2.25f, -1.5f, sigma, .3f, .7f, .2f, .6f};
        assert(ladybird_v_skia_draw_drop_shadow_chain(destination, image, w, h, scale, data, 1));
    } else assert(ladybird_v_skia_draw_css_blur(destination, image, w, h, scale, sigma));
    CGContextFlush(destination);
    CGContextRelease(destination); CGImageRelease(image); CGContextRelease(source);
    return pixels;
}

int main()
{
    assert(shared_picture_draw());
    int cases = 0;
    for (int scale : {1, 2}) for (float sigma : {1.5f, 19.f})
    for (int offset : {-8, 12}) for (int alpha : {173, 255}) for (bool shadow : {false, true}) {
        auto full = render(scale, sigma, offset, alpha, shadow, false);
        auto partial = render(scale, sigma, offset, alpha, shadow, true);
        int width = 96 * scale, height = 64 * scale, pitch = width * 4 + 16;
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            auto* pixel = partial.data() + size_t(y) * pitch + x * 4;
            bool inside = (x >= 30 * scale && x < 53 * scale && y >= 20 * scale && y < 33 * scale)
                || y >= 62 * scale;
            uint8_t untouched[] {uint8_t((x * 7 + y * 13) % (alpha + 1)), uint8_t(x % (alpha + 1)),
                uint8_t(y % (alpha + 1)), uint8_t(alpha)};
            auto* expected = inside ? full.data() + size_t(y) * pitch + x * 4 : untouched;
            assert(!std::memcmp(pixel, expected, 4));
        }
        for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
            assert(partial[size_t(y) * pitch + x] == 0xa9);
        ++cases;
    }
    std::printf("Stationary filters: %d clipped replays equal complete native repaints\n", cases);
}
