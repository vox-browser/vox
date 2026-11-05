// Draws glyph-run scenes with LibWeb's CPU Skia exactly as the Vox bridge's
// retained glyph path does (native_skia_text_darwin.cpp, draw_retained_glyph_run)
// and writes NAME.expected.bgra for every scene.
//
// Script:
//   text NAME WIDTH HEIGHT
//   background transparent | B G R A          (premultiplied fill)
//   font PATH SIZE WEIGHT SMOOTHING           (SMOOTHING as passed to the bridge)
//   matrix A B C D E F                        (device = [A C E; B D F])
//   color R G B A
//   origin X Y                                (baseline origin added to every position)
//   glyph ID X Y                              (repeated)
//   end

#include "include/core/SkCanvas.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkData.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkFontStyle.h"
#include "include/core/SkPaint.h"
#include "include/core/SkStream.h"
#include "include/core/SkSurface.h"
#include "include/core/SkSurfaceProps.h"
#include "include/core/SkTextBlob.h"
#include "include/core/SkTypeface.h"
#include "include/ports/SkFontMgr_mac_ct.h"

#include <cstdio>
#include <cstring>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

namespace {

struct Scene {
    std::string name;
    int width = 0, height = 0;
    bool transparent = true;
    uint8_t background[4] {};
    std::string font_path;
    float font_size = 16;
    int font_weight = 400;
    int smoothing = 16;
    float matrix[6] {1, 0, 0, 1, 0, 0};
    uint8_t color[4] {0, 0, 0, 255};
    float origin[2] {};
    std::vector<uint16_t> glyphs;
    std::vector<double> positions;
};

std::map<std::string, sk_sp<SkTypeface>> s_typefaces;

SkTypeface* typeface_for(std::string const& path)
{
    if (auto found = s_typefaces.find(path); found != s_typefaces.end()) return found->second.get();
    static sk_sp<SkFontMgr> manager = SkFontMgr_New_CoreText(nullptr);
    auto data = SkData::MakeFromFileName(path.c_str());
    sk_sp<SkTypeface> typeface;
    if (data) {
        SkFontArguments arguments;
        arguments.setCollectionIndex(0);
        typeface = manager->makeFromStream(std::make_unique<SkMemoryStream>(std::move(data)), arguments);
    }
    auto* result = typeface.get();
    s_typefaces.emplace(path, std::move(typeface));
    return result;
}

bool render(Scene const& scene, std::vector<uint32_t>& pixels)
{
    auto* typeface = typeface_for(scene.font_path);
    if (!typeface) return false;
    int const font_smoothing = scene.smoothing;
    // The font setup of draw_retained_glyph_run.
    SkFont font(sk_ref_sp(typeface), std::max(scene.font_size, 0.0f));
    font.setEmbolden((font_smoothing & 16) && !(font_smoothing & 128) && scene.font_weight >= 600
        && typeface->fontStyle().weight() < 600);
    font.setSkewX((font_smoothing & 64) && !typeface->isItalic() ? -0.25f : 0.0f);
    if (font_smoothing & 16) {
        font.setEmbeddedBitmaps(false);
        font.setLinearMetrics(true);
        font.setEdging(SkFont::Edging::kSubpixelAntiAlias);
    }
    font.setSubpixel(true);
    switch (font_smoothing & 15) {
    case 1: font.setEdging(SkFont::Edging::kAlias); break;
    case 2:
        font.setEdging(SkFont::Edging::kAntiAlias);
        font.setHinting(SkFontHinting::kNone);
        break;
    case 3: font.setEdging(SkFont::Edging::kSubpixelAntiAlias); break;
    default: break;
    }
    bool const chromium = font_smoothing & 16;

    SkTextBlobBuilder builder;
    int const count = int(scene.glyphs.size());
    auto const& run = builder.allocRunPos(font, count);
    std::memcpy(run.glyphs, scene.glyphs.data(), size_t(count) * sizeof(uint16_t));
    float const origin_x = chromium ? scene.origin[0] : 0;
    float const origin_y = chromium ? scene.origin[1] : 0;
    for (int i = 0; i < count * 2; ++i)
        run.pos[i] = static_cast<SkScalar>(scene.positions[i]) + (i % 2 ? origin_y : origin_x);
    auto blob = builder.make();
    if (!blob) return false;
    float const blob_x = chromium ? 0 : scene.origin[0];
    float const blob_y = chromium ? 0 : scene.origin[1];

    SkPaint paint;
    paint.setColor(SkColorSetARGB(scene.color[3], scene.color[0], scene.color[1], scene.color[2]));
    auto matrix = SkMatrix::MakeAll(scene.matrix[0], scene.matrix[2], scene.matrix[4],
        scene.matrix[1], scene.matrix[3], scene.matrix[5], 0, 0, 1);

    pixels.assign(size_t(scene.width) * scene.height, 0);
    if (!scene.transparent) {
        uint32_t fill;
        std::memcpy(&fill, scene.background, 4);
        pixels.assign(pixels.size(), fill);
    }
    auto info = SkImageInfo::Make(scene.width, scene.height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    SkSurfaceProps chromium_coverage(0, kUnknown_SkPixelGeometry, 0.0f,
        (font_smoothing & 15) == 2 ? 1.0f : 0.0f);
    auto surface = SkSurfaces::WrapPixels(info, pixels.data(), size_t(scene.width) * 4,
        chromium ? &chromium_coverage : nullptr);
    if (!surface) return false;
    auto* canvas = surface->getCanvas();
    if (scene.transparent) canvas->clear(SK_ColorTRANSPARENT);
    canvas->setMatrix(matrix);
    canvas->drawTextBlob(blob, blob_x, blob_y, paint);
    return true;
}

}

int main(int argc, char** argv)
{
    if (argc != 3) {
        std::fprintf(stderr, "usage: %s SCRIPT OUTPUT_DIRECTORY\n", argv[0]);
        return 2;
    }
    std::string output = argv[2];
    std::ifstream script(argv[1]);
    std::string line;
    Scene scene;
    int scenes = 0, failures = 0;
    while (std::getline(script, line)) {
        std::istringstream in(line);
        std::string word;
        if (!(in >> word) || word[0] == '#') continue;
        if (word == "text") {
            scene = Scene {};
            in >> scene.name >> scene.width >> scene.height;
        } else if (word == "background") {
            std::string first;
            in >> first;
            if (first == "transparent") {
                scene.transparent = true;
            } else {
                scene.transparent = false;
                int b = std::stoi(first), g, r, a;
                in >> g >> r >> a;
                scene.background[0] = uint8_t(b);
                scene.background[1] = uint8_t(g);
                scene.background[2] = uint8_t(r);
                scene.background[3] = uint8_t(a);
            }
        } else if (word == "font") {
            in >> scene.font_path >> scene.font_size >> scene.font_weight >> scene.smoothing;
        } else if (word == "matrix") {
            for (auto& value : scene.matrix) in >> value;
        } else if (word == "color") {
            for (auto& value : scene.color) {
                int v;
                in >> v;
                value = uint8_t(v);
            }
        } else if (word == "origin") {
            in >> scene.origin[0] >> scene.origin[1];
        } else if (word == "glyph") {
            int id;
            double x, y;
            in >> id >> x >> y;
            scene.glyphs.push_back(uint16_t(id));
            scene.positions.push_back(x);
            scene.positions.push_back(y);
        } else if (word == "end") {
            std::vector<uint32_t> pixels;
            ++scenes;
            if (!render(scene, pixels)) {
                std::fprintf(stderr, "%s: render failed\n", scene.name.c_str());
                ++failures;
                continue;
            }
            auto path = output + "/" + scene.name + ".expected.bgra";
            FILE* file = std::fopen(path.c_str(), "wb");
            if (!file) return 1;
            std::fwrite(pixels.data(), 4, pixels.size(), file);
            std::fclose(file);
        }
    }
    std::printf("%d scenes, %d failed\n", scenes, failures);
    return failures ? 1 : 0;
}
