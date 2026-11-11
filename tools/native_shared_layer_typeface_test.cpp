// Compositor-layer pictures lease embedded fonts by token. Their GPU raster
// must match the self-contained picture exactly, the payload must no longer
// carry font files, and image encoding must remain unchanged.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>
#include <cstdlib>

static sk_sp<SkPicture> text_picture(sk_sp<SkTypeface> face, sk_sp<SkImage> image)
{
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(320, 96));
    SkFont font(face, 18);
    font.setEdging(SkFont::Edging::kSubpixelAntiAlias);
    SkPaint paint;
    paint.setColor(SkColorSetRGB(13, 13, 13));
    canvas->drawString("typing into the composer", 12, 40, font, paint);
    font.setSize(13);
    canvas->drawString("Lease fonts by token", 12, 72, font, paint);
    canvas->drawImage(image, 250, 10);
    return recorder.finishRecordingAsPicture();
}

static std::vector<uint8_t> draw(SkData const* bytes)
{
    std::vector<uint8_t> pixels(320 * 2 * 96 * 2 * 4, 0);
    float matrix[] {2, 0, 0, 0, 2, 0, 0, 0, 1};
    assert(shared_picture_draw()(pixels.data(), 640, 192, 640 * 4, bytes->data(), bytes->size(), matrix));
    return pixels;
}

int main()
{
    assert(shared_picture_draw());
    auto system = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 18, nullptr);
    assert(system);
    auto face = SkMakeTypefaceFromCTFont(system);
    CFRelease(system);
    assert(face);
    // Larger than the 64 KiB image-token threshold of ordinary shared scopes.
    std::vector<uint32_t> image_pixels(160 * 160);
    for (size_t i = 0; i < image_pixels.size(); ++i) image_pixels[i] = 0xff000000u | uint32_t(i * 2654435761u);
    auto image = SkImages::RasterFromPixmapCopy(SkPixmap(SkImageInfo::MakeN32Premul(160, 160),
        image_pixels.data(), 160 * 4));
    assert(image);
    auto picture = text_picture(face, image);

    SkSerialProcs embedded_procs;
    embedded_procs.fImageProc = serialize_shared_picture_image;
    embedded_procs.fTypefaceProc = vox_serialize_picture_typeface;
    auto embedded = picture->serialize(&embedded_procs);
    assert(embedded);
    auto expected = draw(embedded.get());

    unsigned cases = 0;
    for (int repeat = 0; repeat < 3; ++repeat) {
        SharedPicturePixelsScope shared_typefaces(true, true);
        SkSerialProcs procs;
        procs.fImageProc = serialize_shared_picture_image;
        procs.fTypefaceProc = serialize_shared_picture_typeface;
        auto leased = picture->serialize(&procs);
        assert(leased);
        // The font file is replaced by a 16-byte token; the image stays inline.
        assert(leased->size() + 64 * 1024 < embedded->size());
        assert(leased->size() > image_pixels.size() * 4);
        assert(draw(leased.get()) == expected);
        ++cases;
    }

    setenv("VOX_DISABLE_SHARED_LAYER_TYPEFACES", "1", 1);
    {
        SharedPicturePixelsScope disabled(true, true);
        SkSerialProcs procs;
        procs.fImageProc = serialize_shared_picture_image;
        procs.fTypefaceProc = serialize_shared_picture_typeface;
        auto bytes = picture->serialize(&procs);
        assert(bytes && bytes->size() == embedded->size());
        assert(draw(bytes.get()) == expected);
        ++cases;
    }
    unsetenv("VOX_DISABLE_SHARED_LAYER_TYPEFACES");
    std::printf("Shared layer typefaces: %u exact leased/embedded rasters passed\n", cases);
}
