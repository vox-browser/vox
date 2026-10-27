#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static void check_blur_padding(int scale, float alpha)
{
    s_chromium_painting = true;
    auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto render = [&](int chrome_top, int chrome_bottom) {
        int width = 1024 * scale, height = (768 + chrome_top + chrome_bottom) * scale;
        std::vector<uint8_t> source_pixels(static_cast<size_t>(width) * height * 4);
        auto source_context = CGBitmapContextCreate(source_pixels.data(), width, height,
            8, width * 4, color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        assert(source_context);
        CGContextScaleCTM(source_context, scale, scale);
        CGContextSetRGBFillColor(source_context, 252 / 255., 253 / 255., 1, alpha);
        auto path = CGPathCreateWithRoundedRect(CGRectMake(648, chrome_bottom + 24, 352, 120),
            16, 16, nullptr);
        CGContextAddPath(source_context, path);
        CGContextFillPath(source_context);
        CGPathRelease(path);
        auto source = CGBitmapContextCreateImage(source_context);
        assert(source);
        std::vector<uint8_t> result(source_pixels.size());
        auto destination = CGBitmapContextCreate(result.data(), width, height, 8, width * 4,
            color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        assert(destination);
        CGContextScaleCTM(destination, scale, scale);
        CGContextSetRGBFillColor(destination, 247 / 255., 248 / 255., 252 / 255., alpha);
        CGContextFillRect(destination, CGRectMake(0, 0, 1024, 768 + chrome_top + chrome_bottom));
        const float shadows[] {0, 0, 1, 41 / 255.f, 42 / 255.f, 46 / 255.f, .12f,
            0, 4, 16, 41 / 255.f, 42 / 255.f, 46 / 255.f, .08f};
        assert(ladybird_v_skia_draw_drop_shadow_chain(destination, source, 1024,
            768 + chrome_top + chrome_bottom, scale, shadows, 2));
        CGContextFlush(destination);
        std::vector<uint8_t> document(result.begin() + static_cast<size_t>(chrome_top * scale) * width * 4,
            result.begin() + static_cast<size_t>((chrome_top + 768) * scale) * width * 4);
        CGContextRelease(destination);
        CGImageRelease(source);
        CGContextRelease(source_context);
        return document;
    };
    auto document = render(0, 0);
    auto chrome = render(60, 24);
    size_t different = 0;
    for (size_t i = 0; i < document.size(); ++i)
        different += document[i] != chrome[i];
    if (different)
        std::cerr << "Blur changed with transparent padding: scale=" << scale
                  << " alpha=" << alpha << " channels=" << different << '\n';
    assert(different == 0);
    CGColorSpaceRelease(color_space);
}

int main(int argc, char** argv)
{
    int cases = 0;
    if (argc > 1) {
        assert(argc == 2 && std::string(argv[1]) == "--require-gpu");
        assert(shared_picture_draw());
        SkPictureRecorder recorder;
        recorder.beginRecording(SkRect::MakeWH(1, 1))->clear(SK_ColorRED);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        uint8_t pixel[4] {};
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(pixel, 1, 1, 4, bytes->data(), bytes->size(), identity));
        assert(pixel[0] == 0 && pixel[1] == 0 && pixel[2] == 255 && pixel[3] == 255);
        for (int scale : {1, 2}) for (float alpha : {1.f, .5f}) {
            check_blur_padding(scale, alpha);
            ++cases;
        }
    }
    for (bool chromium : { false, true }) for (int scale : { 1, 2 }) {
        s_chromium_painting = chromium;
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
                    std::cerr << "chromium=" << chromium << " scale=" << scale << " reverse=" << reverse
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
