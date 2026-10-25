// Exact comparisons with the previous native bridge, including fractional
// scrolling. Run with VOX_SKIA_REFERENCE_LIBRARY and DYLD_LIBRARY_PATH set.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<float> border_path(float right, float bottom)
{
    std::vector<float> data;
    auto point = [&](int verb, float x, float y) {
        float segment[12] {float(verb), x, y};
        data.insert(data.end(), segment, segment + 12);
    };
    point(0, right, 19); point(4, right, 19);
    point(1, right - 1, 19); point(1, right - 1, bottom - 1);
    point(1, right, bottom); point(4, right, bottom);
    point(0, right, bottom); point(4, right, bottom);
    point(1, right - 1, bottom - 1); point(1, 23, bottom - 1);
    point(1, 23, bottom); point(4, 23, bottom);
    return data;
}

int main()
{
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
    assert(path && *path);
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    assert(library && graphite_path_parts_draw());
    auto reference = reinterpret_cast<decltype(&ladybird_v_skia_draw_svg_path)>(dlsym(library, "ladybird_v_skia_draw_svg_path"));
    auto reference_mode = reinterpret_cast<decltype(&ladybird_v_skia_set_chromium_painting)>(dlsym(library, "ladybird_v_skia_set_chromium_painting"));
    assert(reference && reference_mode);
    size_t comparisons = 0;
    for (int scale : {1, 2}) for (int clip : {0, 1, 2})
    for (int background : {0, 1}) for (int alpha : {113, 255})
    for (float scroll : {0.f, .1f, .2f, .4f, .5f, 25.2f, 100.8f})
    for (int mutation : {0, 1}) {
        int width = 320 * scale, height = 240 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height, 0xBA);
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            auto* p = expected.data() + size_t(y) * pitch + x * 4;
            uint8_t a = background ? 255 : uint8_t((x + y * 13) % 256);
            p[0] = uint8_t((x + mutation * 31) % (int(a) + 1));
            p[1] = a / 2; p[2] = a / 3; p[3] = a;
        }
        auto actual = expected;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto c = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(c); CGContextScaleCTM(c, scale, scale);
            if (clip == 1) CGContextClipToRect(c, CGRectMake(17.25, 19.5, 217.75, 153.25));
            if (clip == 2) { CGContextAddEllipseInRect(c, CGRectMake(12.5, 8.25, 261.75, 197.5)); CGContextClip(c); }
            return c;
        };
        auto before = make(expected), after = make(actual); CGColorSpaceRelease(space);
        auto data = border_path(287.f - mutation, 219.f - mutation * 7);
        reference_mode(1); ladybird_v_skia_set_chromium_painting(1);
        auto draw = [&](auto c, auto fn) {
            return fn(c, data.data(), int(data.size() / 12), mutation,
                1, 0, 0, 1, .25f * mutation, .1f * mutation, 0, 0, scroll, 320, 240,
                217, 191, 183, uint8_t(alpha), 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0,
                nullptr, 0, 0, background);
        };
        assert(draw(before, reference)); assert(draw(after, &ladybird_v_skia_draw_svg_path));
        CGContextFlush(before); CGContextFlush(after);
        if (expected != actual) {
            size_t differences = 0;
            for (size_t i = 0; i < expected.size(); ++i) if (expected[i] != actual[i]) {
                if (differences++ < 8) std::cerr << " byte=" << i << " expected=" << int(expected[i]) << " actual=" << int(actual[i]) << '\n';
            }
            std::cerr << "Sparse path mismatch scale=" << scale << " clip=" << clip
                << " background=" << background << " alpha=" << alpha << " scroll=" << scroll
                << " mutation=" << mutation << " differences=" << differences << '\n'; return 1;
        }
        ++comparisons; CGContextRelease(before); CGContextRelease(after);
    }
    auto data = border_path(287, 219);
    VoxGraphitePath descriptor {};
    descriptor.segments = data.data(); descriptor.segment_count = int(data.size() / 12);
    descriptor.matrix[0] = descriptor.matrix[4] = descriptor.matrix[8] = 1;
    std::vector<VoxPathRegion> parts;
    assert(vox_sparse_path_regions(descriptor, 320, 240, parts));
    size_t area = 0;
    for (auto p : parts) area += size_t(p.width()) * p.height();
    assert(area < 320 * 240 / 10);
    std::vector<uint8_t> bitmap(320 * 240 * 4, 255);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(bitmap.data(), 320, 240, 8, 320 * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    descriptor.alpha = 255; descriptor.red = 217; descriptor.green = 191; descriptor.blue = 183;
    assert(draw_sparse_svg_path(context, descriptor, RasterRegion {0, 0, 320, 240}, 320, 240, 1, 240, true));
    CGContextRelease(context);
    // Exercise packed cache ownership: mutate source geometry, the backdrop,
    // the view positions and the color through the same caller allocations.
    for (int pass : {0, 1, 2, 0}) {
        std::vector<std::vector<uint8_t>> storage;
        std::vector<VoxGraphitePixelRegion> views;
        for (auto part : parts) {
            int pitch = part.width() * 4 + 7;
            storage.emplace_back(size_t(pitch) * part.height(), 0xBA);
            views.push_back({part.left, part.top, part.width(), part.height(), pitch, storage.back().data()});
        }
        views[0].x += pass;
        std::vector<uint8_t> whole(320 * 240 * 4);
        for (auto const& view : views) for (int y = 0; y < view.height; ++y)
            for (int x = 0; x < view.width; ++x) {
                auto* p = view.pixels + size_t(y) * view.pitch + x * 4;
                p[0] = uint8_t((x + pass * 7) % 137); p[1] = 71; p[2] = 83; p[3] = 197;
                std::memcpy(whole.data() + (size_t(view.y + y) * 320 + view.x + x) * 4, p, 4);
            }
        data[1] = 287.f - pass * .25f; descriptor.alpha = uint8_t(255 - pass * 51);
        assert(graphite_path_draw()(whole.data(), 320, 240, 320 * 4, 1, &descriptor));
        assert(graphite_path_parts_draw()(views.data(), int(views.size()), 320, 240, 1, &descriptor));
        for (auto const& view : views) for (int y = 0; y < view.height; ++y) {
            assert(!std::memcmp(view.pixels + size_t(y) * view.pitch,
                whole.data() + (size_t(view.y + y) * 320 + view.x) * 4, size_t(view.width) * 4));
            for (int x = view.width * 4; x < view.pitch; ++x) assert(view.pixels[size_t(y) * view.pitch + x] == 0xBA);
        }
        auto saved = storage;
        auto invalid = views; invalid.push_back(views[0]);
        assert(!graphite_path_parts_draw()(invalid.data(), int(invalid.size()), 320, 240, 1, &descriptor));
        assert(storage == saved);
        invalid = views; invalid[0].x = -1;
        assert(!graphite_path_parts_draw()(invalid.data(), int(invalid.size()), 320, 240, 1, &descriptor));
        assert(storage == saved);
    }
    // Curves, stroke expansion and non-finite transforms retain full replay.
    data[12] = 3;
    assert(!vox_sparse_path_regions(descriptor, 320, 240, parts));
    data[12] = 4; descriptor.stroke = 1;
    assert(!vox_sparse_path_regions(descriptor, 320, 240, parts));
    descriptor.stroke = 0; descriptor.matrix[2] = INFINITY;
    assert(!vox_sparse_path_regions(descriptor, 320, 240, parts));
    std::cout << "Sparse paths: " << comparisons << " exact GPU comparisons; fast-path eligibility and fallbacks passed\n";
}
