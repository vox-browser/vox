#include "../native/include/native_chromium_screen_blend.h"
#include "../native/include/native_graphite_bridge.h"
#include "../native/include/native_picture_image_transport.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkSerialProcs.h"
#include <cassert>
#include <cstdio>
#include <dlfcn.h>
#include <vector>
int main(int argc, char** argv)
{
    assert(argc == 2);
    auto* lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    assert(lib);
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_picture_pixels)>(dlsym(lib, "vox_graphite_draw_picture_pixels"));
    assert(draw);
    constexpr int width = 256, height = 256;
    std::vector<uint8_t> source(width * height * 4), dest(source.size()), actual(source.size()), expected(source.size());
    size_t failures = 0;
    for (bool translucent : { false, true }) {
        for (int y = 0; y < height; ++y)
            for (int x = 0; x < width; ++x) {
                size_t i = (y * width + x) * 4;
                int sa = translucent ? (x * 17 + y * 11) % 256 : 255, da = translucent ? (x * 13 + y * 29) % 256 : 255;
                source[i] = x % (sa + 1);
                source[i + 1] = (x * 7 + y * 11) % (sa + 1);
                source[i + 2] = (x * 31 + y * 19) % (sa + 1);
                source[i + 3] = sa;
                dest[i] = y % (da + 1);
                dest[i + 1] = (x * 23 + y * 37) % (da + 1);
                dest[i + 2] = (x * 3 + y * 41) % (da + 1);
                dest[i + 3] = da;
            }
        auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
        auto src = SkImages::RasterFromPixmapCopy(SkPixmap(info, source.data(), width * 4));
        auto dst = SkImages::RasterFromPixmapCopy(SkPixmap(info, dest.data(), width * 4));
        assert(src && dst);
        for (float opacity : { 0.0f, .01f, .25f, .5f, .85f, .999f, 1.0f }) {
            SkPictureRecorder recorder;
            auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
            canvas->drawImage(dst, 0, 0);
            SkPaint paint;
            paint.setBlendMode(SkBlendMode::kScreen);
            paint.setAlphaf(opacity);
            canvas->drawImage(src, 0, 0, SkSamplingOptions(), &paint);
            SkSerialProcs procs;
            procs.fImageProc = [](SkImage* image, void*) -> sk_sp<SkData const> { return vox_encode_picture_image(image); };
            auto bytes = recorder.finishRecordingAsPicture()->serialize(&procs);
            assert(bytes);
            float identity[] = { 1, 0, 0, 0, 1, 0, 0, 0, 1 };
            assert(draw(actual.data(), width, height, width * 4, bytes->data(), bytes->size(), identity));
            native_composite_screen_pixels(source.data(), dest.data(), expected.data(), width * height, opacity);
            size_t different = 0;
            for (size_t i = 0; i < actual.size(); i += 4)
                for (int c = 0; c < 4; ++c) {
                    int b = c == 0 ? 2 : c == 2 ? 0
                                                : c;
                    if (actual[i + b] != expected[i + c]) {
                        if (different < 2)
                            std::printf("first trans=%d op=%g pixel=%zu channel=%d GPU=%u CPU=%u\n", translucent, opacity, i / 4, c, actual[i + b], expected[i + c]);
                        ++different;
                    }
                }
            failures += different;
            std::printf("translucent=%d opacity=%g different_channels=%zu\n", translucent, opacity, different);
        }
    }
    std::printf("14 screen composites / 917504 pixels checked against independent GPU pictures\n");
    return failures ? 1 : 0;
}
