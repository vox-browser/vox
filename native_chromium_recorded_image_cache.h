#pragma once

// Immutable CPU images used by speculative pictures. Recreated SkImages have
// different IDs even when their texels match; exact owned content gives the
// retained tile stream a stable resource identity without borrowing pointers.
class RecordedImageCache {
    struct Entry { uint64_t hash; sk_sp<SkImage> image; size_t bytes; };
    std::list<Entry> entries_;
    size_t bytes_ = 0;
    static uint64_t hash(SkPixmap const& pixels)
    {
        uint64_t value = 14695981039346656037ull;
        size_t bytes = pixels.info().minRowBytes();
        for (int y = 0; y < pixels.height(); ++y) {
            auto* row = static_cast<uint8_t const*>(pixels.addr(0, y));
            size_t x = 0;
            for (; bytes - x >= 8; x += 8) {
                uint64_t word; std::memcpy(&word, row + x, 8);
                value = (value ^ word) * 1099511628211ull;
            }
            for (; x < bytes; ++x) value = (value ^ row[x]) * 1099511628211ull;
        }
        return value;
    }
public:
    void clear() { entries_.clear(); bytes_ = 0; }
    sk_sp<SkImage> get(SkPixmap const& source, bool* reused = nullptr)
    {
        if (reused) *reused = false;
        if (!source.addr() || source.width() <= 0 || source.height() <= 0
            || source.rowBytes() < source.info().minRowBytes()) return {};
        size_t row_bytes = source.info().minRowBytes();
        if (row_bytes > SIZE_MAX / size_t(source.height())) return {};
        size_t bytes = row_bytes * source.height();
        constexpr size_t limit = 16 * 1024 * 1024;
        if (bytes > limit / 2) return SkImages::RasterFromPixmapCopy(source);
        auto value = hash(source);
        for (auto it = entries_.begin(); it != entries_.end(); ++it) {
            auto const& info = it->image->imageInfo();
            if (it->hash != value || (info.width() != source.width() || info.height() != source.height())
                || info.colorType() != source.colorType() || info.alphaType() != source.alphaType()
                || !SkColorSpace::Equals(info.colorSpace(), source.colorSpace())) continue;
            SkPixmap owned;
            if (!it->image->peekPixels(&owned)) continue;
            bool equal = true;
            for (int y = 0; y < source.height() && equal; ++y)
                equal = !std::memcmp(source.addr(0, y), owned.addr(0, y), row_bytes);
            if (!equal) continue;
            auto image = it->image;
            entries_.splice(entries_.begin(), entries_, it);
            if (reused) *reused = true;
            return image;
        }
        auto image = SkImages::RasterFromPixmapCopy(source);
        if (!image) return {};
        while (!entries_.empty() && (bytes_ + bytes > limit || entries_.size() >= 128)) {
            bytes_ -= entries_.back().bytes; entries_.pop_back();
        }
        entries_.push_front({value, image, bytes}); bytes_ += bytes;
        return image;
    }
};
static RecordedImageCache s_recorded_image_cache;
