// FreeType engine services for the portable glyph strike. Strike matrices,
// gamma, placement and compositing remain in V.
#pragma once
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_OUTLINE_H
#include FT_MULTIPLE_MASTERS_H
#include FT_COLOR_H
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    FT_Library library;
    FT_Face face;
    char* path;
    int index;
    FT_Matrix matrix;
    float scalar[4];
    float size_x, size_y;
} CPURasterFTFont;

static void cpuraster_ft_release(void* reference) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    if (!f) return;
    if (f->face) FT_Done_Face(f->face);
    if (f->library) FT_Done_FreeType(f->library);
    free(f->path);
    free(f);
}

static void* cpuraster_ft_open(const char* path, int index, int* flags) {
    CPURasterFTFont* f = (CPURasterFTFont*)calloc(1, sizeof(*f));
    if (!f) return NULL;
    f->path = strdup(path);
    f->index = index;
    if (!f->path || FT_Init_FreeType(&f->library)
        || FT_New_Face(f->library, path, index, &f->face)) {
        cpuraster_ft_release(f);
        return NULL;
    }
    *flags = (FT_HAS_COLOR(f->face) ? 1 : 0) | (FT_HAS_MULTIPLE_MASTERS(f->face) ? 2 : 0)
        | (FT_IS_SCALABLE(f->face) ? 4 : 0) | (FT_HAS_FIXED_SIZES(f->face) ? 8 : 0);
    if (FT_HAS_MULTIPLE_MASTERS(f->face)) {
        FT_MM_Var* axes = NULL;
        if (FT_Get_MM_Var(f->face, &axes) == 0) {
            FT_Fixed* coordinates = (FT_Fixed*)malloc(axes->num_axis*sizeof(FT_Fixed));
            if (coordinates) {
                for (FT_UInt i = 0; i < axes->num_axis; ++i)
                    coordinates[i] = (FT_Fixed)((float)axes->axis[i].def / 65536.0f * 65536.0f);
                FT_Set_Var_Design_Coordinates(f->face, axes->num_axis, coordinates);
                free(coordinates);
            }
            FT_Done_MM_Var(f->library, axes);
        }
    }
    f->matrix.xx = f->matrix.yy = 65536;
    return f;
}

static void* cpuraster_ft_strike(void* reference, const float* values) {
    CPURasterFTFont* base = (CPURasterFTFont*)reference;
    int flags = 0;
    CPURasterFTFont* f = (CPURasterFTFont*)cpuraster_ft_open(base->path, base->index, &flags);
    if (!f) return NULL;
    f->size_x = values[0]; f->size_y = values[1];
    float sx = values[2], ky = values[3], kx = values[4], sy = values[5];
    if (flags & 4) {
        if (FT_Set_Char_Size(f->face, (FT_F26Dot6)(values[0]*64.0f),
                (FT_F26Dot6)(values[1]*64.0f), 72, 72)) {
            cpuraster_ft_release(f); return NULL;
        }
    } else {
        FT_Pos wanted = (FT_F26Dot6)(values[1]*64.0f), chosen = 0;
        int strike = -1;
        for (int i = 0; i < f->face->num_fixed_sizes; ++i) {
            FT_Pos ppem = f->face->available_sizes[i].y_ppem;
            if (ppem == wanted) { strike = i; break; }
            if ((chosen < wanted && chosen < ppem) || (wanted < ppem && ppem < chosen)) {
                chosen = ppem; strike = i;
            }
        }
        if (strike < 0 || FT_Select_Size(f->face, strike)) { cpuraster_ft_release(f); return NULL; }
        float x = values[0]/(float)f->face->size->metrics.x_ppem;
        float y = values[1]/(float)f->face->size->metrics.y_ppem;
        sx *= x; ky *= x; kx *= y; sy *= y;
    }
    if ((flags & 4) && (values[0] < 1 || values[1] < 1)) {
        float upem = (float)f->face->units_per_EM;
        float ppem_x = upem * ((float)f->face->size->metrics.x_scale / 65536.0f) / 64.0f;
        float ppem_y = upem * ((float)f->face->size->metrics.y_scale / 65536.0f) / 64.0f;
        float x = values[0]/ppem_x, y = values[1]/ppem_y;
        sx *= x; ky *= x; kx *= y; sy *= y;
    }
    f->matrix.xx = (FT_Fixed)(sx*65536.0f);
    f->matrix.xy = (FT_Fixed)(-kx*65536.0f);
    f->matrix.yx = (FT_Fixed)(-ky*65536.0f);
    f->matrix.yy = (FT_Fixed)(sy*65536.0f);
    f->scalar[0] = sx; f->scalar[1] = ky; f->scalar[2] = kx; f->scalar[3] = sy;
    return f;
}

