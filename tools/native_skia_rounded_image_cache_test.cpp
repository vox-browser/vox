// Deferred until the live FPS target, as requested by the user.
#include "../native_skia_text_darwin.cpp"
#include <cassert>

int main()
{
    constexpr int width = 256, height = 192;
    std::vector<uint32_t> pixels(size_t(width) * height, 0xff334455);
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    auto initial = pixels;
    auto rect = CGRectMake(0, 0, width, height);
    auto image = create_pixel_image(context, std::vector<uint32_t>(pixels), width, height);
    assert(image);
    Backdrop backdrop{reinterpret_cast<uint8_t const*>(pixels.data()), width * 4};
    for (int mode : {0, 1, 2, 3}) {
        clear_native_rounded_image_cache();
        std::vector<uint8_t> key{uint8_t(mode)};
        // First touch admits only the parameter key.
        { NativeRoundedImageCapture cache; cache.begin(context, rect, key, width, height, backdrop); assert(!cache.image()); }
        {
            NativeRoundedImageCapture cache;
            cache.begin(context, rect, key, width, height, backdrop);
            assert(!cache.image());
            if (mode == 0) composite_image(context, image, rect, true);
            if (mode == 1) { composite_image(context, image, rect, true); composite_image(context, image, rect, true); }
            if (mode == 2) composite_image(context, image, CGRectMake(1, 0, width - 1, height), true);
            // Mode three cancels before any publication.
        }
        pixels = initial;
        {
            NativeRoundedImageCapture cache;
            cache.begin(context, rect, key, width, height, backdrop);
            assert(bool(cache.image()) == (mode == 0));
            if (cache.image()) {
                auto bytes = CGDataProviderCopyData(CGImageGetDataProvider(cache.image()));
                assert(bytes && CFDataGetLength(bytes) == width * height * 4);
                CFRelease(bytes);
            }
        }
        pixels[13] ^= 1;
        { NativeRoundedImageCapture cache; cache.begin(context, rect, key, width, height, backdrop); assert(!cache.image()); }
        pixels = initial;
        { NativeRoundedImageCapture cache; cache.begin(context, rect, key, width, height, backdrop); assert(bool(cache.image()) == (mode == 0)); }
    }
    // Existing glyph admission keeps its old single-entry ceiling; the new
    // rounded cache opts into a separate, explicitly bounded large entry.
    GlyphRasterCache glyph;
    auto small = glyph.prepare({1}, width, height, backdrop.pixels, backdrop.pitch);
    assert(!small.pending);
    CGImageRelease(image);
    CGContextRelease(context);
    clear_native_rounded_image_cache();
}
