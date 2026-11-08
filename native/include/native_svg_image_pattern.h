#pragma once

// Keep an embedded raster image inside the pattern's paint record. A bitmap
// tile sampled a second time by Quartz loses the final SVG viewport's phase.
extern "C" int ladybird_v_skia_draw_svg_image_pattern(CGContextRef destination,
    uint8_t const* source_pixels, int image_width, int image_height, int pitch, int flags,
    float const* path_data, int count, int even_odd, float const* outer,
    float const* inner, float const* tile, float const* target, float const* clip,
    float page_x, float page_y, float scroll_y, float canvas_width,
    float canvas_height, float opacity, int nearest)
{
    if (!s_chromium_painting || !destination || !source_pixels || !path_data
        || !outer || !inner || !tile || !target || !clip || count <= 0 || count > 32768
        || image_width <= 0 || image_height <= 0 || image_width > 16384
        || image_height > 16384 || pitch < image_width * 4 || (flags & (4 | 64 | 128))
        || size_t(image_width) * image_height > 8 * 1024 * 1024
        || !(tile[2] > 0 && tile[3] > 0) || !(target[2] > 0 && target[3] > 0)
        || !(clip[2] > 0 && clip[3] > 0) || !(canvas_width > 0 && canvas_height > 0)
        || canvas_width > 16384 || canvas_height > 16384
        || !std::isfinite(opacity)) return 0;
    for (int i = 0; i < 6; ++i)
        if (!std::isfinite(outer[i]) || !std::isfinite(inner[i])) return 0;
    for (int i = 0; i < 4; ++i)
        if (!std::isfinite(tile[i]) || !std::isfinite(target[i]) || !std::isfinite(clip[i])) return 0;
    auto matrix = SkMatrix::MakeAll(outer[0], outer[2], page_x + outer[4],
        outer[1], outer[3], page_y - scroll_y + outer[5], 0, 0, 1);
    auto content = SkMatrix::MakeAll(inner[0], inner[2], inner[4],
        inner[1], inner[3], inner[5], 0, 0, 1);
    float scale = raster_scale_for_context(destination);
    auto effective = matrix * content;
    float sx = std::hypot(effective.getScaleX(), effective.getSkewY()) * scale
        * target[2] / image_width;
    float sy = std::hypot(effective.getSkewX(), effective.getScaleY()) * scale
        * target[3] / image_height;
    if (!(sx > 0 && sy > 0) || !std::isfinite(sx) || !std::isfinite(sy)) return 0;
    // A pattern's embedded bitmap is an ordinary decoded resource. Reuse a
    // compatible larger upload just as direct image draws do; independently
    // downsizing every pattern instance changes its filtered texels.
    VoxGraphiteImage decode {};
    decode.width = image_width; decode.height = image_height; decode.pitch = pitch;
    decode.flags = flags; decode.pixels = source_pixels; decode.nearest = nearest != 0;
    decode.source[2] = image_width; decode.source[3] = image_height;
    std::copy_n(target, 4, decode.destination);
    decode.has_color_profile = s_has_image_color_profile;
    std::copy_n(s_image_color_profile, VOX_IMAGE_COLOR_PROFILE_VALUES, decode.color_profile);
    retain_compatible_image_decode(decode, effective, scale);
    int upload_width = image_width, upload_height = image_height;
    int selected_level = vox_image_decode_level(decode.flags);
    if (selected_level >= 0) {
        upload_width = vox_image_decode_axis(image_width, selected_level);
        upload_height = vox_image_decode_axis(image_height, selected_level);
    } else if (!nearest) for (int level = 1; level < 31; ++level) {
        int w = vox_image_decode_axis(image_width, level), h = vox_image_decode_axis(image_height, level);
        if (w < std::ceil(image_width * sx) || h < std::ceil(image_height * sy)) break;
        upload_width = w; upload_height = h;
    }
    auto info = SkImageInfo::Make(image_width, image_height, kRGBA_8888_SkColorType,
        (flags & 1) ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, image_color_space());
    SkPixmap source(info, source_pixels, pitch);
    auto converted_info = info.makeAlphaType(kPremul_SkAlphaType).makeColorSpace(SkColorSpace::MakeSRGB());
    std::vector<uint8_t> converted(size_t(image_width) * image_height * 4);
    if (!source.readPixels(converted_info, converted.data(), image_width * 4)) return 0;
    source = SkPixmap(converted_info, converted.data(), image_width * 4);
    std::vector<uint8_t> resized;
    if (upload_width != image_width || upload_height != image_height) {
        resized.resize(size_t(upload_width) * upload_height * 4);
        auto resize = graphite_image_resize();
        VoxGraphiteImage input{};
        input.width = image_width; input.height = image_height; input.pitch = image_width * 4;
        input.flags = 1; input.pixels = converted.data();
        if (!resize || !resize(&input, resized.data(), upload_width, upload_height, upload_width * 4)) return 0;
        source = SkPixmap(converted_info.makeWH(upload_width, upload_height), resized.data(), upload_width * 4);
    }
    auto bitmap = SkImages::RasterFromPixmapCopy(source);
    if (!bitmap) return 0;
    bool mips = !nearest && image_width * sx < upload_width && image_height * sy < upload_height;
    SkPictureRecorder tile_recording;
    auto bounds = SkRect::MakeWH(tile[2], tile[3]);
    auto* tile_canvas = tile_recording.beginRecording(bounds);
    tile_canvas->setMatrix(content);
    auto rect = [](float const* r) { return SkRect::MakeXYWH(r[0], r[1], r[2], r[3]); };
    if (rect(clip) != rect(target)) tile_canvas->clipRect(rect(clip), true);
    tile_canvas->concat(SkMatrix::RectToRect(SkRect::MakeWH(upload_width, upload_height), rect(target)));
    tile_canvas->drawImage(bitmap, 0, 0, SkSamplingOptions(nearest ? SkFilterMode::kNearest : SkFilterMode::kLinear,
        mips ? SkMipmapMode::kLinear : SkMipmapMode::kNone));
    auto picture = tile_recording.finishRecordingAsPicture();
    auto phase = SkMatrix::Translate(tile[0], tile[1]);
    auto shader = picture->makeShader(SkTileMode::kRepeat, SkTileMode::kRepeat,
        SkFilterMode::kLinear, &phase, &bounds);
    if (!shader) return 0;
    auto path = path_from_serialized_segments(path_data, count);
    path.setFillType(even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    SkPaint paint;
    paint.setAntiAlias(true); paint.setAlphaf(std::clamp(opacity, 0.f, 1.f)); paint.setShader(shader);
    auto draw = shared_picture_draw();
    int width = raster_dimension(canvas_width, scale), height = raster_dimension(canvas_height, scale);
    if (!draw || width <= 0 || height <= 0 || size_t(width) * height > 8 * 1024 * 1024) return 0;
    RasterRegion region{0, 0, int(std::ceil(canvas_width)), int(std::ceil(canvas_height))};
    std::vector<uint32_t> pixels(size_t(width) * height);
    if (!copy_backdrop(destination, region, scale, width, height, pixels)) return 0;
    auto output_info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto backdrop = SkImages::RasterFromPixmapCopy(SkPixmap(output_info, pixels.data(), width * 4));
    if (!backdrop) return 0;
    SkPictureRecorder output;
    auto* canvas = output.beginRecording(SkRect::MakeWH(width, height));
    canvas->drawImage(backdrop, 0, 0);
    canvas->setMatrix(SkMatrix::Scale(scale, scale) * matrix);
    canvas->drawPath(path, paint);
    SkSerialProcs procs;
    procs.fImageProc = [](SkImage* image, void*) { return vox_encode_picture_image(image); };
    auto bytes = output.finishRecordingAsPicture()->serialize(&procs);
    float identity[]{1,0,0,0,1,0,0,0,1};
    if (!bytes || !draw(reinterpret_cast<uint8_t*>(pixels.data()), width, height,
            width * 4, bytes->data(), bytes->size(), identity)) return 0;
    if (!composite_pixels(destination, std::move(pixels), width, height,
            0, canvas_height - region.bottom, canvas_width, canvas_height, true)) return 0;
    if (auto* retained = shared_recording_canvas(destination)) {
        retained->save(); shared_recording_clip(destination, retained);
        retained->setMatrix(matrix); retained->drawPath(path, paint); retained->restore();
        shared_recording_content(destination, matrix.mapRect(path.getBounds()), page_y, scroll_y);
    }
    return 1;
}