static int cpuraster_ft_load_any(CPURasterFTFont* f, uint16_t id, int smoothing, int outline) {
    FT_Set_Transform(f->face, &f->matrix, NULL);
    FT_Int32 flags = FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH;
    // SkFont disables embedded strikes by default. Bitmap-only faces ignore
    // this flag; a scalable face must use its outlines even at a strike size.
    if (outline || FT_IS_SCALABLE(f->face)) flags |= FT_LOAD_NO_BITMAP;
    if (!FT_IS_SCALABLE(f->face)) flags |= FT_LOAD_COLOR;
    // Rotated/skewed text disables hinting. Canvas text explicitly has none.
    if (smoothing == 2 || f->matrix.xy || f->matrix.yx) flags |= FT_LOAD_NO_HINTING;
    if (smoothing == 1) flags |= FT_LOAD_TARGET_MONO;
    return FT_Load_Glyph(f->face, id, flags) == 0;
}

static int cpuraster_ft_colr(CPURasterFTFont* f, uint16_t id) {
    FT_OpaquePaint paint = {0};
    if (FT_Get_Color_Glyph_Paint(f->face,id,FT_COLOR_INCLUDE_ROOT_TRANSFORM,&paint)) return 2;
    FT_LayerIterator iter = {0}; FT_UInt glyph, color;
    return FT_Get_Color_Glyph_Layer(f->face,id,&glyph,&color,&iter) ? 1 : 0;
}

// 0 empty, 1 outline, 2 gray/mono bitmap, 3 color bitmap, 4 COLRv0.
static int cpuraster_ft_glyph_type(void* reference, uint16_t id, int smoothing) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    int colr = cpuraster_ft_colr(f,id);
    if (colr) return colr == 1 ? 4 : -1;
    if (!cpuraster_ft_load_any(f,id,smoothing,0)) return 0;
    if (f->face->glyph->format == FT_GLYPH_FORMAT_OUTLINE) return 1;
    if (f->face->glyph->format == FT_GLYPH_FORMAT_BITMAP) {
        int mode = f->face->glyph->bitmap.pixel_mode;
        if (mode == FT_PIXEL_MODE_BGRA) return 3;
        if (mode == FT_PIXEL_MODE_GRAY || mode == FT_PIXEL_MODE_MONO) return 2;
    }
    return -1;
}

static int cpuraster_ft_load(CPURasterFTFont* f, uint16_t id, int smoothing) {
    return cpuraster_ft_load_any(f,id,smoothing,0)
        && f->face->glyph->format == FT_GLYPH_FORMAT_OUTLINE;
}

static void cpuraster_ft_matrix(void* reference, float* out) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    memcpy(out,f->scalar,4*sizeof(float));
}

