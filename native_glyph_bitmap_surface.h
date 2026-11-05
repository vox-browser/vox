#pragma once

// A private frame can supply the raster leaf directly. Keep the same crop,
// matrix, paint and Skia surface properties as the ordinary BGRA tile, while
// avoiding its backdrop allocation and Quartz image publication.
static bool draw_glyph_bitmap_surface(CGContextRef context, int width, int height,
    CGRect rectangle, SkMatrix const& matrix, SkTextBlob const* blob,
    float x, float y, SkPaint const& paint, SkSurfaceProps const* properties,
    SkIRect const* device_clip = nullptr)
{
    // A device clip has already been matched against Quartz's clip; otherwise
    // Quartz must not clip the tile at all.
    if (!context || !blob || width <= 0 || height <= 0 || !rgba_bitmap(context)
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || (!device_clip && !CGRectContainsRect(CGContextGetClipBoundingBox(context), rectangle))) return false;
    auto ctm = CGContextGetCTM(context);
    if (!(ctm.a > 0 && ctm.d > 0) || ctm.b != 0 || ctm.c != 0
        || ctm.tx != 0 || ctm.ty != 0) return false;
    auto frame_width = CGBitmapContextGetWidth(context);
    auto frame_height = CGBitmapContextGetHeight(context);
    if (!frame_width || !frame_height) return false;
    double left = CGRectGetMinX(rectangle) * ctm.a;
    double top = double(frame_height) - CGRectGetMaxY(rectangle) * ctm.d;
    if (!std::isfinite(left) || !std::isfinite(top) || left < 0 || top < 0
        || left != std::floor(left) || top != std::floor(top)
        || rectangle.size.width * ctm.a != width
        || rectangle.size.height * ctm.d != height
        || left + width > frame_width || top + height > frame_height) return false;
    static auto srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto color = CGBitmapContextGetColorSpace(context);
    auto pitch = CGBitmapContextGetBytesPerRow(context);
    if (!srgb || !color || !CFEqual(color, srgb) || frame_width > SIZE_MAX / 4
        || pitch < frame_width * 4 || pitch > SIZE_MAX / frame_height) return false;
    CGContextFlush(context);
    auto* data = static_cast<uint8_t*>(CGBitmapContextGetData(context));
    if (!data) return false;
    auto visible = SkIRect::MakeWH(width, height);
    if (device_clip && !visible.intersect(device_clip->makeOffset(-int(left), -int(top))))
        return true; // The clip hides the whole tile; its pixels stay unchanged.
    size_t offset = size_t(top) * pitch + size_t(left) * 4;
    // Quartz writes only inside its clip, so detach through a visible pixel.
    double detach_x = left + visible.left(), detach_y = top + visible.top();
    size_t detach_offset = size_t(detach_y) * pitch + size_t(detach_x) * 4;
    uint32_t previous;
    std::memcpy(&previous, data + detach_offset, sizeof(previous));
    // Detach any earlier immutable Quartz snapshot before borrowing writable
    // pixels. Restore the touched pixel before Skia sees its original backdrop.
    CGContextClearRect(context, CGRectMake(detach_x / ctm.a,
        (double(frame_height) - detach_y - 1) / ctm.d, 1 / ctm.a, 1 / ctm.d));
    CGContextFlush(context);
    data = static_cast<uint8_t*>(CGBitmapContextGetData(context));
    if (!data) return false;
    std::memcpy(data + detach_offset, &previous, sizeof(previous));
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto* tile = data + offset;
    // Raster in precisely the old BGRA format. RGBA CPU blitters can round
    // coverage differently; temporarily swap this private bounded region.
    for (int row = 0; row < height; ++row)
        swap_red_blue_pixels(tile + size_t(row) * pitch, tile + size_t(row) * pitch, width);
    auto surface = SkSurfaces::WrapPixels(info, tile, pitch, properties);
    if (!surface) {
        for (int row = 0; row < height; ++row)
            swap_red_blue_pixels(tile + size_t(row) * pitch, tile + size_t(row) * pitch, width);
        return false;
    }
    auto* canvas = surface->getCanvas();
    if (device_clip) canvas->clipIRect(visible);
    canvas->setMatrix(matrix);
    canvas->drawTextBlob(blob, x, y, paint);
    surface.reset();
    for (int row = 0; row < height; ++row)
        swap_red_blue_pixels(tile + size_t(row) * pitch, tile + size_t(row) * pitch, width);
    return true;
}
