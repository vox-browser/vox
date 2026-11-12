#ifndef VOX_WEBGL_NATIVE_METAL_BOUNDARY_H
#define VOX_WEBGL_NATIVE_METAL_BOUNDARY_H
#include <stdint.h>
#include "metal/shader_translation.h"
#include <mach-o/dyld.h>
#include <string.h>
#include "../platform/native_state.h"
VOX_NATIVE_STATE __thread void* vox_metal_service_current;
static void* vox_metal_service_get(void) { return vox_metal_service_current; }
static void vox_metal_service_set(void* value) { vox_metal_service_current = value; }
static int vox_metal_service_no_angle(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        char const* image = _dyld_get_image_name(i);
        if (strstr(image, "libEGL") || strstr(image, "libGLES") || strstr(image, "libANGLE")) return 0;
    }
    return 1;
}
static int vox_metal_service_validate_stage(char const* source, int length, int fragment, int version, char* log, uint64_t capacity)
{
    if (capacity) log[0] = 0;
    if (!source || length < 0 || memchr(source, 0, (size_t)length)) return 0;
    vox_essl_prepare();
    if (!vox_essl_initialized) return 0;
    glslang_resource_t resources = *glslang_default_resource();
    resources.max_draw_buffers = 8; resources.max_vertex_attribs = 16;
    resources.max_vertex_uniform_components = resources.max_fragment_uniform_components = 4096;
    resources.max_vertex_uniform_vectors = resources.max_fragment_uniform_vectors = 1024;
    char* code = vox_glsl_desktop_source_with_resources(source,length,fragment,version,&resources);
    if (!code) return 0;
    glslang_input_t input = {0};
    input.language = GLSLANG_SOURCE_GLSL; input.stage = fragment ? GLSLANG_STAGE_FRAGMENT : GLSLANG_STAGE_VERTEX;
    input.client = GLSLANG_CLIENT_NONE; input.target_language = GLSLANG_TARGET_NONE;
    input.code = code; input.default_version = 410; input.default_profile = GLSLANG_CORE_PROFILE; input.resource = &resources;
    glslang_shader_t* shader = glslang_shader_create(&input);
    int success = shader && glslang_shader_preprocess(shader,&input) && glslang_shader_parse(shader,&input);
    if (!success && shader && capacity) snprintf(log,capacity,"%s",glslang_shader_get_info_log(shader));
    if (shader) glslang_shader_delete(shader);
    free(code); return success;
}
#endif
