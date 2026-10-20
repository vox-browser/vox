// A deliberately narrow bridge to the same Skia text rasterizer that Ladybird
// uses for DisplayListPlayerSkia. V continues to shape and position every glyph;
// this file only turns the retained glyph IDs into the final antialiased pixels.

#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include "native_graphite_bridge.h"
#include "native_chromium_raster_phase.h"
#include "native_chromium_raster_rows.h"
#include "native_chromium_raster_grid.h"
#import <Metal/Metal.h>
#include "include/gpu/ganesh/GrDirectContext.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include "include/gpu/ganesh/mtl/GrMtlDirectContext.h"
#include "include/gpu/ganesh/mtl/GrMtlBackendContext.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkBlendMode.h"
#include "include/core/SkBlurTypes.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorFilter.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkData.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontArguments.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkGraphics.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkImage.h"
#include "include/core/SkMaskFilter.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkSerialProcs.h"
#include "include/core/SkPath.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSize.h"
#include "include/core/SkSurface.h"
#include "include/core/SkSurfaceProps.h"
#include "include/core/SkStream.h"
#include "include/core/SkTextBlob.h"
#include "include/core/SkTypeface.h"
#include "include/core/SkSamplingOptions.h"
#include "include/effects/SkImageFilters.h"
#include "include/effects/SkDashPathEffect.h"
#include "include/effects/SkGradientShader.h"
#include "include/effects/SkPerlinNoiseShader.h"
#include "include/effects/SkRuntimeEffect.h"
#include "include/ports/SkFontMgr_fontconfig.h"
#include "include/ports/SkFontScanner_FreeType.h"
#include "include/ports/SkFontMgr_mac_ct.h"
#include "include/ports/SkTypeface_mac.h"
#include <CoreText/CoreText.h>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <list>
#include <memory>
#include <set>
#include <pthread.h>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#if defined(__aarch64__)
#include <arm_neon.h>
#endif

namespace {

SkCanvas* shared_recording_canvas(CGContextRef);
void shared_recording_block(SkRect);
void shared_recording_svg(CGContextRef, SkRect, float);
void shared_recording_image(CGContextRef, SkMatrix const&, VoxGraphiteImage const&);
void finish_shared_recording();

enum FontSlot {
    RegularFont = 0,
    BoldFont = 1,
    EmojiFont = 2,
    FontSlotCount = 3,
};

sk_sp<SkFontMgr> s_font_manager;
sk_sp<SkTypeface> s_typefaces[FontSlotCount];
std::unordered_map<std::string, sk_sp<SkTypeface>> s_path_typefaces;
bool s_chromium_painting = false;
// Installed faces selected through CoreText, keyed by the replay identifier
// the browser passes in place of a file path.
std::unordered_map<std::string, sk_sp<SkTypeface>> s_system_typefaces;

sk_sp<SkFontMgr> font_manager()
{
    if (!s_font_manager) {
        auto* layout_test_font = std::getenv("LADYBIRD_LAYOUT_TEST_FONT");
        s_font_manager = layout_test_font && *layout_test_font
            ? SkFontMgr_New_FontConfig(nullptr, SkFontScanner_Make_FreeType())
            : SkFontMgr_New_CoreText(nullptr);
    }
    return s_font_manager;
}

sk_sp<GrDirectContext> s_image_gpu_context;
bool s_image_gpu_context_attempted = false;

GrDirectContext* image_gpu_context()
{
    if (!s_image_gpu_context_attempted) {
        s_image_gpu_context_attempted = true;
        s_image_gpu_context = []() -> sk_sp<GrDirectContext> {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) return nullptr;
        GrMtlBackendContext backend;
        backend.fDevice.reset((GrMTLHandle)device);
        backend.fQueue.reset((GrMTLHandle)[device newCommandQueue]);
        if (!backend.fQueue) return nullptr;
        return GrDirectContexts::MakeMetal(backend);
        }();
    }
    return s_image_gpu_context.get();
}

auto graphite_shadow_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_shadow_pixels)>(
            dlsym(library, "vox_graphite_draw_shadow_pixels")) : nullptr;
    }();
    return draw;
}

auto graphite_image_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(
            dlsym(library, "vox_graphite_draw_image_pixels")) : nullptr;
    }();
    return draw;
}

auto graphite_image_tiles_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_image_tiles)>(
            dlsym(library, "vox_graphite_draw_image_tiles")) : nullptr;
    }();
    return draw;
}

auto graphite_shape_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
            dlsym(library, "vox_graphite_draw_shape_pixels")) : nullptr;
    }();
    return draw;
}

auto graphite_path_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_path_pixels)>(
            dlsym(library, "vox_graphite_draw_path_pixels")) : nullptr;
    }();
    return draw;
}

auto graphite_path_batch_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_path_batch_pixels)>(
            dlsym(library, "vox_graphite_draw_path_batch_pixels")) : nullptr;
    }();
    return draw;
}

auto graphite_svg_image_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_svg_image_pixels)>(
            dlsym(library, "vox_graphite_draw_svg_image_pixels")) : nullptr;
    }();
    return draw;
}

SkTypeface* select_typeface(char const* path, int face_index, int font_weight, int emoji_face)
{
    if (path && *path) {
        if (auto found = s_system_typefaces.find(path); found != s_system_typefaces.end())
            return found->second.get();
        auto key = std::string(path) + "#" + std::to_string(face_index);
        if (auto found = s_path_typefaces.find(key); found != s_path_typefaces.end())
            return found->second.get();
        auto manager = font_manager();
        if (manager) {
            char const* collection_family = nullptr;
            if (std::strcmp(path, "/System/Library/Fonts/HelveticaNeue.ttc") == 0)
                collection_family = "Helvetica Neue";
            else if (std::strcmp(path, "/System/Library/Fonts/LucidaGrande.ttc") == 0)
                collection_family = "Lucida Grande";
            else if (std::strcmp(path, "/System/Library/Fonts/Supplemental/GillSans.ttc") == 0)
                collection_family = "Gill Sans";

            // Keep the collection index attached to the font data explicitly.
            // The CoreText file helper can reopen a TTC as its default face,
            // which makes retained glyph IDs from another face render as
            // unrelated characters (most visibly for Helvetica Neue Bold).
            // CoreText can also silently return the collection's default face
            // for a valid non-zero index. Resolve the three macOS collections
            // emitted by platform::Font through the system manager first.
            auto typeface = collection_family && face_index != 0
                ? manager->matchFamilyStyle(collection_family, SkFontStyle::Bold())
                : nullptr;
            if (!typeface) {
                auto data = SkData::MakeFromFileName(path);
                if (data) {
                    SkFontArguments arguments;
                    arguments.setCollectionIndex(face_index);
                    typeface = manager->makeFromStream(
                        std::make_unique<SkMemoryStream>(std::move(data)), arguments);
                }
            }
            if (typeface) {
                auto* result = typeface.get();
                s_path_typefaces.emplace(std::move(key), std::move(typeface));
                return result;
            }
        }
    }
    auto slot = emoji_face ? EmojiFont : (font_weight >= 600 ? BoldFont : RegularFont);
    if (!s_typefaces[slot] && slot == BoldFont)
        slot = RegularFont;
    return s_typefaces[slot].get();
}

void swap_red_blue_pixels(uint8_t* destination, uint8_t const* source, size_t count)
{
    size_t i = 0;
#if defined(__aarch64__)
    uint8_t const indices[] {2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15};
    auto order = vld1q_u8(indices);
    for (; count - i >= 4; i += 4)
        vst1q_u8(destination + i * 4, vqtbl1q_u8(vld1q_u8(source + i * 4), order));
#endif
    for (; i < count; ++i) {
        uint32_t p;
        std::memcpy(&p, source + i * 4, sizeof(p));
        p = (p & 0xff00ff00u) | ((p & 0xffu) << 16) | ((p >> 16) & 0xffu);
        std::memcpy(destination + i * 4, &p, sizeof(p));
    }
}

bool rgba_bitmap(CGContextRef destination)
{
    return CGBitmapContextGetBitsPerPixel(destination) == 32
        && CGBitmapContextGetAlphaInfo(destination) == kCGImageAlphaPremultipliedLast
        && (CGBitmapContextGetBitmapInfo(destination) & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big;
}

CGImageRef image_from_provider(CGDataProviderRef provider, int width, int height, bool rgba)
{
    if (!provider) return nullptr;
    auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto image = CGImageCreate(static_cast<size_t>(width), static_cast<size_t>(height),
        8, 32, static_cast<size_t>(width) * sizeof(uint32_t), color_space,
        (rgba ? static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big)
            : static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedFirst)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Little)),
        provider, nullptr, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(color_space);
    CGDataProviderRelease(provider);
    return image;
}

CGImageRef create_pixel_image(CGContextRef destination, std::vector<uint32_t> const& pixels,
    int width, int height)
{
    // A drawRect: CGContext may retain the image in a display list and replay it
    // later during the Core Animation transaction. Give the provider its own
    // copy instead of pointing it at a vector which dies when this call returns.
    // Match the readable frame's channel order before handing pixels to Quartz.
    // Otherwise each leaf creates an expensive format-conversion provider.
    bool rgba = rgba_bitmap(destination);
    CGDataProviderRef provider = nullptr;
    if (rgba) {
        size_t bytes = pixels.size() * sizeof(uint32_t);
        auto* converted = static_cast<uint32_t*>(std::malloc(bytes));
        if (!converted) return 0;
        swap_red_blue_pixels(reinterpret_cast<uint8_t*>(converted),
            reinterpret_cast<uint8_t const*>(pixels.data()), pixels.size());
        provider = CGDataProviderCreateWithData(nullptr, converted, bytes,
            [](void*, void const* bytes, size_t) { std::free(const_cast<void*>(bytes)); });
        if (!provider) std::free(converted);
    } else {
        auto data = CFDataCreate(kCFAllocatorDefault,
            reinterpret_cast<UInt8 const*>(pixels.data()),
            static_cast<CFIndex>(pixels.size() * sizeof(uint32_t)));
        if (!data) return 0;
        provider = CGDataProviderCreateWithCFData(data);
        CFRelease(data);
    }
    return image_from_provider(provider, width, height, rgba);
}

// Transfer the finished raster allocation to Quartz. Its provider keeps the
// pixels alive for deferred display-list replay, without a second full bitmap.
CGImageRef create_pixel_image(CGContextRef destination, std::vector<uint32_t>&& pixels,
    int width, int height)
{
    bool rgba = rgba_bitmap(destination);
    if (rgba) swap_red_blue_pixels(reinterpret_cast<uint8_t*>(pixels.data()),
        reinterpret_cast<uint8_t const*>(pixels.data()), pixels.size());
    auto owned = std::make_unique<std::vector<uint32_t>>(std::move(pixels));
    auto provider = CGDataProviderCreateWithData(owned.get(), owned->data(), owned->size() * 4,
        [](void* owner, void const*, size_t) { delete static_cast<std::vector<uint32_t>*>(owner); });
    if (provider) owned.release();
    return image_from_provider(provider, width, height, rgba);
}

int composite_image(CGContextRef destination, CGImageRef image, CGRect rect, bool copy_background = false)
{
    if (!image) return 0;
    CGContextSaveGState(destination);
    if (copy_background) CGContextSetBlendMode(destination, kCGBlendModeCopy);
    CGContextSetInterpolationQuality(destination, kCGInterpolationNone);
    CGContextDrawImage(destination, rect, image);
    CGContextRestoreGState(destination);
    return 1;
}

int composite_pixels(CGContextRef destination, std::vector<uint32_t> const& pixels,
    int width, int height, float destination_x, float destination_y,
    float destination_width, float destination_height, bool copy_background = false)
{
    auto image = create_pixel_image(destination, pixels, width, height);
    int result = composite_image(destination, image,
        CGRectMake(destination_x, destination_y, destination_width, destination_height), copy_background);
    if (image) CGImageRelease(image);
    return result;
}

int composite_pixels(CGContextRef destination, std::vector<uint32_t>&& pixels,
    int width, int height, float destination_x, float destination_y,
    float destination_width, float destination_height, bool copy_background = false)
{
    auto image = create_pixel_image(destination, std::move(pixels), width, height);
    int result = composite_image(destination, image,
        CGRectMake(destination_x, destination_y, destination_width, destination_height), copy_background);
    if (image) CGImageRelease(image);
    return result;
}

// Retained text often replays over identical pixels after an integer scroll.
// Compare owned glyph/position/paint values and the complete input backdrop;
// neither the caller's buffers nor a text run's address promise immutability.
class GlyphRasterCache {
    struct Entry {
        uint64_t hash;
        int width, height;
        std::vector<uint8_t> key;
        std::vector<uint8_t> background;
        CGImageRef image {nullptr};
        size_t cost;
        ~Entry() { if (image) CGImageRelease(image); }
    };
    std::list<std::unique_ptr<Entry>> entries;
    size_t bytes = 0;
    size_t byte_limit, entry_limit;
public:
    explicit GlyphRasterCache(size_t limit = 8 * 1024 * 1024, size_t count = 512)
        : byte_limit(limit), entry_limit(count) { }
    struct Request {
        CGImageRef image {nullptr};
        std::unique_ptr<Entry> pending;
    };
    Request prepare(std::vector<uint8_t> key, int width, int height,
        uint8_t const* background, size_t pitch)
    {
        if (width <= 0 || height <= 0 || (background && pitch < size_t(width) * 4)) return {};
        size_t row_bytes = size_t(width) * 4;
        if (row_bytes > byte_limit / size_t(height)) return {};
        size_t pixel_bytes = row_bytes * size_t(height);
        size_t cost = key.size() + pixel_bytes * (background ? 2 : 1);
        if (!entry_limit || cost > std::min(byte_limit, size_t(256 * 1024))) return {};
        uint64_t hash = 14695981039346656037ull;
        for (auto value : key) hash = (hash ^ value) * 1099511628211ull;
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            auto const& entry = **it;
            if (entry.hash != hash || entry.key != key || entry.width != width || entry.height != height
                || entry.background.size() != (background ? pixel_bytes : 0)) continue;
            bool equal = true;
            if (background) for (int y = 0; equal && y < height; ++y)
                equal = !std::memcmp(entry.background.data() + size_t(y) * row_bytes,
                    background + size_t(y) * pitch, row_bytes);
            if (!equal) continue;
            auto image = entry.image;
            entries.splice(entries.begin(), entries, it);
            return {image, nullptr};
        }
        auto entry = std::make_unique<Entry>();
        entry->hash = hash; entry->width = width; entry->height = height;
        entry->key = std::move(key); entry->cost = cost;
        if (background) {
            entry->background.resize(pixel_bytes);
            for (int y = 0; y < height; ++y)
                std::memcpy(entry->background.data() + size_t(y) * row_bytes,
                    background + size_t(y) * pitch, row_bytes);
        }
        return {nullptr, std::move(entry)};
    }
    void finish(Request&& request, CGImageRef image)
    {
        if (!image || !request.pending) return;
        auto& entry = *request.pending;
        while (!entries.empty() && (bytes + entry.cost > byte_limit || entries.size() >= entry_limit)) {
            bytes -= entries.back()->cost;
            entries.pop_back();
        }
        entry.image = CGImageRetain(image);
        bytes += entry.cost;
        entries.push_front(std::move(request.pending));
    }
    void clear() { entries.clear(); bytes = 0; }
};
GlyphRasterCache s_glyph_raster_cache;

template<typename T> void append_glyph_key(std::vector<uint8_t>& key, T const* data, size_t count)
{
    auto const* bytes = reinterpret_cast<uint8_t const*>(data);
    key.insert(key.end(), bytes, bytes + sizeof(T) * count);
}

