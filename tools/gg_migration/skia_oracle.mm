// Executes gg.canvas scene scripts with the pinned Chromium Skia Graphite
// Metal backend and writes the reference pixels for each scene.
//
// Script lines (floats unless noted):
//   scene NAME WIDTH HEIGHT SAMPLES BACKGROUND   start a scene (ints, BACKGROUND 0/1)
//   matrix M0..M8                                 set the 3x3 row-major matrix
//   paint R G B A AA STYLE WIDTH JOIN CAP MITER  unpremul color, AA 0/1,
//                                                 STYLE 0 fill / 1 stroke, JOIN 0 miter
//                                                 1 round 2 bevel, CAP 0 butt 1 round 2 square
//   color8 R G B A                                replace the paint color with 8-bit values
//   rect L T R B
//   rrect L T R B RX0 RY0 RX1 RY1 RX2 RY2 RX3 RY3
//   oval L T R B
//   clipout L T R B                               clip out a rect without AA, like Vox's
//                                                 shape clip-outs (SkClipOp::kDifference)
//   cliprect L T R B OP AA                        clipRect (ints OP 0 intersect / 1 difference,
//                                                 AA 0/1)
//   cliprrect L T R B RX0 RY0 .. RX3 RY3 OP AA    clipRRect
//   drrect L T R B RX0 .. RY3 L T R B RX0 .. RY3  drawDRRect(outer, inner)
//   save / restore
//   savelayer [L T R B]                           saveLayer without a paint, unbounded or with
//                                                 bounds (Vox's SVG images with rounded clips)
//   path FILL TOKENS...                           drawPath (FILL 0 winding, 1 even-odd, 2 and
//                                                 3 their inverses); tokens
//                                                 M x y, L x y, Q x1 y1 x y, C x1 y1 x2 y2 x y,
//                                                 K x1 y1 x y w (conic), A rx ry degrees large
//                                                 sweep x y (SVG arc), Z, O l t r b (addOval
//                                                 clockwise from start index 1)
//   gradient KIND TILE PREMUL DITHER LINEARCS OPACITY N X0 Y0 R0/X1 ... M0..M8 (R G B A POS)xN
//                                                 gradient shader for the paint, like the
//                                                 bridge's SVG path gradients (KIND 1 linear
//                                                 from (P0,P1) to (P2,P3), 2 two-point conical
//                                                 (P0,P1,P2) to (P3,P4,P5)); after `paint`
//   clippath OP AA FILL TOKENS...                 clipPath with the path tokens above (ints
//                                                 OP 0 intersect / 1 difference, AA 0/1)
//   end                                           render and write NAME.expected.bgra
#include "include/core/SkCanvas.h"
#include "include/core/SkColorFilter.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkRRect.h"
#include "include/core/SkShader.h"
#include "include/core/SkSurface.h"
#include "include/effects/SkGradient.h"
#include "include/gpu/graphite/Context.h"
#include "include/gpu/graphite/ContextOptions.h"
#include "include/gpu/graphite/Recorder.h"
#include "include/gpu/graphite/Recording.h"
#include "include/gpu/graphite/Surface.h"
#include "include/gpu/graphite/mtl/MtlBackendContext.h"
#include "include/gpu/graphite/mtl/MtlGraphiteUtils.h"
#import <Metal/Metal.h>
#include "metal_trace.h"
#include <cstdio>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <algorithm>
#include <vector>

