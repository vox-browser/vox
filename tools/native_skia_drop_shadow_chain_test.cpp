#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    int cases = 0;
    for (int scale : { 1, 2 }) {
        const int size = 96 * scale;
        auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        std::vector<uint32_t> source_pixels(size * size);
        auto source_context = CGBitmapContextCreate(source_pixels.data(), size, size,
            8, size * 4, color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        assert(source_context);
        CGContextSetRGBFillColor(source_context, 1, 1, 1, 1);
        // Quartz uses a bottom-left origin; the filter bridge consumes a
        // top-down source bitmap, as the document painter supplies it.
        CGContextFillRect(source_context, CGRectMake(32 * scale, (96 - 32 - 8) * scale,
            8 * scale, 8 * scale));
        auto source = CGBitmapContextCreateImage(source_context);
        assert(source);
        for (bool reverse : { false, true }) {
            std::vector<uint8_t> pixels(size * size * 4);
            auto destination = CGBitmapContextCreate(pixels.data(), size, size, 8,
                size * 4, color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            assert(destination);
            CGContextScaleCTM(destination, scale, scale);
            // The second shadow reaches pixels occupied by the first shadow.
            // Independent shadows or the opposite operation order cannot pass.
            const float red[] = { 16, 0, 0, 1, 0, 0, 1 };
            const float blue[] = { -8, 0, 0, 0, 0, 1, 1 };
            float shadows[14];
            std::copy_n(reverse ? blue : red, 7, shadows);
            std::copy_n(reverse ? red : blue, 7, shadows + 7);
            assert(ladybird_v_skia_draw_drop_shadow_chain(destination, source,
                96, 96, scale, shadows, 2));
            CGContextFlush(destination);
            auto expect = [&](int x, int y, uint8_t r, uint8_t g, uint8_t b) {
                auto offset = (y * scale * size + x * scale) * 4;
                if (pixels[offset] != r || pixels[offset + 1] != g
                    || pixels[offset + 2] != b || pixels[offset + 3] != 255) {
                    std::cerr << "scale=" << scale << " reverse=" << reverse
                              << " at " << x << ',' << y << " actual="
                              << int(pixels[offset]) << ',' << int(pixels[offset + 1])
                              << ',' << int(pixels[offset + 2]) << ',' << int(pixels[offset + 3])
                              << " expected=" << int(r) << ',' << int(g) << ',' << int(b) << ",255\n";
                }
                assert(pixels[offset] == r && pixels[offset + 1] == g
                    && pixels[offset + 2] == b && pixels[offset + 3] == 255);
            };
            expect(35, 35, 255, 255, 255);
            expect(51, 35, 255, 0, 0);
            expect(27, 35, 0, 0, 255);
            expect(43, 35, reverse ? 255 : 0, 0, reverse ? 0 : 255);
            // A third green shadow is generated from both preceding shadows.
            // Its diagonal output proves that the graph retains the full input.
            float three[21];
            std::copy_n(shadows, 14, three);
            const float green[] = { 0, 16, 0, 0, 1, 0, 1 };
            std::copy_n(green, 7, three + 14);
            assert(ladybird_v_skia_draw_drop_shadow_chain(destination, source,
                96, 96, scale, three, 3));
            CGContextFlush(destination);
            expect(51, 51, 0, 255, 0);
            expect(27, 51, 0, 255, 0);
            CGContextRelease(destination);
            ++cases;
        }
        assert(!ladybird_v_skia_draw_drop_shadow_chain(source_context, source, 96, 96, scale, nullptr, 0));
        CGImageRelease(source);
        CGContextRelease(source_context);
        CGColorSpaceRelease(color_space);
    }
    std::cout << "Native chained drop shadows: " << cases << " cases passed\n";
}