static int cpuraster_ft_bitmap(void* reference, uint16_t id, int smoothing, int32_t* info, uint8_t* pixels) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    if (!cpuraster_ft_load_any(f,id,smoothing,0) || f->face->glyph->format != FT_GLYPH_FORMAT_BITMAP) return 0;
    FT_GlyphSlot glyph = f->face->glyph;
    FT_Bitmap* b = &glyph->bitmap;
    info[0] = glyph->bitmap_left; info[1] = -glyph->bitmap_top;
    info[2] = b->width; info[3] = b->rows;
    info[4] = b->pixel_mode == FT_PIXEL_MODE_BGRA;
    info[5] = FT_IS_SCALABLE(f->face);
    if (!pixels) return 1;
    for (unsigned y = 0; y < b->rows; ++y) {
        const uint8_t* row = b->buffer + (ptrdiff_t)y*b->pitch;
        for (unsigned x = 0; x < b->width; ++x) {
            uint8_t* p = pixels + ((size_t)y*b->width + x)*4;
            if (b->pixel_mode == FT_PIXEL_MODE_BGRA) {
                p[0] = row[x*4+2]; p[1] = row[x*4+1]; p[2] = row[x*4]; p[3] = row[x*4+3];
            } else {
                uint8_t a = b->pixel_mode == FT_PIXEL_MODE_MONO ? ((row[x/8] & (128 >> (x%8))) ? 255 : 0) : row[x];
                p[0] = p[1] = p[2] = p[3] = a;
            }
        }
    }
    return 1;
}

static int cpuraster_ft_bounds(void* reference, uint16_t id, int sub_x, int sub_y,
        int smoothing, int32_t* out) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    if (!cpuraster_ft_load(f, id, smoothing)) return 0;
    if (!f->face->glyph->outline.n_contours) return 0;
    FT_BBox box;
    FT_Outline_Get_CBox(&f->face->glyph->outline, &box);
    out[0] = (int32_t)((box.xMin + sub_x*16) >> 6);
    out[1] = (int32_t)((-box.yMax + sub_y*16) >> 6);
    out[2] = (int32_t)((box.xMax + sub_x*16 + 63) >> 6);
    out[3] = (int32_t)((-box.yMin + sub_y*16 + 63) >> 6);
    return 1;
}

static int cpuraster_ft_image(void* reference, uint16_t id, int sub_x, int sub_y,
        int smoothing, uint8_t* pixels, int width, int height, int pitch) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    if (!cpuraster_ft_load(f, id, smoothing)) return 0;
    FT_Outline* outline = &f->face->glyph->outline;
    FT_BBox box;
    FT_Outline_Get_CBox(outline, &box);
    int dx = sub_x*16, dy = -sub_y*16;
    FT_Outline_Translate(outline, dx - ((box.xMin + dx) & ~63L),
        dy - ((box.yMin + dy) & ~63L));
    FT_Bitmap bitmap = {0};
    bitmap.width = width; bitmap.rows = height; bitmap.pitch = pitch;
    bitmap.buffer = pixels; bitmap.num_grays = 256;
    bitmap.pixel_mode = smoothing == 1 ? FT_PIXEL_MODE_MONO : FT_PIXEL_MODE_GRAY;
    return FT_Outline_Get_Bitmap(f->library, outline, &bitmap) == 0;
}

static int cpuraster_ft_font_bounds(void* reference, float* out) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    if (!FT_IS_SCALABLE(f->face) || FT_HAS_MULTIPLE_MASTERS(f->face)) return 0;
#ifdef FT_CONFIG_OPTION_SVG
    if (f->face->face_flags & FT_FACE_FLAG_SVG) return 0;
#endif
    float em = (float)f->face->units_per_EM;
    out[0] = (float)f->face->bbox.xMin / em;
    out[1] = -(float)f->face->bbox.yMax / em;
    out[2] = (float)f->face->bbox.xMax / em;
    out[3] = -(float)f->face->bbox.yMin / em;
    return 1;
}

