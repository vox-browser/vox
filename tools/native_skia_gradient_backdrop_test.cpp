// Exercise the real GPU bridge against a readable premultiplied destination.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static std::vector<uint8_t> render(bool root, uint8_t alpha)
{
    constexpr int size = 16;
    std::vector<uint8_t> pixels(size * size * 4);
    for (size_t i = 0; i < pixels.size(); i += 4) {
        pixels[i] = alpha / 255;
        pixels[i + 1] = 17 * alpha / 255;
        pixels[i + 2] = 33 * alpha / 255;
        pixels[i + 3] = alpha;
    }
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto destination = CGBitmapContextCreate(pixels.data(), size, size, 8, size * 4,
        space, static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(destination);
    float path[5 * 12] {};
    path[12] = path[24] = path[36] = 1;
    path[13] = path[25] = size;
    path[26] = path[38] = size;
    path[48] = 5;
    float stops[] {128.f/255, 64.f/255, 32.f/255, 128.f/255, 0,
                   128.f/255, 64.f/255, 32.f/255, 128.f/255, 1};
    float clip[] {0, 0, size, size, 0, 0, 0, 0, 0, 0, 0, 0};
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(0, 0, root);
    ladybird_v_skia_set_raster_layer_size(size, size);
    assert(ladybird_v_skia_draw_clipped_svg_linear_gradient_path(destination, path, 5, 0,
        1, 0, 0, 1, 0, 0, 0, 0, 0, size, size,
        0, 0, 0, 0, 4, 0, 0, size, size,
        1, 0, 0, 1, 0, 0, 0, 0, stops, 2, 1, 1, clip, nullptr));
    ladybird_v_skia_set_chromium_painting(0);
    CGContextFlush(destination);
    CGContextRelease(destination);
    return pixels;
}

int main()
{
    ladybird_v_skia_set_msaa_tiles(nullptr, 0, 256);
    for (uint8_t alpha : {0, 128, 255}) {
        auto root = render(true, alpha);
        auto layer = render(false, alpha);
        size_t differences = 0;
        for (size_t i = 0; i < root.size(); ++i) differences += root[i] != layer[i];
        std::printf("Readable gradient backdrop (alpha %u): %zu differing channels\n",
            alpha, differences);
        assert(root[0] > 1 && root[3] >= alpha);
        assert(root == layer);
    }
}
