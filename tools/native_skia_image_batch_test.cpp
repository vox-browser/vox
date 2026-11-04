// Batched image tiles must match serial complete draws and disjoint
// damage-strip replay, including Retina tile seams and fractional sampling.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static std::vector<uint8_t> render(bool batch, bool strips, int scale, int flags,
    float offset, bool nearest, bool root)
{
    constexpr int w = 256, h = 216;
    int width = w * scale, height = h * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa9);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[0] = (x * 17 + y * 7) % 256;
        p[1] = (x * 11 + y * 13) % 256;
        p[2] = (x * 5 + y * 19) % 256; p[3] = 255;
    }
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    setenv("VOX_ENABLE_IMAGE_TILE_BATCH", "1", 1);
    if (batch) unsetenv("VOX_DISABLE_IMAGE_TILE_BATCH");
    else setenv("VOX_DISABLE_IMAGE_TILE_BATCH", "1", 1);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, w, h);
    ladybird_v_skia_set_raster_layer(root ? 0 : 4, root ? 0 : 27, root);
    ladybird_v_skia_set_raster_layer_size(w, 1024);
    ladybird_v_skia_set_root_raster_scroll_y(37);
    int cells[] {0, 3, 4, 7};
    ladybird_v_skia_set_msaa_grid(cells, 4, 130 * scale, 66 * scale, 2);
    std::vector<uint8_t> source(257 * 193 * 4);
    for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 37 + i / 11);
    if (flags & 1) for (size_t i = 0; i < source.size(); i += 4)
        for (int c = 0; c < 3; ++c) source[i + c] = source[i + c] * source[i + 3] / 255;
    float radii[] {4, 4, 7, 7, 3, 3, 0, 0};
    int bands[] {0, 29, 81, 159, h};
    int count = strips ? 4 : 1;
    for (int band = 0; band < count; ++band) {
        CGContextSaveGState(context);
        if (strips) CGContextClipToRect(context,
            CGRectMake(0, h - bands[band + 1], w, bands[band + 1] - bands[band]));
        assert(ladybird_v_skia_draw_rgba_image(context, source.data(), 257, 193, 257 * 4,
            9 + offset, 49 + offset, 228, 159, 0, 0, 257, 193,
            9 + offset, 49 + offset, 228, 159,
            1, 0, 0, 1, 0, -37, 0, 14, 0, w, h, .8f, nearest, flags | 2, radii));
        CGContextRestoreGState(context);
    }
    CGContextFlush(context);
    CGContextRelease(context);
    return pixels;
}

int main()
{
    assert(graphite_image_regions_draw());
    unsetenv("VOX_ENABLE_IMAGE_TILE_BATCH");
    unsetenv("VOX_DISABLE_IMAGE_TILE_BATCH");
    assert(!image_tile_batch_enabled());
    setenv("VOX_ENABLE_IMAGE_TILE_BATCH", "0", 1);
    assert(!image_tile_batch_enabled());
    setenv("VOX_ENABLE_IMAGE_TILE_BATCH", "1", 1);
    assert(image_tile_batch_enabled());
    setenv("VOX_DISABLE_IMAGE_TILE_BATCH", "1", 1);
    assert(!image_tile_batch_enabled());
    int cases = 0;
    for (int scale : {1, 2}) for (int flags : {0, 1, 4, 4 | 8, 1 | VOX_GRAPHITE_IMAGE_VIDEO_FRAME})
    for (float offset : {0.f, .375f, -32.f}) for (bool nearest : {false, true})
    for (bool root : {false, true}) {
        auto expected = render(false, false, scale, flags, offset, nearest, root);
        for (bool strips : {false, true}) {
            auto actual = render(true, strips, scale, flags, offset, nearest, root);
            if (expected != actual) {
                std::fprintf(stderr, "Image batch mismatch scale=%d flags=%d offset=%g nearest=%d strips=%d root=%d\n",
                    scale, flags, offset, nearest, strips, root);
                return 1;
            }
            ++cases;
        }
    }
    std::printf("Image tile batching: %d exact native frame comparisons passed\n", cases);
}