typedef struct { double* values; int count, capacity, failed; } CPURasterFTPath;
static int cpuraster_ft_emit(CPURasterFTPath* p, int verb, const FT_Vector* a,
        const FT_Vector* b, const FT_Vector* c) {
    if (p->count == p->capacity) {
        int capacity = p->capacity ? p->capacity*2 : 64;
        double* values = (double*)realloc(p->values, (size_t)capacity*7*sizeof(double));
        if (!values) { p->failed = 1; return 1; }
        p->values = values; p->capacity = capacity;
    }
    double* v = p->values + (size_t)p->count++*7;
    memset(v, 0, 7*sizeof(double)); v[0] = verb;
    const FT_Vector* points[3] = {a,b,c};
    for (int i = 0; i < 3; ++i) if (points[i]) {
        // glyph_outline's fourfold CoreText geometry convention; FT outlines
        // are already at the requested strike size in 26.6 coordinates.
        v[1+i*2] = (double)points[i]->x / 16.0;
        v[2+i*2] = (double)points[i]->y / 16.0;
    }
    return 0;
}
static int cpuraster_ft_move(const FT_Vector* a, void* data) {
    CPURasterFTPath* p = (CPURasterFTPath*)data;
    if (p->count && cpuraster_ft_emit(p,4,NULL,NULL,NULL)) return 1;
    return cpuraster_ft_emit(p,0,a,NULL,NULL);
}
static int cpuraster_ft_line(const FT_Vector* a, void* data) { return cpuraster_ft_emit(data,1,a,NULL,NULL); }
static int cpuraster_ft_conic(const FT_Vector* a, const FT_Vector* b, void* data) { return cpuraster_ft_emit(data,2,a,b,NULL); }
static int cpuraster_ft_cubic(const FT_Vector* a, const FT_Vector* b, const FT_Vector* c, void* data) { return cpuraster_ft_emit(data,3,a,b,c); }
static int cpuraster_ft_path(void* reference, uint16_t id, double** output) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    *output = NULL;
    if (cpuraster_ft_colr(f,id) || !cpuraster_ft_load_any(f,id,2,1)
        || f->face->glyph->format != FT_GLYPH_FORMAT_OUTLINE) return -1;
    CPURasterFTPath p = {0};
    FT_Outline_Funcs funcs = {cpuraster_ft_move,cpuraster_ft_line,cpuraster_ft_conic,cpuraster_ft_cubic,0,0};
    if (FT_Outline_Decompose(&f->face->glyph->outline,&funcs,&p)
        || p.failed || (p.count && cpuraster_ft_emit(&p,4,NULL,NULL,NULL))) {
        free(p.values); return -1;
    }
    *output = p.values;
    return p.count;
}

// Native services only: palette lookup and outline extraction. Layer order,
// subpixel placement, coverage and RGBA composition belong to the V renderer.
static int cpuraster_ft_color_layers(void* reference, uint16_t id,
        uint16_t* glyphs, uint32_t* colors, uint32_t foreground) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    FT_Palette_Data data = {0}; FT_Color* palette = NULL;
    if (FT_Palette_Data_Get(f->face,&data) || FT_Palette_Select(f->face,0,&palette)) return 0;
    FT_LayerIterator iter = {0}; FT_UInt glyph, color; int count = 0;
    while (FT_Get_Color_Glyph_Layer(f->face,id,&glyph,&color,&iter)) {
        if (glyphs) glyphs[count] = glyph;
        if (colors) {
            FT_Color c = color < data.num_palette_entries ? palette[color] : (FT_Color){0,0,0,0};
            colors[count] = color == 0xffff ? foreground
                : ((uint32_t)c.alpha<<24)|((uint32_t)c.red<<16)|((uint32_t)c.green<<8)|c.blue;
        }
        ++count;
    }
    return count;
}

static int cpuraster_ft_layer_path(void* reference, uint16_t id, int smoothing, double** output) {
    CPURasterFTFont* f = (CPURasterFTFont*)reference;
    *output = NULL;
    if (!cpuraster_ft_load_any(f,id,smoothing,1)
        || f->face->glyph->format != FT_GLYPH_FORMAT_OUTLINE) return -1;
    CPURasterFTPath p = {0};
    FT_Outline_Funcs funcs = {cpuraster_ft_move,cpuraster_ft_line,cpuraster_ft_conic,cpuraster_ft_cubic,0,0};
    if (FT_Outline_Decompose(&f->face->glyph->outline,&funcs,&p)
        || p.failed || (p.count && cpuraster_ft_emit(&p,4,NULL,NULL,NULL))) {
        free(p.values); return -1;
    }
    *output = p.values;
    return p.count;
}
