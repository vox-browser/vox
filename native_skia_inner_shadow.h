// Included after the raster-grid and shared-picture helpers. Inset shadows
// retain their rounded padding-box hole and clip through the Chromium GPU backend.
static sk_sp<SkData> inset_picture_bytes(SkPicture* picture, bool multisampled)
{
    sk_sp<SkPicture> forced;
    if (multisampled) {
        auto bounds = picture->cullRect();
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(bounds);
        canvas->drawPicture(picture);
        // Graphite chooses multisampling for a complete render pass. Carry
        // the owning tile's choice even when this picture has only analytic
        // shapes. A transparent complex path keeps every color unchanged.
        SkPaint noop;
        noop.setAntiAlias(true);
        noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
        SkPath path;
        path.moveTo(bounds.left(), bounds.top());
        path.cubicTo(bounds.right(), bounds.top() + bounds.height() * .1f,
            bounds.left(), bounds.bottom(), bounds.right(), bounds.bottom());
        path.lineTo(bounds.left() + bounds.width() * .5f,
            bounds.top() + bounds.height() * .2f);
        path.close();
        canvas->drawPath(path, noop);
        forced = recorder.finishRecordingAsPicture();
        picture = forced.get();
    }
    SkSerialProcs procs;
    procs.fImageProc = serialize_shared_picture_image;
    return picture->serialize(&procs);
}

#ifdef VOX_TEST_CLIPPED_INSET_SHADOWS
static unsigned s_test_clipped_inset_shadows, s_test_batched_inset_shadows;
#endif