// Screenshot references normally use one device pixel per CSS pixel. A
// LADYBIRD_SCREENSHOT_SCALE above 1 captures at that device density instead, so
// intermediate rasters follow the destination context as in a Retina window.
static bool screenshot_uses_logical_pixels()
{
    if (!std::getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS"))
        return false;
    auto const* scale = std::getenv("LADYBIRD_SCREENSHOT_SCALE");
    return !scale || !(std::strtod(scale, nullptr) > 1.0);
}

float raster_scale_for_context(CGContextRef context)
{
    // AppKit presents an NSView in point-sized user space even when its backing
    // store has two device pixels per point. The Skia bridge creates its own
    // raster surfaces, so it must explicitly match that device-space density;
    // otherwise Core Graphics has to stretch a 1x glyph bitmap over the Retina
    // backing store. Derive the scale from the destination context rather than
    // the window so intentionally 1x screenshot contexts remain pixel-stable.
    auto horizontal = CGContextConvertSizeToDeviceSpace(context, CGSizeMake(1.0, 0.0));
    auto vertical = CGContextConvertSizeToDeviceSpace(context, CGSizeMake(0.0, 1.0));
    auto scale_x = std::hypot(horizontal.width, horizontal.height);
    auto scale_y = std::hypot(vertical.width, vertical.height);
    auto scale = std::max(scale_x, scale_y);
    return std::isfinite(scale) && scale > 0.0 ? static_cast<float>(scale) : 1.0f;
}

struct RasterRegion {
    int left { 0 };
    int top { 0 };
    int right { 0 };
    int bottom { 0 };

    int width() const { return right - left; }
    int height() const { return bottom - top; }
};

int raster_dimension(int logical_dimension, float scale)
{
    return std::max(1, static_cast<int>(std::ceil(
        static_cast<float>(logical_dimension) * scale)));
}

SkMatrix raster_matrix(SkMatrix const& logical_matrix, RasterRegion const& region,
    float scale_x, float scale_y)
{
    return SkMatrix::MakeAll(
        logical_matrix.getScaleX() * scale_x,
        logical_matrix.getSkewX() * scale_x,
        (logical_matrix.getTranslateX() - static_cast<float>(region.left)) * scale_x,
        logical_matrix.getSkewY() * scale_y,
        logical_matrix.getScaleY() * scale_y,
        (logical_matrix.getTranslateY() - static_cast<float>(region.top)) * scale_y,
        logical_matrix.getPerspX(), logical_matrix.getPerspY(), 1.0f);
}

bool clipped_raster_region(SkRect const& bounds, float canvas_width,
    float canvas_height, float guard, RasterRegion& region)
{
    if (!bounds.isFinite())
        return false;
    region.left = std::max(0, static_cast<int>(std::floor(bounds.left() - guard)));
    region.top = std::max(0, static_cast<int>(std::floor(bounds.top() - guard)));
    region.right = std::min(static_cast<int>(std::ceil(canvas_width)),
        static_cast<int>(std::ceil(bounds.right() + guard)));
    region.bottom = std::min(static_cast<int>(std::ceil(canvas_height)),
        static_cast<int>(std::ceil(bounds.bottom() + guard)));
    return region.width() > 0 && region.height() > 0;
}

// Readable frame and opacity-group backdrops use premultiplied RGBA. Keep a
// strided view so a glyph-cache hit needs neither an allocation nor conversion.
struct Backdrop {
    uint8_t const* pixels {nullptr};
    size_t pitch {0};
};

Backdrop read_backdrop(CGContextRef destination, RasterRegion const& region,
    float destination_scale, int raster_width, int raster_height)
{
    if (CGBitmapContextGetBitsPerPixel(destination) != 32
        || CGBitmapContextGetAlphaInfo(destination) != kCGImageAlphaPremultipliedLast
        || (CGBitmapContextGetBitmapInfo(destination) & kCGBitmapByteOrderMask) != kCGBitmapByteOrder32Big)
        return {};
    CGContextFlush(destination);
    auto* background = static_cast<uint8_t*>(CGBitmapContextGetData(destination));
    auto source_width = CGBitmapContextGetWidth(destination);
    auto source_height = CGBitmapContextGetHeight(destination);
    auto source_pitch = CGBitmapContextGetBytesPerRow(destination);
    auto left = static_cast<size_t>(std::lround(region.left * destination_scale));
    auto top = static_cast<size_t>(std::lround(region.top * destination_scale));
    auto ctm = CGContextGetCTM(destination);
    if (!background || !(ctm.a > 0 && ctm.d > 0) || ctm.b != 0 || ctm.c != 0
        || ctm.tx != 0 || ctm.ty != 0 || left + raster_width > source_width
        || top + raster_height > source_height) return {};
    return {background + top * source_pitch + left * 4, source_pitch};
}

void copy_backdrop_pixels(Backdrop source, int width, int height, std::vector<uint32_t>& pixels,
    RasterRegion covered = {})
{
    for (int y = 0; y < height; ++y) {
        auto* row = source.pixels + size_t(y) * source.pitch;
        auto copy = [&](int left, int right) {
            swap_red_blue_pixels(reinterpret_cast<uint8_t*>(pixels.data() + size_t(y) * width + left),
                row + size_t(left) * 4, size_t(right - left));
        };
        if (y >= covered.top && y < covered.bottom) {
            copy(0, covered.left); copy(covered.right, width);
        } else copy(0, width);
    }
}

bool copy_backdrop(CGContextRef destination, RasterRegion const& region,
    float destination_scale, int raster_width, int raster_height, std::vector<uint32_t>& pixels)
{
    auto source = read_backdrop(destination, region, destination_scale, raster_width, raster_height);
    // Preserve translucent group pixels too. Copy blending later applies the
    // foreground over its backdrop exactly once.
    if (source.pixels) copy_backdrop_pixels(source, raster_width, raster_height, pixels);
    return source.pixels != nullptr;
}

// Reject fully clipped leaf surfaces while retaining intersecting surfaces at
// their original origin and dimensions. Shadow and filter inputs stay intact.
bool leaf_raster_region_intersects_destination_clip(CGContextRef destination,
    float canvas_height, RasterRegion const& region)
{
    auto clip = CGContextGetClipBoundingBox(destination);
    if (CGRectIsNull(clip) || CGRectIsEmpty(clip))
        return false;
    if (CGRectIsInfinite(clip) || !std::isfinite(clip.origin.x)
        || !std::isfinite(clip.origin.y) || !std::isfinite(clip.size.width)
        || !std::isfinite(clip.size.height))
        return true;
    constexpr double fringe = 2.0;
    // Keep intersecting surfaces at their original dimensions and origin.
    // Cropping them can change Skia's analytic antialiasing and gradient
    // rounding even when the final CoreGraphics clip is identical.
    return region.right > CGRectGetMinX(clip) - fringe
        && region.left < CGRectGetMaxX(clip) + fringe
        && region.bottom > canvas_height - CGRectGetMaxY(clip) - fringe
        && region.top < canvas_height - CGRectGetMinY(clip) + fringe;
}

struct RasterCommandGroup {
    CGContextRef destination { nullptr };
    float canvas_height { 0.0f };
    RasterRegion region;
    int raster_width { 0 };
    int raster_height { 0 };
    float scale_x { 1.0f };
    float scale_y { 1.0f };
    std::vector<uint32_t> pixels;
    sk_sp<SkSurface> surface;
};

std::unique_ptr<RasterCommandGroup> s_raster_command_group;

SkPath path_from_serialized_segments(float const* data, int segment_count)
{
    SkPath path;
    if (!data || segment_count <= 0)
        return path;

    float last_move_x = 0.0f;
    float last_move_y = 0.0f;
    bool has_move = false;
    for (int index = 0; index < segment_count; ++index) {
        auto const* segment = data + index * 12;
        switch (static_cast<int>(segment[0])) {
        case 0:
            path.moveTo(segment[1], segment[2]);
            last_move_x = segment[1];
            last_move_y = segment[2];
            has_move = true;
            break;
        case 1:
            path.lineTo(segment[1], segment[2]);
            break;
        case 2:
            path.quadTo(segment[3], segment[4], segment[1], segment[2]);
            break;
        case 3:
            path.cubicTo(segment[3], segment[4], segment[5], segment[6],
                segment[1], segment[2]);
            break;
        case 4:
            path.arcTo(std::abs(segment[7]), std::abs(segment[8]),
                segment[9] * 180.0f / static_cast<float>(M_PI),
                segment[10] != 0.0f ? SkPath::kLarge_ArcSize : SkPath::kSmall_ArcSize,
                segment[11] != 0.0f ? SkPathDirection::kCW : SkPathDirection::kCCW,
                segment[1], segment[2]);
            break;
        case 5:
            path.close();
            // Gfx::PathImplSkia starts a fresh contour at the last move point
            // after close(), so retain the same behavior for subsequent segments.
            if (has_move)
                path.moveTo(last_move_x, last_move_y);
            break;
        case 6:
            // Explicit SVG ellipse (LTRB); keep authored arc paths unchanged.
            if (std::isfinite(segment[1]) && std::isfinite(segment[2])
                && std::isfinite(segment[3]) && std::isfinite(segment[4])
                && segment[3] > segment[1] && segment[4] > segment[2])
                path.addOval(SkRect::MakeLTRB(segment[1], segment[2], segment[3], segment[4]),
                    SkPathDirection::kCW, 1);
            break;
        default:
            break;
        }
    }
    return path;
}

} // namespace

// The native owner calls this between frames after document work is idle.
// Cache eviction preserves live images, fonts and retained CPU paint inputs;
// subsequent painting can rebuild purged shaders and other temporary data.
extern "C" void ladybird_v_skia_release_unused_graphics_memory()
{
    if (!pthread_main_np()) return;
    if (auto* gpu = s_image_gpu_context.get()) {
        gpu->flushAndSubmit(GrSyncCpu::kYes);
        gpu->checkAsyncWorkCompletion();
        gpu->freeGpuResources();
        gpu->purgeUnlockedResources(GrPurgeResourceOptions::kAllResources);
        // A GPU image or surface holds its own Context reference. Keep that
        // Context alive while such a caller exists; otherwise only this cache
        // owns it and idle cleanup can release Metal's per-context storage.
        if (gpu->unique()) {
            s_image_gpu_context.reset();
            s_image_gpu_context_attempted = false;
        }
    }
    // Looking up an optional backend must not load it or create its Metal
    // context on a page that has never needed its drawing functions.
    if (void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD)) {
        auto purge = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
            dlsym(library, "vox_graphite_release_unused_graphics_memory"));
        if (purge) purge();
        dlclose(library);
    }
    if (void* library = dlopen("@rpath/libVoxGraphiteDawn.dylib", RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD)) {
        auto purge = reinterpret_cast<decltype(&vox_graphite_picture_release_unused_graphics_memory)>(
            dlsym(library, "vox_graphite_picture_release_unused_graphics_memory"));
        if (purge) purge();
        dlclose(library);
    }
    s_glyph_raster_cache.clear();
    SkGraphics::PurgeAllCaches();
}

extern "C" void ladybird_v_skia_set_chromium_painting(int active)
{
    if (!active) finish_shared_recording();
    s_chromium_painting = active != 0;
}

extern "C" int ladybird_v_skia_generate_svg_turbulence(
    uint8_t* destination_pixels, int width, int height,
    float base_frequency_x, float base_frequency_y, int num_octaves, float seed,
    int fractal_noise, int tile_width, int tile_height, float origin_x,
    float origin_y)
{
    if (!destination_pixels || width <= 0 || height <= 0
        || !std::isfinite(base_frequency_x) || base_frequency_x < 0.0f
        || !std::isfinite(base_frequency_y) || base_frequency_y < 0.0f
        || !std::isfinite(seed) || !std::isfinite(origin_x)
        || !std::isfinite(origin_y))
        return 0;

    auto tile_size = SkISize::Make(std::max(0, tile_width),
        std::max(0, tile_height));
    auto shader = fractal_noise
        ? SkShaders::MakeFractalNoise(base_frequency_x, base_frequency_y,
              std::clamp(num_octaves, 0, 255), seed, &tile_size)
        : SkShaders::MakeTurbulence(base_frequency_x, base_frequency_y,
              std::clamp(num_octaves, 0, 255), seed, &tile_size);
    if (!shader)
        return 0;

    auto image_info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(image_info, destination_pixels,
        static_cast<size_t>(width) * 4);
    if (!surface)
        return 0;

    SkPaint paint;
    paint.setImageFilter(SkImageFilters::Shader(std::move(shader)));
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    canvas->translate(-origin_x, -origin_y);
    canvas->saveLayer(nullptr, &paint);
    canvas->drawRect(SkRect::MakeXYWH(origin_x, origin_y,
                         static_cast<float>(width), static_cast<float>(height)),
        SkPaint {});
    canvas->restore();
    return 1;
}

extern "C" int ladybird_v_skia_begin_command_group(CGContextRef destination,
    float x, float y, float width, float height, float transform_a,
    float transform_b, float transform_c, float transform_d, float transform_e,
    float transform_f, float page_x, float page_y, float scroll_y,
    float canvas_width, float canvas_height)
{
    if (!destination || s_raster_command_group || width <= 0 || height <= 0
        || canvas_width <= 0 || canvas_height <= 0)
        return 0;
    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(SkRect::MakeXYWH(x, y, width, height)),
            canvas_width, canvas_height, 2.0f, region))
        return 0;

    auto destination_scale = screenshot_uses_logical_pixels()
        ? 1.0f
        : raster_scale_for_context(destination);
    auto group = std::make_unique<RasterCommandGroup>();
    group->destination = destination;
    group->canvas_height = canvas_height;
    group->region = region;
    group->raster_width = raster_dimension(region.width(), destination_scale);
    group->raster_height = raster_dimension(region.height(), destination_scale);
    group->scale_x = static_cast<float>(group->raster_width)
        / static_cast<float>(region.width());
    group->scale_y = static_cast<float>(group->raster_height)
        / static_cast<float>(region.height());
    group->pixels.resize(static_cast<size_t>(group->raster_width)
        * static_cast<size_t>(group->raster_height));
    auto image_info = SkImageInfo::Make(group->raster_width, group->raster_height,
        kBGRA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    group->surface = SkSurfaces::WrapPixels(image_info, group->pixels.data(),
        static_cast<size_t>(group->raster_width) * sizeof(uint32_t));
    if (!group->surface)
        return 0;
    group->surface->getCanvas()->clear(SK_ColorTRANSPARENT);
    s_raster_command_group = std::move(group);
    return 1;
}

extern "C" int ladybird_v_skia_end_command_group(CGContextRef destination)
{
    if (!s_raster_command_group || s_raster_command_group->destination != destination)
        return 0;
    auto group = std::move(s_raster_command_group);
    group->surface.reset();
    return composite_pixels(destination, std::move(group->pixels), group->raster_width,
        group->raster_height, static_cast<float>(group->region.left),
        group->canvas_height - static_cast<float>(group->region.bottom),
        static_cast<float>(group->region.width()),
        static_cast<float>(group->region.height()));
}

extern "C" int ladybird_v_skia_configure_font(char const* path, int slot)
{
    if (!path || slot < 0 || slot >= FontSlotCount)
        return 0;
    auto key = std::string(path) + "#0";
    if (auto found = s_path_typefaces.find(key); found != s_path_typefaces.end()) {
        s_typefaces[slot] = found->second;
        return 1;
    }
    auto data = SkData::MakeFromFileName(path);
    if (!data)
        return 0;
    auto manager = font_manager();
    if (!manager)
        return 0;
    SkFontArguments arguments;
    arguments.setCollectionIndex(0);
    auto typeface = manager->makeFromStream(
        std::make_unique<SkMemoryStream>(std::move(data)), arguments);
    if (!typeface)
        return 0;
    s_typefaces[slot] = typeface;
    s_path_typefaces.emplace(std::move(key), std::move(typeface));
    return 1;
}

// Register an installed face for retained glyph replay. Skia's CoreText stream
// loader cannot open non-zero collection members, so recreate the face that
// CoreText selected from its file, PostScript name and variation coordinates,
// as Blink does when it wraps a CTFont in an SkTypeface.
extern "C" int ladybird_v_skia_register_system_face(char const* key, char const* path,
    char const* postscript_name, uint32_t const* axis_tags, float const* axis_values, int axis_count)
{
    if (!key || !path || !postscript_name)
        return 0;
    if (s_system_typefaces.find(key) != s_system_typefaces.end())
        return 1;
    auto url = CFURLCreateFromFileSystemRepresentation(nullptr,
        reinterpret_cast<UInt8 const*>(path), static_cast<CFIndex>(std::strlen(path)), false);
    if (!url)
        return 0;
    auto wanted = CFStringCreateWithCString(nullptr, postscript_name, kCFStringEncodingUTF8);
    CTFontDescriptorRef selected = nullptr;
    // Prefer the installed font CoreText registered under this name. A face
    // re-created from its file loses system behavior that Blink's CTFont keeps,
    // such as Apple Color Emoji's strike advances and ascent. Skia caches the
    // first typeface created for an equal font, so it must also come first.
    if (wanted) {
        auto named = CTFontDescriptorCreateWithNameAndSize(wanted, 12.0);
        auto named_url = named
            ? static_cast<CFURLRef>(CTFontDescriptorCopyAttribute(named, kCTFontURLAttribute))
            : nullptr;
        char named_path[PATH_MAX];
        if (named_url && CFURLGetFileSystemRepresentation(named_url, true,
                reinterpret_cast<UInt8*>(named_path), sizeof(named_path))
            && !std::strcmp(named_path, path))
            selected = named;
        else if (named)
            CFRelease(named);
        if (named_url)
            CFRelease(named_url);
    }
    auto descriptors = selected ? nullptr : CTFontManagerCreateFontDescriptorsFromURL(url);
    CFRelease(url);
    if (!selected && !descriptors) {
        if (wanted)
            CFRelease(wanted);
        return 0;
    }
    for (CFIndex index = 0; !selected && wanted && index < CFArrayGetCount(descriptors); ++index) {
        auto descriptor = static_cast<CTFontDescriptorRef>(CFArrayGetValueAtIndex(descriptors, index));
        auto name = static_cast<CFStringRef>(CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute));
        bool same = name && CFEqual(name, wanted);
        if (name)
            CFRelease(name);
        if (same) {
            selected = static_cast<CTFontDescriptorRef>(CFRetain(descriptor));
            break;
        }
    }
    if (wanted)
        CFRelease(wanted);
    if (descriptors)
        CFRelease(descriptors);
    if (!selected)
        return 0;
    for (int index = 0; index < axis_count; ++index) {
        int32_t tag = static_cast<int32_t>(axis_tags[index]);
        auto tag_number = CFNumberCreate(nullptr, kCFNumberSInt32Type, &tag);
        auto copy = CTFontDescriptorCreateCopyWithVariation(selected, tag_number, axis_values[index]);
        CFRelease(tag_number);
        if (copy) {
            CFRelease(selected);
            selected = copy;
        }
    }
    auto font = CTFontCreateWithFontDescriptor(selected, 12.0, nullptr);
    CFRelease(selected);
    if (!font)
        return 0;
    auto typeface = SkMakeTypefaceFromCTFont(font);
    CFRelease(font);
    if (!typeface)
        return 0;
    s_system_typefaces.emplace(key, std::move(typeface));
    return 1;
}

