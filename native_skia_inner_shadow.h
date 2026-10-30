// Included after the raster-grid and shared-picture helpers. Inset shadows
// retain their rounded padding-box hole and clip through the Chromium GPU backend.
extern "C" int ladybird_v_skia_draw_inner_box_shadow(CGContextRef destination,
    float const* outer_data, float const* inner_data, float const* content_data,
    float const* clip_data, float const* transform, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, float blur,
    uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha, int opaque_backdrop)
{
    auto draw = shared_picture_draw();
    if (!destination || !s_chromium_painting || !draw || !outer_data || !inner_data
        || !content_data || !clip_data || !transform || !(canvas_width > 0)
        || !(canvas_height > 0) || !std::isfinite(blur)) return 0;
    for (float value : {page_x, page_y, scroll_y, canvas_width, canvas_height})
        if (!std::isfinite(value)) return 0;
    for (auto data : {outer_data, inner_data, content_data, clip_data})
        for (int index = 0; index < 12; ++index)
            if (!std::isfinite(data[index])) return 0;
    for (int index = 0; index < 6; ++index)
        if (!std::isfinite(transform[index])) return 0;
    auto rounded = [](float const* data) {
        SkVector radii[4];
        for (int index = 0; index < 4; ++index)
            radii[index] = {std::max(data[4 + index * 2], 0.0f),
                std::max(data[5 + index * 2], 0.0f)};
        SkRRect result;
        result.setRectRadii(SkRect::MakeXYWH(data[0], data[1], data[2], data[3]), radii);
        return result;
    };
    float inner_geometry[12];
    std::copy_n(inner_data, 12, inner_geometry);
    for (int index = 4; index < 12; ++index)
        inner_geometry[index] = std::max(0.0f,
            inner_data[index] - content_data[index] + clip_data[index]);
    auto inner = rounded(inner_geometry);
    auto content = rounded(clip_data);
    auto matrix = SkMatrix::MakeAll(transform[0], transform[2], page_x + transform[4],
        transform[1], transform[3], page_y - scroll_y + transform[5], 0, 0, 1);
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(content.rect()), canvas_width,
            canvas_height, 1, region)) return 1;
    float scale = screenshot_uses_logical_pixels() ? 1 : raster_scale_for_context(destination);
    int width = raster_dimension(region.width(), scale);
    int height = raster_dimension(region.height(), scale);
    if (width <= 0 || height <= 0 || size_t(width) * height > 8 * 1024 * 1024) return 0;
    std::vector<uint32_t> pixels(size_t(width) * height);
    bool has_background = s_raster_layer_is_root && opaque_backdrop
        && copy_backdrop(destination, region, scale, width, height, pixels);
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    if (has_background) {
        auto background = SkImages::RasterFromPixmapCopy(SkPixmap(info,
            pixels.data(), size_t(width) * 4));
        if (!background) return 0;
        canvas->drawImage(background, 0, 0);
    }
    canvas->setMatrix(raster_matrix(matrix, region,
        float(width) / region.width(), float(height) / region.height()));
    canvas->clipRRect(content, true);
    SkPath path;
    path.setFillType(SkPathFillType::kEvenOdd);
    // The outer caster is a rectangle around the complete hole, not another
    // rounded contour. Its corners must not fade into the padding-box clip.
    float spread_x = (content_data[2] - inner_data[2]) / 2;
    float spread_y = (content_data[3] - inner_data[3]) / 2;
    float offset_x = inner_data[0] - content_data[0] - spread_x;
    float offset_y = inner_data[1] - content_data[1] - spread_y;
    auto caster = content.rect().makeOutset(std::max(blur, 0.0f) + std::max(-spread_x, 0.0f),
        std::max(blur, 0.0f) + std::max(-spread_y, 0.0f));
    caster.join(caster.makeOffset(-offset_x, -offset_y));
    caster.offset(offset_x, offset_y);
    path.addRect(caster);
    if (!inner.isEmpty()) path.addRRect(inner);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    if (blur > 0) paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, blur / 2));
    if (auto* recording = isolated_input_recording_canvas(destination)) {
        recording->save();
        shared_recording_clip(destination, recording);
        recording->setMatrix(matrix);
        recording->clipRRect(content, true);
        recording->drawPath(path, paint);
        recording->restore();
        shared_recording_content(destination, matrix.mapRect(content.rect()), page_y, scroll_y);
    }
    canvas->drawPath(path, paint);
    auto picture = recorder.finishRecordingAsPicture();
    SkSerialProcs procs;
    procs.fImageProc = serialize_shared_picture_image;
    auto bytes = picture->serialize(&procs);
    if (!bytes) return 0;
    bool rendered = draw_chromium_root_raster_grid(pixels, width, height,
        region, page_x, page_y, scroll_y, scale,
        [&](auto& tile, long offset_x, long offset_y, bool) {
            float translation[] {1, 0, float(offset_x), 0, 1, float(offset_y), 0, 0, 1};
            return draw(reinterpret_cast<uint8_t*>(tile.data()), s_msaa_grid_width,
                s_msaa_grid_height, s_msaa_grid_width * 4, bytes->data(),
                bytes->size(), translation) != 0;
        });
    if (!rendered) {
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        if (!draw(reinterpret_cast<uint8_t*>(pixels.data()), width, height,
                width * 4, bytes->data(), bytes->size(), identity)) return 0;
    }
    return composite_pixels(destination, std::move(pixels), width, height,
        float(region.left), canvas_height - float(region.bottom),
        float(region.width()), float(region.height()), has_background);
}

