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

static VoxSharedPicturePixelsRegistry shared_fonts(128 * 1024 * 1024, 16);
static std::vector<uint64_t> shared_font_tokens;
extern "C" __attribute__((visibility("default")))
int vox_picture_pixels_acquire(uint64_t token, VoxSharedPicturePixelsLease* out) {
    return shared_fonts.acquire(token, out);
}

static uint64_t publish_font(sk_sp<SkData> data) {
    auto* retained = data.release();
    std::shared_ptr<void const> owner(retained, [](void const* value) {
        static_cast<SkData const*>(value)->unref();
    });
    return shared_fonts.insert(owner, static_cast<uint8_t const*>(retained->data()), retained->size());
}

static sk_sp<SkData> font_token(uint64_t token) {
    VoxSharedPictureTypefaceToken payload; payload.token = token;
    return SkData::MakeWithCopy(&payload, sizeof(payload));
}

static SkSerialReturnType encode_shared_font(SkTypeface* face, void*) {
    auto token = publish_font(vox_serialize_picture_typeface(face, nullptr)); assert(token);
    shared_font_tokens.push_back(token);
    return font_token(token);
}

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
        assert(repeat && repeat.get() == packet.get() && repeat->size() == packet->size()
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

    // The serialization cache owns the face identity and exactly the existing
    // wire packet. LRU eviction/clear must not invalidate caller-owned packets.
    VoxPictureTypefaceSerializationCache serialized(64 * 1024 * 1024, 2);
    auto first_packet = serialized.encode(faces[0].get());
    auto first_hit = serialized.encode(faces[0].get());
    assert(first_packet && first_hit.get() == first_packet.get());
    assert(!std::memcmp(first_packet->data(), packets[0]->data(), first_packet->size()));
    assert(serialized.encode(faces[1].get()));
    assert(serialized.encode(faces[0].get()).get() == first_packet.get());
    auto third_packet = serialized.encode(faces[2].get());
    assert(third_packet);
    assert(serialized.entry_count() == 2);
    assert(serialized.encode(faces[0].get()).get() == first_packet.get());
    assert(serialized.encode(faces[1].get()));
    auto evicted = serialized.encode(faces[2].get());
    assert(evicted && evicted.get() != third_packet.get());
    assert(evicted->size() == packets[2]->size()
        && !std::memcmp(evicted->data(), packets[2]->data(), evicted->size()));
    serialized.clear();
    assert(serialized.entry_count() == 0 && serialized.retained_bytes() == 0);
    SkMemoryStream surviving(first_packet);
    assert(cache.decode_stream(surviving) && surviving.isAtEnd());
    VoxPictureTypefaceSerializationCache small(first_packet->size() - 1, 2);
    assert(small.encode(faces[0].get()) && small.entry_count() == 0);
    VoxPictureTypefaceSerializationCache disabled(64 * 1024 * 1024, 0);
    assert(disabled.encode(faces[0].get()) && disabled.retained_bytes() == 0);
    assert(!serialized.encode(nullptr));
    size_t largest_packet = 0, largest_index = 0;
    for (size_t i = 0; i < packets.size(); ++i)
        if (packets[i]->size() > largest_packet) {
            largest_packet = packets[i]->size(); largest_index = i;
        }
    VoxPictureTypefaceSerializationCache byte_bound(largest_packet, 64);
    auto largest_retained = byte_bound.encode(faces[largest_index].get());
    assert(byte_bound.encode(faces[(largest_index + 1) % faces.size()].get()));
    auto reloaded = byte_bound.encode(faces[largest_index].get());
    assert(reloaded && reloaded.get() != largest_retained.get());
    assert(byte_bound.entry_count() == 1 && byte_bound.retained_bytes() == largest_packet);

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

    // A retired transaction token cannot be acquired again, while the decoded
    // face and cache still own its immutable font bytes. Reissuing the same
    // owned bytes preserves face identity without comparing/copying the font.
    VoxPictureTypefaceCache leased;
    auto first_token = publish_font(packets[0]); assert(first_token);
    SkMemoryStream first_shared(font_token(first_token));
    auto first_shared_face = leased.decode_stream(first_shared);
    assert(first_shared_face && first_shared.isAtEnd() && leased.entry_count() == 1);
    shared_fonts.retire(first_token);
    assert(shared_fonts.live_bytes() == packets[0]->size());
    SkMemoryStream expired_shared(font_token(first_token));
    assert(!leased.decode_stream(expired_shared));
    auto second_token = publish_font(packets[0]); assert(second_token && second_token != first_token);
    SkMemoryStream second_shared(font_token(second_token));
    auto reused_shared_face = leased.decode_stream(second_shared);
    assert(reused_shared_face && second_shared.isAtEnd()
        && reused_shared_face->uniqueID() == first_shared_face->uniqueID());
    shared_fonts.retire(second_token);
    assert(shared_fonts.live_bytes() == packets[0]->size());
    leased.clear();
    first_shared_face.reset(); reused_shared_face.reset();
    assert(shared_fonts.live_bytes() == 0);
    SkMemoryStream zero_token(font_token(0));
    assert(!leased.decode_stream(zero_token));
    auto malformed = SkData::MakeWithCopy(packets[0]->data(), packets[0]->size());
    static_cast<uint8_t*>(malformed->writable_data())[8] ^= 1;
    auto bad_token = publish_font(malformed); assert(bad_token);
    SkMemoryStream bad_shared(font_token(bad_token));
    assert(!leased.decode_stream(bad_shared));
    shared_fonts.retire(bad_token);
    assert(!leased.entry_count() && !shared_fonts.live_bytes());

    serial.fTypefaceProc = encode_shared_font;
    auto shared_bytes = picture->serialize(&serial);
    assert(shared_bytes && shared_bytes->size() < custom_bytes->size() / 2);
    VoxPictureTypefaceCache shared_picture_cache;
    deserial.fTypefaceCtx = &shared_picture_cache;
    auto shared_picture = SkPicture::MakeFromData(shared_bytes.get(), &deserial);
    assert(shared_picture);
    for (auto token : shared_font_tokens) shared_fonts.retire(token);
    assert(raster(shared_picture.get()) == expected);
    shared_picture_cache.clear();
    assert(raster(shared_picture.get()) == expected);
    shared_picture.reset();
    assert(shared_fonts.live_bytes() == 0);
    deserial.fTypefaceCtx = &cache;

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
    // Equal-length keys can share every byte except the last. Keep complete
    // identity checks even when Skia accepts trailing bytes after its font.
    std::vector<uint8_t> suffix_key(static_cast<uint8_t const*>(raw->data()),
        static_cast<uint8_t const*>(raw->data()) + raw->size());
    suffix_key.push_back(1);
    VoxPictureTypefaceCache suffix_cache;
    auto suffix_first = suffix_cache.decode(suffix_key.data(), suffix_key.size());
    assert(suffix_first && suffix_cache.entry_count() == 1);
    suffix_key.back() = 2;
    assert(suffix_cache.decode(suffix_key.data(), suffix_key.size()));
    assert(suffix_cache.entry_count() == 2);
    suffix_key.back() = 1;
    auto suffix_reused = suffix_cache.decode(suffix_key.data(), suffix_key.size());
    assert(suffix_reused && suffix_reused->uniqueID() == suffix_first->uniqueID());
    assert(suffix_cache.entry_count() == 2);
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
        shared_font_tokens.clear();
        auto shared_gpu_bytes = picture->serialize(&serial);
        assert(candidate(reinterpret_cast<uint8_t*>(result.data()), 160, 64, 160 * 4,
            shared_gpu_bytes->data(), shared_gpu_bytes->size(), matrix));
        assert(result == reference);
        for (auto token : shared_font_tokens) shared_fonts.retire(token);
        std::cout << "Four old/new GPU picture comparisons are exact\n";
    } else {
        assert(argc == 1);
    }
    std::cout << "Four embedded faces reuse owned packets; mixed-font pictures are exact; bounds and fallbacks pass\n";
    std::cout << "Shared font tokens: immutable identity, expiry, ownership and mixed-font pixels pass\n";
}
