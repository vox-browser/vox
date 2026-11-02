// Isolated inputs own their coordinate system even without a root picture,
// or while another destination has a root recording open.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    constexpr int width = 128, height = 96;
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    ladybird_v_skia_set_chromium_painting(1);
    assert(shared_picture_draw());
    for (int scale : {1, 2}) for (bool unrelated_root : {false, true}) {
        std::vector<uint8_t> storage(width * height * scale * scale * 4);
        auto destination = CGBitmapContextCreate(storage.data(), width * scale,
            height * scale, 8, width * scale * 4, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(destination);
        CGContextScaleCTM(destination, scale, scale);
        ladybird_v_skia_set_shared_recording(0, width, height);
        auto other = CGBitmapContextCreate(nullptr, 64, 211, 8, 64 * 4, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(other);
        if (unrelated_root) {
            ladybird_v_skia_set_raster_layer(0, 0, 1);
            ladybird_v_skia_set_shared_recording(1, 64, 211);
            assert(shared_recording_canvas(other));
        } else assert(!s_shared_root_recording);
        assert(ladybird_v_skia_begin_isolated_input(destination, width, height));
        ladybird_v_skia_record_rect(destination, 11.25, 17.5, 34.5, 9.25, 70, 127, 194, 201);
        ladybird_v_skia_record_caret(destination, 6, 11, 1, 14, 40, 60, 80, 137);
        uint8_t pixels[] {13,27,81,255, 172,203,64,255, 90,40,12,255, 11,180,131,255};
        VoxGraphiteImage image {
            .matrix = {1,0,0,0,1,0,0,0,1}, .source = {0,0,2,2},
            .destination = {70,17,24,18}, .clip = {70,17,24,18},
            .opacity = 1, .width = 2, .height = 2, .pitch = 8,
            .flags = 1, .nearest = 1, .pixels = pixels
        };
        shared_recording_image(destination, SkMatrix::I(), image);
        auto input = std::unique_ptr<IsolatedInputRecording>(
            static_cast<IsolatedInputRecording*>(ladybird_v_skia_take_isolated_input(destination)));
        assert(input && !input->unsupported && input->canvas_height == height && input->scale == scale);
        assert(input->bounds.contains(SkRect::MakeXYWH(70,17,24,18)));
        assert(input->bounds.contains(SkRect::MakeXYWH(11.25,69.25,34.5,9.25)));
        auto actual_picture = input->recorder.finishRecordingAsPicture();

        SkPictureRecorder oracle;
        auto* canvas = oracle.beginRecording(SkRect::MakeWH(width, height));
        SkPaint paint;
        paint.setAntiAlias(true);
        paint.setColor(SkColorSetARGB(201,70,127,194));
        canvas->drawRect(SkRect::MakeXYWH(11.25,69.25,34.5,9.25),paint);
        paint.setColor(SkColorSetARGB(137,40,60,80));
        canvas->drawRect(SkRect::MakeXYWH(6,71,1,14),paint);
        auto info = SkImageInfo::Make(2,2,kRGBA_8888_SkColorType,kPremul_SkAlphaType,
            SkColorSpace::MakeSRGB());
        auto bitmap = SkImages::RasterFromPixmapCopy(SkPixmap(info,pixels,8));
        assert(bitmap);
        canvas->translate(70,17);
        canvas->scale(12,9);
        canvas->drawImageRect(bitmap,SkRect::MakeWH(2,2),SkRect::MakeWH(2,2),
            SkSamplingOptions(SkFilterMode::kNearest),nullptr,SkCanvas::kFast_SrcRectConstraint);
        auto expected_picture = oracle.finishRecordingAsPicture();
        auto render = [&](SkPicture* picture) {
            SkSerialProcs procs;
            procs.fImageProc = serialize_shared_picture_image;
            auto bytes = picture->serialize(&procs);
            std::vector<uint32_t> result(width * height * scale * scale);
            float matrix[] {float(scale),0,0,0,float(scale),0,0,0,1};
            assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(result.data()),
                width*scale,height*scale,width*scale*4,bytes->data(),bytes->size(),matrix));
            return result;
        };
        auto actual = render(actual_picture.get());
        assert(actual == render(expected_picture.get()));
        assert(actual[(18 * scale) * (width * scale) + 71 * scale] == 0xff0d1b51u);
        assert(ladybird_v_skia_begin_isolated_input(destination,width,height));
        image.flags |= 4; // Unsupported retained-image mask belongs to this input.
        shared_recording_image(destination,SkMatrix::I(),image);
        assert(s_isolated_input_recordings.at(destination)->unsupported);
        if (unrelated_root) assert(s_shared_root_recording->blocked_bounds.empty());
        ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(destination));
        ladybird_v_skia_set_shared_recording(0,width,height);
        CGContextRelease(other);
        CGContextRelease(destination);
    }
    CGColorSpaceRelease(space);
    std::puts("Isolated rectangles, carets and images: four exact owner/scale comparisons");
}
