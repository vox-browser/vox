#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include "include/core/SkCanvas.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkFont.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkSurface.h"
#include "include/core/SkSurfaceProps.h"
#include "include/core/SkTextBlob.h"
#include "include/ports/SkTypeface_mac.h"
#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

static bool rgba_bitmap(CGContextRef context)
{
    return CGBitmapContextGetBitsPerPixel(context) == 32
        && CGBitmapContextGetAlphaInfo(context) == kCGImageAlphaPremultipliedLast
        && (CGBitmapContextGetBitmapInfo(context) & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big;
}
static void swap_red_blue_pixels(uint8_t* output, uint8_t const* input, size_t count)
{
    for (size_t i = 0; i < count; ++i) {
        auto r = input[4*i], b = input[4*i+2];
        output[4*i] = b; output[4*i+1] = input[4*i+1];
        output[4*i+2] = r; output[4*i+3] = input[4*i+3];
    }
}
#include "../native_glyph_bitmap_copy.h"
#include "../native_glyph_bitmap_surface.h"

static CGContextRef frame(double scale, unsigned alpha, bool noisy)
{
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(nullptr, 96, 80, 8, 400, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(context);
    auto* data = static_cast<uint8_t*>(CGBitmapContextGetData(context));
    std::memset(data, 0x6d, 400*80);
    for (size_t y = 0; y < 80; ++y) for (size_t x = 0; x < 96; ++x) {
        auto* pixel = data+y*400+x*4;
        pixel[0] = uint8_t((noisy ? (x*13+y*7)%256 : 231)*alpha/255);
        pixel[1] = uint8_t((noisy ? (x*3+y*19)%256 : 218)*alpha/255);
        pixel[2] = uint8_t((noisy ? (x*5+y*11)%256 : 207)*alpha/255);
        pixel[3] = uint8_t(alpha);
    }
    CGContextScaleCTM(context, scale, scale);
    return context;
}

int main()
{
    auto native_font = CTFontCreateWithName(CFSTR("Helvetica"), 12, nullptr);
    auto typeface = SkMakeTypefaceFromCTFont(native_font);
    CFRelease(native_font); assert(typeface);
    unsigned cases = 0;
    for (double scale : {1.0, 1.25, 2.0}) for (unsigned alpha : {0u, 127u, 255u})
    for (bool noisy : {false, true}) for (float phase : {0.f, .125f, .5f, .875f})
    for (auto edging : {SkFont::Edging::kAlias, SkFont::Edging::kAntiAlias, SkFont::Edging::kSubpixelAntiAlias}) {
        auto actual = frame(scale, alpha, noisy), expected = frame(scale, alpha, noisy);
        auto* original = static_cast<uint8_t*>(CGBitmapContextGetData(actual));
        std::vector<uint8_t> before(original, original+400*80);
        auto snapshot = CGBitmapContextCreateImage(actual); assert(snapshot);
        SkFont font(typeface, 9); font.setSubpixel(true); font.setEdging(edging);
        SkTextBlobBuilder builder;
        auto const& run = builder.allocRunPos(font, 3);
        assert(font.textToGlyphs("Vox", 3, SkTextEncoding::kUTF8,
            SkSpan<SkGlyphID>(run.glyphs, 3)) == 3);
        for (int i = 0; i < 3; ++i) { run.pos[2*i] = 2+float(i)*6+phase; run.pos[2*i+1] = 12+phase; }
        auto blob = builder.make(); assert(blob);
        SkPaint paint; paint.setColor(SkColorSetARGB(191, 17, 83, 211));
        SkSurfaceProps props(0, kUnknown_SkPixelGeometry, 0.0f, 1.0f);
        auto matrix = SkMatrix::I();
        auto rect = CGRectMake(20/scale, 40/scale, 30/scale, 20/scale);
        // The original leaf owns a BGRA copy, then publishes it into Quartz.
        std::vector<uint32_t> pixels(30*20);
        auto* source = static_cast<uint8_t*>(CGBitmapContextGetData(expected));
        for (size_t y = 0; y < 20; ++y)
            swap_red_blue_pixels(reinterpret_cast<uint8_t*>(pixels.data())+y*30*4,
                source+(20+y)*400+20*4, 30);
        auto info = SkImageInfo::Make(30,20,kBGRA_8888_SkColorType,kPremul_SkAlphaType,SkColorSpace::MakeSRGB());
        auto surface = SkSurfaces::WrapPixels(info,pixels.data(),30*4,&props); assert(surface);
        surface->getCanvas()->setMatrix(matrix);
        surface->getCanvas()->drawTextBlob(blob,0,0,paint); surface.reset();
        assert(copy_glyph_bitmap(expected,pixels.data(),30,20,rect));
        assert(draw_glyph_bitmap_surface(actual,30,20,rect,matrix,blob.get(),0,0,paint,&props));
        assert(!std::memcmp(CGBitmapContextGetData(actual),CGBitmapContextGetData(expected),400*80));
        auto retained = CGDataProviderCopyData(CGImageGetDataProvider(snapshot)); assert(retained);
        auto pitch = CGImageGetBytesPerRow(snapshot);
        for (size_t y = 0; y < 80; ++y)
            assert(!std::memcmp(CFDataGetBytePtr(retained)+y*pitch,before.data()+y*400,96*4));
        CFRelease(retained); CGImageRelease(snapshot);
        CGContextRelease(actual); CGContextRelease(expected); ++cases;
    }
    auto context = frame(1,255,false);
    SkPaint paint; auto matrix = SkMatrix::I();
    assert(!draw_glyph_bitmap_surface(context,30,20,CGRectMake(20,40,30,20),matrix,nullptr,0,0,paint,nullptr));
    CGContextRelease(context);
    std::printf("PASS %u exact BGRA raster regions and retained snapshots\n",cases);
}
