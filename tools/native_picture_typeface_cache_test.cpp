#include "../native_picture_typeface_cache.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkFont.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTextBlob.h"
#include "include/ports/SkTypeface_mac.h"
#include <CoreText/CoreText.h>
#include <cassert>
#include <algorithm>
#include <dlfcn.h>
#include <iostream>
#include <vector>

// LibWeb's older Skia passes the picture stream through its legacy callback.
// The pinned Dawn Skia uses the typed stream callback for the same packet.
static sk_sp<SkTypeface> decode_legacy(void const* data, size_t size, void* context)
{
    assert(size == sizeof(SkStream*));
    SkStream* stream;
    std::memcpy(&stream, data, sizeof(stream));
    return static_cast<VoxPictureTypefaceCache*>(context)->decode_stream(*stream);
}

static std::vector<uint32_t> raster(SkPicture* picture)
{
    std::vector<uint32_t> pixels(160 * 64);
    auto surface = SkSurfaces::WrapPixels(SkImageInfo::MakeN32Premul(160, 64),
        pixels.data(), 160 * 4);
    assert(surface);
    surface->getCanvas()->clear(SK_ColorWHITE);
    surface->getCanvas()->drawPicture(picture);
    return pixels;
}

int main(int argc, char** argv)
{
    auto system = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 16, nullptr);
    auto bold = CTFontCreateCopyWithSymbolicTraits(system, 0, nullptr,
        kCTFontBoldTrait, kCTFontBoldTrait);
    auto helvetica = CTFontCreateWithName(CFSTR("HelveticaNeue"), 16, nullptr);
    auto courier = CTFontCreateWithName(CFSTR("Courier"), 16, nullptr);
    assert(system && bold && helvetica && courier);
    std::vector<sk_sp<SkTypeface>> faces;
    for (auto font : {system, bold, helvetica, courier}) {
        faces.push_back(SkMakeTypefaceFromCTFont(font));
        CFRelease(font);
        assert(faces.back());
    }
    VoxPictureTypefaceCache cache;
    std::vector<sk_sp<SkData>> packets;
    std::vector<sk_sp<SkTypeface>> retained;
    for (auto const& face : faces) {
        auto packet = vox_serialize_picture_typeface(face.get(), nullptr);
        assert(packet && packet->size() > 16);
        auto repeat = vox_serialize_picture_typeface(face.get(), nullptr);
        assert(repeat && repeat->size() == packet->size()
            && !std::memcmp(repeat->data(), packet->data(), packet->size()));
        packets.push_back(packet);
        std::vector<uint8_t> caller_bytes(static_cast<uint8_t const*>(packet->data()),
            static_cast<uint8_t const*>(packet->data()) + packet->size());
        SkMemoryStream first(caller_bytes.data(), caller_bytes.size());
        auto decoded = cache.decode_stream(first);
        assert(decoded && first.isAtEnd());
        assert(decoded->fontStyle() == face->fontStyle());
        retained.push_back(decoded);
        std::fill(caller_bytes.begin(), caller_bytes.end(), 0);
        SkMemoryStream second(packet);
        auto reused = cache.decode_stream(second);
        assert(reused && reused->uniqueID() == decoded->uniqueID() && second.isAtEnd());
    }
    assert(cache.entry_count() == faces.size());
    assert(cache.retained_bytes() <= 128 * 1024 * 1024);

    // Font names, weights and glyph pixels survive the real picture protocol.
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(160, 64));
    SkPaint paint;
    paint.setColor(SkColorSetRGB(59, 64, 69));
    for (size_t i = 0; i < faces.size(); ++i) {
        SkFont font(faces[i], 13);
        font.setSubpixel(true);
        auto blob = SkTextBlob::MakeFromText("Home", 4, font);
        assert(blob);
        canvas->drawTextBlob(blob, 4 + i * 38, 24 + i * 7, paint);
    }
    auto picture = recorder.finishRecordingAsPicture();
    auto ordinary_bytes = picture->serialize();
    auto ordinary = SkPicture::MakeFromData(ordinary_bytes.get());
    assert(ordinary);
    auto expected = raster(ordinary.get());
    SkSerialProcs serial;
    serial.fTypefaceProc = vox_serialize_picture_typeface;
    auto custom_bytes = picture->serialize(&serial);
    SkDeserialProcs deserial;
    deserial.fTypefaceProc = decode_legacy;
    deserial.fTypefaceCtx = &cache;
    for (int pass = 0; pass < 3; ++pass) {
        auto decoded = SkPicture::MakeFromData(custom_bytes.get(), &deserial);
        assert(decoded && raster(decoded.get()) == expected);
    }

    size_t largest_cost = 0;
    for (auto const& packet : packets) largest_cost = std::max(largest_cost, (packet->size() - 16) * 2);
    VoxPictureTypefaceCache single(largest_cost, 1);
    for (auto const& packet : packets) {
        SkMemoryStream stream(packet);
        assert(single.decode_stream(stream));
        assert(single.entry_count() == 1 && single.retained_bytes() <= largest_cost);
    }
    single.clear();
    assert(single.entry_count() == 0 && single.retained_bytes() == 0);
    assert(retained[0]->unicharToGlyph('H') == faces[0]->unicharToGlyph('H'));

    VoxPictureTypefaceCache tiny(8, 1);
    SkMemoryStream oversized(packets[0]);
    assert(tiny.decode_stream(oversized) && tiny.entry_count() == 0);
    auto raw = faces[0]->serialize(SkTypeface::SerializeBehavior::kDoIncludeData);
    SkMemoryStream legacy(raw);
    assert(tiny.decode_stream(legacy) && legacy.isAtEnd());
    assert(!tiny.decode(nullptr, 0) && !vox_serialize_picture_typeface(nullptr, nullptr));
    uint8_t invalid[16];
    std::memcpy(invalid, vox_picture_typeface_magic, 8);
    std::memset(invalid + 8, 255, 8);
    SkMemoryStream truncated(invalid, sizeof(invalid));
    assert(!tiny.decode_stream(truncated));
    assert(tiny.entry_count() == 0 && tiny.retained_bytes() == 0);
    if (argc == 3) {
        using Draw = int (*)(uint8_t*, int, int, int, void const*, size_t, float const*);
        auto control_library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        auto candidate_library = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
        assert(control_library && candidate_library);
        auto control = reinterpret_cast<Draw>(dlsym(control_library, "vox_graphite_draw_picture_pixels"));
        auto candidate = reinterpret_cast<Draw>(dlsym(candidate_library, "vox_graphite_draw_picture_pixels"));
        assert(control && candidate && control != candidate);
        Dl_info old_image {}, new_image {};
        assert(dladdr(reinterpret_cast<void*>(control), &old_image));
        assert(dladdr(reinterpret_cast<void*>(candidate), &new_image));
        assert(std::strcmp(old_image.dli_fname, new_image.dli_fname));
        std::cout << "Control: " << old_image.dli_fname << "\nCandidate: " << new_image.dli_fname << '\n';
        float matrix[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        std::vector<uint32_t> reference(160 * 64), result(reference.size());
        assert(control(reinterpret_cast<uint8_t*>(reference.data()), 160, 64, 160 * 4,
            ordinary_bytes->data(), ordinary_bytes->size(), matrix));
        for (int pass = 0; pass < 3; ++pass) {
            assert(candidate(reinterpret_cast<uint8_t*>(result.data()), 160, 64, 160 * 4,
                custom_bytes->data(), custom_bytes->size(), matrix));
            assert(result == reference);
        }
        assert(candidate(reinterpret_cast<uint8_t*>(result.data()), 160, 64, 160 * 4,
            ordinary_bytes->data(), ordinary_bytes->size(), matrix));
        assert(result == reference);
        std::cout << "Four old/new GPU picture comparisons are exact\n";
    } else {
        assert(argc == 1);
    }
    std::cout << "Four embedded faces reuse owned packets; mixed-font pictures are exact; bounds and fallbacks pass\n";
}