namespace {

SkRRect read_rrect(std::istringstream& words) {
    float l, t, r, b;
    SkVector radii[4];
    words >> l >> t >> r >> b;
    for (auto& radius : radii) words >> radius.fX >> radius.fY;
    SkRRect rrect;
    rrect.setRectRadii(SkRect::MakeLTRB(l, t, r, b), radii);
    return rrect;
}

// Reads FILL then path tokens (see the script format above) up to the end of
// the line.
bool read_path(std::istringstream& words, SkPath* out) {
    int fill;
    words >> fill;
    SkPathBuilder builder;
    std::string token;
    while (words >> token) {
        float v[6];
        if (token == "M") { words >> v[0] >> v[1]; builder.moveTo(v[0], v[1]); }
        else if (token == "L") { words >> v[0] >> v[1]; builder.lineTo(v[0], v[1]); }
        else if (token == "Q") {
            words >> v[0] >> v[1] >> v[2] >> v[3];
            builder.quadTo(v[0], v[1], v[2], v[3]);
        } else if (token == "C") {
            for (float& x : v) words >> x;
            builder.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
        } else if (token == "K") {
            words >> v[0] >> v[1] >> v[2] >> v[3] >> v[4];
            builder.conicTo(v[0], v[1], v[2], v[3], v[4]);
        } else if (token == "A") {
            float large, sweep;
            words >> v[0] >> v[1] >> v[2] >> large >> sweep >> v[3] >> v[4];
            builder.arcTo({v[0], v[1]}, v[2],
                large != 0 ? SkPathBuilder::kLarge_ArcSize : SkPathBuilder::kSmall_ArcSize,
                sweep != 0 ? SkPathDirection::kCW : SkPathDirection::kCCW, {v[3], v[4]});
        } else if (token == "Z") {
            builder.close();
        } else if (token == "O") {
            words >> v[0] >> v[1] >> v[2] >> v[3];
            builder.addOval(SkRect::MakeLTRB(v[0], v[1], v[2], v[3]), SkPathDirection::kCW, 1);
        } else {
            std::fprintf(stderr, "unknown path token %s\n", token.c_str());
            return false;
        }
    }
    // FILL 0 winding, 1 even-odd, 2 inverse winding, 3 inverse even-odd.
    builder.setFillType(fill == 3 ? SkPathFillType::kInverseEvenOdd
        : fill == 2 ? SkPathFillType::kInverseWinding
        : fill ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    *out = builder.detach();
    return true;
}

void fill_backdrop(std::vector<uint8_t>& pixels, int width, int height)
{
    // Must match canvas_scene.v.
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        uint8_t* pixel = pixels.data() + (size_t(y) * width + x) * 4;
        uint8_t alpha = uint8_t(128 + (x * 7 + y * 3) % 128);
        pixel[0] = uint8_t((x * 13) % (alpha + 1));
        pixel[1] = uint8_t((y * 29) % (alpha + 1));
        pixel[2] = uint8_t(((x + y) * 5) % (alpha + 1));
        pixel[3] = alpha;
    }
}

void force_msaa_render_pass(SkCanvas* canvas)
{
    // Identical to native_graphite_darwin.mm: a tiny path selects 4x MSAA
    // without covering a sample.
    SkPaint noop;
    noop.setAntiAlias(true);
    noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
    SkPathBuilder path;
    path.moveTo(0, 0);
    path.cubicTo(.01f, .001f, 0, .01f, .01f, .01f);
    path.lineTo(.005f, .002f);
    path.close();
    canvas->drawPath(path.detach(), noop);
}

struct Scene {
    std::string name;
    int width = 0, height = 0, samples = 1, background = 0;
    sk_sp<SkSurface> surface;
    SkPaint paint;
};

}

