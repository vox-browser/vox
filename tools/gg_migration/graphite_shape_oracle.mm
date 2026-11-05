// Runs the original Graphite shape backend on a fixed corpus, saving each
// input descriptor, backdrop, output and Metal trace for the gg port.
#include "../../native_graphite_bridge.h"
#include "metal_trace.h"
#include <cstdio>
#include <cstring>
#include <algorithm>
#include <dirent.h>
#include <dlfcn.h>
#include <string>
#include <vector>

namespace {

struct Case {
    std::string name;
    int width, height, has_background;
    VoxGraphiteShape shape;
};

void write_file(std::string const& path, void const* data, size_t size)
{
    FILE* file = std::fopen(path.c_str(), "wb");
    if (!file) { std::perror(path.c_str()); std::exit(1); }
    std::fwrite(data, 1, size, file);
    std::fclose(file);
}

VoxGraphiteShape base_shape(float x, float y, float w, float h, float radius)
{
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[0] = x; shape.rect[1] = y; shape.rect[2] = w; shape.rect[3] = h;
    for (int i = 4; i < 12; ++i) shape.rect[i] = radius;
    shape.fill = 1;
    shape.anti_alias = 1;
    shape.red = 35; shape.green = 167; shape.blue = 79; shape.alpha = 255;
    return shape;
}

std::vector<Case> corpus()
{
    std::vector<Case> cases;
    auto add = [&](std::string name, VoxGraphiteShape shape, int background = 0) {
        cases.push_back({std::move(name), 64, 48, background, shape});
    };
    add("rrect-fill-aa", base_shape(5.25f, 4.5f, 40.5f, 30.25f, 6));
    add("rect-fill-aa-fractional", base_shape(5.25f, 4.5f, 40.5f, 30.25f, 0));
    auto translucent = base_shape(5, 4, 40, 30, 0);
    translucent.alpha = 127;
    add("rect-fill-aligned-translucent", translucent);
    auto stroke = base_shape(5.25f, 4.5f, 40.5f, 30.25f, 6);
    stroke.fill = 0; stroke.thickness = 2;
    add("rrect-stroke-aa", stroke);
    auto non_aa = base_shape(5.25f, 4.5f, 40.5f, 30.25f, 6);
    non_aa.anti_alias = 0;
    add("rrect-fill-non-aa", non_aa);
    auto msaa = base_shape(5.25f, 4.5f, 40.5f, 30.25f, 6);
    msaa.force_msaa = 1;
    add("rrect-fill-msaa", msaa);
    auto background = base_shape(5.25f, 4.5f, 40.5f, 30.25f, 6);
    background.alpha = 200;
    add("rrect-fill-background", background, 1);
    auto elliptical = base_shape(3.75f, 6.5f, 50, 33, 0);
    for (int i = 4; i < 12; i += 2) { elliptical.rect[i] = 9 + i; elliptical.rect[i + 1] = 5 + i / 2.f; }
    add("rrect-elliptical", elliptical);
    auto scaled = base_shape(3.25f, 2.5f, 20.5f, 15.25f, 3);
    scaled.matrix[0] = scaled.matrix[4] = 2;
    add("rrect-scale2", scaled);
    // CSS borders drawn with their background (vox_draw_rounded_single_border):
    // uniform rings sharing the background's layer (mode 7) and single sides.
    auto with_background = [](VoxGraphiteShape shape, int fill, float top, float right,
                               float bottom, float left) {
        shape.fill = fill;
        shape.border_widths[0] = top; shape.border_widths[1] = right;
        shape.border_widths[2] = bottom; shape.border_widths[3] = left;
        shape.has_underlay = 1;
        shape.underlay_rgba[0] = 230; shape.underlay_rgba[1] = 200; shape.underlay_rgba[2] = 40;
        shape.underlay_rgba[3] = 255;
        return shape;
    };
    auto ring = with_background(base_shape(8.5f, 7.25f, 40.5f, 28.5f, 9), 7, 3, 3, 3, 3);
    ring.alpha = 160;
    add("ring-shared-background-translucent", ring);
    ring.alpha = 255;
    add("ring-shared-background", ring, 1);
    ring.alpha = 0;
    add("ring-shared-background-invisible", ring);
    auto top = with_background(base_shape(6.25f, 5.5f, 44, 30, 7), 2, 4, 1.5f, 2, 1);
    add("side-top-background", top, 1);
    auto left = with_background(base_shape(6.25f, 5.5f, 44, 30, 7), 5, 0, 0, 0, 3);
    left.force_msaa = 1;
    add("side-left-background-msaa", left);
    return cases;
}

}

// Replays descriptors dumped from the browser (NAME.shape.bin, NAME.args with
// width, height, pitch and has_background, and NAME.clips.bin with the
// clip-out rectangles) over the oracle's backdrop.
std::vector<uint8_t> read_file(std::string const& path)
{
    std::vector<uint8_t> data;
    FILE* file = std::fopen(path.c_str(), "rb");
    if (!file) return data;
    std::fseek(file, 0, SEEK_END);
    data.resize(size_t(std::ftell(file)));
    std::fseek(file, 0, SEEK_SET);
    if (!data.empty() && std::fread(data.data(), 1, data.size(), file) != data.size()) data.clear();
    std::fclose(file);
    return data;
}

