#include "../native_graphite_raster_cache.h"
#include "../native_graphite_image_upload_cache.h"
#include <cassert>
#include <iostream>
#include <limits>
#include <cstddef>

static VoxGraphiteImage image(uint8_t const* pixels)
{
    VoxGraphiteImage value {};
    value.matrix[0] = value.matrix[4] = value.matrix[8] = 1;
    value.source[2] = value.destination[2] = value.clip[2] = value.width = 2;
    value.source[3] = value.destination[3] = value.clip[3] = value.height = 2;
    value.opacity = 1;
    value.pitch = 8;
    value.pixels = pixels;
    return value;
}

static void large_draw_admission()
{
    constexpr int width = 128, height = 128, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 31);
    auto original = pixels;
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[2] = shape.rect[3] = 100;
    shape.fill = 1;
    shape.alpha = 255;
    VoxGraphiteRasterCache cache(1024 * 1024, 16, true);
    auto cold = cache.prepare(shape, width, height, pitch, true, pixels.data());
    assert(!cold.hit && !cold.pending && pixels == original);
    cache.finish(std::move(cold), pixels.data(), pitch);
    auto warm = cache.prepare(shape, width, height, pitch, true, pixels.data());
    assert(!warm.hit && warm.pending && pixels == original);
    for (int y = 0; y < height; ++y)
        std::fill_n(pixels.data() + size_t(y) * pitch, width * 4, 137);
    cache.finish(std::move(warm), pixels.data(), pitch);
    pixels = original;
    assert(cache.prepare(shape, width, height, pitch, true, pixels.data()).hit);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width * 4; ++x) assert(pixels[size_t(y) * pitch + x] == 137);
        for (int x = width * 4; x < pitch; ++x) assert(pixels[size_t(y) * pitch + x] == 31);
    }
    // Sampling is an allocation hint. Even changes between sampled bytes
    // must miss the full-value cache lookup and leave caller output intact.
    pixels = original;
    pixels[1]++;
    auto changed = pixels;
    auto miss = cache.prepare(shape, width, height, pitch, true, pixels.data());
    assert(!miss.hit && pixels == changed);
    cache.clear();
    for (int i = 0; i < 1000; ++i) {
        auto unique = shape;
        unique.matrix[2] = float(i);
        auto request = cache.prepare(unique, width, height, pitch, true, pixels.data());
        assert(!request.hit && !request.pending && pixels == changed);
    }
    // A bounded admission history can discard old hints without returning
    // stale pixels. Clearing also removes all hints and retained output.
    assert(!cache.prepare(shape, width, height, pitch, true, pixels.data()).pending);
    cache.clear();
    assert(!cache.prepare(shape, width, height, pitch, true, pixels.data()).pending);
    auto small = cache.prepare(shape, 16, 16, pitch, true, pixels.data());
    assert(!small.hit && small.pending);
}

static void equivalent_path_admission(bool change_padding)
{
    constexpr int width=128, height=128, pitch=width*4+16;
    std::vector<uint8_t> pixels(size_t(pitch)*height,31);
    auto original=pixels;
    float segments[12] {};
    float stops[] {1,0,0,1,0,0,0,1,1,1};
    VoxGraphitePath path {};
    path.matrix[0]=path.matrix[4]=path.matrix[8]=1;
    path.segments=segments;path.segment_count=1;
    path.gradient=1;path.stop_count=2;path.stops=stops;path.opacity=.8f;
    auto changed=path;
    if(change_padding) {
        constexpr size_t begin=offsetof(VoxGraphitePath,matrix)+sizeof(path.matrix);
        constexpr size_t end=offsetof(VoxGraphitePath,segments);
        static_assert(end>begin);
        auto* bytes=reinterpret_cast<uint8_t*>(&changed);
        for(size_t i=begin;i<end;++i) bytes[i]=0xA5;
    } else {
        std::fill_n(changed.clip,12,83.f);
        std::fill_n(changed.ancestor_clip,12,97.f);
        std::fill_n(changed.float_color,4,.25f);
    }
    VoxGraphiteRasterCache cache(1024*1024,16,true);
    auto first=cache.prepare(path,width,height,pitch,true,pixels.data());
    assert(!first.hit&&!first.pending);
    auto second=cache.prepare(changed,width,height,pitch,true,pixels.data());
    // Padding and disabled payloads are absent from the complete cache
    // identity. They must not make an identical draw look like a first use.
    assert(!second.hit&&second.pending);
    for(int y=0;y<height;++y) std::fill_n(pixels.data()+size_t(y)*pitch,width*4,147);
    cache.finish(std::move(second),pixels.data(),pitch);
    pixels=original;
    assert(cache.prepare(path,width,height,pitch,true,pixels.data()).hit);
    for(int y=0;y<height;++y) {
        for(int x=0;x<width*4;++x) assert(pixels[size_t(y)*pitch+x]==147);
        for(int x=width*4;x<pitch;++x) assert(pixels[size_t(y)*pitch+x]==31);
    }
    // Enabling those payloads is a real identity change, even if the
    // admission fingerprint happens to collide.
    for(int field=0;field<3;++field) {
        pixels=original;auto active=changed;
        if(field==0) active.has_clip=1;
        if(field==1) active.has_ancestor_clip=1;
        if(field==2) active.has_float_color=1;
        assert(!cache.prepare(active,width,height,pitch,true,pixels.data()).hit);
        assert(pixels==original);
    }
}

