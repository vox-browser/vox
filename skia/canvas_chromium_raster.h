#pragma once

// Chromium's accelerated Canvas samples images on the GPU. Keep the raster
// implementation for ordinary LibWeb canvases and unsupported GPU commands.
#ifdef __APPLE__
#include "include/core/SkData.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkSerialProcs.h"
#include <cstring>
#include <dlfcn.h>

namespace {
constexpr size_t canvas_gpu_pixel_limit = 8 * 1024 * 1024;
using CanvasPictureDraw = int (*)(unsigned char*, int, int, int, void const*, size_t, float const*);

static bool canvas_gpu_size(int width, int height)
{
    return width > 0 && height > 0 && width <= 16384 && height <= 16384
        && size_t(width) * height <= canvas_gpu_pixel_limit;
}

static sk_sp<SkData> serialize_canvas_image(SkImage* image, void*)
{
    int dimensions[] { image->width(), image->height() };
    if (!canvas_gpu_size(dimensions[0], dimensions[1])) return nullptr;
    size_t pitch = size_t(dimensions[0]) * 4;
    auto bytes = SkData::MakeUninitialized(sizeof(dimensions) + pitch * dimensions[1]);
    auto* pixels = static_cast<uint8_t*>(bytes->writable_data());
    std::memcpy(pixels, dimensions, sizeof(dimensions));
    auto info = SkImageInfo::Make(dimensions[0], dimensions[1], kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    return image->readPixels(nullptr, info, pixels + sizeof(dimensions), pitch, 0, 0) ? bytes : nullptr;
}

static bool replay_canvas_image(uint8_t* pixels, int width, int height, int pitch,
    int alpha_type, VoxCanvasCommand const* command, CanvasPictureDraw draw)
{
    // The shared image protocol carries sRGB premultiplied bytes. Retain the
    // color-managed CPU path for wide-gamut inputs and runtime-effect blenders.
    if (!draw || !pixels || !command || command->operation != 2
        || !canvas_gpu_size(width, height) || pitch < width * 4
        || !canvas_gpu_size(command->style.pattern_width, command->style.pattern_height)
        || !command->style.pattern || command->style.pattern_pitch < command->style.pattern_width * 4
        || command->style.pattern_color_space != 0 || command->composite >= 26) return false;
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
    auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
        alpha_type == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto image = SkImages::RasterFromPixmapCopy(SkPixmap(info, pixels, pitch));
    if (!image) return false;
    SkPaint paint;
    paint.setBlendMode(SkBlendMode::kSrc);
    canvas->drawImage(image, 0, 0, SkSamplingOptions(), &paint);
    if (!draw_canvas_command(canvas, width, height, command)) return false;
    auto picture = recorder.finishRecordingAsPicture();
    SkSerialProcs procs;
    procs.fImageProc = serialize_canvas_image;
    auto bytes = picture->serialize(&procs);
    if (!bytes || bytes->size() > 64 * 1024 * 1024) return false;
    std::vector<uint8_t> result(size_t(width) * height * 4);
    float identity[] { 1, 0, 0, 0, 1, 0, 0, 0, 1 };
    if (!draw(result.data(), width, height, width * 4, bytes->data(), bytes->size(), identity)) return false;
    // Dawn publishes BGRA premultiplied pixels; the Canvas bitmap uses RGBA.
    // Commit only after a complete successful replay, preserving CPU fallback.
    for (int y = 0; y < height; ++y) {
        auto* source = result.data() + size_t(y) * width * 4;
        auto* destination = pixels + size_t(y) * pitch;
        for (int x = 0; x < width; ++x) {
            destination[x * 4] = source[x * 4 + 2];
            destination[x * 4 + 1] = source[x * 4 + 1];
            destination[x * 4 + 2] = source[x * 4];
            destination[x * 4 + 3] = source[x * 4 + 3];
        }
    }
    return true;
}
}
#endif

extern "C" bool vox_skia_canvas_path_chromium(uint8_t* pixels, int width, int height,
    int pitch, int alpha_type, VoxCanvasCommand const* command)
{
#ifdef __APPLE__
    static auto draw = [] {
        auto* library = dlopen("@rpath/libVoxGraphiteDawn.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<CanvasPictureDraw>(dlsym(library, "vox_graphite_draw_picture_pixels")) : nullptr;
    }();
    return replay_canvas_image(pixels, width, height, pitch, alpha_type, command, draw);
#else
    return false;
#endif
}
