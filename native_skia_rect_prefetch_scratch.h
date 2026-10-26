#pragma once

// Lookahead text changes the backdrops of later leaves. Replay that text into
// a private bitmap and collect each rectangle at its original position in the
// stream. The real destination is never changed, and ordered replay still
// requires the raster cache's exact background comparison.
struct PlainRectPrefetchScratch {
    CGContextRef context { nullptr };
    std::vector<VoxGraphiteShape> shapes;
    std::vector<PlainRectPrefetchJob> jobs;
    float page_x, page_y, canvas_width, canvas_height;
    int grid_width, grid_height, next { 0 };
    bool valid { true };

    ~PlainRectPrefetchScratch()
    {
        if (context) CGContextRelease(context);
    }
};

static std::unique_ptr<PlainRectPrefetchScratch> s_plain_rect_scratch;
static std::vector<uint8_t> s_plain_rect_scratch_pixels;

// The returned context is borrowed until finish, including cancellation. Only
// local, pixel-wise text painting belongs between begin/append/finish calls.
extern "C" CGContextRef ladybird_v_skia_begin_rect_prefetch_scratch(CGContextRef destination,
    VoxGraphiteShape const* shapes, int count, float page_x, float page_y,
    float canvas_width, float canvas_height)
{
    if (s_plain_rect_scratch || !shapes || count < 2 || count > 32
        || !plain_rect_prefetch_allowed(destination)
        || !std::isfinite(page_x) || !std::isfinite(page_y)
        || std::abs(page_x) > 65536 || std::abs(page_y) > 65536
        || !(canvas_width > 0 && canvas_width <= 4096)
        || !(canvas_height > 0 && canvas_height <= 4096)
        || CGBitmapContextGetBitsPerComponent(destination) != 8
        || CGBitmapContextGetBitsPerPixel(destination) != 32
        || CGBitmapContextGetAlphaInfo(destination) != kCGImageAlphaPremultipliedLast
        || (CGBitmapContextGetBitmapInfo(destination) & kCGBitmapByteOrderMask) != kCGBitmapByteOrder32Big)
        return nullptr;
    auto ctm = CGContextGetCTM(destination);
    if ((ctm.a != 1 && ctm.a != 2) || ctm.d != ctm.a
        || ctm.b != 0 || ctm.c != 0 || ctm.tx != 0 || ctm.ty != 0)
        return nullptr;
    // Logical-pixel screenshots can override the normal destination scale.
    // A scratch bitmap must retain the same readable backdrop coordinates.
    if (screenshot_uses_logical_pixels() && ctm.a != 1) return nullptr;
    auto scale = static_cast<float>(ctm.a);
    auto width = CGBitmapContextGetWidth(destination);
    auto height = CGBitmapContextGetHeight(destination);
    auto pitch = CGBitmapContextGetBytesPerRow(destination);
    auto* source = static_cast<uint8_t const*>(CGBitmapContextGetData(destination));
    auto color_space = CGBitmapContextGetColorSpace(destination);
    constexpr size_t byte_limit = 64 * 1024 * 1024;
    if (!source || !color_space || !width || !height || width > 8192 || height > 8192
        || pitch < width * 4 || pitch > byte_limit / height
        || canvas_width * scale > width || canvas_height * scale > height)
        return nullptr;
    for (int i = 0; i < count; ++i) {
        if (!plain_rect_prefetch_shape_allowed(shapes[i], scale)) return nullptr;
        for (float value : shapes[i].matrix)
            if (std::abs(value) > 65536) return nullptr;
        for (float value : shapes[i].rect)
            if (std::abs(value) > 32768) return nullptr;
    }
    auto scratch = std::make_unique<PlainRectPrefetchScratch>();
    scratch->shapes.assign(shapes, shapes + count);
    scratch->jobs.reserve(32);
    scratch->page_x = page_x;
    scratch->page_y = page_y;
    scratch->canvas_width = canvas_width;
    scratch->canvas_height = canvas_height;
    scratch->grid_width = s_msaa_grid_width;
    scratch->grid_height = s_msaa_grid_height;
    s_plain_rect_scratch_pixels.resize(pitch * height);
    scratch->context = CGBitmapContextCreate(s_plain_rect_scratch_pixels.data(), width, height,
        8, pitch, color_space, CGBitmapContextGetBitmapInfo(destination));
    if (!scratch->context) return nullptr;
    CGContextConcatCTM(scratch->context, ctm);
    CGContextFlush(destination);
    // Initialize every potential readback region before text replay. Pixels
    // outside these regions cannot enter a collected rectangle's backdrop.
    // Text masks and their composition are local to each destination pixel.
    for (auto const& shape : scratch->shapes) {
        SkMatrix matrix;
        matrix.set9(shape.matrix);
        matrix.postTranslate(page_x, page_y);
        RasterRegion region;
        if (!clipped_raster_region(matrix.mapRect(SkRect::MakeXYWH(shape.rect[0], shape.rect[1],
                    shape.rect[2], shape.rect[3])), canvas_width, canvas_height, 2, region)) continue;
        auto left = size_t(std::lround(region.left * scale));
        auto top = size_t(std::lround(region.top * scale));
        auto columns = size_t(raster_dimension(region.width(), scale));
        auto rows = size_t(raster_dimension(region.height(), scale));
        if (left + columns > width || top + rows > height) return nullptr;
        for (size_t row = top; row < top + rows; ++row)
            std::memcpy(s_plain_rect_scratch_pixels.data() + row * pitch + left * 4,
                source + row * pitch + left * 4, columns * 4);
    }
    auto context = scratch->context;
    s_plain_rect_scratch = std::move(scratch);
    return context;
}

extern "C" int ladybird_v_skia_append_rect_prefetch_scratch(int index)
{
    if (!s_plain_rect_scratch) return 0;
    auto& scratch = *s_plain_rect_scratch;
    if (!scratch.valid || index != scratch.next || index >= int(scratch.shapes.size())
        || s_msaa_grid_width != scratch.grid_width || s_msaa_grid_height != scratch.grid_height
        || !plain_rect_prefetch_allowed(scratch.context)) {
        scratch.valid = false;
        return 0;
    }
    s_plain_rect_prefetch = &scratch.jobs;
    collect_plain_rect_prefetch(scratch.context, scratch.shapes[index], scratch.page_x, scratch.page_y,
        scratch.canvas_width, scratch.canvas_height);
    s_plain_rect_prefetch = nullptr;
    ++scratch.next;
    return 1;
}

extern "C" int ladybird_v_skia_finish_rect_prefetch_scratch(int commit)
{
    if (!s_plain_rect_scratch) return 0;
    auto scratch = std::move(s_plain_rect_scratch);
    if (!commit || !scratch->valid || scratch->next != int(scratch->shapes.size())
        || s_msaa_grid_width != scratch->grid_width || s_msaa_grid_height != scratch->grid_height
        || !plain_rect_prefetch_allowed(scratch->context)) return 0;
    return submit_plain_rect_prefetch(scratch->jobs);
}
