// Actual Metal cache-lifetime regressions. No browser or window is created.
// Build against the same two private Skia bridges as the browser.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <array>
#include <cstdio>
#include <thread>

template<typename Function> Function symbol(void* library, char const* name)
{
    auto function = reinterpret_cast<Function>(dlsym(library, name));
    assert(function);
    return function;
}

static std::vector<uint8_t> graphite_case(void* library, int kind, int scale)
{
    int width = 64 * scale, height = 48 * scale, pitch = width * 4;
    std::vector<uint8_t> pixels(static_cast<size_t>(pitch) * height);
    for (size_t index = 0; index < pixels.size(); index += 4) {
        pixels[index] = 31; pixels[index + 1] = 63;
        pixels[index + 2] = 97; pixels[index + 3] = 255;
    }
    int result = 0;
    if (kind == 0) {
        VoxGraphiteShadow shadow {};
        float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
        std::copy_n(matrix, 9, shadow.matrix);
        float outer[] {6, 5, 52, 38, 6, 6, 6, 6, 6, 6, 6, 6};
        float inner[] {13, 12, 38, 24, 4, 4, 4, 4, 4, 4, 4, 4};
        std::copy_n(outer, 12, shadow.shadow);
        std::copy_n(inner, 12, shadow.content);
        shadow.blur = 5; shadow.red = 190; shadow.green = 55; shadow.blue = 84; shadow.alpha = 197;
        result = symbol<decltype(&vox_graphite_draw_shadow_pixels)>(library,
            "vox_graphite_draw_shadow_pixels")(pixels.data(), width, height, pitch, 1, &shadow);
    } else if (kind == 1) {
        // The caller's immutable CPU image stays alive across backend teardown
        // and recreation, as retained browser image pixels do.
        static const auto source = [] {
            std::array<uint8_t, 8 * 8 * 4> data {};
            for (size_t index = 0; index < data.size(); index += 4) {
                data[index] = uint8_t(index * 13); data[index + 1] = uint8_t(index * 7);
                data[index + 2] = uint8_t(index * 3); data[index + 3] = 255;
            }
            return data;
        }();
        VoxGraphiteImage image {};
        float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
        std::copy_n(matrix, 9, image.matrix);
        float src[] {0, 0, 8, 8}, dst[] {7, 6, 49, 35};
        float clip[] {1, 1, 62, 46, 3, 3, 3, 3, 3, 3, 3, 3};
        std::copy_n(src, 4, image.source); std::copy_n(dst, 4, image.destination);
        std::copy_n(clip, 12, image.clip);
        image.opacity = .8f; image.width = 8; image.height = 8; image.pitch = 32; image.pixels = source.data();
        result = symbol<decltype(&vox_graphite_draw_image_pixels)>(library,
            "vox_graphite_draw_image_pixels")(pixels.data(), width, height, pitch, 1, &image);
    } else if (kind == 2) {
        VoxGraphiteShape shape {};
        float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
        float rect[] {6.25f, 5.5f, 51, 37, 7, 7, 3, 3, 5, 5, 2, 2};
        std::copy_n(matrix, 9, shape.matrix); std::copy_n(rect, 12, shape.rect);
        shape.thickness = 2; shape.red = 23; shape.green = 161; shape.blue = 211; shape.alpha = 201;
        shape.fill = 1; shape.anti_alias = 1; shape.force_msaa = 1;
        result = symbol<decltype(&vox_graphite_draw_shape_pixels)>(library,
            "vox_graphite_draw_shape_pixels")(pixels.data(), width, height, pitch, 1, &shape);
    } else {
        float segments[] {
            0, 7.25f, 6.5f, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            3, 55.5f, 18.25f, 19, 1, 49, 2, 0, 0, 0, 0, 0,
            1, 47.5f, 40.5f, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 13, 35, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        };
        VoxGraphitePath path {};
        float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
        std::copy_n(matrix, 9, path.matrix);
        path.segments = segments; path.segment_count = 5; path.red = 170;
        path.green = 40; path.blue = 110; path.alpha = 213;
        result = symbol<decltype(&vox_graphite_draw_path_pixels)>(library,
            "vox_graphite_draw_path_pixels")(pixels.data(), width, height, pitch, 1, &path);
    }
    assert(result == 1);
    bool changed = false;
    for (size_t index = 0; index < pixels.size(); index += 4)
        changed |= pixels[index] != 31 || pixels[index + 1] != 63 || pixels[index + 2] != 97;
    assert(changed);
    return pixels;
}

