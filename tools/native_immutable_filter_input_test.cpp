#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint8_t> render(bool optimized, int scale, float sigma, int alpha,
    bool tagged, bool padded, bool shadow)
{
    int w = 96 * scale, h = 64 * scale, pitch = w * 4 + (padded ? 16 : 0);
    std::vector<uint8_t> source(size_t(pitch) * h, 0), output(size_t(pitch) * h, 0xa5);
    for (int y = 0; y < h; ++y) for (int x = 0; x < w; ++x) {
        auto* p = source.data() + size_t(y) * pitch + x * 4;
        p[3] = x > 11 && x < w - 17 && y > 9 && y < h - 13 ? alpha : 0;
        p[0] = (x * 7 + y * 13) % (p[3] + 1); p[1] = (x * 11) % (p[3] + 1);
        p[2] = (y * 3) % (p[3] + 1);
        auto* q = output.data() + size_t(y) * pitch + x * 4;
        q[0] = x % 121; q[1] = y % 127; q[2] = 29; q[3] = 173;
    }
    auto space = CGColorSpaceCreateWithName(tagged ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    auto input = CGBitmapContextCreate(source.data(), w, h, 8, pitch, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); assert(input);
    auto image = CGBitmapContextCreateImage(input); assert(image);
    VoxImmutableRGBAImage bytes;
    assert(bytes.load(image) == !tagged);
    if (!tagged) {
        assert(!bytes.load(image));
        assert(!std::memcmp(bytes.pixels(), source.data(), source.size()));
        // The immutable lease must remain valid after the source is changed.
        CGContextClearRect(input, CGRectMake(0, 0, w, h));
        assert(bytes.pixels()[size_t(16) * pitch + 16 * 4 + 3] == alpha);
    }
    CGContextRelease(input);
    auto srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto destination = CGBitmapContextCreate(output.data(), w, h, 8, pitch, srgb,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(srgb); assert(destination);
    CGContextScaleCTM(destination, scale, scale);
    if (optimized) {
        unsetenv("VOX_DISABLE_IMMUTABLE_FILTER_INPUT");
        unsetenv("VOX_DISABLE_FILTER_ALPHA_BOUNDS");
    } else {
        setenv("VOX_DISABLE_IMMUTABLE_FILTER_INPUT", "1", 1);
        setenv("VOX_DISABLE_FILTER_ALPHA_BOUNDS", "1", 1);
    }
    ladybird_v_skia_set_chromium_painting(1);
    if (shadow) {
        float shadows[] {2.25f, -1.5f, sigma, .3f, .7f, .2f, .6f};
        assert(ladybird_v_skia_draw_drop_shadow_chain(destination, image, 96, 64, scale, shadows, 1));
    } else assert(ladybird_v_skia_draw_css_blur(destination, image, 96, 64, scale, sigma));
    CGImageRelease(image); CGContextFlush(destination); CGContextRelease(destination);
    for (int y = 0; y < h; ++y) for (int x = w * 4; x < pitch; ++x)
        assert(output[size_t(y) * pitch + x] == 0xa5);
    return output;
}

int main()
{
    assert(shared_picture_draw());
    auto srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    std::vector<uint8_t> source(32 * 3, 0x44);
    auto provider = CGDataProviderCreateWithData(nullptr, source.data(), source.size(), nullptr);
    for (auto format : {CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big,
            CGBitmapInfo(kCGImageAlphaLast) | kCGBitmapByteOrder32Big,
            CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little,
            CGBitmapInfo(kCGImageAlphaNoneSkipLast) | kCGBitmapByteOrder32Big}) {
        auto image = CGImageCreate(4, 3, 8, 32, 32, srgb, format, provider,
            nullptr, false, kCGRenderingIntentDefault);
        assert(image);
        VoxImmutableRGBAImage bytes;
        bool accepted = format == (CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(bytes.load(image) == accepted);
        CGImageRelease(image);
        if (accepted) assert(bytes.pixels()[95] == 0x44);
    }
    CGDataProviderRelease(provider); CGColorSpaceRelease(srgb);
    unsigned cases = 0;
    for (int scale : {1, 2}) for (float sigma : {.3f, 3.f, 19.f})
    for (int alpha : {0, 173, 255}) for (bool tagged : {false, true})
    for (bool padded : {false, true}) for (bool shadow : {false, true}) {
        assert(render(false, scale, sigma, alpha, tagged, padded, shadow)
            == render(true, scale, sigma, alpha, tagged, padded, shadow));
        ++cases;
    }
    std::cout << cases << " immutable filter input scenes preserve pixels, row padding, ownership and tagged fallback\n";
}
