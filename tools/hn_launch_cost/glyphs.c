// Diagnostic only: count browser-process instructions inside Skia glyph calls.
// Sampling/proc_pid_rusage overhead and concurrent threads affect these deltas.
#include <CoreGraphics/CoreGraphics.h>
#include <libproc.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define GLYPH_ARGUMENTS CGContextRef destination, \
    char const* font_path, int face_index, uint16_t const* glyphs, double const* positions, int count, \
    float size, int weight, int emoji, float x, float y, \
    float a, float b, float c, float d, float e, float f, float page_x, \
    float page_y, float scroll_y, float width, float height, \
    uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha, int smoothing

// The adblock worker inherits the injected library but does not load Skia.
extern int ladybird_v_skia_draw_glyph_run(GLYPH_ARGUMENTS) __attribute__((weak_import));
static uint64_t calls, glyph_count, instructions;
static uint64_t svg_calls, svg_instructions;
static int counter_failed;

static uint64_t current_instructions(void) {
    struct rusage_info_v4 usage = {0};
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&usage))
        counter_failed = 1;
    return usage.ri_instructions;
}

static int counted_glyphs(GLYPH_ARGUMENTS) {
    uint64_t before = current_instructions();
    int result = ladybird_v_skia_draw_glyph_run(destination, font_path, face_index,
        glyphs, positions, count, size, weight, emoji, x, y, a, b, c, d, e, f,
        page_x, page_y, scroll_y, width, height, red, green, blue, alpha, smoothing);
    uint64_t after = current_instructions();
    if (after < before) counter_failed = 1;
    else instructions += after - before;
    ++calls;
    if (count > 0) glyph_count += (uint64_t)count;
    return result;
}

#define SVG_ARGUMENTS CGContextRef destination, const float *data, int count, int even_odd, \
    float a, float b, float c, float d, float e, float f, float page_x, float page_y, \
    float scroll_y, float width, float height, uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha, \
    int fill, uint8_t sr, uint8_t sg, uint8_t sb, uint8_t sa, int stroke, float stroke_width, \
    int cap, int join, float miter, int non_scaling, const double *dash, int dash_count, \
    double dash_offset, int backdrop, const float *fill_components, const float *stroke_components
extern int ladybird_v_skia_draw_svg_path_with_colors(SVG_ARGUMENTS) __attribute__((weak_import));
static int counted_svg(SVG_ARGUMENTS) {
    uint64_t before = current_instructions();
    int result = ladybird_v_skia_draw_svg_path_with_colors(destination, data, count, even_odd,
        a, b, c, d, e, f, page_x, page_y, scroll_y, width, height, red, green, blue, alpha,
        fill, sr, sg, sb, sa, stroke, stroke_width, cap, join, miter, non_scaling,
        dash, dash_count, dash_offset, backdrop, fill_components, stroke_components);
    uint64_t after = current_instructions();
    if (after < before) counter_failed = 1;
    else svg_instructions += after - before;
    ++svg_calls;
    return result;
}

static void report(void) {
    fprintf(stderr, "VOXPROBE_GLYPHS calls=%llu glyphs=%llu instructions=%llu counter_failed=%d\n",
        (unsigned long long)calls, (unsigned long long)glyph_count,
        (unsigned long long)instructions, counter_failed);
    fprintf(stderr, "VOXPROBE_SVG calls=%llu instructions=%llu counter_failed=%d\n",
        (unsigned long long)svg_calls, (unsigned long long)svg_instructions, counter_failed);
}

__attribute__((constructor)) static void initialize(void) { atexit(report); }
__attribute__((used)) static struct { const void *replacement, *replacee; }
interposers[] __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)counted_glyphs, (const void *)ladybird_v_skia_draw_glyph_run},
    {(const void *)counted_svg, (const void *)ladybird_v_skia_draw_svg_path_with_colors},
};
