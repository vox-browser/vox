// Compare CPU sample resolution with the actual Dawn picture renderer, including
// nonuniform backdrops, transforms, clipping, winding, colors and rejected edges.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    constexpr int width = 80, height = 72, pitch = width * 4 + 13;
    unsigned accepted = 0, rejected = 0, accepted_geometry[4] {};
    for (int geometry = 0; geometry < 4; ++geometry)
    for (int palette = 0; palette < 32; ++palette)
    for (float phase : {0.f, .25f, .5f, .875f})
    for (bool even_odd : {false, true}) {
        std::vector<std::array<float, 12>> segments[2];
        auto segment = [&](int path, int kind, float x, float y) {
            std::array<float, 12> value {}; value[0] = kind; value[1] = x; value[2] = y;
            segments[path].push_back(value);
        };
        segment(0, 0, 8, 8); segment(0, 1, 68, 8); segment(0, 1, 68, 64);
        segment(0, 1, 8, 64); segment(0, 5, 0, 0);
        if (geometry == 0) {
            float points[][2] {{12,12},{45,30},{57,12},{57,55},{45,40},{12,55}};
            for (int i = 0; i < 6; ++i) segment(1, i ? 1 : 0, points[i][0], points[i][1]);
        } else if (geometry == 3) {
            // Archived SVG regression: small viewBox scaling must retain the
            // same sample coverage after the local and parent transforms.
            float points[][2] {{73.2521756f,45.01f},{96,92.40130083f},{118.7478244f,45.01f},
                {138.31352071f,45.01f},{103.99f,109.49661468f},{103.99f,150.99f},
                {88.01f,150.99f},{88.01f,109.49661468f},{53.68647929f,45.01f}};
            for (int i = 0; i < 9; ++i) segment(1, i ? 1 : 0, points[i][0], points[i][1]);
        } else {
            // Concave stars, including intersecting contours with distinct
            // nonzero/even-odd interiors and perturbed tessellation vertices.
            for (int i = 0; i < 10; ++i) {
                int vertex = geometry == 2 ? (i * 3) % 10 : i;
                double angle = vertex * M_PI / 5;
                double radius = vertex % 2 ? 9 : 25;
                segment(1, i ? 1 : 0, 38 + std::cos(angle) * radius + (palette % 7) / 11.f,
                    35 + std::sin(angle) * radius + (palette % 5) / 13.f);
            }
        }
        segment(1, 5, 0, 0);
        VoxGraphitePath paths[2] {};
        for (int i = 0; i < 2; ++i) {
            auto& p = paths[i]; p.matrix[0] = p.matrix[4] = p.matrix[8] = 1;
            p.matrix[2] = i ? phase : 0; p.even_odd = even_odd;
            p.segments = segments[i][0].data(); p.segment_count = segments[i].size();
            p.red = (palette * 73 + i * 255) % 256;
            p.green = (palette * 37 + i * 193) % 256;
            p.blue = (palette * 17 + i * 79) % 256;
            p.alpha = 255; p.has_float_alpha = p.has_float_color = 1; p.opacity = 1;
            p.float_color[0] = p.red / 255.f; p.float_color[1] = p.green / 255.f;
            p.float_color[2] = p.blue / 255.f; p.float_color[3] = 1;
        }
        if (geometry == 3) {
            paths[1].matrix[0] = paths[1].matrix[4] = 36.f / 188;
            paths[1].matrix[2] += 10 - 4 * 36.f / 188;
            paths[1].matrix[5] = 10 - 4 * 36.f / 188;
        }
        float parent[] {1,0,0,0,1,0,0,0,1};
        float viewport[] {4,5,70,60}, clip[] {6,7,73,64};
        std::vector<uint8_t> actual(1 + size_t(pitch) * height, 0xa9);
        std::vector<uint32_t> backdrop(size_t(width) * height);
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            uint32_t color = 0xff000000u | uint32_t((x * 7 + y * 3) % 256) << 16
                | uint32_t((x * 3 + y * 13) % 256) << 8 | uint32_t((x * 11 + y * 5) % 256);
            backdrop[size_t(y) * width + x] = color;
            std::memcpy(actual.data() + 1 + size_t(y) * pitch + x * 4, &color, 4);
        }
        auto input = actual;
        VoxGraphitePixelRegion view {0, 0, width, height, pitch, actual.data() + 1};
        if (!vox_draw_solid_svg_polygons(view, paths, 2, parent, viewport, clip)) {
            assert(actual == input); ++rejected; continue;
        }
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
        auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
            kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
        auto image = SkImages::RasterFromPixmapCopy(SkPixmap(info, backdrop.data(), width * 4));
        assert(image); canvas->drawImage(image, 0, 0);
        SkPaint noop; noop.setAntiAlias(true); noop.setColor(SK_ColorTRANSPARENT);
        SkPath trigger; trigger.moveTo(0, 0); trigger.cubicTo(.01f,.001f,0,.01f,.01f,.01f);
        trigger.lineTo(.005f,.002f); trigger.close(); canvas->drawPath(trigger, noop);
        canvas->clipRect(SkRect::MakeLTRB(clip[0], clip[1], clip[2], clip[3]));
        assert(record_chromium_svg_path_batch(canvas, paths, 2, SkMatrix::I(),
            SkRect::MakeXYWH(viewport[0], viewport[1], viewport[2], viewport[3]), nullptr));
        SkSerialProcs procs; procs.fImageProc = serialize_shared_picture_image;
        auto bytes = recorder.finishRecordingAsPicture()->serialize(&procs); assert(bytes);
        std::vector<uint32_t> expected(size_t(width) * height);
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(expected.data()), width, height,
            width * 4, bytes->data(), bytes->size(), parent));
        for (int y = 0; y < height; ++y) {
            if (std::memcmp(actual.data() + 1 + size_t(y) * pitch,
                    expected.data() + size_t(y) * width, width * 4)) {
                std::fprintf(stderr, "Mismatch geometry=%d palette=%d phase=%g even_odd=%d row=%d\n",
                    geometry, palette, phase, even_odd, y);
                return 1;
            }
            for (int x = width * 4; x < pitch; ++x) assert(actual[1 + size_t(y) * pitch + x] == 0xa9);
        }
        assert(actual[0] == 0xa9); ++accepted; ++accepted_geometry[geometry];
        // Rejected batches must also preserve a backdrop after an earlier
        // eligible path: validation is atomic across the entire batch.
        auto original = paths[1];
        auto rejects = [&](VoxGraphitePath invalid) {
            paths[1] = invalid;
            auto before = actual;
            assert(!vox_draw_solid_svg_polygons(view, paths, 2, parent, viewport, clip));
            assert(actual == before);
            paths[1] = original;
        };
        auto invalid = original; invalid.stroke = 1; rejects(invalid);
        invalid = original; invalid.gradient = 1; rejects(invalid);
        invalid = original; invalid.has_clip = 1; rejects(invalid);
        invalid = original; invalid.has_ancestor_clip = 1; rejects(invalid);
        invalid = original; invalid.alpha = 254; rejects(invalid);
        invalid = original; invalid.opacity = .9f; rejects(invalid);
        invalid = original; invalid.float_color[0] += .0001f; rejects(invalid);
        invalid = original; invalid.matrix[1] = .25f; rejects(invalid);
        invalid = original; invalid.segment_count = 65536; rejects(invalid);
        invalid = original; invalid.segments = nullptr; rejects(invalid);
        auto before = actual;
        viewport[0] = 4.25f;
        assert(!vox_draw_solid_svg_polygons(view, paths, 2, parent, viewport, clip));
        assert(actual == before);
    }
    std::fprintf(stderr, "Compared %u accepted batches, rejected %u ambiguous batches\n", accepted, rejected);
    assert((accepted_geometry[1] || accepted_geometry[2]) && accepted_geometry[3] && rejected);
    std::printf("PASS %u exact Dawn polygon comparisons, %u transactional boundary fallbacks\n", accepted, rejected);
}