// Blink shapes with Skia's glyph advances. For CoreText bitmap (sbix) faces,
// such as Apple Color Emoji, those are whole pixels for the selected strike and
// differ from the font's horizontal metrics table.
extern "C" int ladybird_v_skia_system_face_advances(char const* key, char const* path,
    char const* postscript_name, float size, uint16_t const* glyphs, int count, float* advances)
{
    if (!key || !glyphs || !advances || count <= 0 || !(size > 0))
        return 0;
    if (!ladybird_v_skia_register_system_face(key, path, postscript_name, nullptr, nullptr, 0))
        return 0;
    SkFont font(s_system_typefaces[key], size);
    font.setSubpixel(true);
    font.getWidths(SkSpan<const SkGlyphID>(glyphs, static_cast<size_t>(count)),
        SkSpan<SkScalar>(advances, static_cast<size_t>(count)));
    return 1;
}

// The advances of a document face's Skia strike, which Blink's HarfBuzz font
// functions supply in place of HarfBuzz's own scaled design advances.
extern "C" int ladybird_v_skia_face_advances(char const* font_path, int face_index,
    int font_weight, float size, uint16_t const* glyphs, int count, float* advances)
{
    if (!glyphs || !advances || count <= 0 || !(size > 0))
        return 0;
    auto* typeface = select_typeface(font_path, face_index, font_weight, 0);
    if (!typeface)
        return 0;
    SkFont font(sk_ref_sp(typeface), size);
    font.setSubpixel(true);
    font.setHinting(SkFontHinting::kNone);
    font.getWidths(SkSpan<const SkGlyphID>(glyphs, static_cast<size_t>(count)),
        SkSpan<SkScalar>(advances, static_cast<size_t>(count)));
    return 1;
}

static int draw_retained_glyph_run(CGContextRef destination,
    char const* font_path, int face_index, uint16_t const* glyphs, double const* packed_positions, int glyph_count,
    float font_size, int font_weight, int emoji_face, float baseline_x,
    float baseline_y, float transform_a, float transform_b, float transform_c,
    float transform_d, float transform_e, float transform_f, float page_x,
    float page_y, float scroll_y, float canvas_width, float canvas_height,
    uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha, int font_smoothing, float blur)
{
    auto* typeface = select_typeface(font_path, face_index, font_weight, emoji_face);
    if (!destination || !typeface || !glyphs || !packed_positions || glyph_count <= 0
        || canvas_width <= 0 || canvas_height <= 0)
        return 0;

    SkFont font(sk_ref_sp(typeface), std::max(font_size, 0.0f));
    // Blink synthesizes bold when the selected face has no bold instance.
    // Keep the retained glyph positions; Skia expands the glyph outlines.
    font.setEmbolden((font_smoothing & 16) && font_weight >= 600
        && typeface->fontStyle().weight() < 600);
    font.setSkewX((font_smoothing & 64) && !typeface->isItalic() ? -0.25f : 0.0f);
    if (font_smoothing & 16) {
        font.setEmbeddedBitmaps(false);
        font.setLinearMetrics(true);
        font.setEdging(SkFont::Edging::kSubpixelAntiAlias);
    }
    // This is the only non-default setting in Gfx::Font::skia_font().
    font.setSubpixel(true);
    switch (font_smoothing & 15) {
    case 1:
        font.setEdging(SkFont::Edging::kAlias);
        break;
    case 2:
        // Blink disables CoreGraphics outline dilation for antialiased text.
        font.setEdging(SkFont::Edging::kAntiAlias);
        font.setHinting(SkFontHinting::kNone);
        break;
    case 3:
        font.setEdging(SkFont::Edging::kSubpixelAntiAlias);
        break;
    default:
        break;
    }
    // Platform::FontPlugin forces normal hinting in layout-test mode so the
    // compositor produces deterministic screenshot glyphs on every host.
    if (auto* layout_test_font = std::getenv("LADYBIRD_LAYOUT_TEST_FONT");
        layout_test_font && *layout_test_font)
        font.setHinting(SkFontHinting::kNormal);

    SkTextBlobBuilder builder;
    auto const& run = builder.allocRunPos(font, glyph_count);
    for (int index = 0; index < glyph_count; ++index) {
        run.glyphs[index] = glyphs[index];
        run.pos[index * 2] = static_cast<SkScalar>(packed_positions[index * 2]);
        run.pos[index * 2 + 1] = static_cast<SkScalar>(packed_positions[index * 2 + 1]);
    }
    auto blob = builder.make();
    if (!blob)
        return 0;

    SkPaint paint;
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    if (blur > 0)
        paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, blur * 0.5f));
    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);

    if (auto* canvas = shared_recording_canvas(destination)) {
        canvas->save();
        canvas->setMatrix(matrix);
        canvas->drawTextBlob(blob, baseline_x, baseline_y, paint);
        canvas->restore();
    }

    // The old bridge allocated and recorded one canvas-sized transparent image
    // for every glyph run. A text-heavy page consequently made AppKit replay
    // hundreds of full-window images before its first composited frame. Keep
    // Skia's raster origin integer-aligned, but restrict the surface to the
    // transformed run bounds (plus an antialiasing guard pixel).
    auto local_bounds = blob->bounds();
    local_bounds.offset(baseline_x, baseline_y);
    if (blur > 0) {
        SkRect filtered_bounds;
        local_bounds = paint.computeFastBounds(local_bounds, &filtered_bounds);
    }
    auto device_bounds = matrix.mapRect(local_bounds);
    RasterRegion region;
    if (!clipped_raster_region(device_bounds, canvas_width, canvas_height, 2.0f, region))
        return 1;

    if (!leaf_raster_region_intersects_destination_clip(destination, canvas_height, region))
        return 1;

    auto destination_scale = raster_scale_for_context(destination);
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width) / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height) / static_cast<float>(region.height());
    bool chromium = font_smoothing & 16;
    size_t pixel_count = static_cast<size_t>(raster_width) * raster_height;
    // Avoid quantizing a partially covered foreground to premultiplied 8-bit
    // color before blending it over the page. The owning native bitmap frame
    // or opacity group supplies its pixels; transparency layers use the old path.
    auto backdrop = (font_smoothing & 32)
        ? read_backdrop(destination, region, destination_scale, raster_width, raster_height) : Backdrop {};
    bool has_background = backdrop.pixels != nullptr;
    auto draw_matrix = raster_matrix(matrix, region, raster_scale_x, raster_scale_y);
    GlyphRasterCache::Request cached;
    if (glyph_count <= 4096 && pixel_count <= 32768) {
        std::vector<uint8_t> key;
        uint32_t font_key[] {typeface->uniqueID(), uint32_t(font.getEdging()), uint32_t(font.getHinting()),
            uint32_t(font_smoothing), uint32_t(font.isEmbolden()), SkColorSetARGB(alpha, red, green, blue),
            uint32_t(raster_width), uint32_t(raster_height), uint32_t(glyph_count),
            uint32_t(CGBitmapContextGetBitmapInfo(destination)),
            uint32_t(CGBitmapContextGetBitsPerPixel(destination))};
        append_glyph_key(key, font_key, sizeof(font_key) / sizeof(font_key[0]));
        float geometry[] {font_size, baseline_x, baseline_y, blur, font.getSkewX()};
        append_glyph_key(key, geometry, 5);
        SkScalar values[9]; draw_matrix.get9(values); append_glyph_key(key, values, 9);
        append_glyph_key(key, glyphs, glyph_count);
        append_glyph_key(key, packed_positions, size_t(glyph_count) * 2);
        cached = s_glyph_raster_cache.prepare(std::move(key), raster_width, raster_height, backdrop.pixels, backdrop.pitch);
    }
    auto destination_rect = CGRectMake(static_cast<float>(region.left),
        canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()));
    if (cached.image) {
        return composite_image(destination, cached.image, destination_rect, has_background);
    }
    std::vector<uint32_t> pixels(pixel_count);
    if (has_background) copy_backdrop_pixels(backdrop, raster_width, raster_height, pixels);
    auto image_info = SkImageInfo::Make(raster_width, raster_height,
        kBGRA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto row_bytes = static_cast<size_t>(raster_width) * sizeof(uint32_t);
    // Chromium omits the A8 preblend for unhinted CoreText text. Its smoothed
    // masks use the sRGB transfer with zero contrast boost.
    SkSurfaceProps chromium_coverage(0, kUnknown_SkPixelGeometry, 0.0f,
        (font_smoothing & 15) == 2 ? 1.0f : 0.0f);
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(), row_bytes,
        chromium ? &chromium_coverage : nullptr);
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    if (!has_background) canvas->clear(SK_ColorTRANSPARENT);
    canvas->setMatrix(draw_matrix);
    canvas->drawTextBlob(blob, baseline_x, baseline_y, paint);
    surface.reset();
    auto image = create_pixel_image(destination, std::move(pixels), raster_width, raster_height);
    int result = composite_image(destination, image, destination_rect, has_background);
    s_glyph_raster_cache.finish(std::move(cached), image);
    if (image) CGImageRelease(image);

    return result;
}

extern "C" int ladybird_v_skia_draw_glyph_run(CGContextRef destination,
    char const* font_path, int face_index, uint16_t const* glyphs, double const* packed_positions, int glyph_count,
    float font_size, int font_weight, int emoji_face, float baseline_x,
    float baseline_y, float transform_a, float transform_b, float transform_c,
    float transform_d, float transform_e, float transform_f, float page_x,
    float page_y, float scroll_y, float canvas_width, float canvas_height,
    uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha, int font_smoothing)
{
    return draw_retained_glyph_run(destination, font_path, face_index, glyphs,
        packed_positions, glyph_count, font_size, font_weight, emoji_face,
        baseline_x, baseline_y, transform_a, transform_b, transform_c,
        transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
        canvas_width, canvas_height, red, green, blue, alpha, font_smoothing,
        0);
}

extern "C" int ladybird_v_skia_draw_glyph_shadow_run(CGContextRef destination,
    char const* font_path, int face_index, uint16_t const* glyphs, double const* packed_positions, int glyph_count,
    float font_size, int font_weight, int emoji_face, float baseline_x,
    float baseline_y, float transform_a, float transform_b, float transform_c,
    float transform_d, float transform_e, float transform_f, float page_x,
    float page_y, float scroll_y, float canvas_width, float canvas_height,
    uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha, int font_smoothing, float blur)
{
    if (!(font_smoothing & 16) || emoji_face || !std::isfinite(blur) || blur < 0) return 0;
    // The native shell supplies device blur; Skia scales its mask filter with the CTM.
    float font_scale = std::hypot(transform_a, transform_b);
    if (!std::isfinite(font_scale)) return 0;
    return draw_retained_glyph_run(destination, font_path, face_index, glyphs,
        packed_positions, glyph_count, font_size, font_weight, emoji_face,
        baseline_x, baseline_y, transform_a, transform_b, transform_c,
        transform_d, transform_e, transform_f, page_x, page_y, scroll_y,
        canvas_width, canvas_height, red, green, blue, alpha, font_smoothing,
        font_scale > 0 ? blur / font_scale : 0);
}

// Canvas command streams retain shaped glyph IDs all the way to the raster
// backend. The compact V browser stores canvas pixels in unpremultiplied RGBA,
// so wrap a premultiplied working copy in the same Skia text-blob renderer and
// copy it back after each retained run.
extern "C" int ladybird_v_skia_draw_canvas_glyph_run(
    uint8_t* destination_pixels, int width, int height, int pitch,
    int pixels_are_premultiplied,
    char const* font_path, int face_index, uint16_t const* glyphs,
    double const* packed_positions, int glyph_count, float font_size,
    int font_weight, float baseline_x, float baseline_y, float transform_a,
    float transform_b, float transform_c, float transform_d, float transform_e,
    float transform_f, uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha,
    float gradient_x0, float gradient_y0, float gradient_x1, float gradient_y1,
    float const* gradient_stops, int gradient_stop_count, float global_alpha,
    int stroke, int use_outline, float stroke_width)
{
    auto* typeface = select_typeface(font_path, face_index, font_weight, 0);
    if (!destination_pixels || !typeface || !glyphs || !packed_positions
        || glyph_count <= 0 || width <= 0 || height <= 0 || pitch < width * 4)
        return 0;

    SkFont font(sk_ref_sp(typeface), std::max(font_size, 0.0f));
    font.setSubpixel(true);
    // Match Canvas2DCommandStream playback: canvas text preserves fractional
    // baselines and uses unhinted outline geometry.
    font.setHinting(SkFontHinting::kNone);
    font.setForceAutoHinting(false);
    font.setBaselineSnap(false);
    SkTextBlobBuilder builder;
    auto const& run = builder.allocRunPos(font, glyph_count);
    for (int index = 0; index < glyph_count; ++index) {
        run.glyphs[index] = glyphs[index];
        run.pos[index * 2] = static_cast<SkScalar>(packed_positions[index * 2]);
        run.pos[index * 2 + 1] = static_cast<SkScalar>(packed_positions[index * 2 + 1]);
    }
    auto blob = builder.make();
    if (!blob)
        return 0;

    std::vector<uint8_t> premultiplied(static_cast<size_t>(pitch) * height);
    for (int y = 0; y < height; ++y) {
        auto const* source = destination_pixels + static_cast<size_t>(y) * pitch;
        auto* destination = premultiplied.data() + static_cast<size_t>(y) * pitch;
        for (int x = 0; x < width; ++x) {
            auto offset = static_cast<size_t>(x) * 4;
            auto source_alpha = source[offset + 3];
            destination[offset] = pixels_are_premultiplied ? source[offset]
                                                            : static_cast<uint8_t>((source[offset] * source_alpha + 127) / 255);
            destination[offset + 1] = pixels_are_premultiplied ? source[offset + 1]
                                                                : static_cast<uint8_t>((source[offset + 1] * source_alpha + 127) / 255);
            destination[offset + 2] = pixels_are_premultiplied ? source[offset + 2]
                                                                : static_cast<uint8_t>((source[offset + 2] * source_alpha + 127) / 255);
            destination[offset + 3] = source_alpha;
        }
    }

    auto image_info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(image_info, premultiplied.data(),
        static_cast<size_t>(pitch));
    if (!surface)
        return 0;

    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(std::clamp(global_alpha, 0.0f, 1.0f));
    if (gradient_stops && gradient_stop_count > 0) {
        std::vector<SkColor4f> colors;
        std::vector<SkScalar> offsets;
        colors.reserve(static_cast<size_t>(gradient_stop_count));
        offsets.reserve(static_cast<size_t>(gradient_stop_count));
        for (int index = 0; index < gradient_stop_count; ++index) {
            auto const* stop = gradient_stops + index * 5;
            offsets.push_back(stop[0]);
            colors.push_back({ stop[1], stop[2], stop[3], stop[4] });
        }
        SkPoint points[] = { { gradient_x0, gradient_y0 }, { gradient_x1, gradient_y1 } };
        paint.setShader(SkGradientShader::MakeLinear(points, colors.data(),
            SkColorSpace::MakeSRGB(), offsets.data(), gradient_stop_count,
            SkTileMode::kClamp));
    } else {
        paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    }
    if (stroke) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(std::max(stroke_width, 0.0f));
    }

    auto* canvas = surface->getCanvas();
    // Canvas bitmap rows are handed to the Cocoa compositor in bottom-up view
    // coordinates. Store the CSS y-down result reflected in the backing buffer;
    // native_draw_image_part_in_context() performs the matching row reflection
    // when the canvas is painted into the document.
    canvas->setMatrix(SkMatrix::MakeAll(
        transform_a, transform_c, transform_e,
        -transform_b, -transform_d, static_cast<float>(height) - transform_f,
        0.0f, 0.0f, 1.0f));
    if (use_outline) {
        SkPath outline;
        for (int index = 0; index < glyph_count; ++index) {
            SkPath glyph_path;
            if (!font.getPath(glyphs[index], &glyph_path))
                continue;
            SkMatrix translation = SkMatrix::Translate(
                baseline_x + static_cast<float>(packed_positions[index * 2]),
                baseline_y + static_cast<float>(packed_positions[index * 2 + 1]));
            outline.addPath(glyph_path, translation);
        }
        canvas->drawPath(outline, paint);
    } else {
        canvas->drawTextBlob(blob, baseline_x, baseline_y, paint);
    }

    std::memcpy(destination_pixels, premultiplied.data(),
        static_cast<size_t>(pitch) * height);
    return 1;
}