int replay(decltype(&vox_graphite_draw_shape_pixels) draw, std::string const& input,
    std::string const& output)
{
    std::vector<std::string> names;
    if (auto* directory = opendir(input.c_str())) {
        while (auto* entry = readdir(directory)) {
            std::string name = entry->d_name;
            auto suffix = std::string(".shape.bin");
            if (name.size() > suffix.size() && name.compare(name.size() - suffix.size(), suffix.size(), suffix) == 0)
                names.push_back(name.substr(0, name.size() - suffix.size()));
        }
        closedir(directory);
    }
    std::sort(names.begin(), names.end());
    for (auto const& name : names) {
        auto descriptor = read_file(input + "/" + name + ".shape.bin");
        auto clips = read_file(input + "/" + name + ".clips.bin");
        auto args = read_file(input + "/" + name + ".args");
        int width = 0, height = 0, pitch = 0, has_background = 0;
        std::string text(args.begin(), args.end());
        if (descriptor.size() != sizeof(VoxGraphiteShape)
            || std::sscanf(text.c_str(), "%d %d %d %d", &width, &height, &pitch, &has_background) != 4
            || width <= 0 || height <= 0) {
            std::fprintf(stderr, "%s: unreadable dump\n", name.c_str());
            continue;
        }
        VoxGraphiteShape shape;
        std::memcpy(&shape, descriptor.data(), sizeof shape);
        shape.clip_outs = clips.size() >= size_t(shape.clip_out_count) * 16 && shape.clip_out_count > 0
            ? reinterpret_cast<float const*>(clips.data()) : nullptr;
        if (shape.clip_out_count > 0 && !shape.clip_outs) continue;
        pitch = width * 4;
        std::vector<uint8_t> pixels(size_t(pitch) * height);
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            uint8_t* pixel = pixels.data() + size_t(y) * pitch + x * 4;
            uint8_t alpha = uint8_t(has_background ? 128 + (x * 7 + y * 3) % 128 : 0);
            pixel[0] = uint8_t((x * 13) % (alpha + 1));
            pixel[1] = uint8_t((y * 29) % (alpha + 1));
            pixel[2] = uint8_t(((x + y) * 5) % (alpha + 1));
            pixel[3] = alpha;
        }
        std::string prefix = output + "/" + name;
        write_file(prefix + ".shape.bin", descriptor.data(), descriptor.size());
        if (!clips.empty()) write_file(prefix + ".clips.bin", clips.data(), clips.size());
        auto line = std::to_string(width) + " " + std::to_string(height) + " " + std::to_string(pitch)
            + " " + std::to_string(has_background);
        write_file(prefix + ".args", line.data(), line.size());
        write_file(prefix + ".backdrop.bgra", pixels.data(), pixels.size());
        int result = draw(pixels.data(), width, height, pitch, has_background, &shape);
        write_file(prefix + ".expected.bgra", pixels.data(), pixels.size());
        std::printf("%s result=%d %dx%d clips=%d\n", name.c_str(), result, width, height,
            shape.clip_out_count);
    }
    return 0;
}

int main(int argc, char** argv)
{
    if (argc != 3 && argc != 4) {
        std::fprintf(stderr, "usage: %s LIBRARY OUTPUT_DIRECTORY [DUMP_DIRECTORY]\n", argv[0]);
        return 2;
    }
    std::string output = argv[2];
    vox_metal_trace_install(output.c_str());
    void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) { std::fprintf(stderr, "%s\n", dlerror()); return 1; }
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(library, "vox_graphite_draw_shape_pixels"));
    if (!draw) return 1;
    if (argc == 4) return replay(draw, argv[3], output);
    for (auto const& item : corpus()) {
        int pitch = item.width * 4;
        std::vector<uint8_t> pixels(size_t(pitch) * item.height);
        // A deterministic, premultiplied BGRA backdrop.
        for (int y = 0; y < item.height; ++y) for (int x = 0; x < item.width; ++x) {
            uint8_t* pixel = pixels.data() + size_t(y) * pitch + x * 4;
            uint8_t alpha = uint8_t(item.has_background ? 128 + (x * 7 + y * 3) % 128 : 0);
            pixel[0] = uint8_t((x * 13) % (alpha + 1));
            pixel[1] = uint8_t((y * 29) % (alpha + 1));
            pixel[2] = uint8_t(((x + y) * 5) % (alpha + 1));
            pixel[3] = alpha;
        }
        std::string prefix = output + "/" + item.name;
        write_file(prefix + ".shape.bin", &item.shape, sizeof item.shape);
        write_file(prefix + ".backdrop.bgra", pixels.data(), pixels.size());
        vox_metal_trace_begin(output.c_str(), item.name.c_str());
        int result = draw(pixels.data(), item.width, item.height, pitch, item.has_background, &item.shape);
        vox_metal_trace_end();
        write_file(prefix + ".expected.bgra", pixels.data(), pixels.size());
        std::printf("%s result=%d %dx%d background=%d\n", item.name.c_str(), result, item.width,
            item.height, item.has_background);
    }
    return 0;
}
