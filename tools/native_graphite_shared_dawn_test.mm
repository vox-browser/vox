#include "../native_graphite_dawn_darwin.mm"
#include "include/core/SkPictureRecorder.h"
#include "include/effects/SkGradient.h"
#include "src/gpu/graphite/dawn/DawnGraphiteUtils.h"
#include <cassert>
#include <mach/mach.h>
#include <libproc.h>
#include <sys/resource.h>

static sk_sp<SkData> picture(float phase, bool image, bool tagged) {
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(193, 137));
    SkPaint paint;
    paint.setAntiAlias(true);
    SkPoint points[] {{3, 9}, {189, 131}};
    SkColor4f colors[] {SkColor4f::FromColor(0x9f1537cd), SkColor4f::FromColor(0xc7b9345e),
        SkColor4f::FromColor(0x5927ba41)};
    SkGradient gradient(SkGradient::Colors(SkSpan<const SkColor4f>(colors), SkTileMode::kClamp), {});
    paint.setShader(SkShaders::LinearGradient(points, gradient));
    canvas->drawRoundRect(SkRect::MakeXYWH(5.25f + phase, 11.5f, 179, 117), 13.25f, 9.5f, paint);
    if (image) {
        std::vector<uint32_t> source(31 * 23);
        for (size_t i = 0; i < source.size(); ++i) source[i] = 0xff000000 | unsigned(i * 0x172931);
        auto pixels = SkImageInfo::Make(31, 23, kRGBA_8888_SkColorType, kPremul_SkAlphaType,
            tagged ? SkColorSpace::MakeSRGBLinear() : SkColorSpace::MakeSRGB());
        auto raster = SkImages::RasterFromPixmapCopy(SkPixmap(pixels, source.data(), 31 * 4));
        canvas->drawImageRect(raster, SkRect::MakeXYWH(27.25f, 37.75f, 113.5f, 71.25f),
            SkSamplingOptions(SkFilterMode::kLinear), nullptr);
    }
    SkSerialProcs procs;
    procs.fImageProc = [](SkImage* image, void*) -> sk_sp<const SkData> { return vox_encode_picture_image(image); };
    return recorder.finishRecordingAsPicture()->serialize(&procs);
}

static std::vector<uint8_t> draw(bool shared, bool batch, bool backdrop, float phase,
    bool image, bool tagged, bool cropped) {
    if (shared) unsetenv("VOX_DISABLE_SHARED_DAWN_PIXELS");
    else setenv("VOX_DISABLE_SHARED_DAWN_PIXELS", "1", 1);
    auto data = picture(phase, image, tagged);
    int x = cropped ? 17 : 0, y = cropped ? 29 : 0;
    int w = cropped ? 123 : 193, h = cropped ? 77 : 137, pitch = w * 4 + 19;
    std::vector<uint8_t> output(size_t(pitch) * h, 0xa9);
    if (backdrop) for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
        auto* pixel = output.data() + size_t(row) * pitch + col * 4;
        pixel[3] = 173; pixel[0] = (col * 7 + row * 13) % 173;
        pixel[1] = (col * 11 + row * 3) % 173; pixel[2] = 57;
    }
    float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
    if (!batch) {
        assert(!backdrop);
        assert(vox_graphite_draw_picture_region_pixels(output.data(), 193, 137, pitch,
            x, y, w, h, data->data(), data->size(), identity));
    } else {
        // Reuse the same target and immutable payload with different backdrops.
        auto second = output;
        VoxGraphitePictureRegion requests[2] {};
        for (int i = 0; i < 2; ++i) {
            requests[i].output = {x, y, w, h, pitch, i ? second.data() : output.data()};
            requests[i].bytes = data->data(); requests[i].size = data->size();
            std::copy(identity, identity + 9, requests[i].matrix);
        }
        assert(draw_picture_regions_pixels(requests, 2, 193, 137, backdrop));
        assert(second == output);
    }
    for (int row = 0; row < h; ++row) for (int col = w * 4; col < pitch; ++col)
        assert(output[size_t(row) * pitch + col] == 0xa9);
    return output;
}

