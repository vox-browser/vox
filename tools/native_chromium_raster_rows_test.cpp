#include "../native_chromium_raster_rows.h"
#include <cassert>
#include <initializer_list>
int main() {
    for (long row : {-1, 255, 256, 508, 509}) assert(!vox_chromium_row_uses_msaa(row, {0}, 256));
    for (long row : {0, 1, 253, 254}) assert(vox_chromium_row_uses_msaa(row, {0}, 256));
    for (long row : {255, 256, 507, 508}) assert(vox_chromium_row_uses_msaa(row, {1}, 256));
    for (long row : {254, 509}) assert(!vox_chromium_row_uses_msaa(row, {1}, 256));
    assert(!vox_chromium_row_uses_msaa(0, {}, 256));
    for (auto rows : {std::vector<char>{0,0,0,0}, {1,1,1,1}, {1,0,1,0}}) {
        std::vector<uint32_t> pixels(12, 37);
        int calls = 0;
        assert(vox_draw_with_msaa_rows(pixels, 3, rows, [&](auto& target, bool msaa) {
            ++calls; assert(target == std::vector<uint32_t>(12, 37));
            std::fill(target.begin(), target.end(), msaa ? 83 : 149); return true;
        }));
        for (size_t row = 0; row < rows.size(); ++row)
            for (int column = 0; column < 3; ++column) assert(pixels[row*3+column] == (rows[row] ? 83 : 149));
        assert(calls == (rows[0] == rows[1] ? 1 : 2));
    }
    for (bool fail_msaa : {false, true}) {
        std::vector<uint32_t> pixels(12, 37);
        assert(!vox_draw_with_msaa_rows(pixels, 3, {1,0,1,0}, [&](auto& target, bool msaa) {
            std::fill(target.begin(), target.end(), 255); return msaa != fail_msaa;
        }));
        assert(pixels == std::vector<uint32_t>(12, 37));
    }
    // Exhaustive short masks cover leading/trailing runs and alternating
    // single pixels, with both pixel masks and multi-pixel raster rows.
    for (int width : {1, 3, 17}) for (unsigned mask = 0; mask < 256; ++mask) {
        std::vector<char> rows(8);
        std::vector<uint32_t> pixels(8 * width);
        for (size_t i = 0; i < pixels.size(); ++i) pixels[i] = uint32_t(i);
        auto original = pixels;
        for (size_t row = 0; row < rows.size(); ++row) rows[row] = (mask >> row) & 1;
        assert(vox_draw_with_msaa_rows(pixels, width, rows, [&](auto& target, bool msaa) {
            assert(target == original);
            for (auto& pixel : target) pixel += msaa ? 1000 : 2000;
            return true;
        }));
        for (size_t i = 0; i < pixels.size(); ++i)
            assert(pixels[i] == original[i] + (rows[i / width] ? 1000 : 2000));
    }
}