// The root tiles a picture covers render and read back in one GPU submission
// instead of one per tile. Each request keeps its complete tile target and
// multisampling choice, so every pixel matches the serial tiled replay.
static bool draw_root_picture_batch(std::vector<uint32_t>& pixels, int width, int height,
    RasterRegion const& region, float page_x, float page_y, float scroll_y, float scale,
    SkPicture* picture, sk_sp<SkData> const& bytes, sk_sp<SkData>& multisampled_bytes,
    bool direct_backdrop = false)
{
    auto draw = direct_backdrop ? picture_regions_backdrop_draw() : picture_regions_draw();
    auto const* disabled = std::getenv("VOX_DISABLE_INSET_PICTURE_BATCH");
    if (!draw || (disabled && disabled[0] && std::strcmp(disabled, "0") != 0)
        || !s_raster_layer_is_root || s_msaa_grid_columns <= 0
        || s_msaa_grid_width <= 2 || s_msaa_grid_height <= 2) return false;
    long first_x = std::lround((region.left - page_x) * scale);
    long first_y = std::lround((region.top - page_y + scroll_y + s_root_raster_scroll_y) * scale);
    int content_height = std::max(1, int(std::ceil(s_raster_layer_height * scale)));
    int rows = std::max(1, (content_height - 2 + s_msaa_grid_height - 3) / (s_msaa_grid_height - 2));
    VoxChromiumRasterGrid grid{s_msaa_grid_width, s_msaa_grid_height, s_msaa_grid_columns, rows};
    return vox_draw_chromium_raster_grid_batch(pixels, width, height,
        first_x, first_y, grid, [&](auto& tiles) {
            std::vector<VoxGraphitePictureRegion> requests;
            requests.reserve(tiles.size());
            for (auto& tile : tiles) {
                bool msaa = std::binary_search(s_msaa_grid_tiles.begin(), s_msaa_grid_tiles.end(), tile.cell);
                if (msaa && !multisampled_bytes) multisampled_bytes = inset_picture_bytes(picture, true);
                auto const& selected = msaa ? multisampled_bytes : bytes;
                if (!selected) return false;
                requests.push_back({
                    {tile.x, tile.y, tile.width, tile.height, tile.width * 4,
                        reinterpret_cast<uint8_t*>(tile.pixels.data())},
                    selected->data(), selected->size(),
                    {1, 0, float(tile.offset_x), 0, 1, float(tile.offset_y), 0, 0, 1}});
            }
            int result = draw(requests.data(), int(requests.size()), grid.width, grid.height);
            if (result && std::getenv("VOX_PICTURE_REGION_DIAGNOSTICS"))
                std::fprintf(stderr, "VOX_PICTURE_BATCH inset tiles=%zu target=%dx%d\n",
                    requests.size(), grid.width, grid.height);
            return result != 0;
        }, std::getenv("VOX_DISABLE_LARGE_DECORATION_BATCH") ? 1024 * 1024 : 4 * 1024 * 1024);
}

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
    {
        int width = raster_dimension(region.width(), scale);
        int height = raster_dimension(region.height(), scale);
        if (width <= 0 || height <= 0 || size_t(width) * height > 8 * 1024 * 1024) return 0;
    }
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
    paint.setColor(SkColorSetRGB(red, green, blue));
    paint.setColorFilter(SkColorFilters::Blend(
        SkColor4f::FromColor(SkColorSetARGB(alpha, red, green, blue)),
        SkColorSpace::MakeSRGB(), SkBlendMode::kSrcIn));
    if (blur > 0) paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, blur / 2));
    SkRRect outer;
    outer.setRect(caster.makeOffset(-offset_x, -offset_y));
    auto local_inner = inner;
    local_inner.offset(-offset_x, -offset_y);
    // Keep Skia's double-rrect operation. Its circular-hole fast path has
    // different coverage and blur rounding from an equivalent even-odd path.
    auto draw_shadow = [&](SkCanvas* target) {
        if (!inner.isEmpty() && caster.contains(inner.rect())) {
            // Blink retains the offset on the canvas after installing the
            // content clip. Moving the vertices changes clip-edge rounding.
            target->save();
            target->translate(offset_x, offset_y);
            target->drawDRRect(outer, local_inner, paint);
            target->restore();
        } else {
            target->drawPath(path, paint);
        }
    };
    if (auto* recording = shared_recording_canvas(destination)) {
        recording->save();
        shared_recording_clip(destination, recording);
        recording->setMatrix(matrix);
        recording->clipRRect(content, true);
        draw_shadow(recording);
        recording->restore();
        shared_recording_content(destination, matrix.mapRect(content.rect()), page_y, scroll_y);
        if (isolated_input_defers_leaf_raster(destination)
            || shared_recording_defers_leaf_raster(destination, matrix.mapRect(content.rect()).makeOutset(2, 2))) return 1;
    }
    // Rasterize the box over its backdrop in the region's own pixels. A
    // cropped region returns -1 when it cannot use the root tiles, so the
    // complete region replays as before.
    auto raster = [&](RasterRegion const& region, bool cropped) {
        int failed = cropped ? -1 : 0;
        int width = raster_dimension(region.width(), scale);
        int height = raster_dimension(region.height(), scale);
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
            if (!background) return failed;
            canvas->drawImage(background, 0, 0);
        }
        canvas->setMatrix(raster_matrix(matrix, region,
            float(width) / region.width(), float(height) / region.height()));
        canvas->clipRRect(content, true);
        draw_shadow(canvas);
        auto picture = recorder.finishRecordingAsPicture();
        auto bytes = inset_picture_bytes(picture.get(), false);
        sk_sp<SkData> multisampled_bytes;
        if (!bytes) return failed;
        static bool const batched = !std::getenv("VOX_DISABLE_INSET_SHADOW_BATCH");
        bool rendered = batched && draw_root_picture_batch(pixels, width, height, region,
            page_x, page_y, scroll_y, scale, picture.get(), bytes, multisampled_bytes);
#ifdef VOX_TEST_CLIPPED_INSET_SHADOWS
        if (rendered) ++s_test_batched_inset_shadows;
