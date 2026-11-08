#include "../native/include/native_graphite_image_upload_cache.h"
#include "../native/include/native_graphite_raster_cache.h"
#include "../native/include/native_chromium_image_decode_cache.h"
#include <cassert>
#include <cstdio>

int main() {
    // Odd 3x3 4:2:0: Y=9, U=4, V=4, A=9. The final alpha byte must
    // participate in every source identity, including the digest-only path.
    std::vector<uint8_t> planes(26, 128);
    VoxGraphiteImage image {};
    image.width = image.height = 3; image.pitch = 12; image.pixels = planes.data();
    image.flags = 4 | VOX_GRAPHITE_IMAGE_YUVA_ALPHA | VOX_GRAPHITE_IMAGE_VIDEO_FRAME;
    image.opacity = 1;
    image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
    image.source[2] = image.source[3] = 3;
    image.destination[2] = image.destination[3] = image.clip[2] = image.clip[3] = 3;
    VoxGraphiteImageUploadCache<std::shared_ptr<int>> uploads;
    auto upload = uploads.prepare(image, 3, 3, false);
    assert(upload.pending && !upload.texture);
    auto texture = std::make_shared<int>(1);
    uploads.finish(std::move(upload), texture);
    assert(uploads.prepare(image, 3, 3, false).texture == texture);
    planes.back()++;
    assert(!uploads.prepare(image, 3, 3, false).texture);
    planes.back()--;
    assert(uploads.prepare(image, 3, 3, false).texture == texture);

    VoxGraphiteRasterCache raster;
    std::vector<uint8_t> pixels(3 * 3 * 4, 0);
    auto draw = raster.prepare(image, 3, 3, 12, false, pixels.data());
    assert(draw.pending && !draw.hit);
    std::fill(pixels.begin(), pixels.end(), 42);
    raster.finish(std::move(draw), pixels.data(), 12);
    std::fill(pixels.begin(), pixels.end(), 0);
    assert(raster.prepare(image, 3, 3, 12, false, pixels.data()).hit);
    planes.back()++;
    assert(!raster.prepare(image, 3, 3, 12, false, pixels.data()).hit);

    VoxChromiumImageDecodeCache decodes;
    assert(decodes.select("video", image, 1) == 1);
    assert(decodes.select("video", image, 2) == 1);
    planes.back()++;
    assert(decodes.select("video", image, 2) == 2);
    image.flags &= ~VOX_GRAPHITE_IMAGE_YUVA_ALPHA;
    assert(decodes.select("video", image, 3) == 3);
    image.flags |= VOX_GRAPHITE_IMAGE_YUVA_ALPHA;
    assert(decodes.select("video", image, 4) == 4);
    std::vector<uint8_t> large_planes(129 * 129 * 2 + 65 * 65 * 2, 128);
    image.width = image.height = 129; image.pitch = 129 * 4;
    image.pixels = large_planes.data();
    VoxGraphiteImageUploadCache<std::shared_ptr<int>> digests(4096, 1);
    auto large = digests.prepare(image, 1, 1, false);
    assert(large.pending && !large.texture);
    digests.finish(std::move(large), texture);
    auto reused = digests.prepare(image, 1, 1, false);
    assert(reused.texture == texture && reused.verified_by_digest);
    large_planes.back()++;
    assert(!digests.prepare(image, 1, 1, false).texture);
    puts("PASS upload, raster and decode caches invalidate on alpha-plane and format changes");
}
