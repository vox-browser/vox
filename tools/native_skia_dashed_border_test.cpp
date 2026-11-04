// The authored border fixture is an independent Brave GPU pixel reference.
// Exercise both orientations and widths, plus solid and compressed short lines.
#include "../native_skia_text_darwin.cpp"
#include <ImageIO/ImageIO.h>
#include <cassert>
#include <cstdio>

static std::vector<double> intervals(float length, float thickness)
{
    float dash = thickness * (thickness >= 3 ? 2 : 3);
    float gap = thickness * (thickness >= 3 ? 1 : 2);
    if (length <= dash * 2) return {};
    if (length <= dash * 2 + gap) {
        float multiplier = length / (dash * 2 + gap);
        return {dash * multiplier, gap * multiplier};
    }
    float minimum = std::floor((length + gap) / (dash + gap));
    float maximum = minimum + 1;
    float min_gap = (length - minimum * dash) / (minimum - 1);
    float max_gap = (length - maximum * dash) / (maximum - 1);
    return {dash, max_gap <= 0 || std::abs(min_gap - gap) < std::abs(max_gap - gap) ? min_gap : max_gap};
}

int main(int argc, char** argv)
{
    assert(graphite_dashed_path_draw());
    constexpr int width = 1024, height = 768;
    auto url = CFURLCreateWithFileSystemPath(nullptr,
        CFSTR("Tests/Browser/Brave/expected/chromium-single-dashed-border.png"), kCFURLPOSIXPathStyle, false);
    auto source = CGImageSourceCreateWithURL(url, nullptr);
    CFRelease(url); assert(source);
    auto reference = CGImageSourceCreateImageAtIndex(source, 0, nullptr);
    CFRelease(source); assert(reference);
    assert(CGImageGetWidth(reference) == width && CGImageGetHeight(reference) == height);
    std::vector<uint8_t> expected(width * height * 4, 255), actual(expected.size(), 255);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto reference_context = CGBitmapContextCreate(expected.data(), width, height, 8, width * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    assert(reference_context);
    CGContextDrawImage(reference_context, CGRectMake(0, 0, width, height), reference);
    CGContextFlush(reference_context);
    CGContextRelease(reference_context); CGImageRelease(reference);
    auto destination = CGBitmapContextCreate(actual.data(), width, height, 8, width * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); assert(destination);
    ladybird_v_skia_set_chromium_painting(argc > 1 && !std::strcmp(argv[1], "cpu") ? 0 : 1);
    float color[] {34.f / 255, 34.f / 255, 34.f / 255, .2f};
    auto line = [&](float x, float y, float length, float thickness, bool vertical) {
        float path[24] {};
        path[1] = x + (vertical ? thickness / 2 : 0);
        path[2] = y + (vertical ? 0 : thickness / 2);
        path[12] = 1;
        path[13] = path[1] + (vertical ? 0 : length);
        path[14] = path[2] + (vertical ? length : 0);
        auto dash = intervals(length, thickness);
        assert(ladybird_v_skia_draw_svg_path_with_colors(destination, path, 2, 0,
            1, 0, 0, 1, 0, 0, 0, 0, 0, width, height,
            0, 0, 0, 0, 0, 34, 34, 34, 51, 1, thickness, 0, 0, 4, 0,
            dash.data(), int(dash.size()), 0, 1, nullptr, argc > 1 ? nullptr : color));
    };
    int index = 0;
    for (float thickness : {1.f, 2.f, 3.f, 4.f, 6.f}) {
        line(24, 24 + index * 58, 198, thickness, false);
        line(300 + index * 58, 24, 198, thickness, true);
        ++index;
    }
    index = 0;
    for (float length : {7.f, 6.f, 8.f, 9.f, 14.f}) line(24, 380 + index++ * 36, length, 1, false);
    CGContextFlush(destination);
    size_t different = 0;
    int maximum = 0;
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* a = actual.data() + ((height - y - 1) * width + x) * 4;
        auto* b = expected.data() + ((height - y - 1) * width + x) * 4;
        bool changed = false;
        for (int c = 0; c < 4; ++c) { changed |= a[c] != b[c]; maximum = std::max(maximum, std::abs(a[c] - b[c])); }
        different += changed;
    }
    CGContextRelease(destination);
    std::printf("Dashed border fixture: %zu differing pixels, max channel %d\n", different, maximum);
    return different ? 1 : 0;
}
