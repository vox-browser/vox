#ifndef VOX_NATIVE_GLYPH_TEXT_BLOB_CACHE_H
#define VOX_NATIVE_GLYPH_TEXT_BLOB_CACHE_H

#include "include/core/SkFont.h"
#include "include/core/SkTextBlob.h"
#include "include/core/SkTypeface.h"
#include <cstdint>
#include <cstring>
#include <iterator>
#include <list>
#include <unordered_map>
#include <utility>
#include <vector>
#ifdef VOX_TEXT_BLOB_CACHE_DIAGNOSTICS
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#endif

// Positioned runs are unchanged by page scrolling. Retain their immutable Skia
// blobs separately from the raster/backdrop cache, whose device phase can change
// on every precise wheel event. Caller-owned glyph/position arrays are compared
// by value; entries own both the font and the copied run inputs.
class VoxGlyphTextBlobCache {
    struct Entry {
        uint64_t hash;
        SkFont font;
        std::vector<uint16_t> glyphs;
        std::vector<SkScalar> positions;
        sk_sp<SkTextBlob> blob;
        size_t cost;
    };
    using Entries = std::list<Entry>;
    Entries entries_;
    std::unordered_multimap<uint64_t, Entries::iterator> index_;
    size_t bytes_ = 0;
    size_t byte_limit_, entry_limit_;
#ifdef VOX_TEXT_BLOB_CACHE_DIAGNOSTICS
    const char* marker_ = std::getenv("VOX_TEXT_BLOB_INPUT_MARKER");
    bool input_started_ = false;
    uint64_t requests_ = 0, hits_ = 0;
#endif
public:
    explicit VoxGlyphTextBlobCache(size_t bytes = 8 * 1024 * 1024, size_t count = 1024)
        : byte_limit_(bytes), entry_limit_(count) { }
#ifdef VOX_TEXT_BLOB_CACHE_DIAGNOSTICS
    ~VoxGlyphTextBlobCache() {
        std::fprintf(stderr, "VOX_TEXT_BLOB_CACHE input=%d requests=%llu hits=%llu entries=%zu bytes=%zu\n",
            input_started_, (unsigned long long)requests_, (unsigned long long)hits_, entries_.size(), bytes_);
    }
#endif

    sk_sp<SkTextBlob> get(SkFont const& font, uint16_t const* glyphs,
        double const* positions, int count)
    {
        if (!glyphs || !positions || count <= 0) return nullptr;
#ifdef VOX_TEXT_BLOB_CACHE_DIAGNOSTICS
        if (!input_started_ && marker_ && *marker_ && access(marker_, F_OK) == 0) {
            input_started_ = true;
            requests_ = hits_ = 0;
        }
        ++requests_;
#endif
        uint64_t hash = 14695981039346656037ull;
        auto mix = [&](uint32_t value) { hash = (hash ^ value) * 1099511628211ull; };
        mix(font.getTypeface() ? font.getTypeface()->uniqueID() : 0);
        mix(uint32_t(count));
        for (int i = 0; i < count; ++i) mix(glyphs[i]);
        for (size_t i = 0; i < size_t(count) * 2; ++i) {
            float position = static_cast<SkScalar>(positions[i]);
            uint32_t bits;
            std::memcpy(&bits, &position, sizeof(bits));
            mix(bits);
        }
        auto candidates = index_.equal_range(hash);
        for (auto candidate = candidates.first; candidate != candidates.second; ++candidate) {
            auto it = candidate->second;
            auto const& entry = *it;
            if (entry.font != font || entry.glyphs.size() != size_t(count)
                || std::memcmp(entry.glyphs.data(), glyphs, size_t(count) * sizeof(uint16_t))) continue;
            bool same = true;
            for (size_t i = 0; i < size_t(count) * 2; ++i)
                if (entry.positions[i] != static_cast<SkScalar>(positions[i])) { same = false; break; }
            if (!same) continue;
#ifdef VOX_TEXT_BLOB_CACHE_DIAGNOSTICS
            ++hits_;
#endif
            entries_.splice(entries_.begin(), entries_, it);
            return entry.blob;
        }

        SkTextBlobBuilder builder;
        auto const& run = builder.allocRunPos(font, count);
        std::memcpy(run.glyphs, glyphs, size_t(count) * sizeof(uint16_t));
        for (size_t i = 0; i < size_t(count) * 2; ++i) run.pos[i] = static_cast<SkScalar>(positions[i]);
        auto blob = builder.make();
        // One run owns roughly ten bytes per glyph in Skia, plus our input
        // copies. Charge a conservative 4 KiB header/alignment allowance and
        // twice the run payload; huge one-off runs never enter the cache.
        size_t cost = 4096 + size_t(count) * (sizeof(uint16_t) + 2 * sizeof(SkScalar)) * 2;
        if (!blob || !entry_limit_ || count > 4096 || cost > byte_limit_) return blob;
        while (!entries_.empty() && (bytes_ + cost > byte_limit_ || entries_.size() >= entry_limit_)) {
            auto victim = std::prev(entries_.end());
            auto versions = index_.equal_range(victim->hash);
            for (auto version = versions.first; version != versions.second; ++version)
                if (version->second == victim) { index_.erase(version); break; }
            bytes_ -= victim->cost;
            entries_.pop_back();
        }
        Entry entry{hash, font, std::vector<uint16_t>(glyphs, glyphs + count),
            std::vector<SkScalar>(size_t(count) * 2), blob, cost};
        for (size_t i = 0; i < size_t(count) * 2; ++i) entry.positions[i] = static_cast<SkScalar>(positions[i]);
        bytes_ += cost;
        entries_.push_front(std::move(entry));
        index_.emplace(hash, entries_.begin());
        return blob;
    }

    void clear() { index_.clear(); entries_.clear(); bytes_ = 0; }
    size_t size() const { return entries_.size(); }
    size_t charged_bytes() const { return bytes_; }
};

#endif
