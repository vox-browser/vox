#pragma once
#include "native_chromium_superellipse.h"

static bool s_has_contoured_box_reference=false;
static float s_contoured_box_reference[12];
extern "C" void ladybird_v_skia_set_contoured_box_reference(float const* reference)
{
    s_has_contoured_box_reference=reference!=nullptr;
    if(reference)std::copy_n(reference,12,s_contoured_box_reference);
}

// mode: 0 solid background, 1 uniform border (center rectangle), 2 outer shadow.
extern "C" int ladybird_v_skia_draw_contoured_box(CGContextRef destination,
    float const* target_data, float const* parameters, float const* cutout_data,
    float const* affine, float page_x, float page_y, float scroll_y,
    float canvas_width, float canvas_height, uint8_t red, uint8_t green,
    uint8_t blue, uint8_t alpha, int mode, float amount, int opaque_backdrop)
{
    bool has_reference=s_has_contoured_box_reference;
    s_has_contoured_box_reference=false;
    bool precise = s_has_unrounded_paint_color;
    s_has_unrounded_paint_color = false;
    bool has_background_fill = mode == 1 && s_has_rounded_rect_underlay;
    s_has_rounded_rect_underlay = false;
    bool precise_background = has_background_fill && s_has_float_underlay_color;
    s_has_float_underlay_color = false;
    if (!s_chromium_painting || !destination || !target_data || !parameters || !affine
        || !shared_picture_draw() || mode < 0 || mode > 2) return 0;
    auto target = rounded_rect_from_data(target_data);
    if (target.isEmpty()) return 1;
    std::array<float,4> shapes;
    std::copy_n(parameters,4,shapes.begin());
    if(std::any_of(shapes.begin(),shapes.end(),[](float k){return k<0;}))return 0;
    auto matrix = SkMatrix::MakeAll(affine[0],affine[2],page_x+affine[4],
        affine[1],affine[3],page_y-scroll_y+affine[5],0,0,1);
    auto outside = target, inside = target;
    if (mode == 1) {
        target.outset(amount/2,amount/2,&outside);
        target.inset(amount/2,amount/2,&inside);
    }
    auto reference=has_reference?rounded_rect_from_data(s_contoured_box_reference):outside;
    auto cutout = cutout_data ? rounded_rect_from_data(cutout_data) : SkRRect{};
    auto background = has_background_fill ? rounded_rect_from_data(s_rounded_rect_underlay) : SkRRect{};
    auto bounds = outside.rect();
    if (mode == 2) bounds.outset(std::max(amount,0.f)*2+2,std::max(amount,0.f)*2+2);
    // The fallback bitmap keeps a conservative blur margin. Picture overflow
    // uses Chromium's three-sigma extent (CSS blur is twice sigma), matching
    // the compositor layer's bounds. Keep these bounds in document space;
    // the draw paths below are shifted to the layer's local raster origin.
    auto recording_bounds=outside.rect();
    if (mode == 2) {
        float extent=std::ceil(std::max(amount,0.f)*1.5f);
        recording_bounds.outset(extent,extent);
    }
    SkPaint paint; paint.setAntiAlias(true); paint.setColor(SkColorSetARGB(alpha,red,green,blue));
    if (precise) paint.setColor4f({s_unrounded_paint_color[0],s_unrounded_paint_color[1],
        s_unrounded_paint_color[2],s_unrounded_paint_color[3]});
    SkPaint background_paint; background_paint.setAntiAlias(true);
    if (has_background_fill) {
        background_paint.setColor(SkColorSetARGB(s_rounded_rect_underlay_rgba[3],
            s_rounded_rect_underlay_rgba[0],s_rounded_rect_underlay_rgba[1],s_rounded_rect_underlay_rgba[2]));
        if (precise_background) background_paint.setColor4f({s_underlay_float_color[0],
            s_underlay_float_color[1],s_underlay_float_color[2],s_underlay_float_color[3]});
    }
    SkPoint source_origin {0,0};
    if (!s_raster_layer_is_root) {
        SkMatrix inverse;
        if (matrix.invert(&inverse))
            source_origin=inverse.mapPoint(SkPoint::Make(page_x+s_raster_origin_x,page_y-scroll_y+s_raster_origin_y));
    }
    outside.offset(-source_origin.x(),-source_origin.y());
    inside.offset(-source_origin.x(),-source_origin.y());
    target.offset(-source_origin.x(),-source_origin.y());
    cutout.offset(-source_origin.x(),-source_origin.y());
    background.offset(-source_origin.x(),-source_origin.y());
    reference.offset(-source_origin.x(),-source_origin.y());
    auto draw = [&](SkCanvas* canvas, SkMatrix transform) {
        transform.preTranslate(source_origin.x(),source_origin.y());
        canvas->save();canvas->setMatrix(transform);
        if (mode == 2) {
            canvas->clipPath(vox_chromium_superellipse_path(cutout,shapes,has_reference?&reference:nullptr),SkClipOp::kDifference,true);
            auto shadow_paint=paint;
            // Match DrawLooper's opaque source and CSS color filter.
            shadow_paint.setColor(SK_ColorBLACK);
            shadow_paint.setColorFilter(SkColorFilters::Blend(paint.getColor4f(),
                SkColorSpace::MakeSRGB(),SkBlendMode::kSrcIn));
            shadow_paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle,std::max(amount,0.f)/2));
            auto shadow=target;
            float offset_x=has_reference?target.rect().centerX()-reference.rect().centerX():0;
            float offset_y=has_reference?target.rect().centerY()-reference.rect().centerY():0;
            shadow.offset(-offset_x,-offset_y);
            canvas->save();canvas->translate(offset_x,offset_y);
            canvas->drawPath(vox_chromium_superellipse_path(shadow,shapes,
                has_reference?&reference:nullptr),shadow_paint);
            canvas->restore();
        } else if (mode == 0) {
            canvas->drawPath(vox_chromium_superellipse_path(target,shapes,has_reference?&reference:nullptr),paint);
        } else {
            canvas->clipPath(vox_chromium_superellipse_path(outside,shapes),SkClipOp::kIntersect,true);
            canvas->saveLayer(nullptr,nullptr);
            if (has_background_fill) {
                canvas->save();
                if (background != outside)
                    canvas->clipPath(vox_chromium_superellipse_path(background,shapes,&outside),SkClipOp::kIntersect,true);
                canvas->drawRect(outside.rect(),background_paint);canvas->restore();
            }
            canvas->clipPath(vox_chromium_superellipse_path(inside,shapes,&outside),SkClipOp::kDifference,true);
            SkPaint opacity;opacity.setAlphaf(paint.getAlphaf());
            canvas->saveLayer(nullptr,&opacity);
            auto solid=paint;solid.setAlphaf(1);
            if(std::all_of(shapes.begin(),shapes.end(),[](float k){return k>=1;})) {
                auto box=outside.rect();SkPoint join[4];
                for(int i=0;i<4;++i) {
                    auto r=outside.radii(static_cast<SkRRect::Corner>(i));
                    join[i]={(i==0||i==3)?box.left()+(r.x()+amount)/2:box.right()-(r.x()+amount)/2,
                        i<2?box.top()+(r.y()+amount)/2:box.bottom()-(r.y()+amount)/2};
                }
                SkPoint tl{box.left(),box.top()},tr{box.right(),box.top()};
                SkPoint br{box.right(),box.bottom()},bl{box.left(),box.bottom()};
                for(auto side:{std::array<SkPoint,4>{tl,join[0],join[1],tr},
                        std::array<SkPoint,4>{bl,join[3],join[2],br},
                        std::array<SkPoint,4>{tr,join[1],join[2],br},
                        std::array<SkPoint,4>{tl,join[0],join[3],bl}}) {
                    SkPathBuilder clip;clip.addPolygon(side,false);
                    canvas->save();canvas->clipPath(clip.detach(),SkClipOp::kIntersect,false);
                    canvas->drawRect(box,solid);canvas->restore();
                }
            } else canvas->drawRect(outside.rect(),solid);
            canvas->restore();canvas->restore();
        }
        canvas->restore();
    };
    if (auto* canvas=shared_recording_canvas(destination)) {
        canvas->save();shared_recording_clip(destination,canvas);draw(canvas,matrix);canvas->restore();
        shared_recording_content(destination,matrix.mapRect(recording_bounds),page_y,scroll_y);
        // A complete isolated-layer picture will rasterize this contour. The
        // shared guard also protects clips, blocked content and publication
        // bounds; failed publication requests an ordinary frame replay.
        auto* disabled=std::getenv("VOX_DISABLE_CONTOURED_LEAF_DEFER");
        // A shadow's mask blur paints nothing beyond its three-sigma extent,
        // which is exactly what the picture records and publishes. The wider
        // fallback margin only sizes the immediate bitmap and must not keep a
        // blurred leaf out of its layer, including when it overflows the box.
        auto* wide=std::getenv("VOX_DEFER_CONTOURED_SHADOWS_BY_FALLBACK_MARGIN");
        auto deferred_ink=mode==2 && !(wide && *wide) ? matrix.mapRect(recording_bounds)
            : matrix.mapRect(bounds).makeOutset(2,2);
        bool deferred=!(disabled && *disabled)
            && shared_recording_defers_leaf_raster(destination,deferred_ink);
        auto* diagnostics=std::getenv("VOX_CONTOURED_LEAF_DIAGNOSTICS");
        if (diagnostics && *diagnostics)
            std::fprintf(stderr,"VOX_CONTOURED_LEAF mode=%d deferred=%d\n",mode,int(deferred));
        if (deferred) return 1;
    }
    RasterRegion region;
    if (!clipped_raster_region(matrix.mapRect(bounds),canvas_width,canvas_height,2,region)) return 1;
    float scale=raster_scale_for_context(destination);
    int width=raster_dimension(region.width(),scale),height=raster_dimension(region.height(),scale);
    if (width <= 0 || height <= 0 || size_t(width)*height>8*1024*1024) {
        shared_recording_block(matrix.mapRect(bounds));
        return 0;
    }
    std::vector<uint32_t> pixels(size_t(width)*height);
    bool backdrop=s_raster_layer_is_root&&opaque_backdrop
        &&copy_backdrop(destination,region,scale,width,height,pixels);
    auto render=[&](auto& output,int w,int h,long dx,long dy,bool msaa) {
        SkPictureRecorder recorder;auto* canvas=recorder.beginRecording(SkRect::MakeWH(w,h));
        if (backdrop) {
            auto info=SkImageInfo::Make(w,h,kBGRA_8888_SkColorType,kPremul_SkAlphaType,SkColorSpace::MakeSRGB());
            auto image=SkImages::RasterFromPixmapCopy(SkPixmap(info,output.data(),size_t(w)*4));
            if (!image) return false;canvas->drawImage(image,0,0);
        }
        if (msaa) {
            SkPaint noop;noop.setAntiAlias(true);
            noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
            SkPathBuilder trigger;trigger.moveTo(0,0);
            trigger.cubicTo(.01f,.001f,0,.01f,.01f,.01f).lineTo(.005f,.002f).close();
            canvas->drawPath(trigger.detach(),noop);
        }
        auto transform=raster_matrix(matrix,region,float(width)/region.width(),float(height)/region.height());
        transform.postTranslate(dx,dy);draw(canvas,transform);
        SkSerialProcs procs;procs.fImageProc=serialize_shared_picture_image;
        auto bytes=recorder.finishRecordingAsPicture()->serialize(&procs);
        float identity[]={1,0,0,0,1,0,0,0,1};
        return bytes&&shared_picture_draw()(reinterpret_cast<uint8_t*>(output.data()),
            w,h,w*4,bytes->data(),bytes->size(),identity);
    };
    bool painted=backdrop&&draw_chromium_root_raster_grid(pixels,width,height,region,
        page_x,page_y,scroll_y,scale,[&](auto& tile,long dx,long dy,bool msaa){
            return render(tile,s_msaa_grid_width,s_msaa_grid_height,dx,dy,msaa);});
    if (!painted) painted=render(pixels,width,height,0,0,false);
    if (!painted) { shared_recording_block(matrix.mapRect(bounds)); return 0; }
    int result = composite_pixels(destination,std::move(pixels),width,height,
        region.left,canvas_height-region.bottom,region.width(),region.height(),backdrop);
    if (!result) shared_recording_block(matrix.mapRect(bounds));
    return result;
}
