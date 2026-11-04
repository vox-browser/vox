#pragma once

#include "include/core/SkData.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkSerialProcs.h"
#include "include/core/SkStream.h"
#include "include/core/SkTypeface.h"
#include <cstdint>
#include <cstring>
#include <list>
#include <utility>

inline constexpr uint8_t vox_picture_typeface_magic[8] {'V', 'X', 'T', 'F', 1, 0, 0, 0};

// Frame SkPicture's ordinary embedded font bytes so the receiving Skia can
// retain one decoded face without reparsing its descriptor to find its length.
inline SkSerialReturnType vox_serialize_picture_typeface(SkTypeface* face, void*)
{
    if (!face) return nullptr;
    auto font = face->serialize(SkTypeface::SerializeBehavior::kDoIncludeData);
    if (!font || font->size() > 64 * 1024 * 1024 - 16) return nullptr;
    auto packet = SkData::MakeUninitialized(font->size() + 16);
    if (!packet) return nullptr;
    auto* bytes = static_cast<uint8_t*>(packet->writable_data());
    std::memcpy(bytes, vox_picture_typeface_magic, 8);
    uint64_t size = font->size();
    for (int i = 0; i < 8; ++i) bytes[8 + i] = uint8_t(size >> (i * 8));
    std::memcpy(bytes + 16, font->data(), font->size());
    return packet;
}

// Access is serialized by the picture renderer's mutex. Keys own their bytes:
// a caller can release or reuse its picture buffer immediately after replay.
class VoxPictureTypefaceCache {
    struct Entry {
        sk_sp<SkData> encoded;
        sk_sp<SkTypeface> face;
    };
    std::list<Entry> entries;
    size_t bytes = 0;
    size_t byte_limit, entry_limit;
public:
    explicit VoxPictureTypefaceCache(size_t budget = 128 * 1024 * 1024, size_t count = 64)
        : byte_limit(budget), entry_limit(count) { }

    sk_sp<SkTypeface> decode(void const* data, size_t size)
    {
        if (!data || !size || size > 64 * 1024 * 1024) return nullptr;
        // This small LRU already verifies every byte before reusing a face.
        // Compare directly: hashing a multi-megabyte embedded font first
        // repeats the whole scan for every picture tile, including cache hits.
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            if (it->encoded->size() != size
                || std::memcmp(it->encoded->data(), data, size)) continue;
            auto face = it->face;
            entries.splice(entries.begin(), entries, it);
            return face;
        }
        auto encoded = SkData::MakeWithCopy(data, size);
        if (!encoded) return nullptr;
        SkMemoryStream stream(encoded);
        auto face = SkTypeface::MakeDeserialize(&stream, nullptr);
        if (!face) return nullptr;
        // Charge both the key and a decoded face's retained font stream.
        // Oversized faces still decode normally, without occupying the cache.
        if (!entry_limit || size > byte_limit / 2) return face;
        size_t cost = size * 2;
        while (!entries.empty() && (entries.size() >= entry_limit || bytes > byte_limit - cost)) {
            bytes -= entries.back().encoded->size() * 2;
            entries.pop_back();
        }
        entries.push_front({std::move(encoded), face});
        bytes += cost;
        return face;
    }

    sk_sp<SkTypeface> decode_stream(SkStream& stream)
    {
        uint8_t header[16];
        if (stream.peek(header, sizeof(header)) != sizeof(header)
            || std::memcmp(header, vox_picture_typeface_magic, 8)) {
            // Preserve callers that still supply ordinary SkPicture fonts.
            return SkTypeface::MakeDeserialize(&stream, nullptr);
        }
        if (stream.read(header, sizeof(header)) != sizeof(header)) return nullptr;
        uint64_t size = 0;
        for (int i = 0; i < 8; ++i) size |= uint64_t(header[8 + i]) << (i * 8);
        if (!size || size > 64 * 1024 * 1024 || !stream.hasLength() || !stream.hasPosition()
            || stream.getPosition() > stream.getLength()
            || size > stream.getLength() - stream.getPosition()) return nullptr;
        if (auto* memory = stream.getMemoryBase()) {
            auto face = decode(static_cast<uint8_t const*>(memory) + stream.getPosition(), size_t(size));
            if (stream.skip(size_t(size)) != size) return nullptr;
            return face;
        }
        auto encoded = SkData::MakeFromStream(&stream, size_t(size));
        return encoded ? decode(encoded->data(), encoded->size()) : nullptr;
    }

    size_t entry_count() const { return entries.size(); }
    size_t retained_bytes() const { return bytes; }
    void clear() { entries.clear(); bytes = 0; }
};
