// Standalone macOS checks for the actual native gradient tile compositor.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static int calls;
static long expected_first_row;
static float expected_matrix_y;
static int fake_draw(uint8_t* bytes, int width, int height, int pitch,
    int has_background, VoxGraphitePath const* descriptor)
{
    assert(width == 16 && height == 256 && pitch == 64 && has_background);
    assert(descriptor->matrix[2] == 5.25f);
    long first_tile = expected_first_row <= 254 ? 0 : (expected_first_row - 1) / 254;
    assert(descriptor->matrix[5] == expected_matrix_y + expected_first_row
        - (first_tile + calls) * 254);
    auto* pixels = reinterpret_cast<uint32_t*>(bytes);
    for (int y = 0; y < height; ++y)
        for (int x = 0; x < width; ++x)
            pixels[y * width + x] = 0xff000000u | (y << 16) | (x << 8)
                | (pixels[y * width + x] & 255);
    ++calls;
    return 1;
}

static void clipped_generated_tile_bounds(int scale, bool pattern)
{
    constexpr int size = 256;
    constexpr float x = 10.25f, y = 20.5f, w = 183.5f, h = 157.25f;
    std::vector<uint8_t> pixels(size * size * scale * scale * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto destination = CGBitmapContextCreate(pixels.data(), size * scale, size * scale,
        8, size * scale * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(destination && shared_picture_draw());
    CGContextScaleCTM(destination, scale, scale);
    float segments[] {
        0,x,y,0,0,0,0,0,0,0,0,0,
        1,x+w,y,0,0,0,0,0,0,0,0,0,
        1,x+w,y+h,0,0,0,0,0,0,0,0,0,
        1,x,y+h,0,0,0,0,0,0,0,0,0,
        5,0,0,0,0,0,0,0,0,0,0,0,
    };
    float stops[] {1,0,0,1,0, 0,0,1,1,1};
    float clip[] {x,y,w,h,7,7,7,7,7,7,7,7};
    float ancestor[] {x+4,y+5,w-8,h-10,0,0,0,0,0,0,0,0};
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0,size,size);
    ladybird_v_skia_set_raster_layer(0,0,0);
    ladybird_v_skia_set_raster_layer_size(size,size);
    int cell = 0;
    ladybird_v_skia_set_msaa_grid(&cell,1,258*scale,258*scale,1);
    ladybird_v_skia_set_layer_shared_recording(1);
    for (int tile=0;tile<2;++tile) {
        assert(ladybird_v_skia_draw_clipped_svg_linear_gradient_path(destination,segments,5,0,
            1,0,0,1,0,0,0,0,0,size,size,0,0,0,0,4,
            0,0,w,h,1,0,0,1,x+tile*(w+1),y,pattern?3:4,0,stops,2,1,0,clip,ancestor));
        assert(s_shared_root_recording && s_shared_root_recording->replay_bounds.size()==1);
        auto bounds = s_shared_root_recording->replay_bounds.front();
        assert(bounds==SkRect::MakeXYWH(ancestor[0],ancestor[1],ancestor[2],ancestor[3]));
        // The next generated tile lies beyond the background's clip.
        for (int index=0;index<4;++index) segments[index*12+1] += w+1;
    }
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_layer_shared_recording(0);
    ladybird_v_skia_set_chromium_painting(0);
    CGContextRelease(destination);
}

int main()
{
    ladybird_v_skia_set_msaa_tiles(nullptr, 0, 256);
    for (auto row : {0, 1, 253, 254}) assert(chromium_raster_tile_for_row(row) == 0);
    for (auto row : {255, 256, 507, 508}) assert(chromium_raster_tile_for_row(row) == 1);
    assert(chromium_raster_tile_for_row(509) == 2);
    assert(chromium_raster_tile_for_row(763) == 3);
    RasterRegion region {3, 125, 7, 775};
    assert(chromium_root_gradient_tiles_eligible(1, 0, 0, true, 16, region));
    assert(!chromium_root_gradient_tiles_eligible(2, 0, 0, true, 16, region));
    assert(!chromium_root_gradient_tiles_eligible(1, 0, 0, false, 16, region));
    assert(!chromium_root_gradient_tiles_eligible(1, 0, 0, true, 6, region));
    assert(!chromium_root_gradient_tiles_eligible(1, 0, 0, true, 40000, region));
    ladybird_v_skia_set_root_raster_scroll_y(1);
    assert(chromium_root_gradient_tiles_eligible(1, 0, 0, true, 16, region));
    ladybird_v_skia_set_root_raster_scroll_y(6400);
    assert(chromium_root_gradient_tiles_eligible(1, 0, 60, true, 16, region));
    for (double offset : {0.5, -1.0, double(INT_MAX) + 1, double(INFINITY), double(NAN)}) {
        ladybird_v_skia_set_root_raster_scroll_y(offset);
        assert(!chromium_root_gradient_tiles_eligible(1, 0, 0, true, 16, region));
    }
    ladybird_v_skia_set_root_raster_scroll_y(0);

    for (long scroll : {0, 6400}) {
        std::vector<uint32_t> pixels(4 * 650);
        for (size_t i = 0; i < pixels.size(); ++i) pixels[i] = i % 251;
        auto backdrop = pixels;
        VoxGraphitePath descriptor {};
        descriptor.matrix[2] = 2.25;
        descriptor.matrix[5] = 7.5f - scroll;
        expected_matrix_y = descriptor.matrix[5];
        expected_first_row = 125 + scroll;
        calls = 0;
        assert(draw_chromium_root_gradient_tiles(fake_draw, pixels, 4, 650, 16, 3,
            expected_first_row, descriptor));
        assert(calls == 4);
        for (int y = 0; y < 650; ++y) {
            int document_row = expected_first_row + y;
            int tile_row = document_row - chromium_raster_tile_for_row(document_row) * 254;
            for (int x = 0; x < 4; ++x)
                assert(pixels[y * 4 + x] == (0xff000000u | (tile_row << 16)
                    | ((x + 3) << 8) | backdrop[y * 4 + x]));
        }
        assert(descriptor.matrix[2] == 2.25f && descriptor.matrix[5] == expected_matrix_y);
        assert(!draw_chromium_root_gradient_tiles(nullptr, pixels, 4, 650, 16, 3, 125, descriptor));
    }
    ladybird_v_skia_set_msaa_tiles(nullptr, 0, 416);
    assert(chromium_raster_tile_for_row(414) == 0);
    assert(chromium_raster_tile_for_row(415) == 1);
    for (int scale : {1,2}) for (bool pattern : {false,true})
        clipped_generated_tile_bounds(scale,pattern);
    std::puts("PASS: native gradient tile ownership, coordinates, backdrop and fallback gates");
}
