/* Validate ESSL before desktop GLSL spelling changes erase its restrictions. */
#ifndef VOX_WEBGL_NATIVE_GL_SHADER_VALIDATION_H
#define VOX_WEBGL_NATIVE_GL_SHADER_VALIDATION_H

#include <stdlib.h>
#include <string.h>
#include <glslang/Include/glslang_c_interface.h>
#include <glslang/Public/resource_limits_c.h>
#include "../platform/native_state.h"

#ifdef __APPLE__
#include <dlfcn.h>
/* Keep the ESSL compiler out of ordinary page startup. The bundle dependency
 * scanner recognizes these @rpath names and carries their dylib closure. */
#define VOX_ESSL_FUNCTIONS(X) \
    X(glslang_initialize_process) \
    X(glslang_shader_create) \
    X(glslang_shader_preprocess) \
    X(glslang_shader_parse) \
    X(glslang_shader_get_preprocessed_code) \
    X(glslang_shader_get_info_log) \
    X(glslang_shader_delete) \
    X(glslang_default_resource)
typedef struct {
#define VOX_ESSL_FIELD(name) __typeof__(&name) name;
    VOX_ESSL_FUNCTIONS(VOX_ESSL_FIELD)
#undef VOX_ESSL_FIELD
    void* library;
    void* resources;
} VoxESSLAPI;
VOX_NATIVE_STATE VoxESSLAPI vox_essl_api;
static int vox_essl_load(void)
{
    vox_essl_api.library = dlopen("@rpath/libglslang.dylib", RTLD_NOW | RTLD_LOCAL);
    vox_essl_api.resources = dlopen("@rpath/libglslang-default-resource-limits.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!vox_essl_api.library || !vox_essl_api.resources) return 0;
#define VOX_ESSL_RESOLVE(name) do { \
    *(void**)(&vox_essl_api.name) = dlsym(vox_essl_api.library, #name); \
    if (!vox_essl_api.name) *(void**)(&vox_essl_api.name) = dlsym(vox_essl_api.resources, #name); \
    if (!vox_essl_api.name) return 0; \
} while (0);
    VOX_ESSL_FUNCTIONS(VOX_ESSL_RESOLVE)
#undef VOX_ESSL_RESOLVE
    return 1;
}
#undef VOX_ESSL_FUNCTIONS
#define glslang_initialize_process vox_essl_api.glslang_initialize_process
#define glslang_shader_create vox_essl_api.glslang_shader_create
#define glslang_shader_preprocess vox_essl_api.glslang_shader_preprocess
#define glslang_shader_parse vox_essl_api.glslang_shader_parse
#define glslang_shader_get_preprocessed_code vox_essl_api.glslang_shader_get_preprocessed_code
#define glslang_shader_get_info_log vox_essl_api.glslang_shader_get_info_log
#define glslang_shader_delete vox_essl_api.glslang_shader_delete
#define glslang_default_resource vox_essl_api.glslang_default_resource
#endif

VOX_NATIVE_STATE int vox_essl_initialized;
#ifdef _WIN32
#include <windows.h>
VOX_NATIVE_STATE INIT_ONCE vox_essl_once VOX_NATIVE_STATE_INIT(INIT_ONCE_STATIC_INIT);
static BOOL CALLBACK vox_essl_initialize(PINIT_ONCE once, PVOID parameter, PVOID* context)
{
    (void)once; (void)parameter; (void)context;
    vox_essl_initialized = glslang_initialize_process();
    return TRUE;
}
static void vox_essl_prepare(void)
{
    InitOnceExecuteOnce(&vox_essl_once, vox_essl_initialize, NULL, NULL);
}
#else
#include <pthread.h>
VOX_NATIVE_STATE pthread_once_t vox_essl_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
static void vox_essl_initialize(void)
{
#ifdef __APPLE__
    if (!vox_essl_load()) return;
#endif
    vox_essl_initialized = glslang_initialize_process();
}
static void vox_essl_prepare(void)
{
    pthread_once(&vox_essl_once, vox_essl_initialize);
}
#endif

static int vox_essl_validate_preprocessed(char const* source, int length, int fragment, int version,
                             glslang_resource_t const* driver_resources,
                             char* log, size_t log_capacity, char** preprocessed)
{
    if (preprocessed) *preprocessed = NULL;
    if (log && log_capacity) log[0] = 0;
    if (length < 0 || !source || memchr(source, 0, (size_t)length)) return 0;
    vox_essl_prepare();
    if (!vox_essl_initialized) return 0;
    char* terminated = (char*)malloc((size_t)length + 1);
    if (!terminated) return 0;
    memcpy(terminated, source, (size_t)length);
    terminated[length] = 0;
    glslang_resource_t resources = driver_resources ? *driver_resources : *glslang_default_resource();
    if (version == 100) {
        /* WebGL1 requires the statically bounded Appendix A loop/index subset. */
        resources.limits.non_inductive_for_loops = false;
        resources.limits.while_loops = false;
        resources.limits.do_while_loops = false;
        resources.limits.general_attribute_matrix_vector_indexing = false;
        resources.limits.general_varying_indexing = false;
        resources.limits.general_sampler_indexing = false;
        resources.limits.general_constant_matrix_vector_indexing = false;
        resources.limits.general_variable_indexing = false;
        resources.limits.general_uniform_indexing = !fragment;
    }
    glslang_input_t input = {0};
    input.language = GLSLANG_SOURCE_GLSL;
    input.stage = fragment ? GLSLANG_STAGE_FRAGMENT : GLSLANG_STAGE_VERTEX;
    input.client = GLSLANG_CLIENT_NONE;
    input.target_language = GLSLANG_TARGET_NONE;
    input.code = terminated;
    input.default_version = 100;
    input.default_profile = GLSLANG_ES_PROFILE;
    input.messages = GLSLANG_MSG_DEFAULT_BIT;
    input.resource = &resources;
    glslang_shader_t* shader = glslang_shader_create(&input);
    int success = shader && glslang_shader_preprocess(shader, &input)
        && glslang_shader_parse(shader, &input);
    if (success && preprocessed) {
        char const* code = glslang_shader_get_preprocessed_code(shader);
        size_t count = strlen(code);
        *preprocessed = (char*)malloc(count + 1);
        if (*preprocessed) memcpy(*preprocessed, code, count + 1);
        else success = 0;
    }
    if (!success && shader && log && log_capacity) {
        char const* message = glslang_shader_get_info_log(shader);
        size_t count = message ? strlen(message) : 0;
        if (count >= log_capacity) count = log_capacity - 1;
        if (count) memcpy(log, message, count);
        log[count] = 0;
    }
    if (shader) glslang_shader_delete(shader);
    free(terminated);
    return success;
}

static int vox_essl_validate(char const* source, int length, int fragment, int version,
                             glslang_resource_t const* resources, char* log, size_t log_capacity)
{
    return vox_essl_validate_preprocessed(source, length, fragment, version, resources,
        log, log_capacity, NULL);
}
#endif
