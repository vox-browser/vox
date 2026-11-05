#pragma once

#include "include/core/SkData.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkSerialProcs.h"
#include "include/core/SkStream.h"
#include "include/core/SkTypeface.h"
#include "native_shared_picture_pixels.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <list>
#include <mutex>
#include <utility>

inline constexpr uint8_t vox_picture_typeface_magic[8] {'V', 'X', 'T', 'F', 1, 0, 0, 0};
inline constexpr uint8_t vox_shared_typeface_magic[8] {'V', 'X', 'T', 'F', 2, 0, 0, 0};
struct VoxSharedPictureTypefaceToken {
    uint8_t magic[8] {'V', 'X', 'T', 'F', 2, 0, 0, 0};
    uint64_t token = 0;
};
static_assert(sizeof(VoxSharedPictureTypefaceToken) == 16);

// Frame SkPicture's ordinary embedded font bytes so the receiving Skia can
// retain one decoded face without reparsing its descriptor to find its length.
inline sk_sp<SkData> vox_encode_picture_typeface(SkTypeface* face)
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

// A typeface is immutable. Retain its identity with the complete packet so a
// later picture need not serialize and copy the same font again. The strong
// reference prevents a released face's address from becoming a false hit.
// Owners serialize access; the callback below locks its shared instance.
class VoxPictureTypefaceSerializationCache {
    struct Entry {
        sk_sp<SkTypeface> face;
        sk_sp<SkData> packet;
    };
    std::list<Entry> entries;
    size_t bytes = 0;
    size_t byte_limit, entry_limit;
public:
    explicit VoxPictureTypefaceSerializationCache(size_t budget = 64 * 1024 * 1024,
        size_t count = 64) : byte_limit(budget), entry_limit(count) { }

    sk_sp<SkData> encode(SkTypeface* face)
    {
        if (!face) return nullptr;
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            if (it->face.get() != face) continue;
            auto packet = it->packet;
            entries.splice(entries.begin(), entries, it);
            return packet;
        }
        auto packet = vox_encode_picture_typeface(face);
        if (!packet || !entry_limit || packet->size() > byte_limit) return packet;
        while (!entries.empty()
            && (entries.size() >= entry_limit || bytes > byte_limit - packet->size())) {
            bytes -= entries.back().packet->size();
            entries.pop_back();
        }
        bytes += packet->size();
        entries.push_front({sk_ref_sp(face), packet});
        return packet;
    }

    size_t entry_count() const { return entries.size(); }
    size_t retained_bytes() const { return bytes; }
    void clear() { entries.clear(); bytes = 0; }
};

inline SkSerialReturnType vox_serialize_picture_typeface(SkTypeface* face, void*)
{
    static std::mutex mutex;
    static VoxPictureTypefaceSerializationCache cache;
    std::lock_guard<std::mutex> lock(mutex);
    return cache.encode(face);
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

    sk_sp<SkTypeface> decode_input(void const* data, size_t size, sk_sp<SkData> owned)
    {
        if (!data || !size || size > 64 * 1024 * 1024) return nullptr;
        // This small LRU already verifies every byte before reusing a face.
        // Compare directly: hashing a multi-megabyte embedded font first
        // repeats the whole scan for every picture tile, including cache hits.
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            if (it->encoded->size() != size) continue;
            // A shared lease owns immutable encoded bytes. Retaining that
            // owner prevents address reuse, so equal addresses are exact keys.
            if (!(owned && it->encoded->data() == data)
                && std::memcmp(it->encoded->data(), data, size)) continue;
            bool identity_hit = owned && it->encoded->data() == data;
            if (owned) it->encoded = std::move(owned);
            if (identity_hit && std::getenv("VOX_SHARED_PICTURE_TYPEFACES_DIAGNOSTICS"))
                std::fprintf(stderr, "VOX_SHARED_PICTURE_TYPEFACE_REUSE identity=1 bytes=%zu\n", size);
            auto face = it->face;
            entries.splice(entries.begin(), entries, it);
            return face;
        }
        auto encoded = owned ? std::move(owned) : SkData::MakeWithCopy(data, size);
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

    sk_sp<SkTypeface> decode(void const* data, size_t size) {
        return decode_input(data, size, nullptr);
    }

    sk_sp<SkTypeface> decode_shared(uint64_t token) {
        static auto acquire = reinterpret_cast<VoxAcquireSharedPicturePixels>(
            dlsym(RTLD_DEFAULT, "vox_picture_pixels_acquire"));
        VoxSharedPicturePixelsLease lease;
        if (!token || !acquire || !acquire(token, &lease)) return nullptr;
        struct Owner {
            VoxSharedPicturePixelsLease lease;
            ~Owner() { if (lease.release) lease.release(lease.owner); }
        };
        auto owner = std::make_unique<Owner>();
        owner->lease = lease;
        if (!lease.bytes || lease.size <= 16 || lease.size > 64 * 1024 * 1024
            || std::memcmp(lease.bytes, vox_picture_typeface_magic, 8)) return nullptr;
        uint64_t size = 0;
        for (int i = 0; i < 8; ++i) size |= uint64_t(lease.bytes[8 + i]) << (i * 8);
        if (size != lease.size - 16) return nullptr;
        auto encoded = SkData::MakeWithProc(lease.bytes + 16, size,
            [](void const*, void* value) { delete static_cast<Owner*>(value); }, owner.get());
        if (!encoded) return nullptr;
        owner.release();
        auto face = decode_input(encoded->data(), encoded->size(), encoded);
        if (std::getenv("VOX_SHARED_PICTURE_TYPEFACES_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_SHARED_PICTURE_TYPEFACE_DECODE bytes=%zu ready=%d\n",
                size_t(size), bool(face));
        return face;
    }

    sk_sp<SkTypeface> decode_stream(SkStream& stream)
    {
        uint8_t header[16];
        if (stream.peek(header, sizeof(header)) == sizeof(header)
            && !std::memcmp(header, vox_shared_typeface_magic, 8)) {
            VoxSharedPictureTypefaceToken payload;
            if (stream.read(&payload, sizeof(payload)) != sizeof(payload)) return nullptr;
            return decode_shared(payload.token);
        }
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
