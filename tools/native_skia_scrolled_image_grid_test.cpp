// Root scrolling projects an independent layer's images into the viewport.
// Compare those image leaves with full GPU tiles at the layer's document origin.
#ifdef VOX_SKIA_TEXT_UNDER_TEST
#include VOX_SKIA_TEXT_UNDER_TEST
#else
#include "../native_skia_text_darwin.cpp"
#endif
#include <cassert>
#include <cstdio>

static size_t check_image_bridge(char const* library_path = nullptr)
{
    auto library = library_path ? dlopen(library_path, RTLD_NOW | RTLD_LOCAL) : nullptr;
    assert(!library_path || library);
    auto resolve = [library](auto own, char const* name) {
        auto function = library ? reinterpret_cast<decltype(own)>(dlsym(library, name)) : own;
        assert(function);
        return function;
    };
    auto mode = resolve(&ladybird_v_skia_set_chromium_painting, "ladybird_v_skia_set_chromium_painting");
    auto layer = resolve(&ladybird_v_skia_set_raster_layer, "ladybird_v_skia_set_raster_layer");
    auto size = resolve(&ladybird_v_skia_set_raster_layer_size, "ladybird_v_skia_set_raster_layer_size");
    auto scroll = resolve(&ladybird_v_skia_set_root_raster_scroll_y, "ladybird_v_skia_set_root_raster_scroll_y");
    auto grid = resolve(&ladybird_v_skia_set_msaa_grid, "ladybird_v_skia_set_msaa_grid");
    auto rows = resolve(&ladybird_v_skia_set_msaa_tiles, "ladybird_v_skia_set_msaa_tiles");
    auto draw = resolve(&ladybird_v_skia_draw_rgba_image, "ladybird_v_skia_draw_rgba_image");
    std::vector<uint8_t> source(37 * 29 * 4);
    for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 37 + i / 11);
    size_t mismatches = 0;
    for (int scale : {1, 2}) for (int selected : {0, 1, 2, 3})
    for (int root_scroll : {10400, 10701}) {
        int width = 1280 * scale, height = 884 * scale;
        // Native readable canvases use RGBA bytes, including at scale two.
        std::vector<uint32_t> actual(size_t(width) * height, 0xff1f1915);
        auto expected = actual;
        for (bool projected : {false, true}) {
            auto& pixels = projected ? actual : expected;
            auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context);
            CGColorSpaceRelease(color);
            CGContextScaleCTM(context, scale, scale);
            mode(1);
            // Equivalent coordinate bases: an already projected layer origin,
            // or a document origin plus the root viewport's explicit scroll.
            layer(48, 6321 - (projected ? 0 : root_scroll), 0);
            size(1184, 5179);
            scroll(projected ? root_scroll : 0);
            rows(nullptr, 0, 256 * scale);
            int tiles[2], count = 0;
            if (selected & 1) tiles[count++] = 17;
            if (selected & 2) tiles[count++] = 18;
            grid(tiles, count, 1216 * scale, 256 * scale, 1);
            float radii[] {5, 5, 5, 5, 5, 5, 5, 5};
            assert(draw(context, source.data(), 37, 29, 37 * 4, 867, 10860, 120, 96,
                2, 3, 31, 23, 867, 10860, 120, 96, 1, 0, 0, 1, 0, -root_scroll,
                0, 60, 7, 1280, 884, .8f, 0, 2, radii));
            CGContextFlush(context);
            CGContextRelease(context);
        }
        for (size_t i = 0; i < actual.size(); ++i) mismatches += actual[i] != expected[i];
    }
    mode(0);
    std::printf("Image bridge: 16 scenes, %zu differing pixels\n", mismatches);
    return mismatches;
}