extern "C" int ladybird_v_skia_draw_line(CGContextRef destination,
    float from_x, float from_y, float to_x, float to_y, float thickness,
    int line_style, float canvas_width, float canvas_height, uint8_t red,
    uint8_t green, uint8_t blue, uint8_t alpha)
{
    if (!destination || thickness <= 0 || canvas_width <= 0 || canvas_height <= 0)
        return 0;
    auto length = std::hypot(to_x - from_x, to_y - from_y);
    float dash_interval = 0.0f;
    if (line_style == 1 && length > 0.0f) {
        auto dot_count = std::floor(length / (thickness * 2.0f));
        if (dot_count > 0.0f) {
            dash_interval = length / dot_count;
            auto direction_x = (to_x - from_x) / length;
            auto direction_y = (to_y - from_y) / length;
            to_x += direction_x * (dash_interval / 2.0f);
            to_y += direction_y * (dash_interval / 2.0f);
        }
    } else if (line_style == 2 && length > 0.0f) {
        auto extended_length = length + thickness;
        auto dash_count = std::floor(extended_length / thickness / 4.0f) * 2.0f + 1.0f;
        dash_interval = extended_length / dash_count;
        auto direction_x = (to_x - from_x) / length;
        auto direction_y = (to_y - from_y) / length;
        from_x -= direction_x * (thickness / 2.0f);
        from_y -= direction_y * (thickness / 2.0f);
        to_x += direction_x * (thickness / 2.0f);
        to_y += direction_y * (thickness / 2.0f);
    }
    auto half_stroke = thickness * 0.5f;
    RasterRegion region;
    if (!clipped_raster_region(SkRect::MakeLTRB(
            std::min(from_x, to_x) - half_stroke,
            std::min(from_y, to_y) - half_stroke,
            std::max(from_x, to_x) + half_stroke,
            std::max(from_y, to_y) + half_stroke),
            canvas_width, canvas_height, 2.0f, region))
        return 1;
    SkPaint paint;
    paint.setAntiAlias(true);
    auto destination_scale = raster_scale_for_context(destination);
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width) / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height) / static_cast<float>(region.height());
    auto raster_scale = std::max(raster_scale_x, raster_scale_y);
    paint.setStrokeWidth(thickness * raster_scale);
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    if (line_style == 1 && dash_interval > 0.0f) {
        SkScalar intervals[] = { 0.0f, dash_interval * raster_scale };
        paint.setPathEffect(SkDashPathEffect::Make(intervals, 0.0f));
        paint.setStrokeCap(SkPaint::kRound_Cap);
    } else if (line_style == 2 && dash_interval > 0.0f) {
        SkScalar intervals[] = { dash_interval * raster_scale, dash_interval * raster_scale };
        paint.setPathEffect(SkDashPathEffect::Make(intervals, 0.0f));
    }
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width) * static_cast<size_t>(raster_height));
    auto image_info = SkImageInfo::Make(raster_width, raster_height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto row_bytes = static_cast<size_t>(raster_width) * sizeof(uint32_t);
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(), row_bytes);
    if (!surface)
        return 0;
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    canvas->drawLine(
        (from_x - static_cast<float>(region.left)) * raster_scale_x,
        (from_y - static_cast<float>(region.top)) * raster_scale_y,
        (to_x - static_cast<float>(region.left)) * raster_scale_x,
        (to_y - static_cast<float>(region.top)) * raster_scale_y, paint);
    surface.reset();
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()));
}

// The PNG color profile of the next image drawn, set around each draw by the
// native image player: inverse gamma, whether primaries follow, then red,
// green, blue and white chromaticities.
static bool s_has_image_color_profile = false;
static float s_image_color_profile[10] {};

extern "C" void ladybird_v_skia_set_image_color_profile(float const* profile)
{
    s_has_image_color_profile = profile != nullptr;
    if (profile)
        std::copy_n(profile, 10, s_image_color_profile);
}

static sk_sp<SkColorSpace> image_color_space()
{
    if (!s_has_image_color_profile) return SkColorSpace::MakeSRGB();
    skcms_TransferFunction transfer { s_image_color_profile[0], 1, 0, 0, 0, 0, 0 };
    skcms_Matrix3x3 gamut = SkNamedGamut::kSRGB;
    float const* p = s_image_color_profile;
    if (p[1] != 0 && !skcms_PrimariesToXYZD50(p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], &gamut))
        return SkColorSpace::MakeSRGB();
    auto space = SkColorSpace::MakeRGB(transfer, gamut);
    return space ? space : SkColorSpace::MakeSRGB();
}

