/* WebGL's ESSL source boundary for the native desktop OpenGL driver.
 *
 * CGL, WGL and system EGL desktop contexts compile the corresponding GLSL 4.10
 * spelling while retaining the exact ESSL source for getShaderSource().
 * This is a language compatibility adapter, not an independent GLSL compiler:
 * parsing, type checking and optimization remain the native driver's job.
 */
#ifndef VOX_WEBGL_NATIVE_GL_SHADER_H
#define VOX_WEBGL_NATIVE_GL_SHADER_H

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct VoxGLShaderSource {
    struct VoxGLShaderSource* next;
    unsigned shader;
    int length;
    char* source;
} VoxGLShaderSource;

typedef struct {
    char* bytes;
    size_t length;
    size_t capacity;
} VoxGLSLBuffer;

static int vox_glsl_append(VoxGLSLBuffer* buffer, char const* bytes, size_t length)
{
    if (length > (size_t)INT_MAX - 1 - buffer->length)
        return 0;
    size_t needed = buffer->length + length + 1;
    if (needed > buffer->capacity) {
        size_t capacity = buffer->capacity ? buffer->capacity : 256;
        while (capacity < needed) {
            if (capacity > (size_t)INT_MAX / 2) {
                capacity = needed;
                break;
            }
            capacity *= 2;
        }
        char* allocation = (char*)realloc(buffer->bytes, capacity);
        if (!allocation)
            return 0;
        buffer->bytes = allocation;
        buffer->capacity = capacity;
    }
    if (length)
        memcpy(buffer->bytes + buffer->length, bytes, length);
    buffer->length += length;
    buffer->bytes[buffer->length] = 0;
    return 1;
}

static int vox_glsl_text(VoxGLSLBuffer* buffer, char const* text)
{
    return vox_glsl_append(buffer, text, strlen(text));
}

