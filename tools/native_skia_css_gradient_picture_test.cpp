// CSS generated-image tiles dither once, inside the retained image picture.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static void css_gradient_picture(int scale, bool pattern, bool background)
{
    constexpr int width = 256, height = 256;
    constexpr float x = 10.25f, y = 20.5f, w = 183.5f, h = 157.25f;
    int pitch = width * scale * 4;
    std::vector<uint8_t> actual(size_t(pitch) * height * scale), expected(actual);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make = [&](auto& pixels) {
        auto context = CGBitmapContextCreate(pixels.data(), width * scale, height * scale,
            8, pitch, space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(context);
        CGContextScaleCTM(context, scale, scale);
        return context;
    };
    auto destination = make(actual), control = make(expected);
    CGColorSpaceRelease(space);
    float segments[] {
        0,x,y,0,0,0,0,0,0,0,0,0,
        1,x+w,y,0,0,0,0,0,0,0,0,0,
        1,x+w,y+h,0,0,0,0,0,0,0,0,0,
        1,x,y+h,0,0,0,0,0,0,0,0,0,
        5,0,0,0,0,0,0,0,0,0,0,0,
    };
    float stops[] {186.f/255,213.f/255,246.f/255,160.f/255,0,
                   186.f/255,213.f/255,246.f/255,0,1};
    float clip[] {x,y,w,h,7,7,7,7,7,7,7,7};
    ladybird_v_skia_set_shared_recording(0, width, height);
    ladybird_v_skia_set_raster_layer(0, 0, 0);
    ladybird_v_skia_set_raster_layer_size(width, height);
    int cell = 0;
    ladybird_v_skia_set_msaa_grid(&cell, 1, 258 * scale, 258 * scale, 1);
    ladybird_v_skia_set_layer_shared_recording(1);
    if (background)
        ladybird_v_skia_record_rect(destination,0,0,width,height,9,11,15,255);
    assert(ladybird_v_skia_draw_clipped_svg_linear_gradient_path(destination, segments, 5, 0,
        1,0,0,1,0,0,0,0,0,width,height,0,0,0,0,4,
        0,0,w,h,1,0,0,1,x,y,pattern ? 3 : 4,0,stops,2,1,0,clip,nullptr));
    assert(s_shared_root_recording);
    float outside[5 * 12];
    std::copy_n(segments,5 * 12,outside);
    for (int index=0;index<4;++index) outside[index*12+1] += w+1;
    assert(ladybird_v_skia_draw_clipped_svg_linear_gradient_path(destination, outside, 5, 0,
        1,0,0,1,0,0,0,0,0,width,height,0,0,0,0,4,
        0,0,w,h,1,0,0,1,x+w+1,y,pattern ? 3 : 4,0,stops,2,1,0,clip,nullptr));
    for (auto const& bounds : s_shared_root_recording->replay_bounds)
        assert(bounds.left() >= x && bounds.top() >= y && bounds.right() <= x+w && bounds.bottom() <= y+h);
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_layer_shared_recording(0);

    // Assemble the independent complete picture using CSS's premultiplied
    // shader and an undithered outer paint for a generated-image pattern.
    SkColor4f colors[] {{186.f/255,213.f/255,246.f/255,160.f/255},
                       {186.f/255,213.f/255,246.f/255,0}};
    float positions[] {0,1};
    SkPoint points[] {{0,0},{w,h}};
    SkGradientShader::Interpolation interpolation;
    interpolation.fInPremul = SkGradientShader::Interpolation::InPremul::kYes;
    auto placement = SkMatrix::Translate(x,y);
    auto shader = SkGradientShader::MakeLinear(points, colors, nullptr, positions,
        2, SkTileMode::kClamp, interpolation, pattern ? nullptr : &placement);
    assert(shader);
    if (pattern) {
        SkPictureRecorder tile_recorder;
        auto tile = SkRect::MakeWH(w,h);
        auto* tile_canvas = tile_recorder.beginRecording(tile);
        SkPaint inner;
        inner.setAntiAlias(true);
        inner.setDither(true);
        inner.setShader(shader);
        tile_canvas->drawRect(tile, inner);
        shader = tile_recorder.finishRecordingAsPicture()->makeShader(
            SkTileMode::kRepeat, SkTileMode::kRepeat, SkFilterMode::kLinear, &placement, &tile);
    }
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(width,height));
    canvas->clear(background ? SkColorSetRGB(9,11,15) : SK_ColorTRANSPARENT);
    canvas->clipRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(x,y,w,h),7,7),true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setDither(!pattern);
    paint.setShader(std::move(shader));
    canvas->drawRect(SkRect::MakeXYWH(x,y,w,h),paint);
    auto bytes = recorder.finishRecordingAsPicture()->serialize();
    std::vector<uint32_t> pixels(size_t(width) * height * scale * scale);
    float matrix[] {float(scale),0,0,0,float(scale),0,0,0,1};
    assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()),
        width*scale,height*scale,pitch,bytes->data(),bytes->size(),matrix));
    composite_pixels(control,std::move(pixels),width*scale,height*scale,0,0,width,height,true);
    CGContextFlush(destination);
    CGContextFlush(control);
    if (actual != expected) {
        size_t differences = 0;
        for (size_t index=0;index<actual.size();++index) differences += actual[index]!=expected[index];
        std::fprintf(stderr,"CSS picture mismatch scale=%d pattern=%d background=%d channels=%zu\n",
            scale,pattern,background,differences);
    }
    assert(actual == expected);
    CGContextRelease(destination);
    CGContextRelease(control);
}

int main()
{
    assert(shared_picture_draw());
    ladybird_v_skia_set_chromium_painting(1);
    for (int scale : {1,2}) for (bool pattern : {false,true}) for (bool background : {false,true})
        css_gradient_picture(scale,pattern,background);
    ladybird_v_skia_set_chromium_painting(0);
    std::puts("8 CSS direct/pattern compositor pictures match independent complete GPU pictures");
}