#endif
        if (!rendered) rendered = draw_chromium_root_raster_grid(pixels, width, height,
            region, page_x, page_y, scroll_y, scale,
            [&](auto& tile, long offset_x, long offset_y, bool multisampled) {
                if (multisampled && !multisampled_bytes)
                    multisampled_bytes = inset_picture_bytes(picture.get(), true);
                auto const& selected = multisampled ? multisampled_bytes : bytes;
                if (!selected) return false;
                float translation[] {1, 0, float(offset_x), 0, 1, float(offset_y), 0, 0, 1};
                return draw(reinterpret_cast<uint8_t*>(tile.data()), s_msaa_grid_width,
                    s_msaa_grid_height, s_msaa_grid_width * 4, selected->data(),
                    selected->size(), translation) != 0;
            });
        if (!rendered) {
            if (cropped) return failed;
            float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
            if (!draw(reinterpret_cast<uint8_t*>(pixels.data()), width, height,
                    width * 4, bytes->data(), bytes->size(), identity)) return 0;
        }
        return composite_pixels(destination, std::move(pixels), width, height,
            float(region.left), canvas_height - float(region.bottom),
            float(region.width()), float(region.height()), has_background);
    };
    // Root grid tiles are anchored to the document, so a pixel's value does
    // not depend on the requested region. As for outer shadows, a strip or
    // damage repaint copies, rasterizes and composites only the rows it shows
    // rather than the whole box and its backdrop.
    RasterRegion visible;
    if (s_raster_layer_is_root && s_msaa_grid_columns > 0 && !screenshot_uses_logical_pixels()
        && !std::getenv("VOX_DISABLE_CLIPPED_INSET_SHADOWS")
        && visible_raster_region(destination, canvas_height, region, visible)
        && (visible.left != region.left || visible.top != region.top
            || visible.right != region.right || visible.bottom != region.bottom)) {
        int result = raster(visible, true);
        if (result >= 0) {
#ifdef VOX_TEST_CLIPPED_INSET_SHADOWS
            ++s_test_clipped_inset_shadows;
#endif
            return result;
        }
    }
    return raster(region, false);
}

struct InsetDecorationRecording {
    CGContextRef destination;
    RasterRegion region;
    int width, height;
    float scale, canvas_height, page_y, scroll_y;
    std::vector<uint32_t> backdrop;
    // A deferred group can contain an unsupported native fallback draw. Keep
    // its original rows until final publication, so retry starts pixel-exact.
    std::vector<uint32_t> checkpoint;
    bool deferred = false;
    RasterRegion checkpoint_region;
    int checkpoint_width = 0, checkpoint_height = 0;
};
static std::unique_ptr<InsetDecorationRecording> s_inset_decoration_recording;

// A decoration pair may have reserved the whole viewport before its ink was
// known. Keep only the original backdrop under that ink. The GPU still renders
// complete Chromium tiles; cropping their input does not change tile coverage.
static void trim_inset_decoration_backdrop(InsetDecorationRecording& group, SkRect ink)
{
    if (!ink.isFinite() || ink.isEmpty()) return;
    double left = std::max(double(group.region.left), double(std::floor(ink.left() - 2)));
    double top = std::max(double(group.region.top), double(std::floor(ink.top() - 2)));
    double right = std::min(double(group.region.right), double(std::ceil(ink.right() + 2)));
    double bottom = std::min(double(group.region.bottom), double(std::ceil(ink.bottom() + 2)));
    if (!(right > left && bottom > top)) return;
    double x = (left - group.region.left) * group.scale;
    double y = (top - group.region.top) * group.scale;
    double width = (right - left) * group.scale;
    double height = (bottom - top) * group.scale;
    // Preserve the original pixel grid, including unusual backing scales.
    for (double value : {x, y, width, height})
        if (!std::isfinite(value) || value != std::floor(value)) return;
    if (x < 0 || y < 0 || width <= 0 || height <= 0
        || x + width > group.width || y + height > group.height
        || (width == group.width && height == group.height)) return;
    int w = int(width), h = int(height);
    std::vector<uint32_t> cropped(size_t(w) * h);
    for (int row = 0; row < h; ++row)
        std::copy_n(group.backdrop.data() + size_t(int(y) + row) * group.width + int(x),
            w, cropped.data() + size_t(row) * w);
    // The original backdrop is already the rollback copy. Transfer its
    // allocation when cropping rather than copying the viewport at begin.
    if (group.deferred && group.checkpoint.empty())
        group.checkpoint = std::move(group.backdrop);
    group.backdrop = std::move(cropped);
    group.region = {int(left), int(top), int(right), int(bottom)};
    group.width = w;
    group.height = h;
}

