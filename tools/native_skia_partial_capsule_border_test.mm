// Replay the V fixture's snapped geometry through the production border helper.
#import <Foundation/Foundation.h>
#include <ImageIO/ImageIO.h>
#include "../native_graphite_bridge.h"
#include "../native_rounded_single_border.h"
#include "include/core/SkData.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkShader.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

int main(int argc, char** argv)
{
    @autoreleasepool {
        assert(argc == 3);
        auto library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        auto draw = library ? reinterpret_cast<decltype(&vox_graphite_draw_picture_pixels)>(
            dlsym(library, "vox_graphite_draw_picture_pixels")) : nullptr;
        assert(draw);
        constexpr int width = 1024, height = 768, pitch = width * 4;
        std::vector<uint8_t> expected(size_t(pitch) * height);
        auto url = CFURLCreateFromFileSystemRepresentation(nullptr,
            reinterpret_cast<UInt8 const*>(argv[2]), std::strlen(argv[2]), false);
        auto source = CGImageSourceCreateWithURL(url, nullptr);
        auto image = source ? CGImageSourceCreateImageAtIndex(source, 0, nullptr) : nullptr;
        assert(image && CGImageGetWidth(image) == width && CGImageGetHeight(image) == height);
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(expected.data(), width, height, 8, pitch, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(context);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        CGContextRelease(context);
        CGColorSpaceRelease(space);
        CGImageRelease(image);
        CFRelease(source);
        CFRelease(url);
        for (int repeat = 0; repeat < 2; ++repeat) {
            SkPictureRecorder recorder;
            auto* canvas = recorder.beginRecording(width, height);
            canvas->clear(SK_ColorWHITE);
            constexpr float origins[] {22, 221, 420, 620};
            for (int row = 0; row < 2; ++row) for (int column = 0; column < 4; ++column) {
                float x = origins[column];
                float y = row ? 180 : 94, h = row ? 46 : 30;
                float w = column == 3 ? 111 : 110;
                float radius = column == 3 ? 14 : h / 2;
                bool mirror = column == 2;
                SkVector corners[4] {};
                corners[mirror ? 0 : 1] = corners[mirror ? 3 : 2] = {radius - 1, radius - 1};
                SkRRect background;
                background.setRectRadii(SkRect::MakeXYWH(x + (mirror ? 1 : 0), y + 1, w - 1, h - 2), corners);
                SkPaint paint;
                paint.setAntiAlias(true);
                paint.setColor(SkColorSetRGB(45, 44, 46));
                canvas->drawRRect(background, paint);
                corners[mirror ? 0 : 1] = corners[mirror ? 3 : 2] = {radius, radius};
                SkRRect border;
                border.setRectRadii(SkRect::MakeXYWH(x, y, w, h), corners);
                // V retains normalized components for this complex border.
                paint.setColor4f({float(224.0 / 255), float(223.0 / 255), float(224.0 / 255), 1});
                float widths[] {2, mirror ? 0.f : 2.f, 2, mirror ? 2.f : 0.f};
                vox_draw_rounded_single_border(canvas, border, paint, 8, widths);
            }
            // Keep the owning Chromium tile's MSAA choice, even if a backend
            // optimizes the clips into analytic draws.
            SkPaint noop;
            noop.setAntiAlias(true);
            noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
            SkPathBuilder path;
            path.moveTo(0, 0).cubicTo(width, 77, 0, height, width, height).lineTo(512, 154).close();
            canvas->drawPath(path.detach(), noop);
            auto picture = recorder.finishRecordingAsPicture();
            auto bytes = picture->serialize();
            std::vector<uint8_t> actual(expected.size(), 255);
            float matrix[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
            assert(draw(actual.data(), width, height, pitch, bytes->data(), bytes->size(), matrix));
            size_t differences = 0;
            for (size_t i = 0; i < actual.size(); i += 4) {
                std::swap(actual[i], actual[i + 2]); // Graphite exports BGRA.
                differences += std::memcmp(actual.data() + i, expected.data() + i, 4) != 0;
            }
            std::printf("Capsule borders, replay %d: %zu differing pixels\n", repeat, differences);
            if (differences) return 1;
        }
    }
    return 0;
}