static void check_live_ganesh_image_and_font(int scale)
{
    auto* gpu = image_gpu_context();
    assert(gpu);
    auto info = SkImageInfo::MakeN32Premul(64 * scale, 48 * scale);
    auto surface = SkSurfaces::RenderTarget(gpu, skgpu::Budgeted::kYes, info);
    assert(surface);
    auto typeface = font_manager()->matchFamilyStyle("Arial", SkFontStyle());
    assert(typeface);
    SkFont font(typeface, 12 * scale);
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorWHITE);
    SkPaint paint;
    paint.setColor(SK_ColorBLUE);
    canvas->drawCircle(23 * scale, 24 * scale, 17 * scale, paint);
    paint.setColor(SK_ColorBLACK);
    canvas->drawSimpleText("Held", 4, SkTextEncoding::kUTF8, 6 * scale, 30 * scale, font, paint);
    auto image = surface->makeImageSnapshot();
    assert(image && image->isTextureBacked());
    std::vector<uint8_t> before(info.computeMinByteSize()), after(before.size());
    assert(image->readPixels(gpu, info, before.data(), info.minRowBytes(), 0, 0));
    ladybird_v_skia_release_unused_graphics_memory();
    ladybird_v_skia_release_unused_graphics_memory();
    assert(s_image_gpu_context.get() == gpu && !gpu->unique());
    assert(image->readPixels(gpu, info, after.data(), info.minRowBytes(), 0, 0));
    assert(before == after);
    // The live font/typeface and surface remain usable after global cache eviction.
    canvas->clear(SK_ColorWHITE);
    paint.setColor(SK_ColorBLUE);
    canvas->drawCircle(23 * scale, 24 * scale, 17 * scale, paint);
    paint.setColor(SK_ColorBLACK);
    canvas->drawSimpleText("Held", 4, SkTextEncoding::kUTF8, 6 * scale, 30 * scale, font, paint);
    assert(surface->readPixels(info, after.data(), info.minRowBytes(), 0, 0));
    assert(before == after);
}

static void check_idle_ganesh_context_and_cpu_inputs(int scale)
{
    auto typeface = font_manager()->matchFamilyStyle("Arial", SkFontStyle());
    assert(typeface);
    uint32_t source_pixels[64];
    for (int index = 0; index != 64; ++index)
        source_pixels[index] = 0xff000000u | uint32_t(index * 16387);
    auto source = SkImages::RasterFromPixmapCopy(
        SkPixmap(SkImageInfo::MakeN32Premul(8, 8), source_pixels, 32));
    assert(source && !source->isTextureBacked());
    auto draw = [&] {
        auto info = SkImageInfo::MakeN32Premul(64 * scale, 48 * scale);
        auto surface = SkSurfaces::RenderTarget(image_gpu_context(), skgpu::Budgeted::kYes, info);
        assert(surface);
        auto* canvas = surface->getCanvas();
        canvas->clear(SK_ColorWHITE);
        canvas->drawImage(source, 7 * scale, 6 * scale);
        SkPaint paint;
        paint.setColor(SK_ColorBLACK);
        SkFont font(typeface, 12 * scale);
        canvas->drawSimpleText("Held", 4, SkTextEncoding::kUTF8, 6 * scale, 30 * scale, font, paint);
        std::vector<uint8_t> pixels(info.computeMinByteSize());
        assert(surface->readPixels(info, pixels.data(), info.minRowBytes(), 0, 0));
        return pixels;
    };
    auto before = draw();
    assert(s_image_gpu_context->getResourceCacheLimit() == 64 * 1024 * 1024);
    ladybird_v_skia_release_idle_graphics_memory();
    assert(s_image_gpu_context);
    s_image_gpu_context_last_use = std::chrono::steady_clock::now() - std::chrono::seconds(3);
    ladybird_v_skia_release_idle_graphics_memory();
    assert(!s_image_gpu_context && !s_image_gpu_context_attempted);
    assert(before == draw());
    ladybird_v_skia_release_unused_graphics_memory();
    assert(!s_image_gpu_context && !s_image_gpu_context_attempted);
    ladybird_v_skia_release_unused_graphics_memory();
    assert(!s_image_gpu_context && !s_image_gpu_context_attempted);
    assert(before == draw());
    assert(source && !source->isTextureBacked() && typeface);
    ladybird_v_skia_release_unused_graphics_memory();
    assert(!s_image_gpu_context && !s_image_gpu_context_attempted);
}