static bool draw_inset_picture_batch(InsetDecorationRecording const& group, SkPicture* picture,
    sk_sp<SkData> const& bytes, sk_sp<SkData>& multisampled_bytes, std::vector<uint32_t>& pixels,
    bool direct_backdrop = false)
{
    return draw_root_picture_batch(pixels, group.width, group.height, group.region, 0,
        group.page_y, group.scroll_y, group.scale, picture, bytes, multisampled_bytes,
        direct_backdrop);
}

#ifdef VOX_TEST_CLIPPED_DECORATION_GROUPS
static unsigned s_test_clipped_decoration_groups;
#endif

// Retain the original backdrop before the fallback leaves draw. A failed or
// unsupported recording leaves those ordinary draws intact.
extern "C" int ladybird_v_skia_begin_inset_decorations(CGContextRef destination,
    float x, float y, float width, float height, float canvas_width,
    float canvas_height, float page_y, float scroll_y)
{
    if (!s_chromium_painting || !destination || s_speculative_layer_enabled
        || (s_raster_layer_is_root ? s_shared_root_enabled : s_shared_layer_enabled)
        || !shared_picture_draw() || s_inset_decoration_recording
        || s_isolated_input_recordings.count(destination)) return 0;
    for (float value : {x, y, width, height, canvas_width, canvas_height, page_y, scroll_y})
        if (!std::isfinite(value)) return 0;
    if (!(width > 0 && height > 0 && canvas_width > 0 && canvas_height > 0)) return 0;
    auto group = std::make_unique<InsetDecorationRecording>();
    if (!clipped_raster_region(SkRect::MakeXYWH(x, y, width, height),
            canvas_width, canvas_height, 2, group->region)) return 0;
    // A strip or damage repaint publishes only its clipped rows. Root grid
    // tiles are anchored to the document, so the group's backdrop, batch and
    // composite can cover just those rows without changing any of them.
    RasterRegion visible;
    if (s_raster_layer_is_root && s_msaa_grid_columns > 0 && !screenshot_uses_logical_pixels()
        && !std::getenv("VOX_DISABLE_CLIPPED_DECORATION_GROUPS")
        && visible_raster_region(destination, canvas_height, group->region, visible)) {
        group->region = visible;
#ifdef VOX_TEST_CLIPPED_DECORATION_GROUPS
        ++s_test_clipped_decoration_groups;
#endif
    }
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

extern "C" int ladybird_v_skia_begin_deferred_inset_decorations(CGContextRef destination,
    float x, float y, float width, float height, float canvas_width,
    float canvas_height, float page_y, float scroll_y)
{
    if (!ladybird_v_skia_begin_inset_decorations(destination, x, y, width, height,
            canvas_width, canvas_height, page_y, scroll_y)) return 0;
    if (std::getenv("VOX_DISABLE_DEFERRED_DECORATIONS")) return 1;
    // Fractional ancestor coverage blends final publication with the already
    // painted fallback prefix. Keep that legacy prefix when a clip is active.
    auto clip = CGContextConvertRectToDeviceSpace(destination, CGContextGetClipBoundingBox(destination));
    if (!CGRectEqualToRect(clip, CGRectMake(0, 0,
            CGBitmapContextGetWidth(destination), CGBitmapContextGetHeight(destination)))) return 1;
    auto tracked = s_shared_clips.find(destination);
    if (tracked != s_shared_clips.end()
        && (tracked->second.unsupported || !tracked->second.clips.empty())) return 1;
    auto& group = *s_inset_decoration_recording;
    group.deferred = true;
    group.checkpoint_region = group.region;
    group.checkpoint_width = group.width;
    group.checkpoint_height = group.height;
    s_isolated_input_recordings.at(destination)->defer_leaf_raster = true;
    return 1;
}

struct DeferredInsetCheckpoint {
    InsetDecorationRecording const& group;
    bool published = false;
    ~DeferredInsetCheckpoint()
    {
        if (published || !group.deferred) return;
        // Before cropping the unchanged backdrop itself owns the original
        // rows. Afterwards that same allocation lives in checkpoint.
        auto const& original = group.checkpoint.empty() ? group.backdrop : group.checkpoint;
        auto rows = read_backdrop(group.destination, group.checkpoint_region,
            group.scale, group.checkpoint_width, group.checkpoint_height);
        if (!rows.pixels) return;
        for (int y = 0; y < group.checkpoint_height; ++y)
            swap_red_blue_pixels(const_cast<uint8_t*>(rows.pixels) + size_t(y) * rows.pitch,
                reinterpret_cast<uint8_t const*>(original.data()
                    + size_t(y) * group.checkpoint_width), group.checkpoint_width);
    }
};

#ifdef VOX_TEST_DEFERRED_DECORATIONS
static bool s_test_fail_deferred_decorations;
#endif

extern "C" int ladybird_v_skia_end_inset_decorations(CGContextRef destination)
{
    SharedPicturePixelsScope shared_pixels(!std::getenv("VOX_DISABLE_SHARED_DECORATION_PIXELS"));
    if (!s_inset_decoration_recording || s_inset_decoration_recording->destination != destination)
        return 0;
    auto group = std::move(s_inset_decoration_recording);
    DeferredInsetCheckpoint checkpoint {*group};
    std::unique_ptr<IsolatedInputRecording> input(
        static_cast<IsolatedInputRecording*>(ladybird_v_skia_take_isolated_input(destination)));
    if (!input || input->unsupported) return 0;
#ifdef VOX_TEST_DEFERRED_DECORATIONS
    if (s_test_fail_deferred_decorations) return 0;
#endif
    if (!std::getenv("VOX_DISABLE_INSET_DECORATION_BOUNDS"))
        trim_inset_decoration_backdrop(*group, input->bounds);
    auto content = input->recorder.finishRecordingAsPicture();
    if (!content) return 0;
    auto publish = [&](std::vector<uint32_t>&& pixels) {
        int result = composite_pixels(destination, std::move(pixels), group->width, group->height,
            group->region.left, group->canvas_height - group->region.bottom,
            group->region.width(), group->region.height(), true);
        checkpoint.published = result != 0;
        if (result && group->deferred && std::getenv("VOX_PICTURE_REGION_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_DEFERRED_DECORATIONS width=%d height=%d\n", group->width, group->height);
        return result;
    };
    auto draw_region = picture_region_draw();
    bool regional = draw_region && !std::getenv("VOX_DISABLE_PICTURE_REGIONS")
        && !std::getenv("VOX_DISABLE_INSET_PICTURE_REGIONS");
    if (regional && !std::getenv("VOX_DISABLE_DIRECT_PICTURE_BACKDROP")
        && picture_regions_backdrop_draw()) {
        SkPictureRecorder direct_recorder;
        auto* direct_canvas = direct_recorder.beginRecording(SkRect::MakeWH(group->width, group->height));
        direct_canvas->scale(group->scale, group->scale);
        direct_canvas->translate(-group->region.left, -group->region.top);
        direct_canvas->drawPicture(content);
        auto direct_picture = direct_recorder.finishRecordingAsPicture();
        auto direct_bytes = inset_picture_bytes(direct_picture.get(), false);
        sk_sp<SkData> direct_msaa;
        auto direct_pixels = group->backdrop;
        if (direct_bytes && draw_inset_picture_batch(*group, direct_picture.get(), direct_bytes,
                direct_msaa, direct_pixels, true)) {
            if (std::getenv("VOX_DIRECT_BACKDROP_DIAGNOSTICS"))
                std::fprintf(stderr, "VOX_DIRECT_PICTURE_BACKDROP pixels=%zu\n", size_t(group->width) * group->height);
            return publish(std::move(direct_pixels));
        }
    }
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
    auto bytes = inset_picture_bytes(picture.get(), false);
    sk_sp<SkData> multisampled_bytes;
    if (!bytes) return 0;
    auto pixels = group->backdrop;
    auto draw = shared_picture_draw();
    auto rasterize = [&](auto& tile, long offset_x, long offset_y, bool multisampled,
        int x, int y, int width, int height) {
        if (multisampled && !multisampled_bytes)
            multisampled_bytes = inset_picture_bytes(picture.get(), true);
        auto const& selected = multisampled ? multisampled_bytes : bytes;
        if (!selected) return false;
        float translation[] {1, 0, float(offset_x), 0, 1, float(offset_y), 0, 0, 1};
        if (regional) {
            int result = draw_region(reinterpret_cast<uint8_t*>(tile.data()),
                s_msaa_grid_width, s_msaa_grid_height, width * 4,
                x, y, width, height, selected->data(), selected->size(), translation);
            if (result && std::getenv("VOX_PICTURE_REGION_DIAGNOSTICS"))
                std::fprintf(stderr, "VOX_PICTURE_REGION inset target=%dx%d region=%d,%d,%d,%d\n",
                    s_msaa_grid_width, s_msaa_grid_height, x, y, width, height);
            return result != 0;
        }
        return draw(reinterpret_cast<uint8_t*>(tile.data()), s_msaa_grid_width,
            s_msaa_grid_height, s_msaa_grid_width * 4, selected->data(), selected->size(), translation) != 0;
    };
    // Keep each original full-sized GPU tile and transfer only the intersection
    // consumed by the CPU compositor, including its border ownership texels.
    bool rendered = regional && draw_inset_picture_batch(*group, picture.get(), bytes,
        multisampled_bytes, pixels);
    if (std::getenv("VOX_DECORATION_BATCH_DIAGNOSTICS"))
        std::fprintf(stderr, "VOX_DECORATION_BATCH rendered=%d pixels=%zu size=%dx%d encoded=%zu\n",
            rendered, size_t(group->width) * group->height, group->width, group->height, bytes->size());
    if (!rendered) rendered = regional
        ? draw_chromium_root_raster_grid<true>(pixels, group->width, group->height,
            group->region, 0, group->page_y, group->scroll_y, group->scale, rasterize)
        : draw_chromium_root_raster_grid(pixels, group->width, group->height,
        group->region, 0, group->page_y, group->scroll_y, group->scale,
        [&](auto& tile, long offset_x, long offset_y, bool multisampled) {
            return rasterize(tile, offset_x, offset_y, multisampled,
                0, 0, s_msaa_grid_width, s_msaa_grid_height);
        });
    if (!rendered && !s_raster_layer_is_root) {
        rendered = regional
            ? draw_chromium_clipped_layer_raster_grid<true>(pixels, group->width, group->height,
                group->region, 0, group->page_y, group->scroll_y, group->scale,
                input->bounds, rasterize)
            : draw_chromium_clipped_layer_raster_grid(pixels, group->width, group->height,
                group->region, 0, group->page_y, group->scroll_y, group->scale,
                input->bounds, [&](auto& tile, long dx, long dy, bool msaa) {
                    return rasterize(tile, dx, dy, msaa,
                        0, 0, s_msaa_grid_width, s_msaa_grid_height);
                });
    }
    if (!rendered) {
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        if (!draw(reinterpret_cast<uint8_t*>(pixels.data()), group->width, group->height,
                group->width * 4, bytes->data(), bytes->size(), identity)) return 0;
    }
    return publish(std::move(pixels));
}

// A non-deferred legacy group already painted its fallback leaves. Only a
// rolled-back deferred transaction asks the V owner to replay the group.
extern "C" int ladybird_v_skia_end_deferred_inset_decorations(CGContextRef destination)
{
    if (!s_inset_decoration_recording || s_inset_decoration_recording->destination != destination) return 0;
    bool deferred = s_inset_decoration_recording->deferred;
    int result = ladybird_v_skia_end_inset_decorations(destination);
    return result || !deferred;
}
