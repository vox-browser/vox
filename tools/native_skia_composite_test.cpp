// Pixel parity against the previous BGRA provider, including clipping, color
// conversion, transparency and the fallback bitmap layout. No window is used.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static void legacy_composite(CGContextRef context, std::vector<uint32_t> const& pixels,
    int width, int height, CGRect destination)
{
    auto data = CFDataCreate(nullptr, reinterpret_cast<UInt8 const*>(pixels.data()), pixels.size() * 4);
    auto provider = CGDataProviderCreateWithCFData(data);
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto image = CGImageCreate(width, height, 8, 32, width * 4, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedFirst)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Little),
        provider, nullptr, false, kCGRenderingIntentDefault);
    assert(image);
    CGContextSaveGState(context);
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextDrawImage(context, destination, image);
    CGContextRestoreGState(context);
    CGImageRelease(image); CGColorSpaceRelease(color);
    CGDataProviderRelease(provider); CFRelease(data);
}

int main()
{
    int cases = 0;
    for (auto space : {kCGColorSpaceSRGB, kCGColorSpaceDisplayP3, kCGColorSpaceGenericRGBLinear})
    for (bool rgba : {false, true}) for (int scale : {1, 2}) for (int clip = 0; clip < 5; ++clip)
    for (auto blend : {kCGBlendModeNormal, kCGBlendModeCopy, kCGBlendModeMultiply}) {
        int width = 83 * scale, height = 67 * scale;
        auto color = CGColorSpaceCreateWithName(space);
        std::vector<uint8_t> expected(size_t(width) * height * 4), actual(expected.size());
        CGBitmapInfo info = rgba
            ? static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big)
            : static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedFirst) | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Little);
        auto before = CGBitmapContextCreate(expected.data(), width, height, 8, width * 4, color, info);
        auto after = CGBitmapContextCreate(actual.data(), width, height, 8, width * 4, color, info);
        CGColorSpaceRelease(color);
        assert(before && after);
        for (auto context : {before, after}) {
            CGContextScaleCTM(context, scale, scale);
            CGContextSetRGBFillColor(context, .25, .5, .75, .6);
            CGContextFillRect(context, CGRectMake(0, 0, 83, 67));
            if (clip == 1) CGContextClipToRect(context, CGRectMake(23.25, 17.5, 31.75, 28.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(context, CGRectMake(20.25, 13.75, 35.5, 31.25));
                CGContextClip(context);
            }
            if (clip == 3) {
                CGContextTranslateCTM(context, 9.25, 2.5);
                CGContextRotateCTM(context, .125);
            }
            if (clip == 4) CGContextClipToRect(context, CGRectZero);
            CGContextSetBlendMode(context, blend);
            CGContextSetAlpha(context, .85);
        }
        std::vector<uint32_t> pixels(41 * 23);
        for (int layer = 0; layer < 3; ++layer) {
            for (size_t i = 0; i < pixels.size(); ++i) {
                uint32_t alpha = (i * 37 + layer * 19) % 256;
                pixels[i] = alpha << 24 | (alpha / 2) << 16 | (alpha / 3) << 8 | alpha;
            }
            CGRect destination = CGRectMake(13.375 + layer * 3, 9.25 + layer * 7, 41.25, 23.75);
            legacy_composite(before, pixels, 41, 23, destination);
            assert(composite_pixels(after, pixels, 41, 23, destination.origin.x,
                destination.origin.y, destination.size.width, destination.size.height));
            std::fill(pixels.begin(), pixels.end(), 0); // Submitted images own their bytes.
        }
        CGContextFlush(before); CGContextFlush(after);
        if (expected != actual) {
            std::cerr << "Composite mismatch rgba=" << rgba << " scale=" << scale
                << " clip=" << clip << " blend=" << blend << '\n';
            return 1;
        }
        CGContextRelease(before); CGContextRelease(after);
        ++cases;
    }
    std::cout << "Native raster composite: " << cases << " exact pixel comparisons passed\n";
}