int main(int argc, char** argv)
{
    if (argc != 3) {
        std::fprintf(stderr, "usage: %s SCRIPT OUTPUT_DIRECTORY\n", argv[0]);
        return 2;
    }
    std::string output = argv[2];
    vox_metal_trace_install(output.c_str());
    skgpu::graphite::MtlBackendContext backend;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    backend.fDevice.reset((__bridge_retained CFTypeRef)device);
    backend.fQueue.reset((__bridge_retained CFTypeRef)[device newCommandQueue]);
    skgpu::graphite::ContextOptions options;
    auto context = skgpu::graphite::ContextFactory::MakeMetal(backend, options);
    if (!context) { std::fprintf(stderr, "no Graphite context\n"); return 1; }
    auto recorder = context->makeRecorder();
    std::ifstream script(argv[1]);
    std::string line;
    Scene scene;
    int scenes = 0;
    while (std::getline(script, line)) {
        std::istringstream words(line);
        std::string command;
        if (!(words >> command) || command[0] == '#') continue;
        if (command == "scene") {
            words >> scene.name >> scene.width >> scene.height >> scene.samples >> scene.background;
            auto info = SkImageInfo::Make(scene.width, scene.height, kBGRA_8888_SkColorType,
                kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
            scene.surface = SkSurfaces::RenderTarget(recorder.get(), info);
            scene.paint = SkPaint();
            auto* canvas = scene.surface->getCanvas();
            vox_metal_trace_begin(output.c_str(), scene.name.c_str());
            if (scene.background) {
                std::vector<uint8_t> pixels(size_t(scene.width) * scene.height * 4);
                fill_backdrop(pixels, scene.width, scene.height);
                scene.surface->writePixels(SkPixmap(info, pixels.data(), size_t(scene.width) * 4), 0, 0);
            } else {
                canvas->clear(SK_ColorTRANSPARENT);
            }
            if (scene.samples == 4) force_msaa_render_pass(canvas);
        } else if (command == "matrix") {
            float m[9];
            for (float& v : m) words >> v;
            SkMatrix matrix;
            matrix.set9(m);
            scene.surface->getCanvas()->setMatrix(matrix);
        } else if (command == "paint") {
            float r, g, b, a, width, miter;
            int aa, style, join, cap;
            words >> r >> g >> b >> a >> aa >> style >> width >> join >> cap >> miter;
            scene.paint = SkPaint();
            scene.paint.setColor4f({r, g, b, a});
            scene.paint.setAntiAlias(aa != 0);
            scene.paint.setStyle(style ? SkPaint::kStroke_Style : SkPaint::kFill_Style);
            scene.paint.setStrokeWidth(width);
            scene.paint.setStrokeJoin(join == 1 ? SkPaint::kRound_Join
                : join == 2 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
            scene.paint.setStrokeCap(cap == 1 ? SkPaint::kRound_Cap
                : cap == 2 ? SkPaint::kSquare_Cap : SkPaint::kButt_Cap);
            scene.paint.setStrokeMiter(miter);
        } else if (command == "gradient") {
            // Like draw_path_on_canvas() in native_graphite_darwin.mm.
            int kind, tile, premul, dither, linear_cs, count;
            float points[6], matrix[9], opacity;
            words >> kind >> tile >> premul >> dither >> linear_cs >> opacity >> count;
            for (float& v : points) words >> v;
            for (float& v : matrix) words >> v;
            std::vector<SkColor4f> colors(count);
            std::vector<float> positions(count);
            for (int i = 0; i < count; ++i)
                words >> colors[i].fR >> colors[i].fG >> colors[i].fB >> colors[i].fA >> positions[i];
            SkMatrix local;
            local.set9(matrix);
            SkGradient::Interpolation interpolation;
            if (premul) interpolation.fInPremul = SkGradient::Interpolation::InPremul::kYes;
            SkGradient gradient(SkGradient::Colors(SkSpan<const SkColor4f>(colors),
                SkSpan<const float>(positions), static_cast<SkTileMode>(tile)), interpolation);
            sk_sp<SkShader> shader;
            if (kind == 1) {
                SkPoint ends[] {{points[0], points[1]}, {points[2], points[3]}};
                shader = SkShaders::LinearGradient(ends, gradient, &local);
            } else {
                shader = SkShaders::TwoPointConicalGradient({points[0], points[1]}, points[2],
                    {points[3], points[4]}, points[5], gradient, &local);
            }
            scene.paint.setShader(std::move(shader));
            scene.paint.setDither(dither != 0);
            scene.paint.setAlphaf(std::clamp(opacity, 0.0f, 1.0f));
            if (linear_cs) scene.paint.setColorFilter(SkColorFilters::LinearToSRGBGamma());
        } else if (command == "color8") {
            int r, g, b, a;
            words >> r >> g >> b >> a;
            scene.paint.setColor(SkColorSetARGB(a, r, g, b));
        } else if (command == "rect" || command == "oval") {
            float l, t, r, b;
            words >> l >> t >> r >> b;
            if (command == "rect")
                scene.surface->getCanvas()->drawRect(SkRect::MakeLTRB(l, t, r, b), scene.paint);
            else
                scene.surface->getCanvas()->drawOval(SkRect::MakeLTRB(l, t, r, b), scene.paint);
        } else if (command == "clipout") {
            float l, t, r, b;
            words >> l >> t >> r >> b;
            scene.surface->getCanvas()->clipRect(SkRect::MakeLTRB(l, t, r, b),
                SkClipOp::kDifference, false);
        } else if (command == "edgequad") {
            // Oracle shader probes for Graphite's PerEdgeAAQuad renderer.
            float l, t, r, b;
            unsigned flags;
            words >> l >> t >> r >> b >> flags;
            SkPoint quad[4];
            bool has_quad = bool(words >> quad[0].fX >> quad[0].fY);
            if (has_quad)
                for (int i = 1; i < 4; ++i) words >> quad[i].fX >> quad[i].fY;
            scene.surface->getCanvas()->experimental_DrawEdgeAAQuad(SkRect::MakeLTRB(l, t, r, b),
                has_quad ? quad : nullptr, static_cast<SkCanvas::QuadAAFlags>(flags), scene.paint.getColor4f(),
                SkBlendMode::kSrcOver);
        } else if (command == "rrect") {
            scene.surface->getCanvas()->drawRRect(read_rrect(words), scene.paint);
        } else if (command == "drrect") {
            SkRRect outer = read_rrect(words);
            SkRRect inner = read_rrect(words);
            scene.surface->getCanvas()->drawDRRect(outer, inner, scene.paint);
        } else if (command == "cliprect" || command == "cliprrect") {
            SkRect rect;
            SkRRect rrect;
            if (command == "cliprect") {
                words >> rect.fLeft >> rect.fTop >> rect.fRight >> rect.fBottom;
            } else {
                rrect = read_rrect(words);
            }
            int op, aa;
            words >> op >> aa;
            auto clip_op = op ? SkClipOp::kDifference : SkClipOp::kIntersect;
            if (command == "cliprect")
                scene.surface->getCanvas()->clipRect(rect, clip_op, aa != 0);
            else
                scene.surface->getCanvas()->clipRRect(rrect, clip_op, aa != 0);
        } else if (command == "path") {
            SkPath path;
            if (!read_path(words, &path)) return 1;
            scene.surface->getCanvas()->drawPath(path, scene.paint);
        } else if (command == "clippath") {
            int op, aa;
            words >> op >> aa;
            SkPath path;
            if (!read_path(words, &path)) return 1;
            scene.surface->getCanvas()->clipPath(path,
                op ? SkClipOp::kDifference : SkClipOp::kIntersect, aa != 0);
        } else if (command == "save") {
            scene.surface->getCanvas()->save();
        } else if (command == "savelayer") {
            float b[4];
            if (words >> b[0] >> b[1] >> b[2] >> b[3]) {
                SkRect bounds = SkRect::MakeLTRB(b[0], b[1], b[2], b[3]);
                scene.surface->getCanvas()->saveLayer(&bounds, nullptr);
            } else scene.surface->getCanvas()->saveLayer(nullptr, nullptr);
        } else if (command == "restore") {
            scene.surface->getCanvas()->restore();
        } else if (command == "end") {
            auto info = scene.surface->imageInfo();
            std::vector<uint8_t> pixels(size_t(scene.width) * scene.height * 4);
            auto recording = recorder->snap();
            skgpu::graphite::InsertRecordingInfo insertion;
            insertion.fRecording = recording.get();
            context->insertRecording(insertion);
            struct Result { bool done = false; std::unique_ptr<const SkImage::AsyncReadResult> data; } result;
            context->asyncRescaleAndReadPixels(scene.surface.get(), info,
                SkIRect::MakeWH(scene.width, scene.height), SkImage::RescaleGamma::kSrc,
                SkImage::RescaleMode::kNearest,
                [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                    auto* r = static_cast<Result*>(target);
                    r->data = std::move(data);
                    r->done = true;
                }, &result);
            context->submit(skgpu::graphite::SyncToCpu::kYes);
            vox_metal_trace_end();
            if (!result.data) { std::fprintf(stderr, "%s: readback failed\n", scene.name.c_str()); return 1; }
            for (int y = 0; y < scene.height; ++y)
                std::memcpy(pixels.data() + size_t(y) * scene.width * 4,
                    static_cast<uint8_t const*>(result.data->data(0)) + size_t(y) * result.data->rowBytes(0),
                    size_t(scene.width) * 4);
            std::string path = output + "/" + scene.name + ".expected.bgra";
            FILE* file = std::fopen(path.c_str(), "wb");
            std::fwrite(pixels.data(), 1, pixels.size(), file);
            std::fclose(file);
            scene.surface.reset();
            ++scenes;
        }
    }
    std::printf("%d scenes\n", scenes);
    return 0;
}