static sk_sp<SkShader> webp_yuv_shader(uint8_t const* planes, int width, int height,
    SkSamplingOptions const& sampling, SkRect const& source, SkRect const& destination,
    bool full_range, bool full_chroma)
{
    // Sample the original 4:2:0 planes before Rec.601 conversion, as Chromium's
    // GPU YUVA image does. Early RGB quantization changes downscaled colors.
    // WebP planes use the limited BT.601 range and JPEG planes the full range.
    static auto effect = SkRuntimeEffect::MakeForShader(SkString(R"(
        uniform shader luma;
        uniform shader chroma_u;
        uniform shader chroma_v;
        uniform int nearest;
        uniform int full_range;
        uniform float chroma_scale;
        uniform float4 source_bounds;
        half4 main(float2 p) {
            p = clamp(p, source_bounds.xy, source_bounds.zw);
            if (nearest != 0) p = floor(p) + 0.5;
            float y = float(luma.eval(p).r);
            float u = float(chroma_u.eval(p * chroma_scale).r);
            float v = float(chroma_v.eval(p * chroma_scale).r);
            if (full_range != 0) {
                return half4(clamp(float3(
                    y + 1.402 * (v - 0.501961),
                    y - 0.344136 * (u - 0.501961) - 0.714136 * (v - 0.501961),
                    y + 1.772 * (u - 0.501961)), 0.0, 1.0), 1.0);
            }
            return half4(clamp(float3(
                1.164384 * y + 1.596027 * v - 0.874202,
                1.164384 * y - 0.391762 * u - 0.812968 * v + 0.531668,
                1.164384 * y + 2.017232 * u - 1.085631), 0.0, 1.0), 1.0);
        }
    )"));
    if (!effect.effect) return nullptr;
    int uv_width = full_chroma ? width : (width + 1) / 2;
    int uv_height = full_chroma ? height : (height + 1) / 2;
    auto plane = [](uint8_t const* data, int w, int h) {
        SkPixmap pixmap(SkImageInfo::Make(w, h, kGray_8_SkColorType, kOpaque_SkAlphaType), data, w);
        return SkImages::RasterFromPixmapCopy(pixmap);
    };
    auto y = plane(planes, width, height);
    auto u = plane(planes + static_cast<size_t>(width) * height, uv_width, uv_height);
    auto v = plane(planes + static_cast<size_t>(width) * height
        + static_cast<size_t>(uv_width) * uv_height, uv_width, uv_height);
    if (!y || !u || !v) return nullptr;
    SkRuntimeShaderBuilder builder(effect.effect);
    builder.uniform("nearest") = sampling.filter == SkFilterMode::kNearest ? 1 : 0;
    builder.uniform("full_range") = full_range ? 1 : 0;
    builder.uniform("chroma_scale") = full_chroma ? 1.0f : 0.5f;
    builder.uniform("source_bounds") = SkV4{source.left() + 0.5f, source.top() + 0.5f,
        source.right() - 0.5f, source.bottom() - 0.5f};
    builder.child("luma") = y->makeShader(SkTileMode::kClamp, SkTileMode::kClamp, SkSamplingOptions(SkFilterMode::kLinear));
    builder.child("chroma_u") = u->makeShader(SkTileMode::kClamp, SkTileMode::kClamp, SkSamplingOptions(SkFilterMode::kLinear));
    builder.child("chroma_v") = v->makeShader(SkTileMode::kClamp, SkTileMode::kClamp, SkSamplingOptions(SkFilterMode::kLinear));
    auto shader = builder.makeShader();
    return shader ? shader->makeWithLocalMatrix(SkMatrix::RectToRect(source, destination)) : nullptr;
}

// Whether no two tiles touch the same pixel.
static bool tiles_touch_disjoint_pixels(SkMatrix const& matrix, float const* tiles,
    std::vector<int> const& drawn)
{
    std::vector<SkIRect> rects;
    rects.reserve(drawn.size());
    for (int index : drawn) {
        float const* tile = tiles + static_cast<size_t>(index) * 8;
        rects.push_back(matrix.mapRect(SkRect::MakeXYWH(tile[0], tile[1], tile[2], tile[3])).roundOut());
    }
    std::sort(rects.begin(), rects.end(), [](SkIRect const& a, SkIRect const& b) {
        return a.fTop != b.fTop ? a.fTop < b.fTop : a.fLeft < b.fLeft;
    });
    for (size_t index = 0; index < rects.size(); ++index) {
        for (size_t next = index + 1; next < rects.size() && rects[next].fTop < rects[index].fBottom; ++next) {
            if (SkIRect::Intersects(rects[index], rects[next]))
                return false;
        }
    }
    return true;
}

// A background's tiles, eight floats each: the destination and the source
// rectangle that ladybird_v_skia_draw_rgba_image() would receive for it. The
// GPU painter draws them in turn over one raster spanning the regions that
// path would rasterize, so the tiles share one backdrop upload and readback.
// Returns 0 when it cannot, and the caller draws the tiles one at a time.
static std::vector<char> chromium_layer_msaa_rows(long top, int height,
    float page_y, float scroll_y, float scale);
static bool draw_chromium_root_image_tiles(std::vector<uint32_t>& pixels,
    int raster_width, int raster_height, RasterRegion const& region,
    float scale, float page_x, float page_y, float scroll_y,
    float canvas_width, bool has_background, VoxGraphiteImage const& descriptor);

extern "C" int ladybird_v_skia_draw_rgba_image_tiles(CGContextRef destination,
    uint8_t const* source_pixels, int image_width, int image_height,
    int image_pitch, float const* tiles, int tile_count, float clip_x,
    float clip_y, float clip_width, float clip_height, float transform_a,
    float transform_b, float transform_c, float transform_d, float transform_e,
    float transform_f, float page_x, float page_y, float scroll_y,
    float canvas_width, float canvas_height, float opacity, int nearest_neighbor,
    int image_flags, float const* clip_radii)
{
    if (!s_chromium_painting || !destination || !source_pixels || !tiles || tile_count <= 0
        || image_width <= 0 || image_height <= 0 || image_pitch < image_width * 4
        || clip_width <= 0 || clip_height <= 0 || canvas_width <= 0
        || canvas_height <= 0)
        return 0;
    // Graphite's rounded clip coverage depends on the raster it is drawn in,
    // so tiles under rounded corners keep their own rasters.
    if (clip_radii && std::any_of(clip_radii, clip_radii + 8, [](float radius) { return radius != 0; }))
        return 0;
    auto draw = graphite_image_tiles_draw();
    if (!draw)
        return 0;
    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);
    // A scaled draw samples at raster coordinates whose float rounding depends
    // on the raster's extent; only translated tiles sample identically in one.
    if (!matrix.isTranslate())
        return 0;
    auto local_clip = SkRect::MakeXYWH(clip_x, clip_y, clip_width, clip_height);
    auto device_clip = matrix.mapRect(local_clip);
    std::vector<int> drawn;
    drawn.reserve(static_cast<size_t>(tile_count));
    RasterRegion region;
    for (int index = 0; index < tile_count; ++index) {
        float const* tile = tiles + static_cast<size_t>(index) * 8;
        if (!(tile[2] > 0) || !(tile[3] > 0) || !(tile[6] > 0) || !(tile[7] > 0))
            continue;
        auto device_bounds = matrix.mapRect(SkRect::MakeXYWH(tile[0], tile[1], tile[2], tile[3]));
        RasterRegion tile_region;
        if (!device_bounds.intersect(device_clip)
            || !clipped_raster_region(device_bounds, canvas_width, canvas_height, 0.0f, tile_region)
            || !leaf_raster_region_intersects_destination_clip(destination, canvas_height, tile_region))
            continue;
        if (drawn.empty()) {
            region = tile_region;
        } else {
            region.left = std::min(region.left, tile_region.left);
            region.top = std::min(region.top, tile_region.top);
            region.right = std::max(region.right, tile_region.right);
            region.bottom = std::max(region.bottom, tile_region.bottom);
        }
        drawn.push_back(index);
    }
    if (drawn.empty())
        return 1;

    auto destination_scale = raster_scale_for_context(destination);
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width)
        / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height)
        / static_cast<float>(region.height());
    auto rows = chromium_layer_msaa_rows(region.top, raster_height, page_y, scroll_y, destination_scale);
    // Multisampling exposes raster-extent rounding for fractional translations.
    // Preserve each tile's existing raster in that case.
    bool fractional_translation = matrix.getTranslateX() * destination_scale != std::floor(matrix.getTranslateX() * destination_scale)
        || matrix.getTranslateY() * destination_scale != std::floor(matrix.getTranslateY() * destination_scale);
    if (fractional_translation && std::find(rows.begin(), rows.end(), char(1)) != rows.end()) return 0;
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width)
        * static_cast<size_t>(raster_height));
    bool has_background = (image_flags & 2) && copy_backdrop(destination,
        region, destination_scale, raster_width, raster_height, pixels);
    // Over the copied backdrop, each tile blends onto the same 8-bit pixels
    // either way. Composited separately instead, two tiles touching one pixel
    // round their blends in a different order, so none may share a pixel.
    if (!has_background && !tiles_touch_disjoint_pixels(matrix, tiles, drawn))
        return 0;
    float raster_transform[9];
    raster_matrix(matrix, region, raster_scale_x, raster_scale_y).get9(raster_transform);
    std::vector<VoxGraphiteImage> descriptors;
    descriptors.reserve(drawn.size());
    for (int index : drawn) {
        float const* tile = tiles + static_cast<size_t>(index) * 8;
        VoxGraphiteImage descriptor {
            .matrix = {},
            .source = {tile[4], tile[5], tile[6], tile[7]},
            .destination = {tile[0], tile[1], tile[2], tile[3]},
            .clip = {clip_x, clip_y, clip_width, clip_height},
            .opacity = opacity, .width = image_width, .height = image_height,
            .pitch = image_pitch, .flags = image_flags, .nearest = nearest_neighbor == 1,
            .pixels = source_pixels, .has_color_profile = s_has_image_color_profile
        };
        std::copy_n(s_image_color_profile, 10, descriptor.color_profile);
        if (clip_radii) std::copy_n(clip_radii, 8, descriptor.clip + 4);
        std::copy_n(raster_transform, 9, descriptor.matrix);
        descriptors.push_back(descriptor);
    }

    if (!vox_draw_with_msaa_rows(pixels, raster_width, rows, [&](auto& target, bool msaa) {
            for (auto& descriptor : descriptors)
                descriptor.flags = (descriptor.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
                    | (msaa ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
            return draw(reinterpret_cast<uint8_t*>(target.data()), raster_width, raster_height,
                raster_width * 4, has_background, descriptors.data(), static_cast<int>(descriptors.size())) != 0;
        })) return 0;
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
}

extern "C" int ladybird_v_skia_draw_rgba_image(CGContextRef destination,
    uint8_t const* source_pixels, int image_width, int image_height,
    int image_pitch, float destination_x, float destination_y,
    float destination_width, float destination_height, float source_x,
    float source_y, float source_width, float source_height, float clip_x,
    float clip_y, float clip_width, float clip_height, float transform_a,
    float transform_b, float transform_c, float transform_d, float transform_e,
    float transform_f, float page_x, float page_y, float scroll_y,
    float canvas_width, float canvas_height, float opacity, int nearest_neighbor,
    int image_flags, float const* clip_radii)
{
    // Flags: premultiplied RGBA (1), readable opaque page backdrop (2),
    // or a tightly packed Y/U/V 4:2:0 payload in place of RGBA (4).
    if (!destination || !source_pixels || image_width <= 0 || image_height <= 0
        || image_pitch < image_width * 4 || destination_width <= 0
        || destination_height <= 0 || source_width <= 0 || source_height <= 0
        || clip_width <= 0 || clip_height <= 0 || canvas_width <= 0
        || canvas_height <= 0)
        return 0;

    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);
    auto local_destination = SkRect::MakeXYWH(destination_x, destination_y,
        destination_width, destination_height);
    auto local_clip = SkRect::MakeXYWH(clip_x, clip_y, clip_width, clip_height);
    auto device_bounds = matrix.mapRect(local_destination);
    auto device_clip = matrix.mapRect(local_clip);
    if (!device_bounds.intersect(device_clip))
        return 1;
    RasterRegion region;
    if (!clipped_raster_region(device_bounds, canvas_width, canvas_height, 0.0f,
            region))
        return 1;
    if (!leaf_raster_region_intersects_destination_clip(destination, canvas_height, region))
        return 1;

    auto destination_scale = raster_scale_for_context(destination);
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width)
        / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height)
        / static_cast<float>(region.height());
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width)
        * static_cast<size_t>(raster_height));
    bool has_background = (image_flags & 2) && copy_backdrop(destination,
        region, destination_scale, raster_width, raster_height, pixels);
    if (s_chromium_painting) {
        VoxGraphiteImage descriptor {
            .matrix = {},
            .source = {source_x, source_y, source_width, source_height},
            .destination = {destination_x, destination_y, destination_width, destination_height},
            .clip = {clip_x, clip_y, clip_width, clip_height},
            .opacity = opacity, .width = image_width, .height = image_height,
            .pitch = image_pitch, .flags = image_flags, .nearest = nearest_neighbor == 1,
            .pixels = source_pixels, .has_color_profile = s_has_image_color_profile
        };
        std::copy_n(s_image_color_profile, 10, descriptor.color_profile);
        if (clip_radii) std::copy_n(clip_radii, 8, descriptor.clip + 4);
        shared_recording_image(destination, matrix, descriptor);
        raster_matrix(matrix, region, raster_scale_x, raster_scale_y).get9(descriptor.matrix);
        auto rows = chromium_layer_msaa_rows(region.top, raster_height, page_y, scroll_y, destination_scale);
        auto draw = graphite_image_draw();
        bool drawn = draw && draw_chromium_root_image_tiles(pixels, raster_width,
            raster_height, region, destination_scale, page_x, page_y, scroll_y,
            canvas_width, has_background, descriptor);
        if (!drawn && draw) drawn = vox_draw_with_msaa_rows(pixels, raster_width, rows, [&](auto& target, bool msaa) {
                descriptor.flags = (descriptor.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
                    | (msaa ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
                return draw(reinterpret_cast<uint8_t*>(target.data()), raster_width, raster_height,
                    raster_width * 4, has_background, &descriptor) != 0;
            });
        if (drawn) {
            return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
                static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
                static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
        }
    }
    // Build the CPU image only if the GPU path could not draw it.
    sk_sp<SkImage> source_image;
    if (!(image_flags & 4)) {
        auto source_info = SkImageInfo::Make(image_width, image_height,
            kRGBA_8888_SkColorType,
            (image_flags & 1) ? kPremul_SkAlphaType : kUnpremul_SkAlphaType,
            image_color_space());
        SkPixmap source_pixmap(source_info, source_pixels,
            static_cast<size_t>(image_pitch));
        // Chromium uploads premultiplied image texels before filtering. Filtering
        // straight-alpha colors first changes both transparent edges and gradients.
        std::vector<uint8_t> premultiplied_source;
        if (!(image_flags & 1)) {
            premultiplied_source.resize(static_cast<size_t>(image_pitch) * image_height);
            auto info = source_info.makeAlphaType(kPremul_SkAlphaType);
            if (!source_pixmap.readPixels(info, premultiplied_source.data(), image_pitch))
                return 0;
            source_pixmap = SkPixmap(info, premultiplied_source.data(), image_pitch);
        }
        // Like the GPU path, convert a tagged image to an 8-bit sRGB copy first.
        std::vector<uint8_t> converted_source;
        if (s_has_image_color_profile) {
            converted_source.resize(static_cast<size_t>(image_pitch) * image_height);
            auto info = source_pixmap.info().makeColorSpace(SkColorSpace::MakeSRGB());
            if (!source_pixmap.readPixels(info, converted_source.data(), image_pitch))
                return 0;
            source_pixmap = SkPixmap(info, converted_source.data(), image_pitch);
        }
        source_image = SkImages::RasterFromPixmapCopy(source_pixmap);
        if (!source_image)
            return 0;

    }
    auto image_info = SkImageInfo::Make(raster_width, raster_height,
        kBGRA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    std::vector<float> float_pixels;
    auto working_info = image_info;
    void* working_pixels = pixels.data();
    size_t working_pitch = static_cast<size_t>(raster_width) * sizeof(uint32_t);
    if (image_flags & 2) {
        working_info = image_info.makeColorType(kRGBA_F32_SkColorType);
        working_pitch = static_cast<size_t>(raster_width) * 4 * sizeof(float);
        float_pixels.resize(static_cast<size_t>(raster_width) * raster_height * 4);
        SkPixmap background(image_info, pixels.data(), static_cast<size_t>(raster_width) * 4);
        if (!background.readPixels(working_info, float_pixels.data(), working_pitch))
            return 0;
        working_pixels = float_pixels.data();
    }
    auto surface = SkSurfaces::WrapPixels(working_info, working_pixels, working_pitch);
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    if (!has_background) canvas->clear(SK_ColorTRANSPARENT);
    canvas->setMatrix(raster_matrix(matrix, region, raster_scale_x,
        raster_scale_y));
    if (clip_radii) {
        SkVector radii[4] {{clip_radii[0], clip_radii[1]}, {clip_radii[2], clip_radii[3]},
            {clip_radii[4], clip_radii[5]}, {clip_radii[6], clip_radii[7]}};
        SkRRect clip;
        clip.setRectRadii(local_clip, radii);
        canvas->clipRRect(clip, true);
    } else canvas->clipRect(local_clip, true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(std::clamp(opacity, 0.0f, 1.0f));
    auto source_rect = SkRect::MakeXYWH(source_x, source_y, source_width,
        source_height);
    auto sampling = nearest_neighbor == 1
        ? SkSamplingOptions(SkFilterMode::kNearest)
        : SkSamplingOptions(SkFilterMode::kLinear);
    if (image_flags & 4) {
        auto shader = webp_yuv_shader(source_pixels, image_width, image_height,
            sampling, source_rect, local_destination, (image_flags & 8) != 0,
            (image_flags & 16) != 0);
        if (!shader) return 0;
        paint.setShader(std::move(shader));
        canvas->drawRect(local_destination, paint);
    } else {
        canvas->drawImageRect(source_image.get(), source_rect, local_destination,
            sampling, &paint, SkCanvas::kStrict_SrcRectConstraint);
    }
    if (!float_pixels.empty()) {
        SkPixmap result(working_info, float_pixels.data(), working_pitch);
        if (!result.readPixels(image_info, pixels.data(), static_cast<size_t>(raster_width) * 4))
            return 0;
    }
    surface.reset();
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
}

extern "C" int ladybird_v_skia_draw_drop_shadow(CGContextRef destination,
    CGImageRef source, float canvas_width, float canvas_height, float scale,
    float offset_x, float offset_y, float standard_deviation, uint8_t red,
    uint8_t green, uint8_t blue, uint8_t alpha)
{
    if (!destination || !source || canvas_width <= 0 || canvas_height <= 0
        || scale <= 0)
        return 0;
    auto width = static_cast<int>(CGImageGetWidth(source));
    auto height = static_cast<int>(CGImageGetHeight(source));
    if (width <= 0 || height <= 0)
        return 0;

    auto source_pitch = static_cast<size_t>(width) * 4;
    std::vector<uint8_t> source_pixels(source_pitch * static_cast<size_t>(height));
    auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto decode = CGBitmapContextCreate(source_pixels.data(), width, height, 8,
        source_pitch, color_space,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color_space);
    if (!decode)
        return 0;
    CGContextSetBlendMode(decode, kCGBlendModeCopy);
    CGContextDrawImage(decode, CGRectMake(0, 0, width, height), source);
    CGContextRelease(decode);
    for (size_t offset = 0; offset < source_pixels.size(); offset += 4) {
        auto source_alpha = source_pixels[offset + 3];
        if (source_alpha != 0 && source_alpha != 255) {
            source_pixels[offset] = static_cast<uint8_t>(std::min(255,
                (source_pixels[offset] * 255 + source_alpha / 2) / source_alpha));
            source_pixels[offset + 1] = static_cast<uint8_t>(std::min(255,
                (source_pixels[offset + 1] * 255 + source_alpha / 2) / source_alpha));
            source_pixels[offset + 2] = static_cast<uint8_t>(std::min(255,
                (source_pixels[offset + 2] * 255 + source_alpha / 2) / source_alpha));
        }
    }

    auto source_info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
        kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto source_image = SkImages::RasterFromPixmapCopy(
        SkPixmap(source_info, source_pixels.data(), source_pitch));
    if (!source_image)
        return 0;

    std::vector<uint32_t> output_pixels(static_cast<size_t>(width)
        * static_cast<size_t>(height));
    auto output_info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(output_info, output_pixels.data(),
        static_cast<size_t>(width) * sizeof(uint32_t));
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setImageFilter(SkImageFilters::DropShadow(offset_x * scale,
        offset_y * scale, std::max(standard_deviation, 0.0f) * scale,
        std::max(standard_deviation, 0.0f) * scale,
        SkColorSetARGB(alpha, red, green, blue), nullptr));
    canvas->drawImage(source_image.get(), 0, 0, SkSamplingOptions(), &paint);
    surface.reset();
    return composite_pixels(destination, std::move(output_pixels), width, height, 0, 0,
        canvas_width, canvas_height);
}

extern "C" int ladybird_v_skia_draw_masked_image(CGContextRef destination,
    CGImageRef content, CGImageRef mask, float destination_x,
    float destination_y, float destination_width, float destination_height)
{
    if (!destination || !content || !mask || destination_width <= 0
        || destination_height <= 0)
        return 0;
    auto width = static_cast<int>(CGImageGetWidth(content));
    auto height = static_cast<int>(CGImageGetHeight(content));
    if (width <= 0 || height <= 0 || CGImageGetWidth(mask) != static_cast<size_t>(width)
        || CGImageGetHeight(mask) != static_cast<size_t>(height))
        return 0;

    auto decode_image = [width, height](CGImageRef image) -> sk_sp<SkImage> {
        auto pitch = static_cast<size_t>(width) * 4;
        std::vector<uint8_t> pixels(pitch * static_cast<size_t>(height));
        auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(pixels.data(), width, height, 8,
            pitch, color_space, static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
        CGColorSpaceRelease(color_space);
        if (!context)
            return nullptr;
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        CGContextRelease(context);
        for (size_t offset = 0; offset < pixels.size(); offset += 4) {
            auto alpha = pixels[offset + 3];
            if (alpha != 0 && alpha != 255) {
                pixels[offset] = static_cast<uint8_t>(std::min(255,
                    (pixels[offset] * 255 + alpha / 2) / alpha));
                pixels[offset + 1] = static_cast<uint8_t>(std::min(255,
                    (pixels[offset + 1] * 255 + alpha / 2) / alpha));
                pixels[offset + 2] = static_cast<uint8_t>(std::min(255,
                    (pixels[offset + 2] * 255 + alpha / 2) / alpha));
            }
        }
        auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
            kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
        return SkImages::RasterFromPixmapCopy(SkPixmap(info, pixels.data(), pitch));
    };
    auto content_image = decode_image(content);
    auto mask_image = decode_image(mask);
    if (!content_image || !mask_image)
        return 0;

    std::vector<uint32_t> output_pixels(static_cast<size_t>(width)
        * static_cast<size_t>(height));
    auto output_info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(output_info, output_pixels.data(),
        static_cast<size_t>(width) * sizeof(uint32_t));
    if (!surface)
        return 0;
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    canvas->drawImage(content_image.get(), 0, 0);
    SkPaint mask_paint;
    mask_paint.setBlendMode(SkBlendMode::kDstIn);
    canvas->drawImage(mask_image.get(), 0, 0, SkSamplingOptions(), &mask_paint);
    surface.reset();
    return composite_pixels(destination, std::move(output_pixels), width, height,
        destination_x, destination_y, destination_width, destination_height);
}

// The Chromium raster tiles whose render pass is multisampled in this frame,
// by index, with their height in device rows including both border texels.
static std::vector<int> s_msaa_tiles;
static std::vector<int> s_msaa_grid_tiles;
static int s_msaa_grid_width = 0, s_msaa_grid_height = 0, s_msaa_grid_columns = 0;
static int s_msaa_tile_rows = 256;
static double s_root_raster_scroll_y = 0;
static double s_raster_origin_x = 0, s_raster_origin_y = 0;
static double s_raster_layer_width = 0, s_raster_layer_height = 0;
static bool s_raster_layer_is_root = true;

#include "native_chromium_shared_recording.h"

extern "C" void ladybird_v_skia_set_raster_layer(double x, double y, int root)
{
    if (!root) finish_shared_recording();
    s_raster_origin_x = x;
    s_raster_origin_y = y;
    s_raster_layer_is_root = root != 0;
    s_raster_layer_width = s_raster_layer_height = 0;
}

extern "C" void ladybird_v_skia_set_raster_layer_size(double width, double height)
{
    s_raster_layer_width = width;
    s_raster_layer_height = height;
}
// Rectangles clipped out of the next rectangle drawn, as left, top, right and
// bottom in its local coordinates.
static std::vector<float> s_rect_clip_outs;

extern "C" void ladybird_v_skia_set_root_raster_scroll_y(double scroll_y)
{
    s_root_raster_scroll_y = scroll_y;
}

extern "C" void ladybird_v_skia_set_msaa_tiles(int const* tiles, int count, int tile_rows)
{
    s_msaa_grid_tiles.clear();
    s_msaa_grid_columns = 0;
    s_msaa_tiles.assign(tiles, tiles + (tiles && count > 0 ? count : 0));
    std::sort(s_msaa_tiles.begin(), s_msaa_tiles.end());
    s_msaa_tile_rows = std::max(tile_rows, 3);
}

extern "C" void ladybird_v_skia_set_msaa_grid(int const* tiles, int count,
    int tile_width, int tile_height, int columns)
{
    s_msaa_grid_tiles.clear();
    if (tiles && count > 0) s_msaa_grid_tiles.assign(tiles, tiles + count);
    std::sort(s_msaa_grid_tiles.begin(), s_msaa_grid_tiles.end());
    s_msaa_grid_width = tile_width;
    s_msaa_grid_height = tile_height;
    s_msaa_grid_columns = tile_width > 2 && tile_height > 2 ? std::max(columns, 0) : 0;
}

static std::vector<char> chromium_layer_msaa_pixel_mask(RasterRegion const& region,
    int width, int height, float page_x, float page_y, float scroll_y, float scale)
{
    std::vector<char> mask(static_cast<size_t>(width) * height);
    long first_x = std::lround((region.left - page_x - s_raster_origin_x) * scale);
    long first_y = std::lround((region.top - page_y + scroll_y - s_raster_origin_y
        + (s_raster_layer_is_root ? s_root_raster_scroll_y : 0)) * scale);
    auto owner = [](long coordinate, int size) {
        return coordinate <= size - 2 ? 0L : (coordinate - 1) / (size - 2);
    };
    for (int y = 0; y < height; ++y) {
        if (first_y + y < 0) continue;
        long row = owner(first_y + y, s_msaa_grid_height);
        for (int x = 0; x < width; ++x) {
            if (first_x + x < 0) continue;
            long column = owner(first_x + x, s_msaa_grid_width);
            column = std::min(column, static_cast<long>(s_msaa_grid_columns - 1));
            int cell = static_cast<int>(row * s_msaa_grid_columns + column);
            mask[static_cast<size_t>(y) * width + x] = std::binary_search(
                s_msaa_grid_tiles.begin(), s_msaa_grid_tiles.end(), cell);
        }
    }
    return mask;
}

template<typename Draw>
static bool draw_chromium_root_raster_grid(std::vector<uint32_t>& pixels,
    int width, int height, RasterRegion const& region, float page_x,
    float page_y, float scroll_y, float scale, Draw draw)
{
    if (!s_raster_layer_is_root || s_msaa_grid_columns <= 0) return false;
    long first_x = std::lround((region.left - page_x) * scale);
    long first_y = std::lround((region.top - page_y + scroll_y + s_root_raster_scroll_y) * scale);
    int content_height = std::max(1, static_cast<int>(std::ceil(s_raster_layer_height * scale)));
    int rows = std::max(1, (content_height - 2 + s_msaa_grid_height - 3) / (s_msaa_grid_height - 2));
    VoxChromiumRasterGrid grid{s_msaa_grid_width, s_msaa_grid_height, s_msaa_grid_columns, rows};
    return vox_draw_chromium_raster_grid(pixels, width, height, first_x, first_y, grid,
        [&](auto& target, long offset_x, long offset_y, int cell) {
            return draw(target, offset_x, offset_y, std::binary_search(
                s_msaa_grid_tiles.begin(), s_msaa_grid_tiles.end(), cell));
        });
}

extern "C" void ladybird_v_skia_set_rect_clip_outs(float const* rects, int count)
{
    s_rect_clip_outs.assign(rects, rects + (rects && count > 0 ? count * 4 : 0));
}

// A filled rounded rectangle that the next rounded rectangle draws first, in
// the same pass and local coordinates: x, y, width, height and four corner
// radius pairs. A multisampled Chromium tile resolves the two shapes together,
// so drawing them separately would round their shared edge pixels differently.
static bool s_has_rounded_rect_underlay = false;
static bool s_has_unrounded_paint_color = false;
static float s_unrounded_paint_color[4];

extern "C" void ladybird_v_skia_set_unrounded_paint_color(float const* color)
{
    s_has_unrounded_paint_color = color != nullptr;
    if (color) std::copy_n(color, 4, s_unrounded_paint_color);
}
static float s_rounded_rect_underlay[12];
static uint8_t s_rounded_rect_underlay_rgba[4];

extern "C" void ladybird_v_skia_set_rounded_rect_underlay(float const* rect, uint8_t red,
    uint8_t green, uint8_t blue, uint8_t alpha)
{
    s_has_rounded_rect_underlay = rect != nullptr;
    if (rect)
        std::copy(rect, rect + 12, s_rounded_rect_underlay);
    s_rounded_rect_underlay_rgba[0] = red;
    s_rounded_rect_underlay_rgba[1] = green;
    s_rounded_rect_underlay_rgba[2] = blue;
    s_rounded_rect_underlay_rgba[3] = alpha;
}

static SkRRect rounded_rect_from_data(float const* data)
{
    SkVector radii[4] {
        { std::max(data[4], 0.0f), std::max(data[5], 0.0f) },
        { std::max(data[6], 0.0f), std::max(data[7], 0.0f) },
        { std::max(data[8], 0.0f), std::max(data[9], 0.0f) },
        { std::max(data[10], 0.0f), std::max(data[11], 0.0f) },
    };
    SkRRect result;
    result.setRectRadii(SkRect::MakeXYWH(data[0], data[1], data[2], data[3]), radii);
    return result;
}

// Tiles overlap by their border texels. Tile 0 shows content rows
// [0, spacing + 1) and tile k after it [k * spacing + 1, (k + 1) * spacing + 1).
static bool row_in_msaa_tile(long row)
{
    return vox_chromium_row_uses_msaa(row, s_msaa_tiles, s_msaa_tile_rows);
}

static std::vector<char> chromium_layer_msaa_rows(long top, int height,
    float page_y, float scroll_y, float scale)
{
    if (s_msaa_tiles.empty()) return {};
    long first_row = std::lround((top - page_y + scroll_y - s_raster_origin_y) * scale);
    std::vector<char> rows(static_cast<size_t>(height));
    for (int row = 0; row < height; ++row) rows[row] = row_in_msaa_tile(first_row + row);
    return rows;
}

static void clip_out_rects(SkCanvas* canvas)
{
    for (size_t index = 0; index + 3 < s_rect_clip_outs.size(); index += 4) {
        canvas->clipRect(SkRect::MakeLTRB(s_rect_clip_outs[index], s_rect_clip_outs[index + 1],
            s_rect_clip_outs[index + 2], s_rect_clip_outs[index + 3]), SkClipOp::kDifference, false);
    }
}

extern "C" int ladybird_v_skia_draw_rounded_rect(CGContextRef destination,
    float x, float y, float rect_width, float rect_height, float top_left_x,
    float top_left_y, float top_right_x, float top_right_y, float bottom_right_x,
    float bottom_right_y, float bottom_left_x, float bottom_left_y,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, uint8_t red,
    uint8_t green, uint8_t blue, uint8_t alpha, int fill, float thickness,
    int anti_alias, int opaque_backdrop)
{
    bool const has_underlay = s_has_rounded_rect_underlay;
    s_has_rounded_rect_underlay = false;
    bool const has_float_color = s_has_unrounded_paint_color;
    s_has_unrounded_paint_color = false;
    if (!destination || rect_width <= 0 || rect_height <= 0 || canvas_width <= 0
        || canvas_height <= 0 || (!fill && thickness <= 0))
        return 0;
    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);
    SkRRect underlay_rect;
    SkPaint underlay_paint;
    if (has_underlay) {
        underlay_rect = rounded_rect_from_data(s_rounded_rect_underlay);
        underlay_paint.setAntiAlias(true);
        underlay_paint.setColor(SkColorSetARGB(s_rounded_rect_underlay_rgba[3],
            s_rounded_rect_underlay_rgba[0], s_rounded_rect_underlay_rgba[1],
            s_rounded_rect_underlay_rgba[2]));
    }
    SkVector radii[4] {
        { std::max(top_left_x, 0.0f), std::max(top_left_y, 0.0f) },
        { std::max(top_right_x, 0.0f), std::max(top_right_y, 0.0f) },
        { std::max(bottom_right_x, 0.0f), std::max(bottom_right_y, 0.0f) },
        { std::max(bottom_left_x, 0.0f), std::max(bottom_left_y, 0.0f) },
    };
    SkRRect rounded_rect;
    rounded_rect.setRectRadii(SkRect::MakeXYWH(x, y, rect_width, rect_height), radii);
    SkPaint paint;
    if (has_float_color)
        paint.setColor4f({s_unrounded_paint_color[0], s_unrounded_paint_color[1],
            s_unrounded_paint_color[2], s_unrounded_paint_color[3]});
    else
        paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    paint.setAntiAlias(anti_alias != 0);
    if (!fill) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(thickness);
    }
    if (auto* canvas = shared_recording_canvas(destination)) {
        canvas->save();
        canvas->setMatrix(matrix);
        if (has_underlay) canvas->drawRRect(underlay_rect, underlay_paint);
        clip_out_rects(canvas);
        canvas->drawRRect(rounded_rect, paint);
        canvas->restore();
    }
    if (s_raster_command_group
        && s_raster_command_group->destination == destination) {
        auto& group = *s_raster_command_group;
        auto* canvas = group.surface->getCanvas();
        canvas->save();
        canvas->setMatrix(raster_matrix(matrix, group.region, group.scale_x,
            group.scale_y));
        if (has_underlay)
            canvas->drawRRect(underlay_rect, underlay_paint);
        clip_out_rects(canvas);
        canvas->drawRRect(rounded_rect, paint);
        canvas->restore();
        return 1;
    }
    SkRect paint_bounds_storage;
    auto local_bounds = paint.canComputeFastBounds()
        ? paint.computeFastBounds(rounded_rect.rect(), &paint_bounds_storage)
        : rounded_rect.rect();
    if (has_underlay)
        local_bounds.join(underlay_rect.rect());
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(local_bounds), canvas_width,
            canvas_height, anti_alias ? 2.0f : 0.0f, region))
        return 1;
    if (!leaf_raster_region_intersects_destination_clip(destination, canvas_height, region))
        return 1;

    auto destination_scale = screenshot_uses_logical_pixels()
        ? 1.0f
        : raster_scale_for_context(destination);
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width) / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height) / static_cast<float>(region.height());
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width) * static_cast<size_t>(raster_height));
    auto image_info = SkImageInfo::Make(raster_width, raster_height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto row_bytes = static_cast<size_t>(raster_width) * sizeof(uint32_t);
    auto backdrop = s_chromium_painting && opaque_backdrop
        ? read_backdrop(destination, region, destination_scale, raster_width, raster_height) : Backdrop {};
    bool has_background = backdrop.pixels != nullptr;
    if (has_background) {
        RasterRegion covered;
        // The opaque center is independent of the input backdrop. Preserve all
        // edge/corner pixels and a two-device-pixel guard for GPU coverage.
        if (fill && alpha == 255 && s_rect_clip_outs.empty()
            && matrix.getScaleX() > 0 && matrix.getScaleY() > 0
            && matrix.getSkewX() == 0 && matrix.getSkewY() == 0) {
            float rx = 0, ry = 0;
            for (int corner = 0; corner < 4; ++corner) {
                auto radius = rounded_rect.radii(static_cast<SkRRect::Corner>(corner));
                rx = std::max(rx, radius.x()); ry = std::max(ry, radius.y());
            }
            auto draw_matrix = raster_matrix(matrix, region, raster_scale_x, raster_scale_y);
            auto bounds = draw_matrix.mapRect(rounded_rect.rect());
            double inset_x = rx * draw_matrix.getScaleX() + 2;
            double inset_y = ry * draw_matrix.getScaleY() + 2;
            if (bounds.isFinite() && std::isfinite(inset_x) && std::isfinite(inset_y)) {
                covered.left = int(std::clamp(std::ceil(bounds.left() + inset_x), 0.0, double(raster_width)));
                covered.top = int(std::clamp(std::ceil(bounds.top() + inset_y), 0.0, double(raster_height)));
                covered.right = int(std::clamp(std::floor(bounds.right() - inset_x), 0.0, double(raster_width)));
                covered.bottom = int(std::clamp(std::floor(bounds.bottom() - inset_y), 0.0, double(raster_height)));
                if (covered.left > covered.right || covered.top > covered.bottom) covered = {};
            }
        }
        copy_backdrop_pixels(backdrop, raster_width, raster_height, pixels, covered);
    }
    if (s_chromium_painting) {
        VoxGraphiteShape descriptor {
            .matrix = {}, .rect = {x, y, rect_width, rect_height,
                top_left_x, top_left_y, top_right_x, top_right_y,
                bottom_right_x, bottom_right_y, bottom_left_x, bottom_left_y},
            .thickness = thickness, .red = red, .green = green, .blue = blue, .alpha = alpha,
            .fill = fill, .anti_alias = anti_alias, .force_msaa = 0,
            .clip_outs = s_rect_clip_outs.empty() ? nullptr : s_rect_clip_outs.data(),
            .clip_out_count = static_cast<int>(s_rect_clip_outs.size() / 4),
            .has_underlay = has_underlay ? 1 : 0,
            .has_float_color = has_float_color ? 1 : 0
        };
        if (has_float_color) std::copy_n(s_unrounded_paint_color, 4, descriptor.float_color);
        raster_matrix(matrix, region, raster_scale_x, raster_scale_y).get9(descriptor.matrix);
        if (has_underlay) {
            std::copy(s_rounded_rect_underlay, s_rounded_rect_underlay + 12, descriptor.underlay_rect);
            std::copy(s_rounded_rect_underlay_rgba, s_rounded_rect_underlay_rgba + 4,
                descriptor.underlay_rgba);
        }
        // Each raster row takes the mode of the Chromium tile that shows it,
        // in device rows of the root layer's content.
        long first_row = std::lround((static_cast<float>(region.top) - page_y + scroll_y
            - s_raster_origin_y) * destination_scale);
        std::vector<char> msaa_rows(static_cast<size_t>(raster_height));
        int msaa_row_count = 0;
        for (int row = 0; row < raster_height; ++row)
            msaa_row_count += msaa_rows[row] = row_in_msaa_tile(first_row + row);
        auto draw = graphite_shape_draw();
        bool drawn = draw != nullptr;
        bool tiled = drawn && has_background && draw_chromium_root_raster_grid(pixels,
            raster_width, raster_height, region, page_x, page_y, scroll_y,
            destination_scale, [&](auto& target, long offset_x, long offset_y, bool msaa) {
                auto shape = descriptor;
                shape.matrix[2] += offset_x;
                shape.matrix[5] += offset_y;
                shape.force_msaa = msaa;
                return draw(reinterpret_cast<uint8_t*>(target.data()), s_msaa_grid_width,
                    s_msaa_grid_height, s_msaa_grid_width * 4, 1, &shape) != 0;
            });
        if (tiled) {
            drawn = true;
        } else if (drawn && s_msaa_grid_columns > 0) {
            auto mask = chromium_layer_msaa_pixel_mask(region, raster_width, raster_height,
                page_x, page_y, scroll_y, destination_scale);
            // A one-pixel span lets the two-pass compositor preserve both
            // horizontal and vertical tile boundaries over the same backdrop.
            drawn = vox_draw_with_msaa_rows(pixels, 1, mask, [&](auto& target, bool msaa) {
                descriptor.force_msaa = msaa;
                return draw(reinterpret_cast<uint8_t*>(target.data()), raster_width,
                    raster_height, raster_width * 4, has_background, &descriptor) != 0;
            });
        } else if (drawn && msaa_row_count > 0 && msaa_row_count < raster_height) {
            auto multisampled = pixels;
            descriptor.force_msaa = 1;
            drawn = draw(reinterpret_cast<uint8_t*>(multisampled.data()), raster_width,
                raster_height, raster_width * 4, has_background, &descriptor);
            descriptor.force_msaa = 0;
            drawn = drawn && draw(reinterpret_cast<uint8_t*>(pixels.data()), raster_width,
                raster_height, raster_width * 4, has_background, &descriptor);
            for (int row = 0; drawn && row < raster_height; ++row) {
                if (msaa_rows[row])
                    std::copy_n(multisampled.begin() + static_cast<long>(row) * raster_width,
                        raster_width, pixels.begin() + static_cast<long>(row) * raster_width);
            }
        } else if (drawn) {
            descriptor.force_msaa = msaa_row_count > 0;
            drawn = draw(reinterpret_cast<uint8_t*>(pixels.data()), raster_width, raster_height,
                raster_width * 4, has_background, &descriptor);
        }
        if (drawn) {
            return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
                static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
                static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
        }
    }
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(), row_bytes);
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    canvas->setMatrix(raster_matrix(matrix, region, raster_scale_x, raster_scale_y));
    if (has_underlay)
        canvas->drawRRect(underlay_rect, underlay_paint);
    clip_out_rects(canvas);
    canvas->drawRRect(rounded_rect, paint);
    surface.reset();
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()));
}

