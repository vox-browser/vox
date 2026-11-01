#include "../native_chromium_image_decode_cache.h"
#include <cstdio>
#include <cstdlib>
#include <limits>

static int checks;
static void check(bool ok, char const* message)
{
    ++checks;
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}

#ifdef VOX_IMAGE_DECODE_BEFORE
struct Cache {
    explicit Cache(size_t = 0, size_t = 0) { }
    int select(std::string const&, VoxGraphiteImage const&, int level, uint64_t = 0) { return level; }
    void complete_frame() { }
    void reset_requests() { }
    void clear() { }
};
#else
using Cache = VoxChromiumImageDecodeCache;
#endif

int main()
{
    std::vector<uint8_t> pixels(16 * 16 * 4, 127);
    VoxGraphiteImage image {};
    image.width = image.height = 16; image.pitch = 64; image.pixels = pixels.data();
    Cache cache;
    check(cache.select("resource-a", image, 2) == 2, "first decode uses requested size");
    check(cache.select("resource-a", image, 3) == 2, "smaller draw retains larger decode");
    check(cache.select("resource-b", image, 3) == 3, "equal pixels from another resource stay independent");
    check(cache.select("resource-a", image, 1) == 1, "larger draw promotes the decode");
    check(cache.select("resource-a", image, 4) == 1, "promotion survives a later smaller draw");
    cache.complete_frame(); cache.reset_requests();
    image.nearest = 1;
    check(cache.select("resource-a", image, 0) == 0, "unscaled nearest draw promotes to the source size");
    cache.complete_frame(); cache.reset_requests();
    image.nearest = 0;
    check(cache.select("resource-a", image, 4) == 0, "unscaled source remains compatible with smoothing");
    pixels[7] ^= 1;
    check(cache.select("resource-a", image, 3) == 3, "changed pixels replace the old decode");
    pixels[7] ^= 1;
    check(cache.select("resource-a", image, 4) == 4, "returning pixels cannot revive discarded history");
    check(cache.select("resource-a", image, 2) == 2, "fresh high detail is recorded");
    image.flags = 2 | 32;
    check(cache.select("resource-a", image, 5) == 2, "backdrop and coverage flags do not identify pixels");
    image.flags |= 1;
    check(cache.select("resource-a", image, 4) == 4, "alpha interpretation changes the decode");
    image.flags = 0;
    image.has_color_profile = 1; image.color_profile[0] = .5f;
    check(cache.select("resource-a", image, 3) == 3, "color profile presence changes the decode");
    image.color_profile[1] = .75f;
    check(cache.select("resource-a", image, 4) == 4, "color profile contents change the decode");
    image.has_color_profile = 0;
    check(cache.select("resource-a", image, 2) == 2, "untagged source starts a new history");
    std::vector<uint8_t> padded(71 * 16, 204);
    for (int y = 0; y < 16; ++y)
        std::memcpy(padded.data() + y * 71, pixels.data() + y * 64, 64);
    auto strided = image; strided.pitch = 71; strided.pixels = padded.data();
    check(cache.select("resource-a", strided, 4) == 2, "row padding does not identify source pixels");
    std::string embedded("resource-a\0suffix", 17);
    check(cache.select(embedded, image, 4) == 4, "resource identity includes its complete byte length");

    Cache scoped;
    check(scoped.select("shared", image, 3, 0) == 3, "root picture decodes the header");
    check(scoped.select("shared", image, 4, 1) == 4, "concurrent picture starts independently");
    scoped.complete_frame();
    check(scoped.select("shared", image, 4, 1) == 4, "retained picture keeps its in-use decode");
    check(scoped.select("shared", image, 4, 2) == 3, "later picture reuses a completed larger decode");
    check(scoped.select("shared", image, 2, 0) == 2, "new larger request promotes a picture");
    check(scoped.select("shared", image, 4, 2) == 3, "another retained picture stays stable");
    scoped.complete_frame(); scoped.reset_requests();
    check(scoped.select("shared", image, 4, 1) == 2, "rerasterized picture sees completed promotion");

    Cache lru(8192, 2);
    check(lru.select("a", image, 2) == 2, "LRU first");
    check(lru.select("b", image, 2) == 2, "LRU second");
    check(lru.select("a", image, 3) == 2, "LRU touch");
    check(lru.select("c", image, 2) == 2, "LRU third");
    check(lru.select("a", image, 3) == 2, "recent decode survives eviction");
    check(lru.select("b", image, 3) == 3, "least recent decode is evicted");
    lru.clear();
    check(lru.select("a", image, 3) == 3, "clear drops selected sizes");
    Cache byte_bounded(4000, 128);
    check(byte_bounded.select("a", image, 2) == 2, "byte-bounded cache accepts one source");
    check(byte_bounded.select("b", image, 2) == 2, "byte budget evicts to accept a second source");
    check(byte_bounded.select("a", image, 3) == 3, "byte budget evicted the preceding history");
    Cache tiny(128, 1), disabled(4096, 0);
    check(tiny.select("a", image, 2) == -1, "byte budget refuses oversized entries");
    check(disabled.select("a", image, 2) == -1, "zero entry budget disables caching");
    check(cache.select("", image, 2) == -1, "anonymous images retain ordinary replay");
    check(cache.select(std::string(16385, 'x'), image, 2) == -1, "resource key length is bounded");
    auto invalid = image; invalid.pixels = nullptr;
    check(cache.select("resource-a", invalid, 3) == -1, "missing pixels invalidate history");
    check(cache.select("resource-a", image, 4) == 4, "invalidated resource starts fresh");
    invalid = image; invalid.width = invalid.height = std::numeric_limits<int>::max();
    invalid.pixels = reinterpret_cast<uint8_t const*>(1);
    check(cache.select("huge", invalid, 1) == -1, "size overflow is rejected before reading memory");
    invalid = image; invalid.pitch = 1;
    check(cache.select("stride", invalid, 2) == -1, "short rows are rejected");
    invalid = image; invalid.flags = 4;
    check(cache.select("planar", invalid, 2) == -1, "planar inputs retain their own path");
    invalid = image; invalid.flags = 64;
    check(cache.select("repeat", invalid, 2) == -1, "repeated inputs retain their own path");
    check(cache.select("level", image, 31) == -1, "invalid mip levels are rejected");
    check(vox_image_decode_axis(1191, 1) == 596, "odd decode dimensions round up");
    check(vox_image_decode_axis(500, 3) == 63, "header decode size");
    check(vox_image_decode_axis(500, 4) == 32, "footer decode size");
    check(vox_image_decode_axis(1, 30) == 1, "last mip remains nonempty");
    check(vox_image_decode_axis(0, 0) == 0, "invalid source axis");
    check(vox_image_decode_axis(1, 31) == 0, "invalid axis mip");
    for (int level = 0; level <= 30; ++level) {
        int flags = vox_image_with_decode_level(2 | 32, level);
        check(vox_image_decode_level(flags) == level, "plain ABI preserves chosen decode level");
        check((flags & (2 | 32)) == (2 | 32), "decode hint preserves coverage flags");
    }
    check(vox_image_decode_level(0) == -1, "ordinary draw has no decode hint");
    check(vox_image_decode_level(vox_image_decode_hint | (31 << 24)) == -1, "malformed hint is ignored");
    std::printf("PASS: %d independent decode-cache checks\n", checks);
}