int main(int argc, char** argv)
{
    assert(argc == 2 && pthread_main_np());
    assert(!s_image_gpu_context_attempted && !s_image_gpu_context);
    assert(!dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD));
    ladybird_v_skia_release_unused_graphics_memory();
    ladybird_v_skia_release_unused_graphics_memory();
    assert(!s_image_gpu_context_attempted && !s_image_gpu_context);
    assert(!dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD));
    void* library = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
    assert(library);
    auto graphite_purge = symbol<decltype(&vox_graphite_release_unused_graphics_memory)>(
        library, "vox_graphite_release_unused_graphics_memory");
    // A loaded but unused Graphite backend also accepts repeated cleanup.
    graphite_purge(); graphite_purge();
    for (int scale : {1, 2}) {
        for (int kind = 0; kind != 4; ++kind) {
            auto before = graphite_case(library, kind, scale);
            ladybird_v_skia_release_unused_graphics_memory();
            graphite_purge();
            assert(before == graphite_case(library, kind, scale));
            std::printf("Graphite primitive %d scale %d: identical pixels after repeated purge\n", kind, scale);
        }
        check_live_ganesh_image_and_font(scale);
        std::printf("Ganesh held Metal image/font scale %d: identical pixels and redraw\n", scale);
        check_idle_ganesh_context_and_cpu_inputs(scale);
        std::printf("Ganesh idle Context scale %d: released and recreated with retained CPU inputs\n", scale);
    }
    // Reject non-owner use without touching either context.
    graphite_purge();
    auto idle_purge = symbol<decltype(&vox_graphite_release_idle_graphics_memory)>(library,
        "vox_graphite_release_idle_graphics_memory");
    auto cached_pixels = graphite_case(library, 1, 1);
    assert(idle_purge() == 0);
    std::this_thread::sleep_for(std::chrono::milliseconds(2100));
    assert(idle_purge() == 1);
    assert(idle_purge() == 0);
    assert(cached_pixels == graphite_case(library, 1, 1));
    assert(idle_purge() == 0); // CPU cache hit did not recreate a GPU context.
    puts("Graphite idle context retired while CPU raster cache stayed reusable.");
    auto retained_cpu_pixels = graphite_case(library, 3, 1);
    auto* retained_gpu = image_gpu_context();
    assert(retained_gpu);
    std::thread worker([graphite_purge] {
        ladybird_v_skia_release_unused_graphics_memory();
        graphite_purge();
    });
    worker.join();
    assert(s_image_gpu_context.get() == retained_gpu && s_image_gpu_context_attempted);
    assert(retained_cpu_pixels == graphite_case(library, 3, 1));
    graphite_purge();
    ladybird_v_skia_release_unused_graphics_memory();
    assert(!s_image_gpu_context && !s_image_gpu_context_attempted);
    dlclose(library);
    puts("Native graphics cache lifetime checks passed.");
    return 0;
}