struct InsetDecorationRecording {
    CGContextRef destination;
    RasterRegion region;
    int width, height;
    float scale, canvas_height, page_y, scroll_y;
    std::vector<uint32_t> backdrop;
};
static std::unique_ptr<InsetDecorationRecording> s_inset_decoration_recording;

// Retain the original backdrop before the fallback leaves draw. A failed or
// unsupported recording leaves those ordinary draws intact.
extern "C" int ladybird_v_skia_begin_inset_decorations(CGContextRef destination,
    float x, float y, float width, float height, float canvas_width,
    float canvas_height, float page_y, float scroll_y)
{
    if (!s_chromium_painting || !s_raster_layer_is_root || !destination
        || !shared_picture_draw() || s_inset_decoration_recording
        || s_isolated_input_recordings.count(destination)) return 0;
    for (float value : {x, y, width, height, canvas_width, canvas_height, page_y, scroll_y})
        if (!std::isfinite(value)) return 0;
    if (!(width > 0 && height > 0 && canvas_width > 0 && canvas_height > 0)) return 0;
    auto group = std::make_unique<InsetDecorationRecording>();
    if (!clipped_raster_region(SkRect::MakeXYWH(x, y, width, height),
            canvas_width, canvas_height, 2, group->region)) return 0;
    group->destination = destination;
    group->scale = screenshot_uses_logical_pixels() ? 1 : raster_scale_for_context(destination);
    group->width = raster_dimension(group->region.width(), group->scale);
    group->height = raster_dimension(group->region.height(), group->scale);
    if (group->width <= 0 || group->height <= 0
        || size_t(group->width) * group->height > 8 * 1024 * 1024) return 0;
    group->backdrop.resize(size_t(group->width) * group->height);
    if (!copy_backdrop(destination, group->region, group->scale,
            group->width, group->height, group->backdrop)
        || !ladybird_v_skia_begin_isolated_input(destination, canvas_width, canvas_height)) return 0;
    group->canvas_height = canvas_height;
    group->page_y = page_y;
    group->scroll_y = scroll_y;
    s_inset_decoration_recording = std::move(group);
    return 1;
}

extern "C" int ladybird_v_skia_end_inset_decorations(CGContextRef destination)
{
    if (!s_inset_decoration_recording || s_inset_decoration_recording->destination != destination)
        return 0;
    auto group = std::move(s_inset_decoration_recording);
    std::unique_ptr<IsolatedInputRecording> input(
        static_cast<IsolatedInputRecording*>(ladybird_v_skia_take_isolated_input(destination)));
    if (!input || input->unsupported) return 0;
    auto content = input->recorder.finishRecordingAsPicture();
    if (!content) return 0;
    auto info = SkImageInfo::Make(group->width, group->height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto background = SkImages::RasterFromPixmapCopy(SkPixmap(info,
        group->backdrop.data(), size_t(group->width) * 4));
    if (!background) return 0;
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(group->width, group->height));
    canvas->drawImage(background, 0, 0);
    canvas->scale(group->scale, group->scale);
    canvas->translate(-group->region.left, -group->region.top);
    canvas->drawPicture(content);
    auto picture = recorder.finishRecordingAsPicture();
    SkSerialProcs procs;
    procs.fImageProc = serialize_shared_picture_image;
    auto bytes = picture->serialize(&procs);
    if (!bytes) return 0;
    auto pixels = group->backdrop;
    auto draw = shared_picture_draw();
    bool rendered = draw_chromium_root_raster_grid(pixels, group->width, group->height,
        group->region, 0, group->page_y, group->scroll_y, group->scale,
        [&](auto& tile, long offset_x, long offset_y, bool) {
            float translation[] {1, 0, float(offset_x), 0, 1, float(offset_y), 0, 0, 1};
            return draw(reinterpret_cast<uint8_t*>(tile.data()), s_msaa_grid_width,
                s_msaa_grid_height, s_msaa_grid_width * 4, bytes->data(), bytes->size(), translation) != 0;
        });
    if (!rendered) {
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        if (!draw(reinterpret_cast<uint8_t*>(pixels.data()), group->width, group->height,
                group->width * 4, bytes->data(), bytes->size(), identity)) return 0;
    }
    return composite_pixels(destination, std::move(pixels), group->width, group->height,
        group->region.left, group->canvas_height - group->region.bottom,
        group->region.width(), group->region.height(), true);
}
