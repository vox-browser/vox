// Golden control points and paint sequence captured from normal Brave's
// ChatGPT composer layer. Keep independent of our superellipse implementation.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>
static SkPath brave_outer()
{
    SkPathBuilder path;
    path.moveTo(726.0f, 72.0f);
    path.lineTo(726.0f, 72.0f);
    path.cubicTo(730.726806640625f, 72.0f, 738.606750488281f, 72.9738616943359f, 744.816467285156f, 79.1835403442383f);
    path.cubicTo(751.026123046875f, 85.3932189941406f, 752.0f, 93.2731781005859f, 752.0f, 98.0f);
    path.lineTo(752.0f, 98.0f);
    path.cubicTo(752.0f, 102.726821899414f, 751.026123046875f, 110.606781005859f, 744.816467285156f, 116.816459655762f);
    path.cubicTo(738.606750488281f, 123.026138305664f, 730.726806640625f, 124.0f, 726.0f, 124.0f);
    path.lineTo(38.0f, 124.0f);
    path.cubicTo(33.2731781005859f, 124.0f, 25.3932189941406f, 123.026138305664f, 19.1835422515869f, 116.816459655762f);
    path.cubicTo(12.9738636016846f, 110.606781005859f, 12.0f, 102.726821899414f, 12.0f, 98.0f);
    path.lineTo(12.0f, 98.0f);
    path.cubicTo(12.0f, 93.2731781005859f, 12.9738636016846f, 85.3932189941406f, 19.1835422515869f, 79.1835403442383f);
    path.cubicTo(25.3932189941406f, 72.9738616943359f, 33.2731781005859f, 72.0f, 38.0f, 72.0f);
    path.close();
    return path.detach();
}
static SkPath brave_inner()
{
    SkPathBuilder path;
    path.moveTo(38.0f, 73.0f);
    path.lineTo(726.0f, 73.0f);
    path.cubicTo(730.545043945313f, 73.0f, 738.121887207031f, 73.936408996582f, 744.0927734375f, 79.9072494506836f);
    path.cubicTo(750.063598632813f, 85.8780975341797f, 751.0f, 93.4549789428711f, 751.0f, 98.0f);
    path.cubicTo(751.0f, 102.545021057129f, 750.063598632813f, 110.12190246582f, 744.0927734375f, 116.092750549316f);
    path.cubicTo(738.121887207031f, 122.063591003418f, 730.545043945313f, 123.0f, 726.0f, 123.0f);
    path.lineTo(38.0f, 123.0f);
    path.cubicTo(33.4549789428711f, 123.0f, 25.8780956268311f, 122.063591003418f, 19.9072513580322f, 116.092750549316f);
    path.cubicTo(13.9364070892334f, 110.12190246582f, 13.0f, 102.545021057129f, 13.0f, 98.0f);
    path.cubicTo(13.0f, 93.4549789428711f, 13.9364070892334f, 85.8780975341797f, 19.9072513580322f, 79.9072494506836f);
    path.cubicTo(25.8780956268311f, 73.936408996582f, 33.4549789428711f, 73.0f, 38.0f, 73.0f);
    path.close();
    return path.detach();
}

