#pragma once

extern "C" int ladybird_v_skia_draw_svg_cover_pattern(CGContextRef destination,
    VoxGraphitePath const* paths, int count, float const* outer, float const* tile,
    float const* clip, float page_x, float page_y, float scroll_y,
    float canvas_width, float canvas_height)
{
    static auto draw = [] {
        auto* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_svg_pattern_pixels)>(
            dlsym(library, "vox_graphite_draw_svg_pattern_pixels")) : nullptr;
    }();
    if (!s_chromium_painting || !destination || !draw || !paths || !outer || !tile || !clip
        || count <= 0 || count > 32768 || !(clip[2] > 0 && clip[3] > 0)) return 0;
    auto matrix = SkMatrix::MakeAll(outer[0], outer[2], page_x + outer[4],
        outer[1], outer[3], page_y - scroll_y + outer[5], 0, 0, 1);
    auto bounds = SkRect::MakeXYWH(clip[0],clip[1],clip[2],clip[3]);
    if (auto* canvas = shared_recording_canvas(destination)) {
        SkPictureRecorder recorder;
        auto tile_bounds = SkRect::MakeWH(tile[2],tile[3]);
        auto* inner = recorder.beginRecording(tile_bounds);
        if (!record_chromium_svg_path_batch(inner,paths,count,SkMatrix::I(),tile_bounds,nullptr)) {
            shared_recording_block(matrix.mapRect(bounds));
        } else {
            auto picture = recorder.finishRecordingAsPicture();
            auto phase = SkMatrix::Translate(tile[0],tile[1]);
            auto shader = picture->makeShader(SkTileMode::kRepeat,SkTileMode::kRepeat,
                SkFilterMode::kLinear,&phase,&tile_bounds);
            if (!shader) shared_recording_block(matrix.mapRect(bounds));
            else {
                canvas->save();
                shared_recording_clip(destination,canvas);
                canvas->setMatrix(matrix);
                canvas->clipRect(bounds,true);
                SkPaint paint;
                paint.setAntiAlias(true);
                paint.setShader(std::move(shader));
                canvas->drawRect(bounds,paint);
                canvas->restore();
                shared_recording_content(destination,matrix.mapRect(bounds),page_y,scroll_y);
            }
        }
    }
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(bounds),canvas_width,canvas_height,0,region)) return 1;
    float scale = raster_scale_for_context(destination);
    int width = raster_dimension(region.width(),scale), height = raster_dimension(region.height(),scale);
    if (width <= 0 || height <= 0 || size_t(width) * height > 8 * 1024 * 1024) return 0;
    std::vector<uint32_t> pixels(size_t(width) * height);
    bool background = copy_backdrop(destination,region,scale,width,height,pixels);
    auto parent = raster_matrix(matrix,region,float(width)/region.width(),float(height)/region.height());
    bool drawn = false;
    if (background && s_msaa_grid_columns > 0) {
        drawn = draw_chromium_layer_raster_grid(pixels,width,height,region,
            page_x,page_y,scroll_y,scale,[&](auto& target,long dx,long dy,bool) {
                auto placed = parent;
                placed.postTranslate(dx,dy);
                float values[9]; placed.get9(values);
                return draw(reinterpret_cast<uint8_t*>(target.data()),s_msaa_grid_width,
                    s_msaa_grid_height,s_msaa_grid_width*4,1,paths,count,values,tile,clip,1,1) != 0;
            });
    }
    if (!drawn) {
        float values[9]; parent.get9(values);
        drawn = draw(reinterpret_cast<uint8_t*>(pixels.data()),width,height,width*4,
            background,paths,count,values,tile,clip,1,1) != 0;
    }
    if (!drawn) return 0;
    return composite_pixels(destination,std::move(pixels),width,height,region.left,
        canvas_height-region.bottom,region.width(),region.height(),background);
}
