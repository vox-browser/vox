#include "../native/include/native_initial_document_clear.h"
#include <cassert>
#include <cstdio>
#include <vector>

int main()
{
    int cases = 0, direct = 0;
    for (int scale : {1, 2}) for (int padding : {0, 16})
    for (int clipping : {0, 1, 2, 3}) for (int transform : {0, 1, 2})
    for (int color : {0, 1, 2}) for (int rgba : {0, 1}) {
        int width = 317 * scale, height = 183 * scale, pitch = width * 4 + padding;
        std::vector<uint8_t> expected(size_t(pitch) * height);
        for (size_t i = 0; i < expected.size(); ++i) expected[i] = uint8_t(i * 37 + i / 11);
        auto actual = expected;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
                rgba ? kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
                     : kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
            assert(context); CGContextScaleCTM(context, scale, scale);
            return context;
        };
        auto before = make(expected), after = make(actual);
        VoxInitialDocumentClear state {after, 317, 183};
        for (auto context : {before, after}) {
            if (clipping == 1) CGContextClipToRect(context, CGRectMake(7.25, 11.5, 143.5, 91.25));
            if (clipping == 2) {
                vox_initial_document_clear_disarm(&state, context);
                CGContextAddEllipseInRect(context, CGRectMake(0, 0, 317, 183));
                CGContextClip(context);
            }
            if (clipping == 3) CGContextClipToRect(context, CGRectZero);
            if (transform == 1) CGContextTranslateCTM(context, .25, -.5);
            if (transform == 2) CGContextScaleCTM(context, -1, 1);
            CGContextSetRGBFillColor(context, color == 1 ? 0 : 1, 1, 1, color == 2 ? .5 : 1);
        }
        auto rect = CGRectMake(0, 0, 317, 183);
        CGContextFillRect(before, rect);
        int used = vox_initial_document_clear(&state, after, rect, color == 1 ? 0 : 255,
            255, 255, color == 2 ? 128 : 255);
        if (!used) CGContextFillRect(after, rect);
        assert(used == (rgba && !clipping && !transform && !color));
        assert(!vox_initial_document_clear(&state, after, rect, 255, 255, 255, 255));
        CGContextFlush(before); CGContextFlush(after);
        assert(expected == actual);
        direct += used; ++cases;
        CGContextRelease(before); CGContextRelease(after); CGColorSpaceRelease(space);
    }
    assert(direct == 4);
    std::printf("Initial document clear: %d exact comparisons, %d direct clears, clips/transforms/formats/padding and one-shot ownership passed\n", cases, direct);
}
