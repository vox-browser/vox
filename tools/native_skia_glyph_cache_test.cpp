// Compare warm glyph replay with uncached rasterization, including live input
// mutations and Quartz state which is applied after the cached image is drawn.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    auto reference = &ladybird_v_skia_draw_glyph_run;
    if (auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY")) {
        auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        assert(library);
        reference = reinterpret_cast<decltype(reference)>(dlsym(library, "ladybird_v_skia_draw_glyph_run"));
        assert(reference);
    }
    int comparisons = 0;
    for (int scale : {1, 2}) for (int clip = 0; clip < 5; ++clip)
    for (int smoothing : {0, 1, 2, 3, 16, 18, 32, 48, 50, 51})
    for (auto space : {kCGColorSpaceSRGB, kCGColorSpaceDisplayP3}) {
        int width = 128 * scale, height = 96 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height), actual(expected.size());
        auto color_space = CGColorSpaceCreateWithName(space);
        auto make_context = [&](std::vector<uint8_t>& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color_space,
                static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                    | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
            assert(context);
            CGContextScaleCTM(context, scale, scale);
            if (clip == 1) CGContextClipToRect(context, CGRectMake(14.25, 22.5, 53.75, 31.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(context, CGRectMake(12.25, 20.5, 60.75, 37.25));
                CGContextClip(context);
            }
            if (clip == 3) {
                CGContextTranslateCTM(context, 4.5, 7.25);
                CGContextRotateCTM(context, .125);
            }
            if (clip == 4) CGContextClipToRect(context, CGRectZero);
            return context;
        };
        auto before = make_context(expected), after = make_context(actual);
        CGColorSpaceRelease(color_space);
        GlyphRasterCache candidate_cache;
        uint16_t glyphs[6] {36, 37, 38, 39, 40, 41};
        double positions[12] {0, 0, 11.5, 0, 22, 0, 34.25, 0, 46, 0, 57.5, 0};
        for (int step = 0; step < 24; ++step) {
            int mutation = step / 2;
            if (mutation == 2) glyphs[1] = 42;
            if (mutation == 3 && step % 2 == 0) positions[4] += .375;
            for (auto* pixels : {&expected, &actual}) {
                for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
                    auto* p = pixels->data() + size_t(y) * pitch + x * 4;
                    p[0] = 43; p[1] = 67; p[2] = 89; p[3] = mutation == 4 ? 128 : 255;
                }
                if (mutation == 5) (*pixels)[size_t(height / 2) * pitch + width * 2] = 93;
            }
            auto draw = [&](CGContextRef context, decltype(reference) function) {
                CGContextSetAlpha(context, mutation == 8 ? .65 : 1);
                CGContextSetBlendMode(context, mutation == 9 ? kCGBlendModeMultiply : kCGBlendModeNormal);
                return function(context, "/System/Library/Fonts/HelveticaNeue.ttc", mutation == 7 ? 1 : 0, glyphs, positions, mutation == 10 ? 5 : 6,
                    mutation == 6 ? 15.25 : 14, mutation == 7 ? 700 : 400, 0,
                    15.375, 46.25, 1, 0, mutation == 11 ? .125 : 0, 1, 0, 0,
                    0, 0, 0, 128, 96, 197, mutation == 1 ? 97 : 37, 83, 201, smoothing);
            };
            // The control always rasterizes, even when no older library is supplied.
            s_glyph_raster_cache.clear();
            if (!draw(before, reference)) {
                std::cerr << "Reference failed scale=" << scale << " clip=" << clip << " smoothing=" << smoothing << " mutation=" << mutation << '\n';
                return 1;
            }
            std::swap(s_glyph_raster_cache, candidate_cache);
            assert(draw(after, &ladybird_v_skia_draw_glyph_run));
            std::swap(s_glyph_raster_cache, candidate_cache);
            CGContextFlush(before); CGContextFlush(after);
            if (expected != actual) {
                std::cerr << "Glyph mismatch scale=" << scale << " clip=" << clip
                    << " smoothing=" << smoothing << " mutation=" << mutation << '\n';
                return 1;
            }
            ++comparisons;
        }
        CGContextRelease(before); CGContextRelease(after);
    }
    // Owned inputs, disabled/limited caches, eviction and explicit idle release.
    std::vector<uint32_t> pixels(16, 0xff235989u);
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(nullptr, 4, 4, 8, 16, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color);
    auto image = create_pixel_image(context, pixels, 4, 4);
    assert(image);
    GlyphRasterCache cache(150, 1), disabled(0);
    std::vector<uint8_t> key {1, 2, 3};
    auto request = cache.prepare(key, 4, 4, reinterpret_cast<uint8_t const*>(pixels.data()), 16);
    assert(!request.image && request.pending);
    cache.finish(std::move(request), image);
    assert(cache.prepare(key, 4, 4, reinterpret_cast<uint8_t const*>(pixels.data()), 16).image);
    assert(!cache.prepare(key, 2, 8, reinterpret_cast<uint8_t const*>(pixels.data()), 8).image);
    assert(!cache.prepare(key, 4, 4, nullptr, 0).image);
    std::vector<uint8_t> padded(20 * 4, 91);
    for (int y = 0; y < 4; ++y)
        std::memcpy(padded.data() + y * 20, pixels.data() + y * 4, 16);
    assert(cache.prepare(key, 4, 4, padded.data(), 20).image);
    padded[19]++;
    assert(cache.prepare(key, 4, 4, padded.data(), 20).image); // Row padding is irrelevant.
    pixels[15]++;
    assert(!cache.prepare(key, 4, 4, reinterpret_cast<uint8_t const*>(pixels.data()), 16).image);
    pixels[15]--;
    key[0]++;
    request = cache.prepare(key, 4, 4, reinterpret_cast<uint8_t const*>(pixels.data()), 16);
    cache.finish(std::move(request), image);
    key[0]--;
    assert(!cache.prepare(key, 4, 4, reinterpret_cast<uint8_t const*>(pixels.data()), 16).image); // LRU count limit.
    assert(!disabled.prepare(key, 4, 4, reinterpret_cast<uint8_t const*>(pixels.data()), 16).pending);
    cache.clear();
    assert(!cache.prepare(key, 4, 4, reinterpret_cast<uint8_t const*>(pixels.data()), 16).image);
    request = cache.prepare(key, 4, 4, nullptr, 0);
    cache.finish(std::move(request), nullptr);
    assert(!cache.prepare(key, 4, 4, nullptr, 0).image);
    request = cache.prepare(key, 4, 4, nullptr, 0);
    cache.finish(std::move(request), image);
    assert(cache.prepare(key, 4, 4, nullptr, 0).image);
    assert(!cache.prepare(key, 4, 4, padded.data(), 15).pending);
    assert(!cache.prepare(key, 400, 400, nullptr, 0).pending);
    ladybird_v_skia_release_unused_graphics_memory();
    CGImageRelease(image); CGContextRelease(context);
    std::cout << "Native glyph cache: " << comparisons << " exact replay comparisons passed\n";
}
