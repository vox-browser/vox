#pragma once

// Copy a completed, backdrop-composited glyph tile into a private sRGB frame.
// The caller proves rectangular clipping and ordinary frame graphics state.
// Always ask Quartz to perform a real write before borrowing its mutable data:
// CGBitmapContextCreateImage may have protected an earlier copy of the bitmap.
static bool copy_glyph_bitmap(CGContextRef context, uint32_t const* bgra,
    int width, int height, CGRect rectangle)
{
    if (!context || !bgra || width <= 0 || height <= 0 || !rgba_bitmap(context)
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || !CGRectContainsRect(CGContextGetClipBoundingBox(context), rectangle)) return false;
    auto matrix = CGContextGetCTM(context);
    if (!(matrix.a > 0 && matrix.d > 0) || matrix.b != 0 || matrix.c != 0
        || matrix.tx != 0 || matrix.ty != 0) return false;
    auto source_width = CGBitmapContextGetWidth(context);
    auto source_height = CGBitmapContextGetHeight(context);
    double left = CGRectGetMinX(rectangle) * matrix.a;
    double top = double(source_height) - CGRectGetMaxY(rectangle) * matrix.d;
    if (!std::isfinite(left) || !std::isfinite(top) || left < 0 || top < 0
        || left != std::floor(left) || top != std::floor(top)
        || rectangle.size.width * matrix.a != width
        || rectangle.size.height * matrix.d != height
        || left + width > source_width || top + height > source_height) return false;
    static auto srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto color = CGBitmapContextGetColorSpace(context);
    auto pitch = CGBitmapContextGetBytesPerRow(context);
    if (!color || !srgb || !CFEqual(color, srgb) || source_width > SIZE_MAX / 4
        || pitch < source_width * 4 || pitch > SIZE_MAX / source_height
        || !CGBitmapContextGetData(context)) return false;
    // The copied tile includes this pixel. Its final value is installed below;
    // ClearRect only detaches shared snapshot storage and marks native damage.
    CGContextClearRect(context, CGRectMake(left / matrix.a,
        (double(source_height) - top - 1) / matrix.d, 1 / matrix.a, 1 / matrix.d));
    CGContextFlush(context);
    auto* pixels = static_cast<uint8_t*>(CGBitmapContextGetData(context));
    if (!pixels) return false; // The ordinary image replay covers the cleared tile too.
    pixels += size_t(top) * pitch + size_t(left) * 4;
    for (int row = 0; row < height; ++row)
        swap_red_blue_pixels(pixels + size_t(row) * pitch,
            reinterpret_cast<uint8_t const*>(bgra + size_t(row) * width), width);
    return true;
}
