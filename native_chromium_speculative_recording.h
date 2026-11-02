#pragma once

// Opt-in native recording follows actual visible paint order, ending at each
// existing layer/context barrier. Unsupported content and failed publication
// retain the existing whole-frame non-deferred replay; the retry never opts in.
static bool speculative_picture_enabled()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_ENABLE_SPECULATIVE_PICTURES");
        return value && !std::strcmp(value, "1") && !std::getenv("VOX_DISABLE_SPECULATIVE_PICTURES");
    }();
    return enabled;
}
static bool complete_speculative_picture_enabled()
{
    auto* value = std::getenv("VOX_ENABLE_COMPLETE_SPECULATIVE_PICTURES");
    return value && !std::strcmp(value, "1");
}
static double speculative_picture_time()
{
    using Clock = double (*)();
    static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
    return clock ? clock() : -1;
}

// A failed transaction replays correctly, but repeating that failed work on
// every wheel frame can cost more than ordinary rendering. Remember a small
// set of declined layer geometries. A false match only declines acceleration;
// no pixel or resource identity is inferred from these coordinates.
struct SpeculativeDeclinedLayer {
    float x, y, width, height, scale;
    int canvas_width, canvas_height;
    bool operator==(SpeculativeDeclinedLayer const&) const = default;
};
static std::vector<SpeculativeDeclinedLayer> s_speculative_declined_layers;
static void speculative_picture_decline(SharedRootRecording const& group)
{
    if (!complete_speculative_picture_enabled()) return;
    SpeculativeDeclinedLayer key {group.origin_x, group.origin_y, group.layer_width,
        group.layer_height, group.scale, int(group.canvas_width * group.scale),
        int(group.canvas_height * group.scale)};
    if (std::find(s_speculative_declined_layers.begin(), s_speculative_declined_layers.end(), key)
            != s_speculative_declined_layers.end()) return;
    if (s_speculative_declined_layers.size() >= 128) s_speculative_declined_layers.erase(s_speculative_declined_layers.begin());
    s_speculative_declined_layers.push_back(key);
}
static CGContextRef speculative_picture_current_context()
{
    // Keep AppKit hosting optional for non-windowed native engine callers.
    // Only pointer-valued Objective-C methods cross this graphics boundary.
    using Lookup = void* (*)(char const*);
    using Send = void* (*)(void*, void*);
    static auto lookup = reinterpret_cast<Lookup>(dlsym(RTLD_DEFAULT, "objc_getClass"));
    static auto selector = reinterpret_cast<Lookup>(dlsym(RTLD_DEFAULT, "sel_registerName"));
    static auto send = reinterpret_cast<Send>(dlsym(RTLD_DEFAULT, "objc_msgSend"));
    if (!lookup || !selector || !send) return nullptr;
    auto cls = lookup("NSGraphicsContext");
    auto context = cls ? send(cls, selector("currentContext")) : nullptr;
    return context ? static_cast<CGContextRef>(send(context, selector("CGContext"))) : nullptr;
}
static bool speculative_picture_context_eligible(CGContextRef context)
{
    if (!context || !CGBitmapContextGetData(context)
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || CGBitmapContextGetBitmapInfo(context) !=
            (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)) return false;
    auto ctm = CGContextGetCTM(context);
    if (!(ctm.a > 0) || ctm.d != ctm.a || ctm.b != 0 || ctm.c != 0
        || ctm.tx != 0 || ctm.ty != 0) return false;
    auto width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    SpeculativeDeclinedLayer key {float(s_raster_origin_x), float(s_raster_origin_y),
        float(s_raster_layer_width), float(s_raster_layer_height), float(ctm.a), int(width), int(height)};
    if (complete_speculative_picture_enabled()
        && std::find(s_speculative_declined_layers.begin(), s_speculative_declined_layers.end(), key)
            != s_speculative_declined_layers.end()) return false;
    if (!width || !height || width > 16384 || height > 16384
        || size_t(width) * height > 8 * 1024 * 1024
        || !(s_raster_layer_width * ctm.a >= 1 && s_raster_layer_width * ctm.a <= 16384)
        || !(s_raster_layer_height * ctm.a >= 1 && s_raster_layer_height * ctm.a <= 16384)
        || s_raster_layer_width * s_raster_layer_height * ctm.a * ctm.a < 262144) return false;
    auto space = CGBitmapContextGetColorSpace(context);
    auto name = space ? CGColorSpaceCopyName(space) : nullptr;
    bool srgb = name && CFEqual(name, kCGColorSpaceSRGB);
    if (name) CFRelease(name);
    if (!srgb) return false;
    auto initial_clip = CGContextConvertRectToDeviceSpace(context, CGContextGetClipBoundingBox(context));
    if (CGRectIsEmpty(initial_clip) || CGRectIsNull(initial_clip) || CGRectIsInfinite(initial_clip)) return false;
    for (double edge : {CGRectGetMinX(initial_clip), CGRectGetMinY(initial_clip),
            CGRectGetMaxX(initial_clip), CGRectGetMaxY(initial_clip)})
        if (!std::isfinite(edge) || edge != std::floor(edge)) return false;
    auto clips = s_shared_clips.find(context);
    if (clips != s_shared_clips.end()) {
        if (clips->second.unsupported) return false;
        // The registration API requires a genuinely rectangular initial clip.
        // Reject masks, rounded clips and fractional device-space boundaries.
        for (auto const& clip : clips->second.clips) {
            if (!clip.rect.isRect() || !clip.matrix.rectStaysRect()) return false;
            auto rect = SkMatrix::Scale(ctm.a, ctm.a).mapRect(clip.matrix.mapRect(clip.rect.rect()));
            for (float edge : {rect.left(), rect.top(), rect.right(), rect.bottom()})
                if (!std::isfinite(edge) || edge != std::floor(edge)) return false;
        }
    }
    return true;
}