int main(int argc, char** argv)
{
    if (argc == 3 && !std::strcmp(argv[1], "--admission-policy")) {
        assert(vox_canonical_path_admission_enabled() == (argv[2][0] == '1'));
        return 0;
    }
    assert(argc == 1);
    setenv("VOX_ENABLE_CANONICAL_PATH_ADMISSION", "1", 1);
    unsetenv("VOX_DISABLE_CANONICAL_PATH_ADMISSION");
    large_draw_admission();
    equivalent_path_admission(true);
    equivalent_path_admission(false);
    std::vector<uint8_t> source(16, 87), pixels(16, 31);
    auto descriptor = image(source.data());
    VoxGraphiteRasterCache cache;
    auto miss = cache.prepare(descriptor, 2, 2, 8, true, pixels.data());
    assert(!miss.hit && miss.pending);
    std::fill(pixels.begin(), pixels.end(), 123);
    cache.finish(std::move(miss), pixels.data(), 8);
    std::fill(pixels.begin(), pixels.end(), 31);
    assert(cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 123));

    // Reused allocations and changes outside the source crop must be observed.
    source[15]++;
    std::fill(pixels.begin(), pixels.end(), 31);
    assert(!cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);
    source[15]--;
    pixels[15]++;
    assert(!cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);
    pixels[15]--;

    // Every render parameter that affects the result participates in identity.
    auto check_miss = [&](VoxGraphiteImage const& changed) {
        assert(!cache.prepare(changed, 2, 2, 8, true, pixels.data()).hit);
    };
    for (int field = 0; field < 9 + 4 + 4 + 12; ++field) {
        auto changed = descriptor;
        if (field < 9) changed.matrix[field] += .25f;
        else if (field < 13) changed.source[field - 9] += .25f;
        else if (field < 17) changed.destination[field - 13] += .25f;
        else changed.clip[field - 17] += .25f;
        check_miss(changed);
    }
    auto changed = descriptor; changed.opacity = .5f; check_miss(changed);
    changed = descriptor; changed.nearest = 1; check_miss(changed);
    changed = descriptor; changed.flags = 1; check_miss(changed);
    changed = descriptor; changed.width = 1; check_miss(changed);
    changed = descriptor; changed.height = 1; check_miss(changed);
    changed = descriptor; changed.has_color_profile = 1; check_miss(changed);
    assert(!cache.prepare(descriptor, 1, 2, 8, true, pixels.data()).hit);
    assert(!cache.prepare(descriptor, 2, 1, 8, true, pixels.data()).hit);
    assert(!cache.prepare(descriptor, 2, 2, 8, false, pixels.data()).hit);

    // Compare owned pixel values, not pointers or row padding, for both inputs.
    std::vector<uint8_t> padded_source(24, 0), padded_output(24, 44);
    for (int y = 0; y < 2; ++y) {
        std::memcpy(padded_source.data() + y * 12, source.data() + y * 8, 8);
        std::memcpy(padded_output.data() + y * 12, pixels.data() + y * 8, 8);
    }
    changed = descriptor; changed.pixels = padded_source.data(); changed.pitch = 12;
    assert(cache.prepare(changed, 2, 2, 12, true, padded_output.data()).hit);
    for (int y = 0; y < 2; ++y) {
        for (int x = 0; x < 8; ++x) assert(padded_output[y * 12 + x] == 123);
        for (int x = 8; x < 12; ++x) assert(padded_output[y * 12 + x] == 44);
    }
    cache.clear();
    assert(!cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);

    // Cache full profiles, planar YUV (including odd 4:2:0 dimensions), and
    // transparent draws, which have no dependency on the output's old contents.
    for (int flags : {0, 4, 4 | 8, 4 | 16, 4 | 8 | VOX_GRAPHITE_IMAGE_YUV422}) {
        std::vector<uint8_t> planes(27, 50);
        auto planar = image(planes.data());
        planar.width = planar.height = 3;
        planar.pitch = 12;
        planar.flags = flags;
        if (!flags) { planes.resize(36, 50); planar.pixels = planes.data(); }
        planar.has_color_profile = 1;
        for (int p = 0; p < VOX_IMAGE_COLOR_PROFILE_VALUES; ++p) planar.color_profile[p] = .1f * p;
        auto request = cache.prepare(planar, 2, 2, 8, false, pixels.data());
        assert(!request.hit && request.pending);
        cache.finish(std::move(request), pixels.data(), 8);
        assert(cache.prepare(planar, 2, 2, 8, false, pixels.data()).hit);
        size_t last = flags & 4 ? (flags & 16 ? 26 : flags & VOX_GRAPHITE_IMAGE_YUV422 ? 20 : 16) : 35;
        planes[last]++;
        assert(!cache.prepare(planar, 2, 2, 8, false, pixels.data()).hit);
        planes[last]--;
        for (int p = 0; p < VOX_IMAGE_COLOR_PROFILE_VALUES; ++p) {
            auto profile = planar;
            profile.color_profile[p] += .1f;
            assert(!cache.prepare(profile, 2, 2, 8, false, pixels.data()).hit);
        }
    }

    // LRU and byte caps bound retained memory; failures are never published.
    VoxGraphiteRasterCache small(64, 2);
    auto put = [&](int key) {
        auto value = descriptor; value.nearest = key;
        auto request = small.prepare(value, 2, 2, 8, false, pixels.data());
        bool hit = request.hit;
        small.finish(std::move(request), pixels.data(), 8);
        return hit;
    };
    assert(!put(0)); assert(!put(1)); assert(put(0));
    assert(!put(2)); assert(put(0)); assert(!put(1));
    VoxGraphiteRasterCache tiny(31);
    assert(!tiny.prepare(descriptor, 2, 2, 8, false, pixels.data()).pending);
    VoxGraphiteRasterCache disabled(1024, 0);
    assert(!disabled.prepare(descriptor, 2, 2, 8, false, pixels.data()).pending);
    changed = descriptor; changed.width = changed.height = std::numeric_limits<int>::max();
    assert(!cache.prepare(changed, 2, 2, 8, false, pixels.data()).pending);
    changed.flags = 4;
    assert(!cache.prepare(changed, 2, 2, 8, false, pixels.data()).pending);
    assert(!cache.prepare(descriptor, 2, 2, 7, false, pixels.data()).pending);
    assert(!cache.prepare(descriptor, 0, 2, 8, false, pixels.data()).pending);
    assert(!cache.prepare(descriptor, 2, 2, 8, false, nullptr).pending);
    // Shapes retain clip-out contents, MSAA mode and the optional underlay.
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[2] = shape.rect[3] = 2;
    shape.thickness = 1;
    shape.alpha = 255;
    shape.fill = shape.anti_alias = 1;
    float clips[] {0, 0, 1, 1};
    shape.clip_outs = clips;
    shape.clip_out_count = 1;
    shape.has_underlay = 1;
    shape.has_float_underlay_color = 1;
    shape.underlay_float_color[0] = .9634f;
    shape.underlay_float_color[1] = .96506f;
    shape.underlay_float_color[2] = .9966f;
    shape.underlay_float_color[3] = 1;
    shape.has_float_color = 1;
    shape.float_color[0] = .0602f;
    shape.float_color[1] = .06608f;
    shape.float_color[2] = .0798f;
    shape.float_color[3] = 1;
    auto request = cache.prepare(shape, 2, 2, 8, false, pixels.data());
    assert(!request.hit && request.pending);
    cache.finish(std::move(request), pixels.data(), 8);
    assert(cache.prepare(shape, 2, 2, 8, false, pixels.data()).hit);
    auto shape_misses = [&](VoxGraphiteShape const& value) {
        assert(!cache.prepare(value, 2, 2, 8, false, pixels.data()).hit);
    };
    for (int i = 0; i < 9 + 12 + 12; ++i) {
        auto value = shape;
        if (i < 9) value.matrix[i] += .125f;
        else if (i < 21) value.rect[i - 9] += .125f;
        else value.underlay_rect[i - 21] += .125f;
        shape_misses(value);
    }
    auto value = shape; value.thickness++; shape_misses(value);
    value = shape; value.red++; shape_misses(value);
    value = shape; value.green++; shape_misses(value);
    value = shape; value.blue++; shape_misses(value);
    value = shape; value.alpha--; shape_misses(value);
    value = shape; value.fill = 0; shape_misses(value);
    value = shape; value.anti_alias = 0; shape_misses(value);
    value = shape; value.force_msaa = 1; shape_misses(value);
    // Geometrically present transparent sides change a single rounded edge.
    {
        auto single = shape; single.fill = 4;
        single.border_widths[0] = single.border_widths[1] = single.border_widths[3] = 1;
        single.border_widths[2] = 2;
        auto request = cache.prepare(single, 2, 2, 8, true, pixels.data());
        assert(!request.hit && request.pending);
        cache.finish(std::move(request), pixels.data(), 8);
        assert(cache.prepare(single, 2, 2, 8, true, pixels.data()).hit);
        for (int side = 0; side < 4; ++side) {
            auto changed = single; changed.border_widths[side] += .5f;
            assert(!cache.prepare(changed, 2, 2, 8, true, pixels.data()).hit);
        }
    }
    value = shape; value.has_underlay = 0; shape_misses(value);
    value = shape; value.has_float_underlay_color = 0; shape_misses(value);
    value = shape; value.has_float_color = 0; shape_misses(value);
    value = shape; value.clip_out_count = 0; shape_misses(value);
    for (int i = 0; i < 4; ++i) {
        value = shape; value.underlay_rgba[i]++; shape_misses(value);
        value = shape; value.float_color[i] += .001f; shape_misses(value);
        value = shape; value.underlay_float_color[i] += .001f; shape_misses(value);
        clips[i]++; shape_misses(shape); clips[i]--;
    }
    assert(!cache.prepare(shape, 2, 2, 8, true, pixels.data()).hit);
    value = shape; value.clip_out_count = -1;
    assert(!cache.prepare(value, 2, 2, 8, false, pixels.data()).pending);
    value = shape; value.clip_outs = nullptr;
    assert(!cache.prepare(value, 2, 2, 8, false, pixels.data()).pending);
    std::vector<uint8_t> large_output(800 * 800 * 4);
    assert(!cache.prepare(shape, 800, 800, 3200, false, large_output.data()).pending);
    assert(cache.prepare(descriptor, 800, 800, 3200, false, large_output.data()).pending);
    cache.clear();
    assert(!cache.prepare(shape, 2, 2, 8, false, pixels.data()).hit);
    // Corner patches retain the original surface geometry in addition to the
    // packed pixels, so a different GPU coverage calculation cannot alias.
    shape.clip_out_count = 0;
    // A small pill can arrive in a complete Chromium root tile. Retain its
    // complete input/output, including pixels far outside the pill, and keep
    // the existing total budget and parameter/mutation checks.
    {
        constexpr int width = 544, height = 256, pitch = width * 4 + 12;
        std::vector<uint8_t> tile(pitch * height, 31);
        VoxGraphiteRasterCache tiles;
        auto draw = tiles.prepare(shape, width, height, pitch, true, tile.data());
        assert(draw.pending && !draw.hit);
        std::fill(tile.begin(), tile.end(), 123);
        tiles.finish(std::move(draw), tile.data(), pitch);
        std::fill(tile.begin(), tile.end(), 31);
        assert(tiles.prepare(shape, width, height, pitch, true, tile.data()).hit);
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width * 4; ++x) assert(tile[y * pitch + x] == 123);
            for (int x = width * 4; x < pitch; ++x) assert(tile[y * pitch + x] == 31);
        }
        std::fill(tile.begin(), tile.end(), 31);
        tile[(height - 1) * pitch + width * 4 - 1]++;
        assert(!tiles.prepare(shape, width, height, pitch, true, tile.data()).hit);
        tile[(height - 1) * pitch + width * 4 - 1]--;
        auto moved = shape; moved.matrix[5] += .125f;
        assert(!tiles.prepare(moved, width, height, pitch, true, tile.data()).hit);
        VoxGraphiteRasterCache bounded(1024 * 1024);
        assert(!bounded.prepare(shape, width, height, pitch, true, tile.data()).pending);
        tiles.clear();
        assert(!tiles.prepare(shape, width, height, pitch, true, tile.data()).hit);
    }
    std::fill(pixels.begin(), pixels.end(), 19);
    request = cache.prepare_patches(shape, 631, 303, 4, true, pixels.data());
    assert(!request.hit && request.pending);
    std::fill(pixels.begin(), pixels.end(), 71);
    cache.finish(std::move(request), pixels.data(), 16);
    std::fill(pixels.begin(), pixels.end(), 19);
    assert(!cache.prepare_patches(shape, 632, 303, 4, true, pixels.data()).hit);
    assert(!cache.prepare_patches(shape, 631, 304, 4, true, pixels.data()).hit);
    assert(!cache.prepare(shape, 4, 1, 16, true, pixels.data()).hit);
    assert(cache.prepare_patches(shape, 631, 303, 4, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 71));
    std::fill(pixels.begin(), pixels.end(), 19); pixels[15]++;
    assert(!cache.prepare_patches(shape, 631, 303, 4, true, pixels.data()).hit);
    shape.clip_out_count = 1;
    // Packed compound shapes own the clip bytes, including when the caller
    // mutates or frees that allocation between otherwise identical draws.
    std::vector<float> packed_clips {0, 0, 1, 1};
    shape.clip_outs = packed_clips.data();
    std::fill(pixels.begin(), pixels.end(), 19);
    request = cache.prepare_patches(shape, 631, 303, 4, true, pixels.data());
    assert(request.pending && !request.hit);
    std::fill(pixels.begin(), pixels.end(), 83);
    cache.finish(std::move(request), pixels.data(), 16);
    packed_clips[0]++;
    std::fill(pixels.begin(), pixels.end(), 19);
    assert(!cache.prepare_patches(shape, 631, 303, 4, true, pixels.data()).hit);
    packed_clips.clear(); packed_clips.shrink_to_fit();
    float replacement_clips[] {0, 0, 1, 1};
    shape.clip_outs = replacement_clips;
    assert(cache.prepare_patches(shape, 631, 303, 4, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 83));
    value = shape; value.clip_outs = nullptr;
    assert(!cache.prepare_patches(value, 631, 303, 4, true, pixels.data()).pending);
    value = shape; value.clip_out_count = -1;
    assert(!cache.prepare_patches(value, 631, 303, 4, true, pixels.data()).pending);
    shape.clip_out_count = 0;
    assert(!cache.prepare_patches(shape, 0, 303, 4, true, pixels.data()).pending);
    assert(!cache.prepare_patches(shape, 631, 303, -1, true, pixels.data()).pending);
    // Paths own geometry and gradient stops; recycled buffers cannot identify a draw.
    cache.clear();
    float segments[24] {0, 1, 2};
    float stops[10] {1, 0, 0, 1, 0, 0, 0, 1, 1, 1};
    VoxGraphitePath path {};
    path.matrix[0] = path.matrix[4] = path.matrix[8] = 1;
    path.segments = segments; path.segment_count = 2;
    path.stops = stops; path.stop_count = 2; path.gradient = 1;
    std::fill(pixels.begin(), pixels.end(), 19);
    request = cache.prepare(path, 2, 2, 8, true, pixels.data());
    assert(!request.hit && request.pending);
    std::fill(pixels.begin(), pixels.end(), 71);
    cache.finish(std::move(request), pixels.data(), 8);
    auto path_misses = [&](VoxGraphitePath const& changed_path) {
        std::fill(pixels.begin(), pixels.end(), 19);
        assert(!cache.prepare(changed_path, 2, 2, 8, true, pixels.data()).hit);
    };
    for (auto field : {&VoxGraphitePath::even_odd, &VoxGraphitePath::stroke,
        &VoxGraphitePath::line_cap, &VoxGraphitePath::line_join, &VoxGraphitePath::non_scaling_stroke, &VoxGraphitePath::gradient,
        &VoxGraphitePath::tile_mode, &VoxGraphitePath::linear_color_space, &VoxGraphitePath::has_float_alpha,
        &VoxGraphitePath::has_float_color, &VoxGraphitePath::gradient_premul}) {
        auto v = path; ++(v.*field); path_misses(v);
    }
    for (auto field : {&VoxGraphitePath::red, &VoxGraphitePath::green,
        &VoxGraphitePath::blue, &VoxGraphitePath::alpha}) {
        auto v = path; ++(v.*field); path_misses(v);
    }
    for (auto field : {&VoxGraphitePath::stroke_width, &VoxGraphitePath::miter_limit,
        &VoxGraphitePath::opacity}) {
        auto v = path; v.*field += .25f; path_misses(v);
    }
    for (int i = 0; i < 9 + 9 + 6; ++i) {
        auto v = path;
        if (i < 9) v.matrix[i] += .25f;
        else if (i < 18) v.gradient_matrix[i - 9] += .25f;
        else v.gradient_points[i - 18] += .25f;
        path_misses(v);
    }
    for (int i = 0; i < 4; ++i) {
        auto precise = path; precise.has_float_color = 1;
        std::fill(pixels.begin(), pixels.end(), 19);
        auto item = cache.prepare(precise, 2, 2, 8, true, pixels.data());
        std::fill(pixels.begin(), pixels.end(), 71);
        cache.finish(std::move(item), pixels.data(), 8);
        precise.float_color[i] = .2501f; path_misses(precise);
        cache.clear();
        std::fill(pixels.begin(), pixels.end(), 19);
        item = cache.prepare(path, 2, 2, 8, true, pixels.data());
        std::fill(pixels.begin(), pixels.end(), 71);
        cache.finish(std::move(item), pixels.data(), 8);
    }
    for (int i = 0; i < 12; ++i) {
        auto clipped = path; clipped.has_clip = 1;
        std::fill(pixels.begin(), pixels.end(), 19);
        auto item = cache.prepare(clipped, 2, 2, 8, true, pixels.data());
        std::fill(pixels.begin(), pixels.end(), 71);
        cache.finish(std::move(item), pixels.data(), 8);
        clipped.clip[i] += .25f; path_misses(clipped);
        cache.clear();
        std::fill(pixels.begin(), pixels.end(), 19);
        item = cache.prepare(path, 2, 2, 8, true, pixels.data());
        std::fill(pixels.begin(), pixels.end(), 71);
        cache.finish(std::move(item), pixels.data(), 8);
    }
    for (int i = 0; i < 12; ++i) {
        auto clipped = path; clipped.has_ancestor_clip = 1;
        std::fill(pixels.begin(), pixels.end(), 19);
        auto item = cache.prepare(clipped, 2, 2, 8, true, pixels.data());
        std::fill(pixels.begin(), pixels.end(), 71);
        cache.finish(std::move(item), pixels.data(), 8);
        clipped.ancestor_clip[i] += .25f; path_misses(clipped);
        cache.clear();
        std::fill(pixels.begin(), pixels.end(), 19);
        item = cache.prepare(path, 2, 2, 8, true, pixels.data());
        std::fill(pixels.begin(), pixels.end(), 71);
        cache.finish(std::move(item), pixels.data(), 8);
    }
    for (auto& segment : segments) { segment += .25f; path_misses(path); segment -= .25f; }
    for (auto& stop : stops) { stop += .25f; path_misses(path); stop -= .25f; }
    auto v = path; --v.segment_count; path_misses(v);
    v = path; --v.stop_count; path_misses(v);
    std::fill(pixels.begin(), pixels.end(), 19); pixels[15]++;
    assert(!cache.prepare(path, 2, 2, 8, true, pixels.data()).hit);
    std::fill(pixels.begin(), pixels.end(), 19);
    float other_segments[24], other_stops[10];
    std::copy_n(segments, 24, other_segments); std::copy_n(stops, 10, other_stops);
    v = path; v.segments = other_segments; v.stops = other_stops;
    assert(cache.prepare(v, 2, 2, 8, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 71));
    v.segment_count = -1;
    assert(!cache.prepare(v, 2, 2, 8, false, pixels.data()).pending);
    v = path; v.stops = nullptr;
    assert(!cache.prepare(v, 2, 2, 8, false, pixels.data()).pending);
    v = path; v.segment_count = std::numeric_limits<int>::max();
    assert(!cache.prepare(v, 2, 2, 8, false, pixels.data()).pending);
    v = path; v.stop_count = std::numeric_limits<int>::max();
    assert(!cache.prepare(v, 2, 2, 8, false, pixels.data()).pending);
    cache.clear();
    assert(!cache.prepare(path, 2, 2, 8, true, pixels.data()).hit);
    // Several small draws from one sheet must fit a bounded cache without
    // retaining the whole sheet separately for each destination geometry.
    VoxGraphiteRasterCache sprites(256, 16);
    descriptor = image(source.data());
    for (int i = 0; i < 6; ++i) {
        changed = descriptor; changed.matrix[2] = float(i);
        std::fill(pixels.begin(), pixels.end(), 19);
        auto sprite = sprites.prepare(changed, 2, 2, 8, true, pixels.data());
        assert(sprite.pending && !sprite.hit);
        std::fill(pixels.begin(), pixels.end(), uint8_t(71 + i));
        sprites.finish(std::move(sprite), pixels.data(), 8);
    }
    for (int i = 0; i < 6; ++i) {
        changed = descriptor; changed.matrix[2] = float(i);
        std::fill(pixels.begin(), pixels.end(), 19);
        assert(sprites.prepare(changed, 2, 2, 8, true, pixels.data()).hit);
        assert(pixels == std::vector<uint8_t>(16, uint8_t(71 + i)));
    }
    source[15]++;
    std::fill(pixels.begin(), pixels.end(), 19);
    assert(!sprites.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);
    source[15]--;
    // Pending source owners survive a clear, then re-enter the byte accounting.
    auto pending1 = sprites.prepare(descriptor, 2, 2, 8, false, pixels.data());
    auto pending2 = sprites.prepare(descriptor, 2, 2, 8, false, pixels.data());
    sprites.clear();
    sprites.finish(std::move(pending1), pixels.data(), 8);
    sprites.finish(std::move(pending2), pixels.data(), 8);
    assert(sprites.prepare(descriptor, 2, 2, 8, false, pixels.data()).hit);
    // Upload reuse crosses destination/backdrop changes, but retains every
    // decoded byte and interpretation parameter, including odd YUV planes.
    VoxGraphiteImageUploadCache<std::shared_ptr<int>> uploads(8192, 1);
    descriptor = image(source.data());
    auto upload = uploads.prepare(descriptor, 2, 2, false);
    assert(!upload.texture && upload.pending);
    auto texture = std::make_shared<int>(73);
    uploads.finish(std::move(upload), texture);
    assert(uploads.prepare(descriptor, 2, 2, false).texture == texture);
    changed = descriptor; changed.matrix[2] = .375f; changed.opacity = .5f;
    changed.source[0] = 1; changed.destination[2] = 17; changed.nearest = 1;
    assert(uploads.prepare(changed, 2, 2, false).texture == texture);
    auto upload_misses = [&](VoxGraphiteImage const& v) {
        assert(!uploads.prepare(v, 2, 2, false).texture);
    };
    source[15]++; upload_misses(descriptor); source[15]--;
    changed = descriptor; changed.flags = 1; upload_misses(changed);
    changed = descriptor; changed.has_color_profile = 1; upload_misses(changed);
    assert(!uploads.prepare(descriptor, 1, 2, false).texture);
    assert(!uploads.prepare(descriptor, 2, 1, false).texture);
    auto upgrade = uploads.prepare(descriptor, 2, 2, true);
    assert(upgrade.texture == texture && upgrade.pending && upgrade.needs_mipmaps);
    // A failed upgrade must leave the original upload available to retry.
    uploads.finish(std::move(upgrade), nullptr);
    assert(uploads.prepare(descriptor, 2, 2, false).texture == texture);
    upgrade = uploads.prepare(descriptor, 2, 2, true);
    assert(upgrade.texture == texture && upgrade.needs_mipmaps);
    auto mip_texture = std::make_shared<int>(74);
    uploads.finish(std::move(upgrade), mip_texture);
    upgrade = uploads.prepare(descriptor, 2, 2, true);
    assert(upgrade.texture == mip_texture && !upgrade.pending && !upgrade.needs_mipmaps);
    assert(uploads.prepare(descriptor, 2, 2, false).texture == mip_texture);
    for (int y = 0; y < 2; ++y)
        std::memcpy(padded_source.data() + y * 12, source.data() + y * 8, 8);
    changed = descriptor; changed.pixels = padded_source.data(); changed.pitch = 12;
    assert(uploads.prepare(changed, 2, 2, false).texture == mip_texture);
    padded_source[11]++;
    assert(uploads.prepare(changed, 2, 2, false).texture == mip_texture);
    changed = descriptor; changed.has_color_profile = 1; changed.color_profile[0] = 1.8f;
    upload = uploads.prepare(changed, 2, 2, false);
    uploads.finish(std::move(upload), texture);
    auto original_profile = changed;
    for (int field = 0; field < VOX_IMAGE_COLOR_PROFILE_VALUES; ++field) {
        changed = original_profile; changed.color_profile[field] += .125f; upload_misses(changed);
    }
    assert(!uploads.prepare(descriptor, 2, 2, false).texture); // Count eviction.
    for (int flags : {4, 12, 20, 28, 12 | VOX_GRAPHITE_IMAGE_YUV422}) {
        std::vector<uint8_t> planes(33, 91);
        auto yuv = descriptor; yuv.width = 3; yuv.height = 3; yuv.pitch = 12;
        yuv.flags = flags; yuv.pixels = planes.data();
        upload = uploads.prepare(yuv, 3, 3, false);
        assert(upload.pending);
        uploads.finish(std::move(upload), texture);
        assert(uploads.prepare(yuv, 3, 3, false).texture == texture);
        // Do not turn a planar upload into an RGBA copy while adding mips.
        auto planar_mips = uploads.prepare(yuv, 3, 3, true);
        assert(!planar_mips.texture && planar_mips.pending && !planar_mips.needs_mipmaps);
        size_t last = flags & 16 ? 26 : flags & VOX_GRAPHITE_IMAGE_YUV422 ? 20 : 16;
        planes[last]++;
        assert(!uploads.prepare(yuv, 3, 3, false).texture);
    }
    uploads.clear();
    assert(!uploads.prepare(descriptor, 2, 2, false).texture);
    auto first_mips = uploads.prepare(descriptor, 2, 2, true);
    assert(!first_mips.texture && first_mips.pending && !first_mips.needs_mipmaps);
    upload = uploads.prepare(descriptor, 2, 2, false);
    uploads.finish(std::move(upload), nullptr);
    assert(!uploads.prepare(descriptor, 2, 2, false).texture);
    VoxGraphiteImageUploadCache<std::shared_ptr<int>> disabled_uploads(0);
    assert(!disabled_uploads.prepare(descriptor, 2, 2, false).pending);
    changed = descriptor; changed.width = std::numeric_limits<int>::max();
    assert(!uploads.prepare(changed, 2, 2, false).pending);
    assert(!uploads.prepare(descriptor, std::numeric_limits<int>::max(), 2, false).pending);
    {
        VoxGraphiteImageUploadCache<std::shared_ptr<int>> upgrades(8192, 4);
        auto base = upgrades.prepare(descriptor, 2, 2, false);
        auto later_base = upgrades.prepare(descriptor, 2, 2, false);
        upgrades.finish(std::move(base), texture);
        auto mips = upgrades.prepare(descriptor, 2, 2, true);
        assert(mips.texture == texture && mips.pending && mips.needs_mipmaps);
        upgrades.finish(std::move(mips), mip_texture);
        // Publish another base entry ahead of the completed mipmapped entry.
        // An exact mipmapped hit must win over that potential upgrade source.
        upgrades.finish(std::move(later_base), texture);
        auto base_hit = upgrades.prepare(descriptor, 2, 2, false);
        assert(base_hit.texture == texture && !base_hit.needs_mipmaps);
        mips = upgrades.prepare(descriptor, 2, 2, true);
        assert(mips.texture == mip_texture && !mips.pending && !mips.needs_mipmaps);
        source.back()++;
        auto mutated = upgrades.prepare(descriptor, 2, 2, true);
        assert(!mutated.texture && mutated.pending && !mutated.needs_mipmaps);
        source.back()--;
        auto other_profile = descriptor;
        other_profile.has_color_profile = 1;
        auto interpreted = upgrades.prepare(other_profile, 2, 2, true);
        assert(!interpreted.texture && interpreted.pending && !interpreted.needs_mipmaps);
        // A pending upgrade owns its decoded bytes across cache eviction.
        upgrades.clear();
        base = upgrades.prepare(descriptor, 2, 2, false);
        upgrades.finish(std::move(base), texture);
        mips = upgrades.prepare(descriptor, 2, 2, true);
        upgrades.clear();
        upgrades.finish(std::move(mips), mip_texture);
        assert(upgrades.prepare(descriptor, 2, 2, true).texture == mip_texture);
    }
    // Packed and strided sheets/output have identical active pixels. Exercise
    // long rows and tails, keeping source and destination padding unobservable.
    {
        VoxGraphiteRasterCache rows;
        std::vector<uint8_t> packed(17 * 33 * 4, 83), strided(80 * 33, 201);
        std::vector<uint8_t> input(7 * 19 * 4, 29), padded(44 * 19, 202);
        auto sheet = image(packed.data());
        sheet.width = 17; sheet.height = 33; sheet.pitch = 68;
        auto draw = rows.prepare(sheet, 7, 19, 28, true, input.data());
        assert(draw.pending && !draw.hit);
        std::fill(input.begin(), input.end(), 107);
        rows.finish(std::move(draw), input.data(), 28);
        for (int y = 0; y < 33; ++y)
            std::memcpy(strided.data() + y * 80, packed.data() + y * 68, 68);
        auto padded_sheet = sheet;
        padded_sheet.pixels = strided.data(); padded_sheet.pitch = 80;
        auto reset = [&] {
            std::fill(input.begin(), input.end(), 29);
            for (int y = 0; y < 19; ++y) std::fill_n(padded.data() + y * 44, 28, 29);
        };
        reset();
        assert(rows.prepare(padded_sheet, 7, 19, 44, true, padded.data()).hit);
        for (int y = 0; y < 19; ++y) {
            for (int x = 0; x < 28; ++x) assert(padded[y * 44 + x] == 107);
            for (int x = 28; x < 44; ++x) assert(padded[y * 44 + x] == 202);
        }
        reset();
        assert(rows.prepare(sheet, 7, 19, 28, true, input.data()).hit);
        assert(input == std::vector<uint8_t>(input.size(), 107));
        reset(); packed.back()++;
        assert(!rows.prepare(sheet, 7, 19, 28, true, input.data()).hit);
        packed.back()--;
        strided[32 * 80 + 67]++;
        assert(!rows.prepare(padded_sheet, 7, 19, 44, true, padded.data()).hit);
        strided[32 * 80 + 67]--;
        for (int row : {0, 9, 18}) {
            reset(); input[row * 28 + 27]++;
            assert(!rows.prepare(sheet, 7, 19, 28, true, input.data()).hit);
            padded[row * 44 + 27]++;
            assert(!rows.prepare(padded_sheet, 7, 19, 44, true, padded.data()).hit);
        }
    }
    {
        // Three full surfaces exceed the raw byte budget together. Lossless
        // flat-region storage keeps all three without increasing that budget.
        VoxGraphiteRasterCache compact(4 * 1024 * 1024);
        constexpr int width = 513, height = 511, pitch = width * 4 + 13;
        std::vector<uint8_t> surface(pitch * height, 201);
        VoxGraphiteShadow large_shadow {};
        auto reset = [&] {
            for (int y = 0; y < height; ++y) std::fill_n(surface.data() + y * pitch, width * 4, 47);
        };
        for (int key = 0; key != 3; ++key) {
            large_shadow.red = key;
            reset();
            auto draw = compact.prepare(large_shadow, width, height, pitch, true, surface.data());
            assert(draw.pending && !draw.hit);
            for (int y = 0; y < height; ++y) std::fill_n(surface.data() + y * pitch, width * 4, 103 + key);
            compact.finish(std::move(draw), surface.data(), pitch);
        }
        for (int key = 0; key != 3; ++key) {
            large_shadow.red = key;
            reset();
            assert(compact.prepare(large_shadow, width, height, pitch, true, surface.data()).hit);
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width * 4; ++x) assert(surface[y * pitch + x] == 103 + key);
                for (int x = width * 4; x < pitch; ++x) assert(surface[y * pitch + x] == 201);
            }
            reset(); surface[(height - 1) * pitch + width * 4 - 1]++;
            assert(!compact.prepare(large_shadow, width, height, pitch, true, surface.data()).hit);
        }
    }
    // A modest photo can have a larger visible raster on a Retina display.
    // Its source plus two raw surfaces exceeds the small-control entry cap,
    // even though the ordinary image-cache budget comfortably covers it.
    {
        VoxGraphiteRasterCache photos;
        constexpr int width = 1252, height = 884, pitch = width * 4 + 13;
        std::vector<uint8_t> planes(700 * 700 * 3, 91), surface(pitch * height, 201);
        auto photo = image(planes.data());
        photo.width = photo.height = 700; photo.pitch = 2800;
        photo.source[2] = photo.source[3] = 700;
        photo.destination[2] = photo.clip[2] = width;
        photo.destination[3] = photo.clip[3] = height;
        photo.flags = 4 | 8 | 16;
        auto reset = [&] {
            for (int y = 0; y < height; ++y) std::fill_n(surface.data() + y * pitch, width * 4, 47);
        };
        reset();
        auto draw = photos.prepare(photo, width, height, pitch, true, surface.data());
        assert(draw.pending && !draw.hit);
        for (int y = 0; y < height; ++y)
            for (int x = 0; x < width * 4; ++x) surface[y * pitch + x] = (x * 17 + y * 31) % 251;
        photos.finish(std::move(draw), surface.data(), pitch);
        reset();
        assert(photos.prepare(photo, width, height, pitch, true, surface.data()).hit);
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width * 4; ++x) assert(surface[y * pitch + x] == (x * 17 + y * 31) % 251);
            for (int x = width * 4; x < pitch; ++x) assert(surface[y * pitch + x] == 201);
        }
        reset(); surface[(height / 2) * pitch + (width / 2) * 4] ^= 31;
        assert(photos.prepare(photo, width, height, pitch, true, surface.data()).hit);
        reset(); planes.back()++;
        assert(!photos.prepare(photo, width, height, pitch, true, surface.data()).hit);
        planes.back()--; surface[(height - 1) * pitch + width * 4 - 1]++;
        assert(!photos.prepare(photo, width, height, pitch, true, surface.data()).hit);
        // The per-image bound and the configured total budget still apply.
        std::vector<uint8_t> oversized(2048 * 1024 * 4, 47);
        assert(!photos.prepare(photo, 2048, 1024, 2048 * 4, true, oversized.data()).pending);
        VoxGraphiteRasterCache small(8 * 1024 * 1024);
        assert(!small.prepare(photo, width, height, pitch, true, surface.data()).pending);
        // Partial opacity and transforms without the coverage proof still
        // compare every backdrop pixel, including the image's center.
        for (int kind : {0, 1, 2}) {
            VoxGraphiteRasterCache conservative;
            auto changed_photo = photo;
            if (kind == 0) changed_photo.opacity = .5f;
            else if (kind == 1) changed_photo.matrix[1] = .1f;
            else {
                // Float cancellation can hide large local-coordinate errors.
                changed_photo.destination[0] = changed_photo.clip[0] = 1073741824;
                changed_photo.matrix[2] = -1073741824;
            }
            reset();
            auto request = conservative.prepare(changed_photo, width, height, pitch, true, surface.data());
            assert(request.pending);
            conservative.finish(std::move(request), surface.data(), pitch);
            reset(); surface[(height / 2) * pitch + (width / 2) * 4] ^= 31;
            assert(!conservative.prepare(changed_photo, width, height, pitch, true, surface.data()).hit);
        }
    }
    // A large flat SVG path can fit after lossless row compression even when
    // its two raw surfaces exceed the unchanged 8 MiB path-cache budget.
    {
        VoxGraphiteRasterCache paths(8 * 1024 * 1024);
        constexpr int width = 1260, height = 888, pitch = width * 4;
        std::vector<uint8_t> surface(size_t(pitch) * height, 47);
        float rectangle[6 * 12] {};
        VoxGraphitePath path {};
        path.segments = rectangle; path.segment_count = 6;
        path.matrix[0] = path.matrix[4] = path.matrix[8] = 1;
        auto draw = paths.prepare(path, width, height, pitch, true, surface.data());
        assert(draw.pending && !draw.hit);
        std::fill(surface.begin(), surface.end(), 103);
        paths.finish(std::move(draw), surface.data(), pitch);
        std::fill(surface.begin(), surface.end(), 47);
        assert(paths.prepare(path, width, height, pitch, true, surface.data()).hit);
        assert(surface == std::vector<uint8_t>(surface.size(), 103));
        std::fill(surface.begin(), surface.end(), 47); surface.back()++;
        assert(!paths.prepare(path, width, height, pitch, true, surface.data()).hit);
        // An incompressible result must be rejected without evicting the warm
        // entry speculatively on the basis of its larger raw size.
        for (size_t i = 0; i < surface.size(); ++i) surface[i] = (i * 17 + i / 11) % 251;
        auto noise = surface;
        draw = paths.prepare(path, width, height, pitch, true, surface.data());
        assert(draw.pending && !draw.hit);
        for (size_t i = 0; i < surface.size(); ++i) surface[i] = (i * 31 + i / 13) % 253;
        paths.finish(std::move(draw), surface.data(), pitch);
        surface = noise;
        assert(!paths.prepare(path, width, height, pitch, true, surface.data()).hit);
        std::fill(surface.begin(), surface.end(), 47);
        assert(paths.prepare(path, width, height, pitch, true, surface.data()).hit);
    }
    std::cout << "Graphite raster cache: source/backdrop mutation, geometry, profiles, strides, YUV, LRU and bounds passed\n";
}
