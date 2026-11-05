// The linked Skia archive has release TArray layouts. ASan adds an extra
// TArray field when this macro is set, breaking private Graphite offsets.
// Keep those layouts compatible while Clang still instruments this entire
// fixture and the included Vox implementation with ASan/UBSan.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#define VOX_TEST_ISOLATED_CANVAS_FAILURE
#include "../native_graphite_darwin.mm"
#include <cassert>
#include "../native_chromium_screen_blend.h"
#include "../native_opacity_group_darwin.h"

static std::vector<uint8_t> read_surface(skgpu::graphite::Context* gpu,
    skgpu::graphite::Recorder* recorder, SkSurface* surface) {
    auto recording = recorder->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        assert(gpu->insertRecording(insertion) == skgpu::graphite::InsertStatus::kSuccess);
    }
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface, surface->imageInfo(),
        SkIRect::MakeWH(surface->width(), surface->height()), SkImage::RescaleGamma::kSrc,
        SkImage::RescaleMode::kNearest,
        [](void* owner, std::unique_ptr<const SkImage::AsyncReadResult> pixels) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(owner) = std::move(pixels);
        }, &result);
    assert(result);
    std::vector<uint8_t> output(size_t(surface->width()) * surface->height() * 4);
    for (int y = 0; y < surface->height(); ++y)
        std::memcpy(output.data() + size_t(y) * surface->width() * 4,
            static_cast<uint8_t const*>(result->data(0)) + size_t(y) * result->rowBytes(0),
            size_t(surface->width()) * 4);
    return output;
}