extern "C" int ladybird_v_skia_draw_outer_box_shadow(CGContextRef destination,
    float shadow_x, float shadow_y, float shadow_width, float shadow_height,
    float shadow_top_left_x, float shadow_top_left_y, float shadow_top_right_x,
    float shadow_top_right_y, float shadow_bottom_right_x,
    float shadow_bottom_right_y, float shadow_bottom_left_x,
    float shadow_bottom_left_y, float content_x, float content_y,
    float content_width, float content_height, float content_top_left_x,
    float content_top_left_y, float content_top_right_x,
    float content_top_right_y, float content_bottom_right_x,
    float content_bottom_right_y, float content_bottom_left_x,
    float content_bottom_left_y, float transform_a, float transform_b,
    float transform_c, float transform_d, float transform_e, float transform_f,
    float page_x, float page_y, float scroll_y, float canvas_width,
    float canvas_height, float blur, uint8_t red, uint8_t green, uint8_t blue,
    uint8_t alpha, int opaque_backdrop)
{
    if (!destination || shadow_width <= 0 || shadow_height <= 0
        || content_width < 0 || content_height < 0 || canvas_width <= 0
        || canvas_height <= 0)
        return 0;

    auto make_rounded_rect = [](float x, float y, float width, float height,
                                 float top_left_x, float top_left_y,
                                 float top_right_x, float top_right_y,
                                 float bottom_right_x, float bottom_right_y,
                                 float bottom_left_x, float bottom_left_y) {
        SkVector radii[4] {
            { std::max(top_left_x, 0.0f), std::max(top_left_y, 0.0f) },
            { std::max(top_right_x, 0.0f), std::max(top_right_y, 0.0f) },
            { std::max(bottom_right_x, 0.0f), std::max(bottom_right_y, 0.0f) },
            { std::max(bottom_left_x, 0.0f), std::max(bottom_left_y, 0.0f) },
        };
        SkRRect result;
        result.setRectRadii(SkRect::MakeXYWH(x, y, width, height), radii);
        return result;
    };
    auto shadow = make_rounded_rect(shadow_x, shadow_y, shadow_width,
        shadow_height, shadow_top_left_x, shadow_top_left_y, shadow_top_right_x,
        shadow_top_right_y, shadow_bottom_right_x, shadow_bottom_right_y,
        shadow_bottom_left_x, shadow_bottom_left_y);
    auto content = make_rounded_rect(content_x, content_y, content_width,
        content_height, content_top_left_x, content_top_left_y,
        content_top_right_x, content_top_right_y, content_bottom_right_x,
        content_bottom_right_y, content_bottom_left_x, content_bottom_left_y);
    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);

    auto blur_guard = std::max(blur, 0.0f) * 2.0f + 2.0f;
    auto local_bounds = shadow.rect().makeOutset(blur_guard, blur_guard);
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(local_bounds), canvas_width,
            canvas_height, 0.0f, region))
        return 1;

    auto destination_scale = screenshot_uses_logical_pixels()
        ? 1.0f
        : raster_scale_for_context(destination);
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width) / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height) / static_cast<float>(region.height());
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width)
        * static_cast<size_t>(raster_height));
    bool has_background = opaque_backdrop && copy_backdrop(destination,
        region, destination_scale, raster_width, raster_height, pixels);
    auto image_info = SkImageInfo::Make(raster_width, raster_height,
        kBGRA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    if (s_chromium_painting) {
        VoxGraphiteShadow descriptor {
            .matrix = {},
            .shadow = {shadow_x, shadow_y, shadow_width, shadow_height,
                shadow_top_left_x, shadow_top_left_y, shadow_top_right_x,
                shadow_top_right_y, shadow_bottom_right_x, shadow_bottom_right_y,
                shadow_bottom_left_x, shadow_bottom_left_y},
            .content = {content_x, content_y, content_width, content_height,
                content_top_left_x, content_top_left_y, content_top_right_x,
                content_top_right_y, content_bottom_right_x, content_bottom_right_y,
                content_bottom_left_x, content_bottom_left_y},
            .blur = blur, .red = red, .green = green, .blue = blue, .alpha = alpha
        };
        raster_matrix(matrix, region, raster_scale_x, raster_scale_y).get9(descriptor.matrix);
        if (auto draw = graphite_shadow_draw(); draw && draw(reinterpret_cast<uint8_t*>(pixels.data()),
                raster_width, raster_height, raster_width * 4, has_background, &descriptor)) {
            return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
                static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
                static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
        }
    }
    auto* gpu = s_chromium_painting ? image_gpu_context() : nullptr;
    auto surface = gpu ? SkSurfaces::RenderTarget(gpu, skgpu::Budgeted::kNo,
        image_info, 0, kTopLeft_GrSurfaceOrigin, nullptr) : nullptr;
    bool gpu_surface = surface != nullptr;
    if (!surface) surface = SkSurfaces::WrapPixels(image_info, pixels.data(),
        static_cast<size_t>(raster_width) * sizeof(uint32_t));
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    if (has_background) {
        surface->writePixels(SkPixmap(image_info, pixels.data(),
            static_cast<size_t>(raster_width) * sizeof(uint32_t)), 0, 0);
    } else {
        canvas->clear(SK_ColorTRANSPARENT);
    }
    canvas->setMatrix(raster_matrix(matrix, region, raster_scale_x, raster_scale_y));
    canvas->clipRRect(content, SkClipOp::kDifference, true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle,
        std::max(blur, 0.0f) / 2.0f));
    canvas->drawRRect(shadow, paint);
    if (gpu_surface && !surface->readPixels(image_info, pixels.data(),
        static_cast<size_t>(raster_width) * sizeof(uint32_t), 0, 0)) return 0;
    surface.reset();
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
}

static long chromium_raster_tile_for_row(long row);