static std::vector<uint8_t> upload(bool shared, SkColorType type, bool mipmaps, bool opaque) {
    if (shared) unsetenv("VOX_DISABLE_SHARED_DAWN_PIXELS");
    else setenv("VOX_DISABLE_SHARED_DAWN_PIXELS", "1", 1);
    auto* gpu = context();
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::MakeN32Premul(31, 23, SkColorSpace::MakeSRGB());
    auto target = VoxDawnSharedSurface::Make(recorder.get(), info); assert(target.surface);
    auto source_info = info.makeWH(13, 7).makeColorType(type)
        .makeAlphaType(opaque ? kOpaque_SkAlphaType : kPremul_SkAlphaType);
    size_t pitch = 13 * 4 + 8;
    std::vector<uint8_t> source(pitch * 7, 0xa9);
    for (int y = 0; y < 7; ++y) for (int x = 0; x < 13; ++x) {
        auto* p = source.data() + y * pitch + x * 4;
        p[3] = opaque ? 255 : 173;
        p[0] = (x * 17 + y * 7) % 173; p[1] = (x * 11 + y * 23) % 173; p[2] = 47;
    }
    auto raster = SkImages::RasterFromPixmapCopy(SkPixmap(source_info, source.data(), pitch));
    auto image = vox_dawn_shared_image(recorder.get(), raster.get(), {mipmaps}); assert(image);
    assert(image->hasMipmaps() == mipmaps);
    raster.reset(); std::fill(source.begin(), source.end(), 0);
    target.surface->getCanvas()->clear(SK_ColorBLUE);
    target.surface->getCanvas()->drawImageRect(image, SkRect::MakeXYWH(3.25f, 5.5f, 21.5f, 13.25f),
        SkSamplingOptions(SkFilterMode::kLinear, mipmaps ? SkMipmapMode::kNearest : SkMipmapMode::kNone));
    image.reset();
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion; insertion.fRecording = recording.get();
    assert(gpu->insertRecording(insertion) == skgpu::graphite::InsertStatus::kSuccess);
    std::vector<uint8_t> pixels;
    if (target.pixels) assert(target.read(gpu, SkIRect::MakeSize(info.dimensions()), pixels));
    else {
        std::unique_ptr<const SkImage::AsyncReadResult> result;
        gpu->asyncRescaleAndReadPixels(target.surface.get(), info, SkIRect::MakeSize(info.dimensions()),
            SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
            [](void* value, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(value) = std::move(data);
            }, &result);
        assert(gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) && result);
        pixels.resize(info.computeMinByteSize());
        for (int y = 0; y < info.height(); ++y)
            std::memcpy(pixels.data() + size_t(y) * info.minRowBytes(),
                static_cast<uint8_t const*>(result->data(0)) + size_t(y) * result->rowBytes(0), info.minRowBytes());
    }
    return pixels;
}

static void check_retired_texture_views() {
    unsetenv("VOX_DISABLE_SHARED_DAWN_PIXELS");
    auto recorder = context()->makeRecorder();
    auto info = SkImageInfo::MakeN32Premul(1024, 1024, SkColorSpace::MakeSRGB());
    std::vector<uint8_t> source(info.computeMinByteSize(), 0x9a);
    std::vector<wgpu::TextureView> views;
    task_vm_info_data_t before {}, after {}; mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&before, &count) == KERN_SUCCESS);
    for (int i = 0; i < 16; ++i) {
        auto owner = VoxDawnSharedPixels::Make(recorder.get(), info); assert(owner);
        assert(owner->copy(SkIRect::MakeSize(info.dimensions()), source.data(), info.minRowBytes(), true));
        assert(owner->begin(true));
        wgpu::Texture texture(skgpu::graphite::BackendTextures::GetDawnTexturePtr(owner->backend()));
        views.push_back(texture.CreateView()); assert(views.back());
        // Dawn/Skia caches can retain views after their image or target retires.
        // The bridge owns the imported allocation, not those stale cache keys.
        owner.reset();
    }
    count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&after, &count) == KERN_SUCCESS);
    int64_t growth = int64_t(after.phys_footprint) - int64_t(before.phys_footprint);
    std::fprintf(stderr, "Retired IOSurfaces with 16 cached views: %lld bytes growth\n", (long long)growth);
    assert(growth < 16 * 1024 * 1024);
}