static int vox_glsl_identifier_start(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

static int vox_glsl_identifier(char c)
{
    return vox_glsl_identifier_start(c) || (c >= '0' && c <= '9');
}

static int vox_glsl_equal(char const* token, size_t length, char const* name)
{
    return strlen(name) == length && memcmp(token, name, length) == 0;
}

static int vox_glsl_space(char c)
{
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

/* Comments become spaces only in this parsing copy. The submitted shader keeps
 * every original comment and newline, including those in preprocessor lines. */
static char* vox_glsl_without_comments(char const* source, size_t length)
{
    char* clean = (char*)malloc(length + 1);
    if (!clean)
        return NULL;
    if (length)
        memcpy(clean, source, length);
    clean[length] = 0;
    for (size_t i = 0; i < length;) {
        if (source[i] == '"' || source[i] == '\'') {
            char quote = source[i++];
            while (i < length) {
                if (source[i] == '\\' && i + 1 < length) {
                    i += 2;
                    continue;
                }
                if (source[i++] == quote)
                    break;
            }
        } else if (source[i] == '/' && i + 1 < length && source[i + 1] == '/') {
            while (i < length && source[i] != '\n')
                clean[i++] = ' ';
        } else if (source[i] == '/' && i + 1 < length && source[i + 1] == '*') {
            clean[i++] = ' ';
            clean[i++] = ' ';
            while (i < length) {
                if (source[i] == '*' && i + 1 < length && source[i + 1] == '/') {
                    clean[i++] = ' ';
                    clean[i++] = ' ';
                    break;
                }
                if (source[i] != '\n' && source[i] != '\r')
                    clean[i] = ' ';
                ++i;
            }
        } else {
            ++i;
        }
    }
    return clean;
}

static size_t vox_glsl_directive_end(char const* source, size_t start, size_t length)
{
    size_t end = start;
    while (end < length) {
        if (source[end] == '\n') {
            size_t previous = end;
            if (previous > start && source[previous - 1] == '\r')
                --previous;
            if (previous == start || source[previous - 1] != '\\')
                break;
        }
        ++end;
    }
    return end;
}

static size_t vox_glsl_skip_space(char const* source, size_t at, size_t end)
{
    while (at < end && vox_glsl_space(source[at]))
        ++at;
    return at;
}

static int vox_glsl_blank(VoxGLSLBuffer* output, char const* source, size_t length)
{
    for (size_t i = 0; i < length; ++i) {
        char c = source[i] == '\n' || source[i] == '\r' ? source[i] : ' ';
        if (!vox_glsl_append(output, &c, 1))
            return 0;
    }
    return 1;
}

static int vox_glsl_known_extension(char const* token, size_t length)
{
    return vox_glsl_equal(token, length, "GL_OES_standard_derivatives")
        || vox_glsl_equal(token, length, "GL_EXT_shader_texture_lod")
        || vox_glsl_equal(token, length, "GL_EXT_frag_depth")
        || vox_glsl_equal(token, length, "GL_EXT_draw_buffers");
}

static char const* vox_glsl_extension_macro(char const* token, size_t length)
{
    if (vox_glsl_equal(token, length, "GL_OES_standard_derivatives")) return "_webgl_native_derivatives";
    if (vox_glsl_equal(token, length, "GL_EXT_shader_texture_lod")) return "_webgl_native_texture_lod";
    if (vox_glsl_equal(token, length, "GL_EXT_frag_depth")) return "_webgl_native_frag_depth";
    if (vox_glsl_equal(token, length, "GL_EXT_draw_buffers")) return "_webgl_native_draw_buffers";
    return NULL;
}

static int vox_glsl_desktop_only(char const* token, size_t length)
{
    static char const* const names[] = {
        "double", "dvec2", "dvec3", "dvec4", "dmat2", "dmat3", "dmat4",
        "dmat2x2", "dmat2x3", "dmat2x4", "dmat3x2", "dmat3x3", "dmat3x4",
        "dmat4x2", "dmat4x3", "dmat4x4", "sampler1D", "sampler1DShadow",
        "sampler1DArray", "sampler1DArrayShadow", "sampler2DRect",
        "sampler2DRectShadow", "samplerBuffer", "sampler2DMS", "sampler2DMSArray",
        "samplerCubeArray", "samplerCubeArrayShadow", "isampler1D",
        "isampler1DArray", "isampler2DRect", "isamplerBuffer", "isampler2DMS",
        "isampler2DMSArray", "usampler1D", "usampler1DArray", "usampler2DRect",
        "usamplerBuffer", "usampler2DMS", "usampler2DMSArray", "subroutine",
        "patch", "texture1D", "texture1DProj", "texture1DLod", "texture1DProjLod",
        "texture2DRect", "texture2DRectProj", "ftransform", "noise1", "noise2",
        "noise3", "noise4", "EmitVertex", "EndPrimitive", "barrier"
    };
    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i)
        if (vox_glsl_equal(token, length, names[i]))
            return 1;
    return 0;
}

static int vox_glsl_known_builtin(char const* token, size_t length, int version)
{
    static char const* const common[] = {
        "gl_Position", "gl_PointSize", "gl_FragCoord", "gl_FrontFacing",
        "gl_PointCoord", "gl_DepthRange", "gl_DepthRangeParameters",
        "gl_MaxVertexAttribs", "gl_MaxVertexUniformVectors", "gl_MaxVaryingVectors",
        "gl_MaxVertexTextureImageUnits", "gl_MaxCombinedTextureImageUnits",
        "gl_MaxTextureImageUnits", "gl_MaxFragmentUniformVectors", "gl_MaxDrawBuffers"
    };
    for (size_t i = 0; i < sizeof(common) / sizeof(common[0]); ++i)
        if (vox_glsl_equal(token, length, common[i]))
            return 1;
    if (version == 100)
        return vox_glsl_equal(token, length, "gl_FragColor")
            || vox_glsl_equal(token, length, "gl_FragData")
            || vox_glsl_equal(token, length, "gl_FragDepthEXT");
    static char const* const es300[] = {
        "gl_VertexID", "gl_InstanceID", "gl_FragDepth", "gl_MaxVertexOutputVectors",
        "gl_MaxFragmentInputVectors", "gl_MinProgramTexelOffset", "gl_MaxProgramTexelOffset"
    };
    for (size_t i = 0; i < sizeof(es300) / sizeof(es300[0]); ++i)
        if (vox_glsl_equal(token, length, es300[i]))
            return 1;
    return 0;
}

/* Returns an allocated, NUL-terminated shader or NULL on allocation failure.
 * Unsupported versions/features become #error so compileShader and its normal
 * info log report the failure; shaderSource itself still preserves the input. */
static char* vox_glsl_desktop_source(char const* source, int input_length,
                                    int fragment, int context_version)
{
    size_t length = (size_t)input_length;
    char* clean = vox_glsl_without_comments(source, length);
    if (!clean)
        return NULL;
    VoxGLSLBuffer body = {0}, output = {0};
    char const* error = NULL;
    int version = 100, have_version = 0, have_content = 0, line_start = 1;
    /* Resolve #version before rewriting any token or deciding the interface. */
    for (size_t i = 0; i < length && !error;) {
        if (clean[i] == '\n') { line_start = 1; ++i; continue; }
        if (vox_glsl_space(clean[i])) { ++i; continue; }
        if (line_start && clean[i] == '#') {
            size_t end = vox_glsl_directive_end(clean, i, length);
            size_t word = vox_glsl_skip_space(clean, i + 1, end), at = word;
            while (at < end && vox_glsl_identifier(clean[at])) ++at;
            if (vox_glsl_equal(clean + word, at - word, "version")) {
                if (have_version || have_content) {
                    error = "#error WebGL: version must be the first shader directive\n";
                    break;
                }
                have_version = 1;
                at = vox_glsl_skip_space(clean, at, end);
                size_t number = at;
                while (at < end && clean[at] >= '0' && clean[at] <= '9') ++at;
                if (vox_glsl_equal(clean + number, at - number, "100")) {
                    version = 100;
                } else if (vox_glsl_equal(clean + number, at - number, "300") && context_version == 3) {
                    version = 300;
                    at = vox_glsl_skip_space(clean, at, end);
                    if (at + 2 > end || memcmp(clean + at, "es", 2) != 0) {
                        error = "#error WebGL: GLSL ES 3.00 requires the es profile\n";
                        break;
                    }
                    at += 2;
                } else {
                    error = "#error WebGL: unsupported ESSL version for this context\n";
                    break;
                }
                if (vox_glsl_skip_space(clean, at, end) != end)
                    error = "#error WebGL: invalid shader version directive\n";
            } else {
                have_content = 1;
            }
            i = end;
        } else {
            have_content = 1;
            line_start = 0;
            ++i;
        }
    }

    int fragment_outputs = 0, invariant = 0, in_directive = 0;
    line_start = 1;
    for (size_t i = 0; i < length && !error;) {
        if (line_start && clean[i] == '#') {
            in_directive = 1;
            size_t end = vox_glsl_directive_end(clean, i, length);
            size_t word = vox_glsl_skip_space(clean, i + 1, end), at = word;
            while (at < end && vox_glsl_identifier(clean[at])) ++at;
            int erase = vox_glsl_equal(clean + word, at - word, "version");
            if (vox_glsl_equal(clean + word, at - word, "extension")) {
                erase = 1;
                at = vox_glsl_skip_space(clean, at, end);
                size_t name = at;
                while (at < end && vox_glsl_identifier(clean[at])) ++at;
                size_t name_length = at - name;
                at = vox_glsl_skip_space(clean, at, end);
                if (at >= end || clean[at++] != ':') {
                    error = "#error WebGL: invalid shader extension directive\n";
                    break;
                }
                at = vox_glsl_skip_space(clean, at, end);
                size_t behavior = at;
                while (at < end && vox_glsl_identifier(clean[at])) ++at;
                int disable = vox_glsl_equal(clean + behavior, at - behavior, "disable");
                int warn = vox_glsl_equal(clean + behavior, at - behavior, "warn");
                int enable = vox_glsl_equal(clean + behavior, at - behavior, "enable");
                int require = vox_glsl_equal(clean + behavior, at - behavior, "require");
                if ((!disable && !warn && !enable && !require)
                    || vox_glsl_skip_space(clean, at, end) != end) {
                    error = "#error WebGL: invalid shader extension behavior\n";
                    break;
                }
                int all = vox_glsl_equal(clean + name, name_length, "all");
                if ((all && (enable || require))
                    || (!all && !disable && !warn && !vox_glsl_known_extension(clean + name, name_length))) {
                    /* Keep the rejection inside its original preprocessor
                     * branch: an unavailable extension in #if 0 is harmless. */
                    if (!vox_glsl_text(&body, "#error WebGL: unsupported native shader extension ")) goto oom;
                }
            }
            if (erase) {
                if (!vox_glsl_blank(&body, source + i, end - i)) goto oom;
                i = end;
                continue;
            }
        }
        if (clean[i] == '\n') {
            line_start = 1;
            size_t previous = i;
            if (previous && clean[previous - 1] == '\r') --previous;
            if (!previous || clean[previous - 1] != '\\') in_directive = 0;
        }
        else if (!vox_glsl_space(clean[i])) line_start = 0;
        /* A comment, quote or numeric literal is copied without identifier
         * substitution. In particular, names inside comments never create IO. */
        if (source[i] != clean[i]) {
            size_t end = i + 1;
            while (end < length && source[end] != clean[end]) ++end;
            if (!vox_glsl_append(&body, source + i, end - i)) goto oom;
            i = end;
            continue;
        }
        if (clean[i] == '"' || clean[i] == '\'') {
            size_t end = i + 1;
            char quote = clean[i];
            while (end < length) {
                if (clean[end] == '\\' && end + 1 < length) { end += 2; continue; }
                if (clean[end++] == quote) break;
            }
            if (!vox_glsl_append(&body, source + i, end - i)) goto oom;
            i = end;
            continue;
        }
        if (vox_glsl_identifier_start(clean[i])) {
            size_t end = i + 1;
            while (end < length && vox_glsl_identifier(clean[end])) ++end;
            char const* token = clean + i;
            size_t n = end - i;
            /* GLSL 4.10 accepts precision qualifiers, but its default
             * precision statement only accepts int/float, whereas ESSL also
             * permits sampler defaults. All these defaults are immaterial to
             * desktop arithmetic. Preserve their line positions and remove
             * the whole declaration, without touching macro definitions. */
            if (!in_directive && vox_glsl_equal(token, n, "precision")) {
                size_t at = vox_glsl_skip_space(clean, end, length);
                int words = 0;
                for (int word = 0; word < 2 && at < length; ++word) {
                    if (!vox_glsl_identifier_start(clean[at])) break;
                    while (at < length && vox_glsl_identifier(clean[at])) ++at;
                    ++words;
                    at = vox_glsl_skip_space(clean, at, length);
                }
                if (words == 2 && at < length && clean[at] == ';') {
                    if (!vox_glsl_blank(&body, source + i, at + 1 - i)) goto oom;
                    i = at + 1;
                    continue;
                }
            }
            char const* replacement = NULL;
            int unavailable = (n >= 6 && memcmp(token, "webgl_", 6) == 0)
                || (n >= 7 && memcmp(token, "_webgl_", 7) == 0)
                || vox_glsl_desktop_only(token, n)
                || (n >= 3 && memcmp(token, "gl_", 3) == 0 && !vox_glsl_known_builtin(token, n, version));
            /* Leave inactive #if branches to the native preprocessor. A GLSL
             * reserved word fails compilation only if this token is active;
             * rejecting the whole source here would break shared ES100/300
             * shaders that guard version-specific builtins with __VERSION__. */
            if (unavailable) replacement = "asm /* unavailable in ESSL */";
            else if (!in_directive && (vox_glsl_equal(token, n, "lowp")
                || vox_glsl_equal(token, n, "mediump") || vox_glsl_equal(token, n, "highp"))) replacement = " ";
            else if (vox_glsl_equal(token, n, "GL_ES")) replacement = "_webgl_native_es";
            else if (vox_glsl_equal(token, n, "GL_FRAGMENT_PRECISION_HIGH")) replacement = "_webgl_native_highp";
            else if (vox_glsl_equal(token, n, "__VERSION__")) replacement = "_webgl_native_version";
            else if (vox_glsl_equal(token, n, "gl_MaxVertexUniformVectors")) replacement = "(gl_MaxVertexUniformComponents / 4)";
            else if (vox_glsl_equal(token, n, "gl_MaxFragmentUniformVectors")) replacement = "(gl_MaxFragmentUniformComponents / 4)";
            else if (vox_glsl_equal(token, n, "gl_MaxVaryingVectors")) replacement = "(gl_MaxVaryingComponents / 4)";
            else if (vox_glsl_equal(token, n, "gl_MaxVertexOutputVectors")) replacement = "(gl_MaxVertexOutputComponents / 4)";
            else if (vox_glsl_equal(token, n, "gl_MaxFragmentInputVectors")) replacement = "(gl_MaxFragmentInputComponents / 4)";
            else if (vox_glsl_equal(token, n, "gl_MaxDrawBuffers") && version == 100 && context_version == 3) replacement = "1";
            else replacement = vox_glsl_extension_macro(token, n);
            if (version == 100 && !unavailable) {
                if (vox_glsl_equal(token, n, "attribute")) replacement = "in";
                else if (vox_glsl_equal(token, n, "varying")) replacement = fragment ? "in" : "out";
                else if (fragment && vox_glsl_equal(token, n, "gl_FragColor")) {
                    fragment_outputs = 1;
                    replacement = invariant ? "_webgl_native_frag_outputs" : "_webgl_native_frag_outputs[0]";
                } else if (fragment && vox_glsl_equal(token, n, "gl_FragData")) {
                    fragment_outputs = 1;
                    replacement = "_webgl_native_frag_outputs";
                } else if (vox_glsl_equal(token, n, "gl_FragDepthEXT")) replacement = "gl_FragDepth";
                else if (vox_glsl_equal(token, n, "texture2D") || vox_glsl_equal(token, n, "textureCube")) replacement = "texture";
                else if (vox_glsl_equal(token, n, "texture2DProj")) replacement = "textureProj";
                else if (vox_glsl_equal(token, n, "texture2DLod") || vox_glsl_equal(token, n, "textureCubeLod")
                    || vox_glsl_equal(token, n, "texture2DLodEXT") || vox_glsl_equal(token, n, "textureCubeLodEXT")) replacement = "textureLod";
                else if (vox_glsl_equal(token, n, "texture2DProjLod") || vox_glsl_equal(token, n, "texture2DProjLodEXT")) replacement = "textureProjLod";
                else if (vox_glsl_equal(token, n, "texture2DGradEXT") || vox_glsl_equal(token, n, "textureCubeGradEXT")) replacement = "textureGrad";
                else if (vox_glsl_equal(token, n, "texture2DProjGradEXT")) replacement = "textureProjGrad";
            }
            if (!in_directive && vox_glsl_equal(token, n, "invariant")) invariant = 1;
            if (!(replacement ? vox_glsl_text(&body, replacement) : vox_glsl_append(&body, source + i, n))) goto oom;
            i = end;
            continue;
        }
        if (clean[i] == ';' || clean[i] == '{' || clean[i] == '}') invariant = 0;
        if (!vox_glsl_append(&body, source + i, 1)) goto oom;
        ++i;
    }

    if (!vox_glsl_text(&output, "#version 410 core\n")) goto oom;
    if (error) {
        if (!vox_glsl_text(&output, error)) goto oom;
    } else {
        if (!vox_glsl_text(&output,
                "#define _webgl_native_es 1\n"
                "#define _webgl_native_highp 1\n"
                "#define _webgl_native_derivatives 1\n"
                "#define _webgl_native_texture_lod 1\n"
                "#define _webgl_native_frag_depth 1\n"
                "#define _webgl_native_draw_buffers 1\n")) goto oom;
        if (!vox_glsl_text(&output, version == 100 ? "#define _webgl_native_version 100\n" : "#define _webgl_native_version 300\n")) goto oom;
        if (fragment_outputs && !vox_glsl_text(&output, context_version == 3
                ? "layout(location = 0) out vec4 _webgl_native_frag_outputs[1];\n"
                : "layout(location = 0) out vec4 _webgl_native_frag_outputs[gl_MaxDrawBuffers];\n")) goto oom;
        if (!vox_glsl_text(&output, "#line 1\n") || !vox_glsl_append(&output, body.bytes, body.length)) goto oom;
    }
    free(clean);
    free(body.bytes);
    return output.bytes;
oom:
    free(clean);
    free(body.bytes);
    free(output.bytes);
    return NULL;
}

static VoxGLShaderSource* vox_native_shader_find_source(VoxGLShaderSource* sources, unsigned shader)
{
    for (; sources; sources = sources->next)
        if (sources->shader == shader)
            return sources;
    return NULL;
}

/* Returns zero only when an allocation fails. All language diagnostics are
 * deliberately left to compileShader, as with the native GLES source API. */
static int vox_native_shader_source(VoxGLShaderSource** sources, unsigned shader,
                                    char const* source, int length, int context_version)
{
#if VOX_NATIVE_GL_DESKTOP
    if (length < 0 || length >= INT_MAX || (!source && length))
        return 0;
    GLint shader_type = 0;
    glGetShaderiv(shader, GL_SHADER_TYPE, &shader_type);
    if (shader_type != GL_VERTEX_SHADER && shader_type != GL_FRAGMENT_SHADER)
        return 1;
    char* original = (char*)malloc((size_t)length + 1);
    if (!original)
        return 0;
    if (length)
        memcpy(original, source, (size_t)length);
    original[length] = 0;
    char* translated = vox_glsl_desktop_source(original, length, shader_type == GL_FRAGMENT_SHADER, context_version);
    if (!translated) {
        free(original);
        return 0;
    }
    VoxGLShaderSource* record = vox_native_shader_find_source(*sources, shader);
    if (!record) {
        record = (VoxGLShaderSource*)calloc(1, sizeof(*record));
        if (!record) {
            free(translated);
            free(original);
            return 0;
        }
        record->shader = shader;
        record->next = *sources;
        *sources = record;
    }
    char const* driver_source = translated;
    GLint driver_length = (GLint)strlen(translated);
    glShaderSource(shader, 1, &driver_source, &driver_length);
    free(translated);
    free(record->source);
    record->source = original;
    record->length = length;
#else
    (void)sources;
    (void)context_version;
    glShaderSource(shader, 1, &source, &length);
#endif
    return 1;
}

static int vox_native_shader_source_length(VoxGLShaderSource* sources, unsigned shader)
{
    VoxGLShaderSource* record = vox_native_shader_find_source(sources, shader);
    return record ? (record->length ? record->length + 1 : 0) : -1;
}

static int vox_native_shader_get_source(VoxGLShaderSource* sources, unsigned shader, int capacity, char* output)
{
    VoxGLShaderSource* record = vox_native_shader_find_source(sources, shader);
    if (!record)
        return 0;
    if (capacity > 0 && output) {
        size_t count = (size_t)(record->length < capacity - 1 ? record->length : capacity - 1);
        memcpy(output, record->source, count);
        output[count] = 0;
    }
    return 1;
}

static void vox_native_shader_delete_source(VoxGLShaderSource** sources, unsigned shader)
{
    for (VoxGLShaderSource** slot = sources; *slot; slot = &(*slot)->next) {
        VoxGLShaderSource* record = *slot;
        if (record->shader == shader) {
            *slot = record->next;
            free(record->source);
            free(record);
            return;
        }
    }
}

static void vox_native_shader_free_sources(VoxGLShaderSource** sources)
{
    while (*sources) {
        VoxGLShaderSource* record = *sources;
        *sources = record->next;
        free(record->source);
        free(record);
    }
}

#endif