extern "C" int ladybird_v_skia_draw_svg_path_batch(CGContextRef destination,
    VoxGraphitePath const* paths, int count, float const* outer, float x, float y,
    float width, float height, float page_x, float page_y, float scroll_y,
    float canvas_width, float canvas_height, int opaque_backdrop)
{
    auto draw = graphite_svg_image_draw();
    if (!s_chromium_painting || !destination || !draw || !paths || !outer
        || count <= 0 || count > 65536 || width <= 0 || height <= 0) return 0;
    auto matrix = SkMatrix::MakeAll(outer[0], outer[2], page_x + outer[4],
        outer[1], outer[3], page_y - scroll_y + outer[5], 0, 0, 1);
    if (auto* canvas = shared_recording_canvas(destination)) {
        auto bounds = matrix.mapRect(SkRect::MakeXYWH(x, y, width, height));
        bool supported = std::none_of(paths, paths + count,
            [](auto const& path) { return path.gradient != 0; });
        if (!supported) shared_recording_block(bounds);
        else {
            shared_recording_svg(destination, bounds, page_y);
            canvas->save();
            canvas->setMatrix(matrix);
            canvas->clipRect(SkRect::MakeXYWH(x, y, width, height));
            for (int index = 0; index < count; ++index) {
                auto const& source = paths[index];
                SkMatrix local;
                local.set9(source.matrix);
                auto geometry = path_from_serialized_segments(source.segments, source.segment_count);
                geometry.setFillType(source.even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
                SkPaint paint;
                paint.setAntiAlias(true);
                paint.setColor(SkColorSetARGB(source.alpha, source.red, source.green, source.blue));
                if (source.has_float_alpha) paint.setAlphaf(source.opacity);
                canvas->save();
                canvas->setMatrix(matrix);
                canvas->concat(local);
                if (source.stroke) {
                    paint.setStyle(SkPaint::kStroke_Style);
                    paint.setStrokeWidth(source.stroke_width);
                    paint.setStrokeCap(SkPaint::Cap(source.line_cap));
                    paint.setStrokeJoin(SkPaint::Join(source.line_join));
                    paint.setStrokeMiter(source.miter_limit);
                    if (source.non_scaling_stroke) {
                        geometry.transform(local);
                        SkMatrix inverse;
                        if (local.invert(&inverse)) canvas->concat(inverse);
                    }
                }
                canvas->drawPath(geometry, paint);
                canvas->restore();
            }
            canvas->restore();
        }
    }
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(SkRect::MakeXYWH(x, y, width, height)),
            canvas_width, canvas_height, 0, region)) return 1;
    auto scale = raster_scale_for_context(destination);
    int raster_width = raster_dimension(region.width(), scale);
    int raster_height = raster_dimension(region.height(), scale);
    if (static_cast<size_t>(raster_width) * raster_height > 8 * 1024 * 1024) return 0;
    float sx = static_cast<float>(raster_width) / region.width();
    float sy = static_cast<float>(raster_height) / region.height();
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width) * raster_height);
    bool has_background = s_raster_layer_is_root && opaque_backdrop && copy_backdrop(destination, region,
        scale, raster_width, raster_height, pixels);
    auto image_to_raster = raster_matrix(matrix, region, sx, sy);
    float viewport[] {x, y, width, height};
    auto draw_in_raster = [&](std::vector<uint32_t>& target, int target_width,
                              int target_height, int offset_x, long offset_y) {
        auto parent = image_to_raster;
        parent.postTranslate(offset_x, offset_y);
        float parent_values[9];
        parent.get9(parent_values);
        return draw(reinterpret_cast<uint8_t*>(target.data()), target_width,
            target_height, target_width * 4, has_background, paths, count,
            parent_values, viewport) != 0;
    };
    constexpr size_t maximum_tile_pixels = 8 * 1024 * 1024;
    int layer_width = raster_dimension(s_raster_layer_is_root ? canvas_width : s_raster_layer_width, scale);
    int layer_height = raster_dimension(s_raster_layer_height, scale);
    int offset_x = std::lround((region.left - (s_raster_layer_is_root ? 0 : s_raster_origin_x)) * scale);
    long first_row = std::lround((region.top - page_y + scroll_y
        + (s_raster_layer_is_root ? s_root_raster_scroll_y : -s_raster_origin_y)) * scale);
    bool drawn = false;
    if (has_background) drawn = draw_chromium_root_raster_grid(pixels, raster_width,
        raster_height, region, page_x, page_y, scroll_y, scale,
        [&](auto& target, long offset_x, long offset_y, bool) {
            return draw_in_raster(target, s_msaa_grid_width, s_msaa_grid_height, offset_x, offset_y);
        });
    if (!drawn && layer_width > 0 && offset_x >= 0 && offset_x + raster_width <= layer_width
        && first_row >= 0 && (s_raster_layer_is_root ? has_background
            : s_raster_layer_width > 0 && s_raster_layer_height > 0
                && first_row + raster_height <= layer_height)) {
        int tile_height = s_raster_layer_is_root ? s_msaa_tile_rows : layer_height;
        if (static_cast<size_t>(layer_width) * tile_height <= maximum_tile_pixels) {
            auto original = pixels;
            auto result = pixels;
            long spacing = s_msaa_tile_rows - 2;
            long first_tile = s_raster_layer_is_root ? chromium_raster_tile_for_row(first_row) : 0;
            long last_tile = s_raster_layer_is_root ? chromium_raster_tile_for_row(first_row + raster_height - 1) : 0;
            std::vector<uint32_t> tile_pixels(static_cast<size_t>(layer_width) * tile_height);
            drawn = true;
            for (long tile = first_tile; tile <= last_tile; ++tile) {
                long origin = s_raster_layer_is_root ? tile * spacing : 0;
                std::fill(tile_pixels.begin(), tile_pixels.end(), 0);
                for (int row = 0; row < raster_height; ++row) {
                    long tile_row = first_row + row - origin;
                    if (tile_row < 0 || tile_row >= tile_height) continue;
                    std::copy_n(original.begin() + static_cast<size_t>(row) * raster_width,
                        raster_width, tile_pixels.begin() + tile_row * layer_width + offset_x);
                }
                if (!draw_in_raster(tile_pixels, layer_width, tile_height, offset_x, first_row - origin)) {
                    drawn = false;
                    break;
                }
                for (int row = 0; row < raster_height; ++row) {
                    long document_row = first_row + row;
                    if (s_raster_layer_is_root && chromium_raster_tile_for_row(document_row) != tile) continue;
                    long tile_row = document_row - origin;
                    if (tile_row < 0 || tile_row >= tile_height) continue;
                    std::copy_n(tile_pixels.begin() + tile_row * layer_width + offset_x,
                        raster_width, result.begin() + static_cast<size_t>(row) * raster_width);
                }
            }
            if (drawn) pixels = std::move(result);
        }
    }
    if (!drawn && !draw_in_raster(pixels, raster_width, raster_height, 0, 0)) return 0;
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        region.left, canvas_height - region.bottom, region.width(), region.height(), has_background);
}

extern "C" int ladybird_v_skia_draw_svg_path(CGContextRef destination,
    float const* data, int segment_count, int even_odd,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height,
    uint8_t fill_red, uint8_t fill_green, uint8_t fill_blue, uint8_t fill_alpha,
    int has_fill, uint8_t stroke_red, uint8_t stroke_green, uint8_t stroke_blue,
	uint8_t stroke_alpha, int has_stroke, float stroke_width, int line_cap,
	int line_join, float miter_limit, int non_scaling_stroke,
	double const* dash_data, int dash_count, double dash_offset, int opaque_backdrop)
{
    if (!destination || !data || segment_count <= 0 || (!has_fill && !has_stroke)
        || canvas_width <= 0 || canvas_height <= 0)
        return 0;

    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);

    auto path = path_from_serialized_segments(data, segment_count);
    path.setFillType(even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
	auto local_bounds = path.getBounds();
	SkPath transformed_stroke_path;
	if (non_scaling_stroke && has_stroke)
		path.transform(matrix, &transformed_stroke_path);
	auto draw_path = [&](SkCanvas* canvas, RasterRegion const& region,
	                     float scale_x, float scale_y) {
		canvas->setMatrix(raster_matrix(matrix, region, scale_x, scale_y));
		if (has_fill) {
			SkPaint paint;
			paint.setAntiAlias(true);
			paint.setColor(SkColorSetARGB(fill_alpha, fill_red, fill_green, fill_blue));
			canvas->drawPath(path, paint);
		}
		if (has_stroke && stroke_width > 0.0f) {
			if (non_scaling_stroke)
				canvas->setMatrix(raster_matrix(SkMatrix::I(), region, scale_x, scale_y));
			SkPaint paint;
			paint.setAntiAlias(true);
			paint.setStyle(SkPaint::kStroke_Style);
			paint.setStrokeWidth(stroke_width);
			paint.setColor(SkColorSetARGB(stroke_alpha, stroke_red, stroke_green, stroke_blue));
			paint.setStrokeCap(line_cap == 1 ? SkPaint::kRound_Cap
				: line_cap == 2 ? SkPaint::kSquare_Cap : SkPaint::kButt_Cap);
			paint.setStrokeJoin(line_join == 1 ? SkPaint::kRound_Join
				: line_join == 2 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
			paint.setStrokeMiter(std::max(miter_limit, 1.0f));
			if (dash_data && dash_count > 0) {
				std::vector<SkScalar> intervals;
				intervals.reserve(static_cast<size_t>(dash_count));
				for (int index = 0; index < dash_count; ++index)
					intervals.push_back(static_cast<SkScalar>(dash_data[index]));
				paint.setPathEffect(SkDashPathEffect::Make(
					{ intervals.data(), intervals.size() }, static_cast<SkScalar>(dash_offset)));
			}
			canvas->drawPath(non_scaling_stroke ? transformed_stroke_path : path, paint);
		}
	};
    if (auto* canvas = shared_recording_canvas(destination)) {
        shared_recording_svg(destination, matrix.mapRect(local_bounds), page_y);
        canvas->save();
        draw_path(canvas, RasterRegion{}, 1, 1);
        canvas->restore();
    }
	if (s_raster_command_group
		&& s_raster_command_group->destination == destination) {
		auto& group = *s_raster_command_group;
		draw_path(group.surface->getCanvas(), group.region, group.scale_x,
			group.scale_y);
		return 1;
	}
	if (has_stroke && stroke_width > 0.0f && !non_scaling_stroke) {
        SkPaint bounds_paint;
        bounds_paint.setStyle(SkPaint::kStroke_Style);
        bounds_paint.setStrokeWidth(stroke_width);
        bounds_paint.setStrokeCap(line_cap == 1 ? SkPaint::kRound_Cap
            : line_cap == 2 ? SkPaint::kSquare_Cap : SkPaint::kButt_Cap);
        bounds_paint.setStrokeJoin(line_join == 1 ? SkPaint::kRound_Join
            : line_join == 2 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
        bounds_paint.setStrokeMiter(std::max(miter_limit, 1.0f));
        SkRect stroke_bounds;
        if (bounds_paint.canComputeFastBounds())
            local_bounds.join(bounds_paint.computeFastBounds(path.getBounds(), &stroke_bounds));
    }
	auto device_bounds = matrix.mapRect(local_bounds);
	if (has_stroke && stroke_width > 0.0f && non_scaling_stroke) {
		SkPaint bounds_paint;
		bounds_paint.setStyle(SkPaint::kStroke_Style);
		bounds_paint.setStrokeWidth(stroke_width);
		SkRect stroke_bounds;
		if (bounds_paint.canComputeFastBounds())
			device_bounds.join(bounds_paint.computeFastBounds(transformed_stroke_path.getBounds(), &stroke_bounds));
	}
	RasterRegion region;
	if (!clipped_raster_region(device_bounds, canvas_width,
            canvas_height, 2.0f, region)
        || !leaf_raster_region_intersects_destination_clip(destination, canvas_height, region))
        return 1;

    auto destination_scale = raster_scale_for_context(destination);
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width) / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height) / static_cast<float>(region.height());
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width) * static_cast<size_t>(raster_height));
    bool strokes = has_stroke && stroke_width > 0.0f;
    if (s_chromium_painting && (has_fill || strokes)
        && !(strokes && dash_data && dash_count > 0)) {
        // Chromium draws SVG paths with its GPU rasterizer. The stroke draws
        // over the fill's result, as both would on Chromium's canvas. Inside a
        // clip or opacity layer the destination bitmap lacks the layer's
        // pixels, so only a top-level opaque page is blended on the GPU.
        bool has_background = opaque_backdrop && copy_backdrop(destination, region,
            destination_scale, raster_width, raster_height, pixels);
        VoxGraphitePath descriptor {
            .matrix = {}, .segments = data, .segment_count = segment_count,
            .even_odd = even_odd, .line_cap = line_cap, .line_join = line_join,
            .non_scaling_stroke = non_scaling_stroke,
            .stroke_width = non_scaling_stroke ? stroke_width * raster_scale_x : stroke_width,
            .miter_limit = miter_limit
        };
        raster_matrix(matrix, region, raster_scale_x, raster_scale_y).get9(descriptor.matrix);
        auto draw = graphite_path_draw();
        bool drawn = draw != nullptr;
        if (drawn && has_fill) {
            descriptor.red = fill_red;
            descriptor.green = fill_green;
            descriptor.blue = fill_blue;
            descriptor.alpha = fill_alpha;
            drawn = draw(reinterpret_cast<uint8_t*>(pixels.data()), raster_width, raster_height,
                raster_width * 4, has_background, &descriptor);
        }
        if (drawn && strokes) {
            descriptor.stroke = 1;
            descriptor.red = stroke_red;
            descriptor.green = stroke_green;
            descriptor.blue = stroke_blue;
            descriptor.alpha = stroke_alpha;
            drawn = draw(reinterpret_cast<uint8_t*>(pixels.data()), raster_width, raster_height,
                raster_width * 4, has_background || has_fill, &descriptor);
        }
        if (drawn) {
            return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
                static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
                static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
        }
        std::fill(pixels.begin(), pixels.end(), 0);
    }
    auto image_info = SkImageInfo::Make(raster_width, raster_height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(),
        static_cast<size_t>(raster_width) * sizeof(uint32_t));
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    draw_path(canvas, region, raster_scale_x, raster_scale_y);

    surface.reset();
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()));
}

static SkTileMode svg_gradient_tile_mode(int spread_method)
{
    switch (spread_method) {
    case 1:
        return SkTileMode::kRepeat;
    case 2:
        return SkTileMode::kMirror;
    default:
        return SkTileMode::kClamp;
    }
}

// The first tile owns rows [0, spacing], subsequent tiles exclude their
// first border texel. This is also the tile whose device coordinates seed
// gradient dithering at each visible row.
static long chromium_raster_tile_for_row(long row)
{
    long spacing = s_msaa_tile_rows - 2;
    return row <= spacing ? 0 : (row - 1) / spacing;
}

