#include "canvas_raster.cpp"
#include <cassert>
#include <cstdio>
#include <string>

static int calls;
static int failing_draw(unsigned char* pixels, int width, int height, int, void const*, size_t, float const*)
{
    ++calls;
    std::memset(pixels, 255, size_t(width) * height * 4);
    return 0;
}

int main(int argc, char** argv)
{
    assert(argc == 2);
    std::string directory = argv[1];
    std::vector<uint8_t> source(64 * 48 * 4);
    for (int y = 0; y < 48; ++y) for (int x = 0; x < 64; ++x) {
        int i = (y * 64 + x) * 4;
        int color = x < 24 ? 0xe95f35 : x < 40 ? 0x2878bc : 0xf1cb3c;
        if (x >= 16 && x < 48 && y >= 16 && y < 32) color = 0x161c2a;
        source[i] = color >> 16; source[i + 1] = color >> 8;
        source[i + 2] = color; source[i + 3] = 255;
    }
    VoxCanvasCommand command {};
    command.operation = 2; command.smoothing = 1; command.global_alpha = 1;
    command.transform[0] = command.transform[3] = 1;
    command.source[2] = 64; command.source[3] = 48;
    command.destination[2] = 192; command.destination[3] = 144;
    command.style.pattern = source.data(); command.style.pattern_width = 64;
    command.style.pattern_height = 48; command.style.pattern_pitch = 256;
    command.style.pattern_alpha = 2;
    std::vector<uint8_t> pixels(192 * 144 * 4);
    auto save_readback = [&](char const* name) {
        std::vector<uint8_t> rgba(pixels.size());
        SkBitmap bitmap;
        assert(bitmap.installPixels(SkImageInfo::Make(192, 144, kRGBA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB()), pixels.data(), 768));
        assert(bitmap.readPixels(SkImageInfo::Make(192, 144, kRGBA_8888_SkColorType, kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB()), rgba.data(), 768, 0, 0));
        auto* output = std::fopen((directory + "/" + name + ".rgba").c_str(), "wb");
        assert(output && std::fwrite(rgba.data(), 1, rgba.size(), output) == rgba.size());
        std::fclose(output);
    };
    assert(vox_skia_canvas_path_chromium(pixels.data(), 192, 144, 768, 2, &command));
    auto* file = std::fopen((directory + "/plain.raw").c_str(), "wb");
    assert(file && std::fwrite(pixels.data(), 1, pixels.size(), file) == pixels.size());
    std::fclose(file);
    save_readback("plain");

    // The same source and filter graph as canvas-svg-filters.html. Compare
    // these complete bitmaps with Brave, including translucent edge pixels.
    int32_t input0[] {-1}, input1[] {0}, input2[] {1}, merge[] {2, 1}, input4[] {3};
    VoxCanvasSvgFilterNode graph[5] {};
    graph[0].kind = 5; graph[0].inputs = input0; graph[0].input_count = 1;
    graph[1].kind = 0; graph[1].inputs = input1; graph[1].input_count = 1; graph[1].x = graph[1].y = 6;
    graph[2].kind = 2; graph[2].inputs = input2; graph[2].input_count = 1;
    graph[3].kind = 3; graph[3].inputs = merge; graph[3].input_count = 2;
    graph[4].kind = 6; graph[4].inputs = input4; graph[4].input_count = 1;
    VoxCanvasFilter filters[2] {};
    filters[0].radius = 6; filters[0].graph_nodes = graph;
    filters[0].graph_count = 5; filters[0].graph_root = 4;
    filters[0].graph_region[2] = filters[0].graph_region[3] = 1;
    filters[0].graph_object_bounds = 1;
    filters[1].kind = 4; filters[1].clamp = 1;
    filters[1].matrix[0] = filters[1].matrix[6] = filters[1].matrix[12] = 1;
    filters[1].matrix[18] = .9f;
    command.filters = filters; command.filter_count = 2;
    for (int kind : {3, 0}) {
        filters[0].kind = kind;
        std::fill(pixels.begin(), pixels.end(), 0);
        assert(vox_skia_canvas_path_chromium(pixels.data(), 192, 144, 768, 2, &command));
        auto* output = std::fopen((directory + (kind == 3 ? "/backdrop.raw" : "/blur.raw")).c_str(), "wb");
        assert(output && std::fwrite(pixels.data(), 1, pixels.size(), output) == pixels.size());
        std::fclose(output);
        save_readback(kind == 3 ? "backdrop" : "blur");
        // The extra filter kind must leave LibWeb's CPU matrix behavior intact.
        std::vector<uint8_t> cpu(pixels.size()), matrix(pixels.size());
        assert(vox_skia_canvas_path(cpu.data(), 192, 144, 768, 2, &command));
        filters[1].kind = 2;
        assert(vox_skia_canvas_path(matrix.data(), 192, 144, 768, 2, &command));
        assert(cpu == matrix);
        filters[1].kind = 4;
    }
    command.filters = nullptr; command.filter_count = 0;

    // Backend failure and ineligible requests must leave the destination intact.
    auto before = pixels;
    assert(!replay_canvas_image(pixels.data(), 192, 144, 768, 2, &command, failing_draw));
    assert(calls == 1 && pixels == before);
    calls = 0;
    auto reject = [&](VoxCanvasCommand const& input, int width, int height, int pitch) {
        assert(!replay_canvas_image(pixels.data(), width, height, pitch, 2, &input, failing_draw));
        assert(calls == 0 && pixels == before);
    };
    reject(command, 16385, 1, 65540);
    reject(command, 4096, 4096, 16384);
    reject(command, 192, 144, 767);
    auto invalid = command; invalid.style.pattern_color_space = 1; reject(invalid, 192, 144, 768);
    invalid = command; invalid.style.pattern_width = 16385; reject(invalid, 192, 144, 768);
    invalid = command; invalid.style.pattern_pitch = 255; reject(invalid, 192, 144, 768);
    invalid = command; invalid.style.pattern = nullptr; reject(invalid, 192, 144, 768);
    invalid = command; invalid.composite = 26; reject(invalid, 192, 144, 768);
    invalid = command; invalid.operation = 0; reject(invalid, 192, 144, 768);

    // Integer geometry gives an exact CPU oracle for transforms, device clips,
    // compositing, destination alpha conversion and padded destination rows.
    uint8_t red[] {255, 0, 0, 255};
    command.style.pattern = red; command.style.pattern_width = command.style.pattern_height = 1;
    command.style.pattern_pitch = 4; command.source[2] = command.source[3] = 1;
    command.destination[2] = command.destination[3] = 8;
    command.transform[4] = 4; command.transform[5] = 2;
    command.smoothing = 0;
    float clip_segments[5 * 12] {};
    clip_segments[0] = 0; clip_segments[1] = 6; clip_segments[2] = 4;
    clip_segments[12] = 1; clip_segments[13] = 10; clip_segments[14] = 4;
    clip_segments[24] = 1; clip_segments[25] = 10; clip_segments[26] = 8;
    clip_segments[36] = 1; clip_segments[37] = 6; clip_segments[38] = 8;
    clip_segments[48] = 5;
    VoxCanvasPath clip {clip_segments, 5, 0};
    command.clips = &clip; command.clip_count = 1;
    filters[1].matrix[18] = 1;
    for (bool filtered : {false, true}) for (int alpha : {1, 2}) for (int composite : {0, 6, 9, 10}) {
        command.filters = filtered ? filters + 1 : nullptr;
        command.filter_count = filtered ? 1 : 0;
        command.composite = composite; command.global_alpha = .5;
        std::vector<uint8_t> cpu(80 * 16, 0xad);
        for (int y = 0; y < 16; ++y) for (int x = 0; x < 16; ++x) {
            auto* p = cpu.data() + y * 80 + x * 4;
            p[0] = 0; p[1] = alpha == 1 ? 254 : 127; p[2] = 0; p[3] = 128;
        }
        auto gpu = cpu;
        assert(vox_skia_canvas_path(cpu.data(), 16, 16, 80, alpha, &command));
        assert(vox_skia_canvas_path_chromium(gpu.data(), 16, 16, 80, alpha, &command));
        assert(cpu == gpu);
        for (int y = 0; y < 16; ++y) for (int i = 64; i < 80; ++i) assert(gpu[y * 80 + i] == 0xad);
    }
    std::puts("Chromium Canvas GPU: sampling, filters, transforms, clips, alpha, compositing, stride and transactional fallback passed");
}
