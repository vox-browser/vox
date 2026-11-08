#pragma once
#include <algorithm>
#include <cstdint>
#include <vector>
#include <utility>

// The overlapping border texels are shown by exactly one Chromium tile.
inline bool vox_chromium_row_uses_msaa(long row, std::vector<int> const& tiles, int tile_rows)
{
    if (row < 0 || tiles.empty() || tile_rows < 3) return false;
    long spacing = tile_rows - 2;
    long tile = row <= spacing ? 0 : (row - 1) / spacing;
    return std::binary_search(tiles.begin(), tiles.end(), static_cast<int>(tile));
}

// Both passes start from the same immutable backdrop. A failed mixed pass must
// leave that input intact for the ordinary CPU fallback.
template<typename Draw>
bool vox_draw_with_msaa_rows(std::vector<uint32_t>& pixels, int width,
    std::vector<char> const& rows, Draw draw)
{
    size_t count = std::count(rows.begin(), rows.end(), char(1));
    if (count == 0) return draw(pixels, false);
    if (count == rows.size()) return draw(pixels, true);
    auto original = pixels;
    auto multisampled = original;
    if (!draw(multisampled, true) || !draw(pixels, false)) {
        pixels = std::move(original);
        return false;
    }
    // Pixel masks use width=1 to preserve horizontal tile boundaries. Copy
    // complete selected spans rather than dispatching one copy per pixel.
    auto cursor = rows.begin();
    while (cursor != rows.end()) {
        auto first = std::find(cursor, rows.end(), char(1));
        auto end = std::find(first, rows.end(), char(0));
        auto offset = size_t(first - rows.begin()) * width;
        auto count = size_t(end - first) * width;
        std::copy_n(multisampled.begin() + offset, count, pixels.begin() + offset);
        cursor = end;
    }
    return true;
}