static bool draw_chromium_root_image_tiles(std::vector<uint32_t>& pixels,
    int raster_width, int raster_height, RasterRegion const& region,
    float scale, float page_x, float page_y, float scroll_y,
    float canvas_width, bool has_background, VoxGraphiteImage const& descriptor)
{
    auto draw = graphite_image_draw();
    if (draw && has_background && s_raster_layer_is_root && s_msaa_grid_columns > 0)
        return draw_chromium_root_raster_grid(pixels, raster_width, raster_height,
            region, page_x, page_y, scroll_y, scale,
            [&](auto& target, long offset_x, long offset_y, bool msaa) {
                auto image = descriptor;
                image.matrix[2] += offset_x;
                image.matrix[5] += offset_y;
                image.flags = (image.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
                    | (msaa ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
                return draw(reinterpret_cast<uint8_t*>(target.data()), s_msaa_grid_width,
                    s_msaa_grid_height, s_msaa_grid_width * 4, 1, &image) != 0;
            });
    int tile_width = raster_dimension(canvas_width, scale);
    int offset_x = std::lround(region.left * scale);
    constexpr size_t maximum_tile_pixels = 8 * 1024 * 1024;
    if (!draw || !s_raster_layer_is_root || !has_background || page_x != 0
        || scale <= 0 || tile_width <= 0 || offset_x < 0
        || offset_x + raster_width > tile_width
        || static_cast<size_t>(tile_width) * s_msaa_tile_rows > maximum_tile_pixels)
        return false;

    // Graphite's image coordinates are normalized against the raster extent.
    // Keep the root tile's width, height and origin even for a small visible
    // part of an image. A tight leaf raster changes interpolated texels.
    long first_row = std::lround((region.top - page_y + scroll_y
        + s_root_raster_scroll_y) * scale);
    long spacing = s_msaa_tile_rows - 2;
    long first_tile = chromium_raster_tile_for_row(first_row);
    long last_tile = chromium_raster_tile_for_row(first_row + raster_height - 1);
    auto backdrop = pixels;
    auto result = pixels;
    std::vector<uint32_t> tile_pixels(static_cast<size_t>(tile_width) * s_msaa_tile_rows);
    for (long tile = first_tile; tile <= last_tile; ++tile) {
        long origin = tile * spacing;
        std::fill(tile_pixels.begin(), tile_pixels.end(), 0);
        for (int row = 0; row < raster_height; ++row) {
            long tile_row = first_row + row - origin;
            if (tile_row < 0 || tile_row >= s_msaa_tile_rows) continue;
            std::copy_n(backdrop.begin() + static_cast<size_t>(row) * raster_width,
                raster_width, tile_pixels.begin() + tile_row * tile_width + offset_x);
        }
        auto image = descriptor;
        image.matrix[2] += offset_x;
        image.matrix[5] += first_row - origin;
        // MSAA bookkeeping follows the projected command coordinates, while
        // the root raster itself retains the document's unscrolled origin.
        long projected_row = origin - std::lround(s_root_raster_scroll_y * scale);
        image.flags = (image.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
            | (row_in_msaa_tile(projected_row + 1) ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
        if (!draw(reinterpret_cast<uint8_t*>(tile_pixels.data()), tile_width,
                s_msaa_tile_rows, tile_width * 4, 1, &image)) return false;
        for (int row = 0; row < raster_height; ++row) {
            long document_row = first_row + row;
            if (chromium_raster_tile_for_row(document_row) != tile) continue;
            long tile_row = document_row - origin;
            std::copy_n(tile_pixels.begin() + tile_row * tile_width + offset_x,
                raster_width, result.begin() + static_cast<size_t>(row) * raster_width);
        }
    }
    pixels = std::move(result);
    return true;
}

static bool chromium_root_gradient_tiles_eligible(float scale, float page_x,
    float page_y, bool has_background, int tile_width, RasterRegion const& region)
{
    // Other scales, scrolled roots and isolated layers keep the existing
    // bounded leaf renderer until their raster origins are supplied separately.
    constexpr size_t maximum_tile_pixels = 8 * 1024 * 1024;
    return scale == 1 && page_x == 0 && page_y == std::round(page_y)
        && s_raster_layer_is_root && s_root_raster_scroll_y == 0 && has_background && tile_width > 0
        && region.left >= 0 && region.right <= tile_width
        && static_cast<size_t>(tile_width) * s_msaa_tile_rows <= maximum_tile_pixels;
}

static bool draw_chromium_root_gradient_tiles(
    decltype(&vox_graphite_draw_path_pixels) draw,
    std::vector<uint32_t>& pixels, int raster_width, int raster_height,
    int tile_width, int offset_x, long first_row, VoxGraphitePath const& descriptor)
{
    if (!draw) return false;
    auto original_backdrop = pixels;
    long spacing = s_msaa_tile_rows - 2;
    long first_tile = chromium_raster_tile_for_row(first_row);
    long last_tile = chromium_raster_tile_for_row(first_row + raster_height - 1);
    std::vector<uint32_t> tile_pixels(static_cast<size_t>(tile_width) * s_msaa_tile_rows);
    for (long tile = first_tile; tile <= last_tile; ++tile) {
        long origin = tile * spacing;
        std::fill(tile_pixels.begin(), tile_pixels.end(), 0);
        for (int row = 0; row < raster_height; ++row) {
            long tile_row = first_row + row - origin;
            if (tile_row < 0 || tile_row >= s_msaa_tile_rows) continue;
            std::copy_n(original_backdrop.begin() + static_cast<size_t>(row) * raster_width,
                raster_width, tile_pixels.begin() + tile_row * tile_width + offset_x);
        }
        auto tile_descriptor = descriptor;
        tile_descriptor.matrix[2] += offset_x;
        tile_descriptor.matrix[5] += first_row - origin;
        if (!draw(reinterpret_cast<uint8_t*>(tile_pixels.data()), tile_width,
                s_msaa_tile_rows, tile_width * 4, 1, &tile_descriptor)) return false;
        for (int row = 0; row < raster_height; ++row) {
            long document_row = first_row + row;
            if (chromium_raster_tile_for_row(document_row) != tile) continue;
            long tile_row = document_row - origin;
            if (tile_row < 0 || tile_row >= s_msaa_tile_rows) continue;
            std::copy_n(tile_pixels.begin() + tile_row * tile_width + offset_x,
                raster_width, pixels.begin() + static_cast<size_t>(row) * raster_width);
        }
    }
    return true;
}

template<typename MakeShader>
static int draw_svg_gradient_path(CGContextRef destination, float const* data,
    int segment_count, int even_odd, float transform_a, float transform_b,
    float transform_c, float transform_d, float transform_e, float transform_f,
    float page_x, float page_y, float scroll_y, float canvas_width,
    float canvas_height, int stroke, float stroke_width, int line_cap,
    int line_join, float miter_limit, float gradient_a, float gradient_b,
    float gradient_c, float gradient_d, float gradient_e, float gradient_f,
    int spread_method, int linear_color_space, float const* stop_data,
    int stop_count, float opacity, int gradient_kind, float const* gradient_points,
    int opaque_backdrop, float const* clip, float const* ancestor_clip, MakeShader make_shader)
{
    if (!destination || !data || segment_count <= 0 || !stop_data
        || stop_count <= 0 || canvas_width <= 0 || canvas_height <= 0)
        return 0;

    auto path = path_from_serialized_segments(data, segment_count);
    path.setFillType(even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    auto local_bounds = path.getBounds();
    SkPaint paint;
    paint.setAntiAlias(true);
    if (stroke) {
        if (stroke_width <= 0)
            return 1;
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(stroke_width);
        paint.setStrokeCap(line_cap == 1 ? SkPaint::kRound_Cap
            : line_cap == 2 ? SkPaint::kSquare_Cap : SkPaint::kButt_Cap);
        paint.setStrokeJoin(line_join == 1 ? SkPaint::kRound_Join
            : line_join == 2 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
        paint.setStrokeMiter(std::max(miter_limit, 1.0f));
        SkRect stroke_bounds;
        if (paint.canComputeFastBounds())
            local_bounds = paint.computeFastBounds(local_bounds, &stroke_bounds);
    }

    auto gradient_stop_count = stop_count == 1 ? 2 : stop_count;
    std::vector<SkColor4f> colors(static_cast<size_t>(gradient_stop_count));
    std::vector<SkScalar> positions(static_cast<size_t>(gradient_stop_count));
    for (int index = 0; index < gradient_stop_count; ++index) {
        auto source_index = stop_count == 1 ? 0 : index;
        auto const* stop = stop_data + source_index * 5;
        colors[static_cast<size_t>(index)] = {
            std::clamp(stop[0], 0.0f, 1.0f),
            std::clamp(stop[1], 0.0f, 1.0f),
            std::clamp(stop[2], 0.0f, 1.0f),
            std::clamp(stop[3], 0.0f, 1.0f),
        };
        positions[static_cast<size_t>(index)] = stop_count == 1
            ? static_cast<float>(index)
            : std::clamp(stop[4], 0.0f, 1.0f);
    }

    auto gradient_matrix = SkMatrix::MakeAll(
        gradient_a, gradient_c, gradient_e,
        gradient_b, gradient_d, gradient_f,
        0.0f, 0.0f, 1.0f);
    auto shader = make_shader(colors, positions,
        svg_gradient_tile_mode(spread_method), gradient_matrix);
    if (!shader)
        return 0;
    paint.setShader(std::move(shader));
    paint.setAlphaf(std::clamp(opacity, 0.0f, 1.0f));
    if (linear_color_space)
        paint.setColorFilter(SkColorFilters::LinearToSRGBGamma());

    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(local_bounds), canvas_width,
            canvas_height, 2.0f, region)
        || !leaf_raster_region_intersects_destination_clip(destination, canvas_height, region))
        return 1;
    auto destination_scale = raster_scale_for_context(destination);
    if (s_chromium_painting) {
        // Skia's ordered gradient dither repeats every eight device pixels from
        // the surface origin; align the surface with the page's pixel grid.
        int alignment = std::max(1, static_cast<int>(std::lround(8.0f / destination_scale)));
        region.left -= region.left % alignment;
        region.top -= region.top % alignment;
    }
    auto raster_width = raster_dimension(region.width(), destination_scale);
    auto raster_height = raster_dimension(region.height(), destination_scale);
    auto raster_scale_x = static_cast<float>(raster_width)
        / static_cast<float>(region.width());
    auto raster_scale_y = static_cast<float>(raster_height)
        / static_cast<float>(region.height());
    std::vector<uint32_t> pixels(static_cast<size_t>(raster_width)
        * static_cast<size_t>(raster_height));
    if (s_chromium_painting) {
        // Chromium fills and strokes SVG paths with its GPU rasterizer.
        std::vector<float> stops;
        stops.reserve(colors.size() * 5);
        for (size_t index = 0; index < colors.size(); ++index) {
            stops.insert(stops.end(), {colors[index].fR, colors[index].fG,
                colors[index].fB, colors[index].fA, positions[index]});
        }
        bool has_background = s_raster_layer_is_root && opaque_backdrop && copy_backdrop(destination, region,
            destination_scale, raster_width, raster_height, pixels);
        VoxGraphitePath descriptor {
            .matrix = {}, .segments = data, .segment_count = segment_count,
            .even_odd = even_odd, .stroke = stroke, .line_cap = line_cap,
            .line_join = line_join, .stroke_width = stroke_width, .miter_limit = miter_limit,
            .gradient = gradient_kind, .tile_mode = static_cast<int>(svg_gradient_tile_mode(spread_method)),
            .linear_color_space = linear_color_space, .stop_count = static_cast<int>(colors.size()),
            .gradient_points = {gradient_points[0], gradient_points[1], gradient_points[2],
                gradient_points[3], gradient_points[4], gradient_points[5]},
            .gradient_matrix = {}, .opacity = opacity, .stops = stops.data()
        };
        if (clip) {
            descriptor.has_clip = 1;
            std::copy_n(clip, 12, descriptor.clip);
        }
        if (ancestor_clip) {
            descriptor.has_ancestor_clip = 1;
            std::copy_n(ancestor_clip, 12, descriptor.ancestor_clip);
        }
        raster_matrix(matrix, region, raster_scale_x, raster_scale_y).get9(descriptor.matrix);
        gradient_matrix.get9(descriptor.gradient_matrix);
        auto draw = graphite_path_draw();
        int tile_width = static_cast<int>(std::ceil(canvas_width));
        bool drawn;
        if (chromium_root_gradient_tiles_eligible(destination_scale, page_x, page_y,
                has_background, tile_width, region)) {
            // A page-aligned eight-pixel dither pattern stops matching at the
            // next Chromium tile. Replay in each tile's actual coordinate
            // space, retaining its border texels and immutable backdrop.
            long first_row = std::lround(static_cast<float>(region.top) - page_y + scroll_y);
            drawn = draw_chromium_root_gradient_tiles(draw, pixels, raster_width,
                raster_height, tile_width, region.left, first_row, descriptor);
        } else {
            if (!s_raster_layer_is_root) {
                // Independent composited layers rasterize against transparent
                // pixels. Preserve the layer's ordered-dither phase even when
                // rendering just this bounded leaf instead of its full tile.
                int phase_x = vox_chromium_dither_phase(region.left - page_x,
                    s_raster_origin_x, destination_scale);
                int phase_y = vox_chromium_dither_phase(region.top - page_y + scroll_y,
                    s_raster_origin_y, destination_scale);
                int width = raster_width + phase_x, height = raster_height + phase_y;
                std::vector<uint32_t> shifted(static_cast<size_t>(width) * height);
                descriptor.matrix[2] += phase_x;
                descriptor.matrix[5] += phase_y;
                drawn = draw && draw(reinterpret_cast<uint8_t*>(shifted.data()), width,
                    height, width * 4, 0, &descriptor);
                if (drawn) {
                    for (int row = 0; row < raster_height; ++row)
                        std::copy_n(shifted.begin() + static_cast<size_t>(row + phase_y) * width + phase_x,
                            raster_width, pixels.begin() + static_cast<size_t>(row) * raster_width);
                }
            } else {
                drawn = draw && draw(reinterpret_cast<uint8_t*>(pixels.data()), raster_width,
                    raster_height, raster_width * 4, has_background, &descriptor);
            }
        }
        if (drawn) {
            return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
                static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
                static_cast<float>(region.width()), static_cast<float>(region.height()), has_background);
        }
        std::fill(pixels.begin(), pixels.end(), 0);
    }
    auto image_info = SkImageInfo::Make(raster_width, raster_height,
        kBGRA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(),
        static_cast<size_t>(raster_width) * sizeof(uint32_t));
    if (!surface)
        return 0;
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    canvas->setMatrix(raster_matrix(matrix, region, raster_scale_x, raster_scale_y));
    if (clip) canvas->clipRRect(rounded_rect_from_data(clip), SkClipOp::kIntersect, true);
    if (ancestor_clip) canvas->clipRRect(rounded_rect_from_data(ancestor_clip), SkClipOp::kIntersect, true);
    canvas->drawPath(path, paint);
    surface.reset();
    return composite_pixels(destination, std::move(pixels), raster_width, raster_height,
        static_cast<float>(region.left), canvas_height - static_cast<float>(region.bottom),
        static_cast<float>(region.width()), static_cast<float>(region.height()));
}

static int draw_svg_linear_gradient_path_with_clip(
    CGContextRef destination, float const* data, int segment_count, int even_odd,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, int stroke,
    float stroke_width, int line_cap, int line_join, float miter_limit,
    float start_x, float start_y, float end_x, float end_y, float gradient_a,
    float gradient_b, float gradient_c, float gradient_d, float gradient_e,
    float gradient_f, int spread_method, int linear_color_space,
    float const* stop_data, int stop_count, float opacity, int opaque_backdrop, float const* clip, float const* ancestor_clip)
{
    float const gradient_points[] { start_x, start_y, end_x, end_y, 0.0f, 0.0f };
    return draw_svg_gradient_path(destination, data, segment_count, even_odd,
        transform_a, transform_b, transform_c, transform_d, transform_e,
        transform_f, page_x, page_y, scroll_y, canvas_width, canvas_height,
        stroke, stroke_width, line_cap, line_join, miter_limit, gradient_a,
        gradient_b, gradient_c, gradient_d, gradient_e, gradient_f,
        spread_method, linear_color_space, stop_data, stop_count, opacity,
        1, gradient_points, opaque_backdrop, clip, ancestor_clip,
        [=](std::vector<SkColor4f> const& colors,
            std::vector<SkScalar> const& positions, SkTileMode tile_mode,
            SkMatrix const& gradient_matrix) {
            SkPoint points[] { { start_x, start_y }, { end_x, end_y } };
            SkGradientShader::Interpolation interpolation;
            return SkGradientShader::MakeLinear(points, colors.data(), nullptr,
                positions.data(), static_cast<int>(colors.size()), tile_mode,
                interpolation, &gradient_matrix);
        });
}

extern "C" int ladybird_v_skia_draw_svg_linear_gradient_path(
    CGContextRef destination, float const* data, int segment_count, int even_odd,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, int stroke,
    float stroke_width, int line_cap, int line_join, float miter_limit,
    float start_x, float start_y, float end_x, float end_y, float gradient_a,
    float gradient_b, float gradient_c, float gradient_d, float gradient_e,
    float gradient_f, int spread_method, int linear_color_space,
    float const* stop_data, int stop_count, float opacity, int opaque_backdrop)
{
    return draw_svg_linear_gradient_path_with_clip(destination, data, segment_count, even_odd,
        transform_a, transform_b, transform_c, transform_d, transform_e, transform_f,
        page_x, page_y, scroll_y, canvas_width, canvas_height, stroke, stroke_width,
        line_cap, line_join, miter_limit, start_x, start_y, end_x, end_y, gradient_a,
        gradient_b, gradient_c, gradient_d, gradient_e, gradient_f, spread_method,
        linear_color_space, stop_data, stop_count, opacity, opaque_backdrop, nullptr, nullptr);
}

extern "C" int ladybird_v_skia_draw_clipped_svg_linear_gradient_path(
    CGContextRef destination, float const* data, int segment_count, int even_odd,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, int stroke,
    float stroke_width, int line_cap, int line_join, float miter_limit,
    float start_x, float start_y, float end_x, float end_y, float gradient_a,
    float gradient_b, float gradient_c, float gradient_d, float gradient_e,
    float gradient_f, int spread_method, int linear_color_space,
    float const* stop_data, int stop_count, float opacity, int opaque_backdrop, float const* clip, float const* ancestor_clip)
{
    return draw_svg_linear_gradient_path_with_clip(destination, data, segment_count, even_odd,
        transform_a, transform_b, transform_c, transform_d, transform_e, transform_f,
        page_x, page_y, scroll_y, canvas_width, canvas_height, stroke, stroke_width,
        line_cap, line_join, miter_limit, start_x, start_y, end_x, end_y, gradient_a,
        gradient_b, gradient_c, gradient_d, gradient_e, gradient_f, spread_method,
        linear_color_space, stop_data, stop_count, opacity, opaque_backdrop, clip, ancestor_clip);
}

extern "C" int ladybird_v_skia_draw_svg_radial_gradient_path(
    CGContextRef destination, float const* data, int segment_count, int even_odd,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, int stroke,
    float stroke_width, int line_cap, int line_join, float miter_limit,
    float start_x, float start_y, float start_radius, float end_x, float end_y,
    float end_radius, float gradient_a, float gradient_b, float gradient_c,
    float gradient_d, float gradient_e, float gradient_f, int spread_method,
    int linear_color_space, float const* stop_data, int stop_count, float opacity,
    int opaque_backdrop)
{
    float const gradient_points[] { start_x, start_y, std::max(start_radius, 0.0f),
        end_x, end_y, std::max(end_radius, 0.0f) };
    return draw_svg_gradient_path(destination, data, segment_count, even_odd,
        transform_a, transform_b, transform_c, transform_d, transform_e,
        transform_f, page_x, page_y, scroll_y, canvas_width, canvas_height,
        stroke, stroke_width, line_cap, line_join, miter_limit, gradient_a,
        gradient_b, gradient_c, gradient_d, gradient_e, gradient_f,
        spread_method, linear_color_space, stop_data, stop_count, opacity,
        2, gradient_points, opaque_backdrop, nullptr, nullptr,
        [=](std::vector<SkColor4f> const& colors,
            std::vector<SkScalar> const& positions, SkTileMode tile_mode,
            SkMatrix const& gradient_matrix) {
            SkGradientShader::Interpolation interpolation;
            return SkGradientShader::MakeTwoPointConical(
                SkPoint::Make(start_x, start_y), std::max(start_radius, 0.0f),
                SkPoint::Make(end_x, end_y), std::max(end_radius, 0.0f),
                colors.data(), nullptr, positions.data(),
                static_cast<int>(colors.size()), tile_mode, interpolation,
                &gradient_matrix);
        });
}
