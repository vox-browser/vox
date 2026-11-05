#include "../native_avif.h"
#include "../native_graphite_bridge.h"
#include "../native_chromium_image_decode_cache.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>

static std::vector<uint8_t> read_reference(char const* path) {
    auto url = CFURLCreateFromFileSystemRepresentation(nullptr, reinterpret_cast<UInt8 const*>(path), strlen(path), false);
    auto source = CGImageSourceCreateWithURL(url, nullptr);
    auto reference = CGImageSourceCreateImageAtIndex(source, 0, nullptr);
    assert(reference && CGImageGetWidth(reference) == 1024 && CGImageGetHeight(reference) == 768);
    std::vector<uint8_t> expected(1024 * 768 * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(expected.data(), 1024, 768, 8, 4096, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little);
    assert(context);
    CGContextDrawImage(context, CGRectMake(0, 0, 1024, 768), reference);
    CGContextRelease(context); CGColorSpaceRelease(space); CGImageRelease(reference); CFRelease(source); CFRelease(url);
    return expected;
}

int main(int argc, char** argv) {
    assert(argc == 5);
    auto* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(dlsym(library, "vox_graphite_draw_image_pixels"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(dlsym(library, "vox_graphite_release_unused_graphics_memory"));
    auto supported = reinterpret_cast<int(*)()>(dlsym(library, "vox_graphite_supports_yuv422"));
    assert(draw && clear && supported && supported());
    auto full = read_reference(argv[3]), reduced = read_reference(argv[4]);
    std::vector<uint8_t> actual(full.size(), 255);
    std::ifstream file(argv[2], std::ios::binary);
    std::vector<uint8_t> bytes{std::istreambuf_iterator<char>(file), {}};
    int32_t w, h, size, sub;
    auto* planes = vox_avif_decode_yuv(bytes.data(), bytes.size(), &w, &h, &size, &sub);
    assert(planes && sub == 1 && w == 585 && h == 390);
    int comparisons = 0;
    for (int small : {0, 1}) for (int nearest : {0, 1}) for (int msaa : {0, 32}) {
      if (small && !nearest) continue;
      clear();
      for (int repeat : {0, 1}) {
        std::fill(actual.begin(), actual.end(), 255);
        VoxGraphiteImage image {};
        image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
        image.source[2] = w; image.source[3] = h;
        int x = 32, y = small ? 224 : 64, dw = small ? 195 : w, dh = small ? 130 : h;
        image.destination[0] = image.clip[0] = x; image.destination[1] = image.clip[1] = y;
        image.destination[2] = image.clip[2] = dw; image.destination[3] = image.clip[3] = dh;
        image.opacity = 1; image.width = w; image.height = h; image.pitch = w * 4;
        image.flags = 12 | VOX_GRAPHITE_IMAGE_YUV422 | msaa;
        image.nearest = nearest; image.pixels = planes;
        assert(draw(actual.data(), 1024, 768, 4096, 1, &image));
        auto const& expected = small ? reduced : full;
        for (int yy = y; yy < y + dh; ++yy) for (int xx = x; xx < x + dw; ++xx)
            for (int c = 0; c < 4; ++c) assert(actual[(yy * 1024 + xx) * 4 + c] == expected[(yy * 1024 + xx) * 4 + c]);
        ++comparisons;
      }
    }
    // The preceding nearest-neighbor use leaves a full-size planar upload.
    // Its later mipmap upgrade must match the unchanged smooth-photo region,
    // including the document raster's overlapping 256-pixel tiles.
    for (int msaa : {0, 32}) {
      clear();
      VoxGraphiteImage image {};
      image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
      image.source[2] = w; image.source[3] = h;
      image.destination[0] = image.clip[0] = 32;
      image.destination[1] = image.clip[1] = 64;
      image.destination[2] = image.clip[2] = w;
      image.destination[3] = image.clip[3] = h;
      image.opacity = 1; image.width = w; image.height = h; image.pitch = w * 4;
      image.flags = vox_image_with_decode_level(14 | VOX_GRAPHITE_IMAGE_YUV422 | msaa, 0);
      image.nearest = 1; image.pixels = planes;
      std::fill(actual.begin(), actual.end(), 255);
      assert(draw(actual.data(), 1024, 768, 4096, 1, &image));
      image.nearest = 0;
      image.destination[0] = image.clip[0] = 640;
      image.destination[1] = image.clip[1] = 240;
      image.destination[2] = image.clip[2] = 293;
      image.destination[3] = image.clip[3] = 195;
      for (int repeat : {0, 1}) {
        std::fill(actual.begin(), actual.end(), 255);
        std::vector<uint8_t> tile(1024 * 256 * 4, 255);
        for (int index = 0; index < 2; ++index) {
          std::fill(tile.begin(), tile.end(), 255);
          int origin = index * 254;
          image.matrix[5] = -origin;
          assert(draw(tile.data(), 1024, 256, 4096, 1, &image));
          for (int y = 240; y < 435; ++y) {
            if ((index == 0 && y > 254) || (index == 1 && y <= 254)) continue;
            std::memcpy(actual.data() + y * 4096, tile.data() + (y - origin) * 4096, 4096);
          }
        }
        size_t different = 0;
        for (int y = 240; y < 435; ++y) for (int x = 640; x < 933; ++x)
          different += std::memcmp(actual.data() + (y * 1024 + x) * 4,
              full.data() + (y * 1024 + x) * 4, 4) != 0;
        if (different) std::fprintf(stderr, "Warm AVIF mipmap mismatch: %zu pixels\n", different);
        assert(different == 0);
        ++comparisons;
      }
    }
    vox_avif_release(planes); dlclose(library);
    std::printf("AVIF YUV422: %d exact full-size and reduced Brave photo comparisons, nearest/linear, MSAA and warm mipmap upgrades passed\n", comparisons);
}
