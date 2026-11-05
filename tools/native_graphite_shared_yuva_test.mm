#include "../native_graphite_darwin.mm"
#include <mach/mach.h>
#include <cassert>

static uint64_t physical_footprint()
{
    task_vm_info_data_t info{};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO,
        reinterpret_cast<task_info_t>(&info), &count) == KERN_SUCCESS);
    return info.phys_footprint;
}

static std::vector<uint8_t> render_yuva(bool shared, int width, int height,
    SkYUVAInfo::Subsampling subsampling, SkYUVColorSpace conversion, bool mipmaps,
    bool padded, bool overwrite_source)
{ @autoreleasepool {
    auto* gpu = context();
    assert(gpu);
    auto recorder = gpu->makeRecorder();
    assert(recorder);
    SkYUVAInfo info(SkISize::Make(width, height), SkYUVAInfo::PlaneConfig::kY_U_V,
        subsampling, conversion);
    SkISize dimensions[SkYUVAInfo::kMaxPlanes];
    assert(info.planeDimensions(dimensions) == 3);
    SkPixmap views[SkYUVAInfo::kMaxPlanes];
    std::array<std::vector<uint8_t>, 3> bytes;
    for (int index = 0; index < 3; ++index) {
        auto size = dimensions[index];
        size_t pitch = size.width() + (padded ? 13 : 0);
        bytes[index].resize(pitch * size.height(), 231);
        for (int y = 0; y < size.height(); ++y)
            for (int x = 0; x < size.width(); ++x)
                bytes[index][y * pitch + x] = (x * 31 + y * 47 + index * 79) % 256;
        views[index] = SkPixmap(SkImageInfo::Make(size.width(), size.height(),
            kGray_8_SkColorType, kOpaque_SkAlphaType), bytes[index].data(), pitch);
    }
    auto pixmaps = SkYUVAPixmaps::FromExternalPixmaps(info, views);
    assert(pixmaps.isValid());
    SkImage::RequiredProperties required{.fMipmapped = mipmaps};
    auto image = shared ? vox_shared_yuva_image(recorder.get(), pixmaps, required,
        SkColorSpace::MakeSRGB()) : SkImages::TextureFromYUVAPixmaps(recorder.get(),
        pixmaps, required, false, SkColorSpace::MakeSRGB());
    assert(image);
    if (overwrite_source) {
        for (auto& plane : bytes) { std::fill(plane.begin(), plane.end(), 0); plane.clear(); }
    }
    // Drain texture descriptors before drawing. Only the wrapped texture
    // proxies may keep their independently copied plane data alive.
    constexpr int out_width = 89, out_height = 71;
    auto output = SkImageInfo::Make(out_width, out_height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), output);
    assert(surface);
    auto* canvas = surface->getCanvas();
    canvas->clear(SkColorSetARGB(255, 33, 77, 119));
    SkPaint paint; paint.setAlphaf(.73f);
    canvas->drawImageRect(image, SkRect::MakeXYWH(3.25f, 7.5f, 73.5f, 51.25f),
        SkSamplingOptions(SkFilterMode::kLinear,
            mipmaps ? SkMipmapMode::kLinear : SkMipmapMode::kNone), &paint);
    std::vector<uint8_t> result(out_width * out_height * 4);
    assert(read_pixels(gpu, recorder.get(), surface.get(), output, result.data(), out_width * 4));
    return result;
} }

int main(int argc, char** argv)
{ @autoreleasepool {
    if (argc == 2) {
        bool shared = std::strcmp(argv[1], "shared") == 0;
        assert(shared || std::strcmp(argv[1], "control") == 0);
        uint64_t before = physical_footprint();
        auto pixels = render_yuva(shared, 140, 73, SkYUVAInfo::Subsampling::k420,
            kJPEG_Full_SkYUVColorSpace, false, true, true);
        uint64_t after = physical_footprint(), hash = 1469598103934665603ull;
        for (auto byte : pixels) { hash ^= byte; hash *= 1099511628211ull; }
        std::printf("{\"shared\":%s,\"before_bytes\":%llu,\"after_bytes\":%llu,"
            "\"growth_bytes\":%llu,\"pixel_hash\":\"%llu\"}\n", shared ? "true" : "false",
            (unsigned long long)before, (unsigned long long)after,
            (unsigned long long)(after - before), (unsigned long long)hash);
        return 0;
    }
    int cases = 0;
    for (auto conversion : {kJPEG_Full_SkYUVColorSpace, kRec601_SkYUVColorSpace,
            kRec709_SkYUVColorSpace})
        for (auto sampling : {SkYUVAInfo::Subsampling::k420, SkYUVAInfo::Subsampling::k422,
                SkYUVAInfo::Subsampling::k444})
            for (bool padded : {false, true})
                for (bool mipmaps : {false, true}) {
                    auto control = render_yuva(false, 37, 29, sampling, conversion, mipmaps,
                        padded, true);
                    auto actual = render_yuva(true, 37, 29, sampling, conversion, mipmaps,
                        padded, true);
                    assert(control == actual);
                    ++cases;
                }
    setenv("VOX_DISABLE_SHARED_YUVA_UPLOADS", "1", 1);
    auto disabled = render_yuva(true, 27, 5, SkYUVAInfo::Subsampling::k420,
        kJPEG_Full_SkYUVColorSpace, false, true, true);
    unsetenv("VOX_DISABLE_SHARED_YUVA_UPLOADS");
    assert(disabled == render_yuva(true, 27, 5, SkYUVAInfo::Subsampling::k420,
        kJPEG_Full_SkYUVColorSpace, false, true, true));
    std::printf("Shared YUV uploads: %d exact comparisons plus disabled fallback\n", cases);
} }
