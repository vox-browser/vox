#pragma once
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>

struct VoxRGBAAlphaBounds {
    int left = 0, top = 0, right = 0, bottom = 0;
    bool empty() const { return right <= left || bottom <= top; }
};

// Only the first and last nontransparent pixel of each row can enlarge its
// bounds. Skip transparent spans in bounded, unaligned-safe blocks and avoid
// scanning dense interiors entirely.
static VoxRGBAAlphaBounds vox_rgba_alpha_bounds(uint8_t const* pixels,
    int width, int height, size_t pitch)
{
    if (!pixels || width <= 0 || height <= 0 || size_t(width) > SIZE_MAX / 4
        || pitch < size_t(width) * 4 || pitch > SIZE_MAX / size_t(height)) return {};
    VoxRGBAAlphaBounds bounds {width, height, 0, 0};
    auto transparent16 = [](uint8_t const* p) {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        uint64_t channels = 0;
        for (int i = 0; i < 8; ++i) {
            uint64_t pair; std::memcpy(&pair, p + i * 8, 8); channels |= pair;
        }
        return !(channels & UINT64_C(0xff000000ff000000));
#else
        unsigned alpha = 0;
        for (int i = 0; i < 16; ++i) alpha |= p[i * 4 + 3];
        return !alpha;
#endif
    };
    for (int y = 0; y < height; ++y) {
        auto* row = pixels + size_t(y) * pitch;
        int left = 0, right = width;
        while (width - left >= 16 && transparent16(row + size_t(left) * 4)) left += 16;
        while (left < width && !row[size_t(left) * 4 + 3]) ++left;
        if (left == width) continue;
        while (right - left >= 16 && transparent16(row + size_t(right - 16) * 4)) right -= 16;
        while (right > left && !row[size_t(right - 1) * 4 + 3]) --right;
        bounds.left = std::min(bounds.left, left); bounds.right = std::max(bounds.right, right);
        bounds.top = std::min(bounds.top, y); bounds.bottom = y + 1;
    }
    return bounds.empty() ? VoxRGBAAlphaBounds{} : bounds;
}