int main() { @autoreleasepool {
    auto* gpu = context(); assert(gpu);
    auto recorder = gpu->makeRecorder(); assert(recorder);
    for (auto [width, height] : {std::pair{37, 29}, {1024, 512}, {3421, 1906}}) {
        auto info = canvas_info(width, height);
        auto reference = vox_shared_surface(recorder.get(), info);
        auto linear = vox_shared_surface(recorder.get(), info, true);
        assert(reference && linear);
        assert(!vox_shared_metal_texture(reference.get()).buffer);
        auto texture = vox_shared_metal_texture(linear.get());
        assert(texture && texture.buffer && texture.bufferBytesPerRow >= size_t(width) * 4);
        std::vector<uint32_t> backdrop(9 * 5, 0x80306020);
        for (auto* surface : {reference.get(), linear.get()}) {
            surface->getCanvas()->clear(SK_ColorBLUE);
            // Pending GPU writers finish before a padded partial CPU upload.
            vox_shared_write(gpu, surface, SkPixmap(info.makeWH(7, 5), backdrop.data(), 9 * 4), 2, 3);
            auto* canvas = surface->getCanvas();
            SkPaint paint; paint.setAntiAlias(true); paint.setColor(0x9050d030);
            canvas->drawRoundRect(SkRect::MakeXYWH(.25f, .5f, width - 2.75f, height - 3.5f), 5, 7, paint);
            canvas->save();
            canvas->clipRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(5.5f, 6.25f, 20, 16), 3, 4), true);
            paint.setColor(0x70ff2080); canvas->drawCircle(15.25f, 13.5f, 12.75f, paint);
            canvas->restore();
        }
        auto expected = read_surface(gpu, recorder.get(), reference.get());
        auto actual = read_surface(gpu, recorder.get(), linear.get());
        assert(expected == actual);
        linear->getCanvas()->clear(SK_ColorGREEN);
        auto reused = read_surface(gpu, recorder.get(), linear.get());
        assert(actual == expected && reused != expected);
    }
    for (int linear = 0; linear < 2; ++linear) for (int staged = 0; staged < 2; ++staged) {
    canvas_reset();
    if (linear) setenv("VOX_GPU_CANVAS_LINEAR_TEXTURES", "1", 1);
    else unsetenv("VOX_GPU_CANVAS_LINEAR_TEXTURES");
    if (staged) setenv("VOX_GPU_CANVAS_STAGED_UPLOAD", "1", 1);
    else unsetenv("VOX_GPU_CANVAS_STAGED_UPLOAD");
    int rects[] {3, 7, 37, 29, 3, 7, 37, 29, 48, 1, 19, 13, 48, 1, 19, 13};
    assert(vox_graphite_canvas_begin(rects, 2));
    for (size_t index = 0; index < canvas_tiles.size(); ++index) {
        auto const& tile = canvas_tiles[index];
        assert(bool(vox_shared_metal_texture(tile.surface.get()).buffer) == bool(linear));
        // A queued draw precedes the replacement. The upload owns its bytes
        // before returning, even though that replacement runs later on the GPU.
        tile.surface->getCanvas()->clear(SK_ColorRED);
        std::vector<uint32_t> pixels(size_t(tile.width + 3) * tile.height, 0xff20a040 + index);
        assert(!vox_graphite_canvas_upload(int(index), reinterpret_cast<uint8_t const*>(pixels.data()), tile.width * 4 - 1));
        assert(vox_graphite_canvas_upload(int(index), reinterpret_cast<uint8_t const*>(pixels.data()), (tile.width + 3) * 4));
        std::fill(pixels.begin(), pixels.end(), 0xdeadc0de);
    }
    if (staged) {
        auto recording = canvas_recorder->snap();
        assert(recording); // The uploads stayed queued with their pending draws.
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        assert(gpu->insertRecording(insertion) == skgpu::graphite::InsertStatus::kSuccess);
    }
    VoxGraphiteShape shape {.matrix={1,0,0,0,1,0,0,0,1},
        .rect={8,12,10,8,3,3,3,3,3,3,3,3}, .red=240, .green=80, .blue=40,
        .alpha=128, .fill=1, .anti_alias=1};
    float bounds[] {6,10,20,22};
    int msaa[] {0,0,16,16};
    vox_test_isolated_shape_fail_after=0;
    assert(!vox_graphite_canvas_draw_shape_isolated(&shape,bounds,nullptr,0,msaa,1));
    std::vector<uint8_t> unchanged(37*4*29);
    uint32_t other=0;
    VoxGraphitePixelRegion check[] {{0,0,37,29,37*4,unchanged.data()},
        {0,0,1,1,4,reinterpret_cast<uint8_t*>(&other)}};
    assert(vox_graphite_canvas_read_direct(check,2));
    for (size_t pixel=0;pixel<37*29;++pixel)
        assert(reinterpret_cast<uint32_t*>(unchanged.data())[pixel]==0xff20a040);
    assert(other==0xff20a041);
    vox_test_isolated_shape_fail_after=-1;
    assert(vox_graphite_canvas_draw_shape_isolated(&shape,bounds,nullptr,0,msaa,1));
    std::vector<uint32_t> replacement(5*2,0x40102030);
    assert(!vox_graphite_canvas_copy_pixels(reinterpret_cast<uint8_t const*>(replacement.data()),0,2,20,12,14));
    assert(vox_graphite_canvas_copy_pixels(reinterpret_cast<uint8_t const*>(replacement.data()),3,2,20,12,14));
    std::fill(replacement.begin(),replacement.end(),0xdeadc0de);
    std::vector<uint8_t> first(43 * 4 * 29, 0xa7), second(24 * 4 * 13, 0xa7);
    VoxGraphitePixelRegion views[] {{0, 0, 37, 29, 43 * 4, first.data()},
        {0, 0, 19, 13, 24 * 4, second.data()}};
    assert(vox_graphite_canvas_read_direct(views, 2));
    assert(*reinterpret_cast<uint32_t*>(first.data()+7*43*4+9*4)==0x40102030);
    for (int y = 0; y < 29; ++y) {
        assert(*reinterpret_cast<uint32_t*>(first.data() + y * 43 * 4) == 0xff20a040);
        for (int x = 37 * 4; x < 43 * 4; ++x) assert(first[y * 43 * 4 + x] == 0xa7);
    }
    for (int y = 0; y < 13; ++y) {
        assert(*reinterpret_cast<uint32_t*>(second.data() + y * 24 * 4) == 0xff20a041);
        for (int x = 19 * 4; x < 24 * 4; ++x) assert(second[y * 24 * 4 + x] == 0xa7);
    }
    vox_graphite_canvas_end();
    }
    for (int iteration=0; iteration<12; ++iteration) {
        canvas_reset();
        constexpr int width=79,height=53;
        IOSurfaceRef frame = IOSurfaceCreate((__bridge CFDictionaryRef)@{
            (__bridge id)kIOSurfaceWidth:@(width), (__bridge id)kIOSurfaceHeight:@(height),
            (__bridge id)kIOSurfaceBytesPerElement:@4,
            (__bridge id)kIOSurfacePixelFormat:@((uint32_t)'RGBA')});
        assert(frame && IOSurfaceLock(frame,0,nullptr)==kIOReturnSuccess);
        size_t pitch=IOSurfaceGetBytesPerRow(frame);
        auto* pixels=static_cast<uint8_t*>(IOSurfaceGetBaseAddress(frame));
        std::memset(pixels,0xa7,pitch*height);
        // Disjoint damage, overlapping tiles and alpha replacement preserve
        // exact channels, damage order and all untouched bytes, including pitch.
        int rects[] {3,7,37,29, 5,9,31,23, 30,20,39,25, 32,23,33,19};
        assert(vox_graphite_canvas_begin(rects,2));
        for (int index=0;index<2;++index) {
            auto const& tile=canvas_tiles[index];
            std::vector<uint32_t> input(size_t(tile.width)*tile.height,0x80203040+index);
            assert(vox_graphite_canvas_upload(index,reinterpret_cast<uint8_t*>(input.data()),tile.width*4));
            SkPaint paint; paint.setColor(0x9020a040); paint.setAntiAlias(true);
            tile.surface->getCanvas()->drawCircle(12.25f,11.5f,8.75f,paint);
        }
        // An invalid destination declines without consuming pending draws or
        // writing bytes. The next transfer still includes those pending draws.
        assert(!vox_graphite_canvas_read_iosurface(frame,width-1,height));
        for (size_t byte=0;byte<pitch*height;++byte) assert(pixels[byte]==0xa7);
        std::vector<uint8_t> expected(pitch*height,0xa7);
        std::vector<std::vector<uint32_t>> read(2);
        VoxGraphitePixelRegion views[2];
        for (int index=0;index<2;++index) {
            auto const& tile=canvas_tiles[index];
            read[index].resize(size_t(tile.clip.width())*tile.clip.height());
            views[index]={tile.clip.x(),tile.clip.y(),tile.clip.width(),tile.clip.height(),
                tile.clip.width()*4,reinterpret_cast<uint8_t*>(read[index].data())};
        }
        // Retain a CPU reference, then queue another identical paint so the
        // IOSurface path is also tested with pending source commands.
        assert(vox_graphite_canvas_read_direct(views,2));
        for (int index=0;index<2;++index) {
            auto const& tile=canvas_tiles[index];
            for (int y=0;y<tile.clip.height();++y) for(int x=0;x<tile.clip.width();++x) {
                auto bgra=read[index][size_t(y)*tile.clip.width()+x];
                auto* out=expected.data()+size_t(tile.y+tile.clip.y()+y)*pitch+(tile.x+tile.clip.x()+x)*4;
                out[0]=(bgra>>16)&255;out[1]=(bgra>>8)&255;out[2]=bgra&255;out[3]=bgra>>24;
            }
            SkPaint copy;copy.setBlendMode(SkBlendMode::kSrc);
            tile.surface->getCanvas()->drawRect(SkRect::MakeXYWH(0,0,1,1),copy);
        }
        assert(vox_graphite_canvas_read_iosurface(frame,width,height)==1);
        assert(!std::memcmp(pixels,expected.data(),expected.size()));
        // CPU access is locked again and the same frame can be transferred a
        // second time. No imported frame texture escapes the temporary recorder.
        assert(vox_graphite_canvas_read_iosurface(frame,width,height)==1);
        assert(!std::memcmp(pixels,expected.data(),expected.size()));
        assert(!IOSurfaceIsInUse(frame));
        assert(IOSurfaceUnlock(frame,0,nullptr)==kIOReturnSuccess);
        CFRelease(frame); vox_graphite_canvas_end();
    }
    canvas_reset();
    {
        constexpr int width=3416,height=1906;
        IOSurfaceRef frame=IOSurfaceCreate((__bridge CFDictionaryRef)@{
            (__bridge id)kIOSurfaceWidth:@(width),(__bridge id)kIOSurfaceHeight:@(height),
            (__bridge id)kIOSurfaceBytesPerElement:@4,
            (__bridge id)kIOSurfacePixelFormat:@((uint32_t)'RGBA')});
        assert(frame && IOSurfaceLock(frame,0,nullptr)==kIOReturnSuccess);
        int rects[]={0,0,width,height,0,0,width,height};
        assert(vox_graphite_canvas_begin(rects,1));
        std::vector<uint32_t> source(size_t(width)*height);
        for(size_t pixel=0;pixel<source.size();++pixel) {
            unsigned alpha=32+pixel%224;
            source[pixel]=(alpha<<24)|(((pixel*13)%(alpha+1))<<16)
                |(((pixel*7)%(alpha+1))<<8)|((pixel*3)%(alpha+1));
        }
        assert(vox_graphite_canvas_upload(0,reinterpret_cast<uint8_t*>(source.data()),width*4));
        std::vector<uint32_t> expected(source.size());
        VoxGraphitePixelRegion view{0,0,width,height,width*4,reinterpret_cast<uint8_t*>(expected.data())};
        auto* pixels=static_cast<uint8_t*>(IOSurfaceGetBaseAddress(frame));
        size_t pitch=IOSurfaceGetBytesPerRow(frame);
        std::memset(pixels,0xa7,pitch*height);
        for(int pass=0;pass<3;++pass) {
            auto* canvas=canvas_tiles[0].surface->getCanvas();
            force_msaa_render_pass(canvas,width,height);
            SkPaint paint;paint.setAntiAlias(true);paint.setColor(0x704080c0);
            canvas->drawRoundRect(SkRect::MakeXYWH(5.25f+pass,9.5f,width-11.75f,height-17.25f),23.5f,19.25f,paint);
            assert(vox_graphite_canvas_read_iosurface(frame,width,height)==1);
            assert(vox_graphite_canvas_read_direct(&view,1));
            for(int y=0;y<height;++y) for(int x=0;x<width;++x) {
                auto bgra=expected[size_t(y)*width+x];auto* actual=pixels+size_t(y)*pitch+x*4;
                assert(actual[0]==((bgra>>16)&255) && actual[1]==((bgra>>8)&255)
                    && actual[2]==(bgra&255) && actual[3]==(bgra>>24));
            }
            for(int y=0;y<height;++y) for(size_t x=width*4;x<pitch;++x) assert(pixels[y*pitch+x]==0xa7);
        }
        assert(!IOSurfaceIsInUse(frame));
        assert(IOSurfaceUnlock(frame,0,nullptr)==kIOReturnSuccess);
        CFRelease(frame);vox_graphite_canvas_end();
    }
    canvas_reset();
    setenv("VOX_GPU_CANVAS_NATIVE_GRID","1",1);
    std::vector<int> grid;
    for(int index=0;index<32;++index) {
        int x=(index%8)*128,y=(index/8)*128;
        grid.insert(grid.end(),{x,y,128,128,x+3,y+5,121,117});
    }
    assert(vox_graphite_canvas_begin_native_grid(grid.data(),32));
    std::vector<uint32_t> source(128*128,0xff203040);
    for(int index=0;index<32;++index) {
        assert(canvas_tiles[index].surface->width()==128 && canvas_tiles[index].surface->height()==128);
        assert(vox_graphite_canvas_upload(index,reinterpret_cast<uint8_t*>(source.data()),128*4));
    }
    VoxGraphiteShape grid_shape{.matrix={1,0,0,0,1,0,0,0,1},.rect={5,7,80,63,4,4,4,4,4,4,4,4},
        .red=40,.green=100,.blue=200,.alpha=255,.fill=1,.anti_alias=1};
    float bounds[]={3,5,87,72};int msaa[]={0,0,128,128};
    assert(vox_graphite_canvas_draw_shape_native_grid(&grid_shape,bounds,nullptr,0,msaa,1));
    auto invalid=grid;invalid[2]=16384;invalid[3]=16384;
    assert(!vox_graphite_canvas_begin_native_grid(invalid.data(),32));
    std::vector<uint32_t> output(32);
    std::vector<VoxGraphitePixelRegion> views;
    for(int index=0;index<32;++index)views.push_back({index?127:40,index?127:40,1,1,4,reinterpret_cast<uint8_t*>(&output[index])});
    assert(vox_graphite_canvas_read(views.data(),32));
    assert(output[0]==0xff2864c8);
    for(int index=1;index<32;++index)assert(output[index]==0xff203040);
    vox_graphite_canvas_end();assert(canvas_surface_pool.size()==32);
    unsetenv("VOX_GPU_CANVAS_NATIVE_GRID");
    canvas_reset();
    for (int blend : {0, 3}) for (float opacity : {0.f, .01f, .25f, .5f, .85f, .999f, 1.f}) {
        constexpr int w = 67, h = 53, pitch = w * 4;
        std::vector<uint8_t> input(pitch * h), backdrop(input.size()), expected(input.size()), actual(input.size());
        for (int pixel = 0; pixel < w * h; ++pixel) {
            int sa = (pixel * 17) % 256, da = (pixel * 23) % 256;
            for (int c = 0; c < 3; ++c) {
                input[pixel * 4 + c] = (pixel * (c + 3)) % (sa + 1);
                backdrop[pixel * 4 + c] = (pixel * (c + 7)) % (da + 1);
            }
            input[pixel * 4 + 3] = sa; backdrop[pixel * 4 + 3] = da;
        }
        if (blend == 3) native_composite_screen_pixels(input.data(), backdrop.data(), expected.data(), w * h, opacity);
        else native_composite_opacity_pixels(input.data(), backdrop.data(), expected.data(), w * h, opacity);
        int rect[] {0, 0, w, h, 0, 0, w, h};
        assert(vox_graphite_canvas_begin(rect, 1));
        assert(vox_graphite_canvas_upload(0, backdrop.data(), pitch));
        assert(!vox_graphite_canvas_draw_layer_pixels(input.data(), w, h, pitch, 0, 0, nullptr, 0, opacity, 1));
        assert(vox_graphite_canvas_draw_layer_pixels(input.data(), w, h, pitch, 0, 0, nullptr, 0, opacity, blend));
        std::fill(input.begin(), input.end(), 0xdd); input.clear(); input.shrink_to_fit();
        VoxGraphitePixelRegion view {0, 0, w, h, pitch, actual.data()};
        assert(vox_graphite_canvas_read(&view, 1));
        assert(actual == expected);
        vox_graphite_canvas_end();
    }
    canvas_reset(); recorder.reset(); gpu_context.reset();
    std::puts("Metal canvas: exact odd/large targets, alpha/AA/clips, pending GPU writes, immediate/staged uploads with dead sources, linear/ordinary textures, reuse, buffer lifetime, direct readback and row padding passed");
} }