int main(int argc, char** argv) { @autoreleasepool {
    if (argc > 1 && (std::strcmp(argv[1], "final-direct") == 0
        || std::strcmp(argv[1], "final-staged") == 0)) {
        bool direct = std::strcmp(argv[1], "final-direct") == 0;
        unsetenv("VOX_DISABLE_SHARED_DAWN_PIXELS");
        if (direct) unsetenv("VOX_DISABLE_DIRECT_DAWN_READBACK");
        else setenv("VOX_DISABLE_DIRECT_DAWN_READBACK", "1", 1);
        constexpr int width = 2048, height = 2048;
        std::vector<uint8_t> output(size_t(width) * height * 4, 0xa9);
        auto data = picture(.25f, true, true);
        float matrix[] {10, 0, 0, 0, 10, 0, 0, 0, 1};
        assert(vox_graphite_draw_picture_pixels(output.data(), width, height, width * 4,
            data->data(), data->size(), matrix));
        rusage_info_v4 usage {};
        assert(proc_pid_rusage(getpid(), RUSAGE_INFO_V4, reinterpret_cast<rusage_info_t*>(&usage)) == 0);
        uint64_t hash = 1469598103934665603ULL;
        for (auto value : output) { hash ^= value; hash *= 1099511628211ULL; }
        std::printf("{\"direct\":%s,\"peak_bytes\":%llu,\"pixel_hash\":\"%llu\"}\n",
            direct ? "true" : "false", (unsigned long long)usage.ri_lifetime_max_phys_footprint,
            (unsigned long long)hash);
        return 0;
    }
    if (argc > 1) {
        bool shared = std::strcmp(argv[1], "shared") == 0;
        task_vm_info_data_t before {}, after {}; mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
        assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&before, &count) == KERN_SUCCESS);
        auto output = draw(shared, true, true, .25f, true, true, true);
        count = TASK_VM_INFO_COUNT;
        assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&after, &count) == KERN_SUCCESS);
        uint64_t hash = 1469598103934665603ULL;
        for (auto value : output) { hash ^= value; hash *= 1099511628211ULL; }
        std::printf("{\"shared\":%s,\"growth_bytes\":%lld,\"pixel_hash\":\"%llu\"}\n",
            shared ? "true" : "false", (long long)(after.phys_footprint - before.phys_footprint),
            (unsigned long long)hash);
        return 0;
    }
    unsetenv("VOX_DISABLE_SHARED_DAWN_PIXELS");
    auto* gpu = context(); assert(gpu);
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::MakeN32Premul(11, 9, SkColorSpace::MakeSRGB());
    auto owner = VoxDawnSharedPixels::Make(recorder.get(), info); assert(owner);
    assert(!owner->copy(SkIRect::MakeWH(1, 1), nullptr, 4, false));
    std::vector<uint8_t> scratch(11 * 9 * 4);
    assert(!owner->copy(SkIRect::MakeXYWH(-1, 0, 1, 1), scratch.data(), 4, false));
    assert(!owner->copy(SkIRect::MakeXYWH(10, 8, 2, 1), scratch.data(), 8, false));
    assert(!owner->copy(SkIRect::MakeWH(11, 9), scratch.data(), 43, false));
    assert(!owner->copy(SkIRect::MakeWH(11, 9), scratch.data(), SIZE_MAX, false));
    assert(owner->begin(false));
    assert(!owner->copy(SkIRect::MakeWH(11, 9), scratch.data(), 44, false));
    assert(owner->end_and_wait());
    assert(!VoxDawnSharedPixels::Make(recorder.get(), info.makeColorType(kAlpha_8_SkColorType)));
    assert(!VoxDawnSharedPixels::Make(recorder.get(), info.makeAlphaType(kUnpremul_SkAlphaType)));
    unsigned cases = 0;
    for (auto type : {kBGRA_8888_SkColorType, kRGBA_8888_SkColorType})
    for (bool mipmaps : {false, true}) for (bool opaque : {false, true}) {
        assert(upload(false, type, mipmaps, opaque) == upload(true, type, mipmaps, opaque));
        ++cases;
    }
    for (bool batch : {false, true}) for (bool backdrop : {false, true}) {
        if (backdrop && !batch) continue;
        for (float phase : {0.f, .25f, .5f, .75f}) for (bool image : {false, true})
        for (bool tagged : {false, true}) for (bool cropped : {false, true}) {
            auto expected = draw(false, batch, backdrop, phase, image, tagged, cropped);
            if (!batch) {
                setenv("VOX_DISABLE_DIRECT_DAWN_READBACK", "1", 1);
                assert(draw(true, batch, backdrop, phase, image, tagged, cropped) == expected);
                unsetenv("VOX_DISABLE_DIRECT_DAWN_READBACK");
            }
            auto actual = draw(true, batch, backdrop, phase, image, tagged, cropped);
            if (actual != expected) {
                std::fprintf(stderr, "Pixels differ batch=%d backdrop=%d phase=%g image=%d tagged=%d crop=%d\n",
                    batch, backdrop, phase, image, tagged, cropped);
                return 1;
            }
            ++cases;
        }
    }
    check_retired_texture_views();
    std::printf("%u exact Dawn shared surface/image/region/backdrop comparisons pass\n", cases);
} }