int main(int argc, char** argv)
{
    assert(argc == 1 || argc == 2);
    if (argc == 2) return check_image_bridge(argv[1]) ? 1 : 0;
    auto draw = graphite_image_draw();
    assert(draw && graphite_image_region_draw());
    std::vector<uint8_t> source(37 * 29 * 4);
    for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 37 + i / 11);
    int cases = 0, rejected = 0;
    size_t mismatches = 0;
    // These document coordinates also occur in vlang.io's resumed footer layer.
    constexpr int document_x = 867, document_y = 10860;
    constexpr int layer_x = 48, layer_y = 6321;
    for (int scale : {1, 2}) for (int selected : {0, 1, 2, 3})
    for (int root_scroll : {1000, 10701}) for (int page_y : {0, 60})
    for (int local_scroll : {0, 7}) {
        int width = 120 * scale, height = 96 * scale;
        int tile_width = 1216 * scale, tile_height = 256 * scale;
        int first_x = (document_x - layer_x) * scale;
        int first_y = (document_y - layer_y) * scale;
        int spacing = tile_height - 2;
        // Both scales intersect precisely rows 17 and 18. Their shared border
        // belongs to row 17, so row 18 starts one texel after its raster origin.
        assert(first_y >= 17 * spacing && first_y + height <= 18 * spacing + tile_height);
        int tiles[2], count = 0;
        if (selected & 1) tiles[count++] = 17;
        if (selected & 2) tiles[count++] = 18;
        ladybird_v_skia_set_msaa_tiles(nullptr, 0, tile_height);
        ladybird_v_skia_set_msaa_grid(tiles, count, tile_width, tile_height, 1);
        ladybird_v_skia_set_raster_layer(layer_x, layer_y, 0);
        ladybird_v_skia_set_raster_layer_size(1184, 5179);
        ladybird_v_skia_set_root_raster_scroll_y(root_scroll);
        RasterRegion region {document_x, document_y + page_y - root_scroll - local_scroll,
            document_x + 120, document_y + page_y - root_scroll - local_scroll + 96};
        VoxGraphiteImage image {
            .matrix = {float(scale), 0, float(-document_x * scale),
                0, float(scale), float(-document_y * scale), 0, 0, 1},
            .source = {2, 3, 31, 23},
            .destination = {document_x, document_y, 120, 96},
            .clip = {document_x, document_y, 120, 96, 5, 5, 5, 5, 5, 5, 5, 5},
            .opacity = .8f, .width = 37, .height = 29, .pitch = 37 * 4,
            .pixels = source.data()
        };
        std::vector<uint32_t> actual(size_t(width) * height, 0xff15191f);
        auto backdrop = actual, expected = actual;
        // Independent oracle: two full GPU surfaces. Copy each output row
        // according to the fixed seam, without the compact grid iterator.
        int seam = 18 * spacing + 1 - first_y;
        for (int row : {17, 18}) {
            int origin_y = row * spacing;
            std::vector<uint32_t> tile(size_t(tile_width) * tile_height);
            for (int y = 0; y < height; ++y) {
                int tile_y = first_y + y - origin_y;
                if (tile_y >= 0 && tile_y < tile_height)
                    std::copy_n(backdrop.data() + size_t(y) * width, width,
                        tile.data() + size_t(tile_y) * tile_width + first_x);
            }
            auto full = image;
            full.matrix[2] = -layer_x * scale;
            full.matrix[5] = -layer_y * scale - origin_y;
            if (selected & (row == 17 ? 1 : 2)) full.flags |= VOX_GRAPHITE_IMAGE_FORCE_MSAA;
            assert(draw(reinterpret_cast<uint8_t*>(tile.data()), tile_width, tile_height,
                tile_width * 4, 1, &full));
            int begin = row == 17 ? 0 : seam, end = row == 17 ? seam : height;
            for (int y = begin; y < end; ++y)
                std::copy_n(tile.data() + size_t(first_y + y - origin_y) * tile_width + first_x,
                    width, expected.data() + size_t(y) * width);
        }
        bool tiled = draw_chromium_layer_image_tiles(actual, width, height, region,
            scale, 0, page_y, local_scroll, 1280, true, image);
        if (!tiled) {
            // Exercise the old fallback too: negative layer-relative rows have
            // no MSAA selection and draw the image in a tight leaf surface.
            ++rejected;
            auto rows = chromium_layer_msaa_rows(region.top, height, page_y, local_scroll, scale);
            assert(vox_draw_with_msaa_rows(actual, width, rows, [&](auto& pixels, bool msaa) {
                auto leaf = image;
                if (msaa) leaf.flags |= VOX_GRAPHITE_IMAGE_FORCE_MSAA;
                return draw(reinterpret_cast<uint8_t*>(pixels.data()), width, height,
                    width * 4, 1, &leaf) != 0;
            }));
        }
        for (size_t i = 0; i < actual.size(); ++i) mismatches += actual[i] != expected[i];
        assert(image.matrix[2] == -document_x * scale && image.matrix[5] == -document_y * scale);
        ++cases;
    }
    std::printf("Scrolled image grids: %d scenes, %d rejected grids, %zu differing pixels\n",
        cases, rejected, mismatches);
    return check_image_bridge() || rejected || mismatches ? 1 : 0;
}
