/* WebGL's ESSL source boundary for the native desktop OpenGL driver.
 *
 * CGL, WGL and system EGL desktop contexts compile the corresponding GLSL 4.10
 * spelling while retaining the exact ESSL source for getShaderSource().
 * glslang validates the original ESSL before this spelling adapter runs. The
 * native driver compiles and optimizes the translated desktop shader.
 */
#ifndef VOX_WEBGL_NATIVE_GL_SHADER_H
#define VOX_WEBGL_NATIVE_GL_SHADER_H

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "native_gl_shader_validation.h"

typedef struct VoxGLShaderSource {
    struct VoxGLShaderSource* next;
    unsigned shader;
    int length;
    char* source;
} VoxGLShaderSource;

#include "essl_desktop_translation.h"

static glslang_resource_t vox_glsl_driver_resources(void)
{
    vox_essl_prepare();
    if (!vox_essl_initialized) {
        glslang_resource_t unavailable = {0};
        return unavailable;
    }
    glslang_resource_t resources = *glslang_default_resource();
    GLint value = 0;
#define VOX_ESSL_LIMIT(field, name) do { glGetIntegerv(name, &value); resources.field = value; } while (0)
    VOX_ESSL_LIMIT(max_vertex_attribs, GL_MAX_VERTEX_ATTRIBS);
    VOX_ESSL_LIMIT(max_vertex_uniform_components, GL_MAX_VERTEX_UNIFORM_COMPONENTS);
    VOX_ESSL_LIMIT(max_fragment_uniform_components, GL_MAX_FRAGMENT_UNIFORM_COMPONENTS);
    VOX_ESSL_LIMIT(max_vertex_output_components, GL_MAX_VERTEX_OUTPUT_COMPONENTS);
    VOX_ESSL_LIMIT(max_fragment_input_components, GL_MAX_FRAGMENT_INPUT_COMPONENTS);
    VOX_ESSL_LIMIT(max_vertex_texture_image_units, GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS);
    VOX_ESSL_LIMIT(max_combined_texture_image_units, GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS);
    VOX_ESSL_LIMIT(max_texture_image_units, GL_MAX_TEXTURE_IMAGE_UNITS);
    VOX_ESSL_LIMIT(max_draw_buffers, GL_MAX_DRAW_BUFFERS);
    VOX_ESSL_LIMIT(min_program_texel_offset, GL_MIN_PROGRAM_TEXEL_OFFSET);
    VOX_ESSL_LIMIT(max_program_texel_offset, GL_MAX_PROGRAM_TEXEL_OFFSET);
#undef VOX_ESSL_LIMIT
    /* MAX_VARYING_COMPONENTS is a legacy query rejected by Apple's core
     * context. Its vertex-output/fragment-input replacement limits are core. */
    resources.max_varying_components = resources.max_vertex_output_components < resources.max_fragment_input_components
        ? resources.max_vertex_output_components : resources.max_fragment_input_components;
    resources.max_vertex_uniform_vectors = resources.max_vertex_uniform_components / 4;
    resources.max_fragment_uniform_vectors = resources.max_fragment_uniform_components / 4;
    resources.max_varying_vectors = resources.max_varying_components / 4;
    resources.max_varying_floats = resources.max_varying_components;
    resources.max_vertex_output_vectors = resources.max_vertex_output_components / 4;
    resources.max_fragment_input_vectors = resources.max_fragment_input_components / 4;
    return resources;
}

static char* vox_glsl_desktop_source(char const* source, int length, int fragment, int version)
{
    glslang_resource_t resources = vox_glsl_driver_resources();
    return vox_glsl_desktop_source_with_resources(source, length, fragment, version, &resources);
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