int main()
{
    assert(shared_picture_draw());
    int cases = 0;
    for (int scale : {1, 2}) for (bool recording : {false, true})
    for (bool msaa : {false,true}) for (int alpha : {26,38,128}) {
        int width = 800 * scale, height = 160 * scale, tile_height = 256 * scale;
        std::vector<uint8_t> actual(size_t(width) * height * 4, 252);
        for (size_t i=3;i<actual.size();i+=4) actual[i]=255;
        auto space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context=CGBitmapContextCreate(actual.data(),width,height,8,width*4,space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast)|kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space);assert(context);
        CGContextScaleCTM(context,scale,scale);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_raster_layer(0,0,1);
        ladybird_v_skia_set_raster_layer_size(800,160);
        int tile=0;ladybird_v_skia_set_msaa_grid(msaa?&tile:nullptr,msaa?1:0,width,tile_height,1);
        ladybird_v_skia_set_shared_recording(recording,800,160);
        float target[] {12.5,72.5,739,51,25.5,25.5,25.5,25.5,25.5,25.5,25.5,25.5};
        float background[] {13,73,738,50,25,25,25,25,25,25,25,25};
        float shapes[] {1.1,1.1,1.1,1.1}, affine[] {1,0,0,1,0,0};
        if(msaa) {
            // A real unfiltered contour selects the parent pass's MSAA mode.
            // Its opaque color equals the backdrop, leaving reference pixels.
            float producer[] {4,4,10,10,5,5,5,5,5,5,5,5};
            assert(ladybird_v_skia_draw_contoured_box(context,producer,shapes,nullptr,
                affine,0,0,0,800,160,252,252,252,255,2,0,1));
        }
        float reference[] {12,72,740,52,26,26,26,26,26,26,26,26};
        ladybird_v_skia_set_contoured_box_reference(reference);
        ladybird_v_skia_set_rounded_rect_underlay(background,255,255,255,255);
        assert(ladybird_v_skia_draw_contoured_box(context,target,shapes,nullptr,
            affine,0,0,0,800,160,0,0,0,alpha,1,1,1));
        assert(!s_has_contoured_box_reference);
        ladybird_v_skia_finish_shared_recording();CGContextFlush(context);

        SkPictureRecorder recorder;
        auto* canvas=recorder.beginRecording(SkRect::MakeWH(width,tile_height));
        canvas->clear(SkColorSetRGB(252,252,252));canvas->scale(scale,scale);
        if(msaa) {
            SkPathBuilder producer;producer.moveTo(4,4);
            producer.cubicTo(14,4,4,14,14,14).lineTo(9,6).close();
            SkPaint ink;ink.setAntiAlias(true);ink.setColor(SkColorSetRGB(252,252,252));
            canvas->drawPath(producer.detach(),ink);
        }
        canvas->save();canvas->clipPath(brave_outer(),SkClipOp::kIntersect,true);
        canvas->saveLayer(nullptr,nullptr);
        SkPaint paint;paint.setAntiAlias(true);paint.setColor(SK_ColorWHITE);
        canvas->save();canvas->clipPath(brave_inner(),SkClipOp::kIntersect,true);
        canvas->drawRect(SkRect::MakeLTRB(12,72,752,124),paint);canvas->restore();
        canvas->clipPath(brave_inner(),SkClipOp::kDifference,true);
        SkPaint opacity;opacity.setAlpha(alpha);canvas->saveLayer(nullptr,&opacity);
        paint.setColor(SK_ColorBLACK);
        // Blink draws the four border sides through hard trapezoid clips.
        for (auto points : {std::array<SkPoint,4>{{{12,72},{25.5,85.5},{738.5,85.5},{752,72}}},
                std::array<SkPoint,4>{{{12,124},{25.5,110.5},{738.5,110.5},{752,124}}},
                std::array<SkPoint,4>{{{12,72},{25.5,85.5},{25.5,110.5},{12,124}}},
                std::array<SkPoint,4>{{{752,72},{738.5,85.5},{738.5,110.5},{752,124}}}}) {
            SkPathBuilder side;side.addPolygon(points,false);
            canvas->save();canvas->clipPath(side.detach(),SkClipOp::kIntersect,false);
            canvas->drawRect(SkRect::MakeLTRB(12,72,752,124),paint);canvas->restore();
        }
        canvas->restore();canvas->restore();canvas->restore();
        auto bytes=recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint8_t> expected(size_t(width)*tile_height*4);
        float identity[] {1,0,0,0,1,0,0,0,1};
        assert(shared_picture_draw()(expected.data(),width,tile_height,width*4,
            bytes->data(),bytes->size(),identity));expected.resize(actual.size());
        size_t differences=0;int maximum=0;
        for (size_t i=0;i<actual.size();++i) if(actual[i]!=expected[i]) {
            ++differences;maximum=std::max(maximum,std::abs(int(actual[i])-int(expected[i])));
        }
        if(differences)std::fprintf(stderr,"scale=%d recording=%d msaa=%d alpha=%d: %zu channels, max %d\n",
            scale,recording,msaa,alpha,differences,maximum);
        assert(actual==expected);
        CGContextRelease(context);ladybird_v_skia_set_shared_recording(0,0,0);++cases;
    }
    std::printf("Contoured border: %d exact Brave picture/native cases passed\n",cases);
}
