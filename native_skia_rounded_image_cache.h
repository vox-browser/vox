#pragma once

// Cache one complete native publication only after identical parameters recur.
// Owned backdrop bytes participate in every hit; neither CGContext addresses nor
// caller allocations establish content identity. GPU/CPU fallback is unchanged.
static GlyphRasterCache s_native_rounded_image_cache(64 * 1024 * 1024, 64, 16 * 1024 * 1024);
static std::unordered_map<std::string, bool> s_native_rounded_admission;
static bool native_rounded_image_cache_enabled()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_ENABLE_NATIVE_ROUNDED_IMAGE_CACHE");
        return value && !std::strcmp(value, "1") && !std::getenv("VOX_DISABLE_NATIVE_ROUNDED_IMAGE_CACHE");
    }();
    return enabled;
}
static void clear_native_rounded_image_cache()
{
    s_native_rounded_image_cache.clear();
    s_native_rounded_admission.clear();
}
class NativeRoundedImageCapture;
static NativeRoundedImageCapture* s_native_rounded_capture = nullptr;
class NativeRoundedImageCapture {
    GlyphRasterCache::Request request;
    CGContextRef destination {nullptr};
    CGRect rectangle {};
    CGImageRef published {nullptr};
    unsigned publications = 0;
    int width = 0, height = 0;
    bool active = false;
public:
    ~NativeRoundedImageCapture()
    {
        if (active) s_native_rounded_capture = nullptr;
        if (publications == 1 && published && CGImageGetWidth(published) == size_t(width)
            && CGImageGetHeight(published) == size_t(height)) {
            // A pooled provider can own a larger allocation than its visible
            // image. Pack cache ownership into exactly the charged byte count.
            auto data = CGDataProviderCopyData(CGImageGetDataProvider(published));
            size_t bytes = size_t(width) * height * 4;
            if (data && CFDataGetLength(data) == CFIndex(bytes)) {
                auto packed = CFDataCreate(kCFAllocatorDefault, CFDataGetBytePtr(data), bytes);
                auto provider = packed ? CGDataProviderCreateWithCFData(packed) : nullptr;
                if (packed) CFRelease(packed);
                auto image = image_from_provider(provider, width, height, true);
                if (image) {
                    s_native_rounded_image_cache.finish(std::move(request), image);
                    CGImageRelease(image);
                }
            }
            if (data) CFRelease(data);
        }
        if (published) CGImageRelease(published);
    }
    void begin(CGContextRef context, CGRect rect, std::vector<uint8_t> key,
        int width, int height, Backdrop backdrop, bool root = true)
    {
        // Bound admission metadata independently of image/backdrop storage.
        if (s_native_rounded_capture || key.size() > 4096) return;
        std::string admission(reinterpret_cast<char const*>(key.data()), key.size());
        bool admitted = s_native_rounded_admission.count(admission);
        if (!admitted) {
            if (s_native_rounded_admission.size() >= 512) s_native_rounded_admission.clear();
            s_native_rounded_admission.emplace(std::move(admission), true);
        } else {
            destination = context; rectangle = rect;
            this->width = width; this->height = height;
            request = s_native_rounded_image_cache.prepare(std::move(key), width, height,
                backdrop.pixels, backdrop.pitch);
            if (request.pending) { s_native_rounded_capture = this; active = true; }
        }
        if (std::getenv("VOX_NATIVE_ROUNDED_IMAGE_CACHE_DIAGNOSTICS")) {
            using Clock = double (*)();
            static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
            std::fprintf(stderr, "VOX_NATIVE_ROUNDED_IMAGE_CACHE root=%d admitted=%d hit=%d pending=%d pixels=%zu t_us=%.3f\n",
                root, admitted, bool(request.image), bool(request.pending), size_t(width) * height, clock ? clock() : -1);
        }
    }
    CGImageRef image() const { return request.image; }
    void publication(CGContextRef context, CGImageRef image, CGRect rect, bool copy)
    {
        if (context != destination) return;
        ++publications;
        if (publications == 1 && copy && CGRectEqualToRect(rect, rectangle))
            published = CGImageRetain(image);
    }
};
void capture_native_rounded_image(CGContextRef context, CGImageRef image, CGRect rect, bool copy)
{
    if (s_native_rounded_capture) s_native_rounded_capture->publication(context, image, rect, copy);
}
