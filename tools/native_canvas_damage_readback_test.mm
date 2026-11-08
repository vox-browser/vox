// Keep the release archive's private container layouts under ASan/UBSan.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#define VOX_TEST_CANVAS_BLIT_FAILURE 1
#include "../native_graphite_darwin.mm"
#include <cassert>

static std::vector<uint8_t> damaged_canvas(int count, bool legacy, int fail_after = -1) {
    if (legacy) setenv("VOX_DISABLE_LARGE_CANVAS_BLIT", "1", 1);
    else unsetenv("VOX_DISABLE_LARGE_CANVAS_BLIT");
    vox_test_canvas_blit_fail_after = fail_after;
    unsigned calls = vox_test_canvas_blit_calls;
    std::vector<int> rects;
    for (int i=0; i<count; ++i) {
        int x=(i%7)*40, y=(i/7)*40;
        rects.insert(rects.end(), {x,y,32,32,x+2,y+3,27,24});
    }
    assert(vox_graphite_canvas_begin(rects.data(),count));
    std::vector<std::vector<uint8_t>> pixels(count,std::vector<uint8_t>(32*32*4));
    std::vector<VoxGraphitePixelRegion> output;
    for (int i=0;i<count;++i) {
        for (int pixel=0;pixel<32*32;++pixel) {
            pixels[i][pixel*4]=uint8_t((pixel+i*13)%256);
            pixels[i][pixel*4+1]=uint8_t((pixel*3+i*7)%256);
            pixels[i][pixel*4+2]=uint8_t((pixel*5+i*11)%256);
            pixels[i][pixel*4+3]=255;
        }
        assert(vox_graphite_canvas_upload(i,pixels[i].data(),32*4));
        output.push_back({0,0,32,32,32*4,pixels[i].data()});
    }
    // Translucent paint crosses several damage rectangles and their gaps.
    for (auto const& tile:canvas_tiles) {
        auto* canvas=tile.surface->getCanvas();
        canvas->save(); canvas->clipRect(SkRect::Make(tile.clip));
        SkPaint paint; paint.setColor4f({.15f,.25f,.35f,.5f});
        canvas->drawOval(SkRect::MakeXYWH(-2.25f,4.5f,34,22),paint);
        canvas->restore();
    }
    // Invalid output is rejected before staging or modifying caller bytes.
    auto invalid=output;invalid.back().pitch=1;
    auto sentinel=pixels;
    assert(!vox_graphite_canvas_read(invalid.data(),count));
    assert(pixels==sentinel && vox_test_canvas_blit_calls==calls);
    assert(vox_graphite_canvas_read(output.data(),count));
    bool batched=!legacy && count>8 && fail_after<0;
    assert(vox_test_canvas_blit_calls==calls+unsigned(batched));
    // A CPU edit followed by a new upload/draw cannot return stale staged data.
    for (int i=0;i<count;++i) {
        pixels[i][5*32*4+4*4]=0;
        assert(vox_graphite_canvas_upload(i,pixels[i].data(),32*4));
    }
    assert(vox_graphite_canvas_read(output.data(),count));
    assert(vox_test_canvas_blit_calls==calls+unsigned(batched)*2);
    vox_graphite_canvas_end();
    std::vector<uint8_t> result;
    for (auto const& region:pixels) result.insert(result.end(),region.begin(),region.end());
    return result;
}

int main() { @autoreleasepool {
    unsetenv("VOX_GPU_CANVAS_BLIT_READBACK");
    for (int count:{1,8,9,16,36,49}) {
        auto expected=damaged_canvas(count,true);
        assert(damaged_canvas(count,false)==expected);
        if (count>8) {
            assert(damaged_canvas(count,false,0)==expected);
            assert(damaged_canvas(count,false,count-1)==expected);
        }
    }
    assert(vox_graphite_retire_graphics_context());
    std::puts("1/8/9/16/36/49 damage regions: exact readback, batched submission, CPU edits, invalid views and allocation-failure fallback passed");
} }
