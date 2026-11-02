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
static double speculative_picture_time()
{
    using Clock = double (*)();
    static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
    return clock ? clock() : -1;
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
