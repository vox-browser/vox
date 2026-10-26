// A shifted root may place a leaf's first rows before the first raster tile.
// Those rows retain their backdrop; visible rows must match a full root draw.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto draw = graphite_image_draw();
    assert(draw);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_root_raster_scroll_y(0);
    int cases = 0;
    uint8_t source[] {23, 51, 73, 255};
    for (int scale : {1, 2}) for (int tile_rows : {32, 256, 416})
    for (int first_row : {-513, -37, -1, 0, 1, 29, 255}) {
        ladybird_v_skia_set_msaa_tiles(nullptr, 0, tile_rows);
        int width = 4 * scale, height = 530 * scale, root_width = 16 * scale;
        int offset_x = 3 * scale;
        std::vector<uint32_t> pixels(size_t(width) * height);
        for (size_t i = 0; i < pixels.size(); ++i) pixels[i] = 0xff000000u | (i % 251);
        auto backdrop = pixels;
        VoxGraphiteImage image {
            .matrix = {1, 0, 0, 0, 1, 0, 0, 0, 1},
            .source = {0, 0, 1, 1}, .destination = {0, 0, float(width), float(height)},
            .clip = {0, 0, float(width), float(height)},
            .opacity = 1, .width = 1, .height = 1, .pitch = 4, .flags = 1,
            .nearest = 1, .pixels = source
        };
        // Independent oracle: one complete root, without tile-row indexing.
        int root_height = std::max(tile_rows, first_row + height);
        std::vector<uint32_t> root(size_t(root_width) * root_height);
        for (int y = 0; y < height; ++y) if (first_row + y >= 0)
            std::copy_n(backdrop.data() + size_t(y) * width, width,
                root.data() + size_t(first_row + y) * root_width + offset_x);
        auto full = image;
        full.matrix[2] = offset_x;
        full.matrix[5] = first_row;
        assert(draw(reinterpret_cast<uint8_t*>(root.data()), root_width,
            root_height, root_width * 4, 1, &full));
        RasterRegion region {3, 0, 7, height / scale};
        assert(draw_chromium_layer_image_tiles(pixels, width, height, region,
            scale, 0, -float(first_row) / scale, 0, 16, true, image));
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            auto expected = first_row + y < 0 ? backdrop[size_t(y) * width + x]
                : root[size_t(first_row + y) * root_width + offset_x + x];
            if (pixels[size_t(y) * width + x] != expected) {
                std::fprintf(stderr, "Root image mismatch scale=%d tile_rows=%d first_row=%d x=%d y=%d\n",
                    scale, tile_rows, first_row, x, y);
                return 1;
            }
        }
        assert(image.matrix[2] == 0 && image.matrix[5] == 0);
        ++cases;
    }
    std::printf("Root image rows: %d exact native comparisons passed\n", cases);
}
