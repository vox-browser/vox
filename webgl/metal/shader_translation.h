/* ESSL -> validated GLSL/SPIR-V -> MSL. No ANGLE or OpenGL driver calls. */
#ifndef VOX_METAL_SHADER_TRANSLATION_H
#define VOX_METAL_SHADER_TRANSLATION_H
#include "../essl_desktop_translation.h"
#include <spirv_cross_c.h>
#include <stdio.h>

typedef struct {
    char* name;
    uint32_t kind, stage, location, binding, secondary_binding;
    uint32_t offset, array_stride, matrix_stride, base_type, rows, columns, array_length;
    uint64_t byte_size;
} VoxMetalShaderResource;

typedef struct {
    char* msl[2];
    char* entry[2];
    VoxMetalShaderResource* resources;
    size_t resource_count;
} VoxMetalTranslatedProgram;

static char* vox_metal_string_copy(char const* value)
{
    if (!value) return NULL;
    size_t size = strlen(value) + 1;
    char* copy = malloc(size);
    if (copy) memcpy(copy, value, size);
    return copy;
}

static void vox_metal_translation_destroy(VoxMetalTranslatedProgram* program)
{
    if (!program) return;
    for (int i = 0; i < 2; ++i) { free(program->msl[i]); free(program->entry[i]); }
    for (size_t i = 0; i < program->resource_count; ++i) free(program->resources[i].name);
    free(program->resources);
    free(program);
}

static int vox_metal_reflect_type(spvc_type type, VoxMetalShaderResource* output)
{
    output->base_type = spvc_type_get_basetype(type);
    output->rows = spvc_type_get_vector_size(type);
    output->columns = spvc_type_get_columns(type);
    output->array_length = 1;
    unsigned dimensions = spvc_type_get_num_array_dimensions(type);
    for (unsigned i = 0; i < dimensions; ++i) {
        if (!spvc_type_array_dimension_is_literal(type, i)) return 0;
        unsigned length = spvc_type_get_array_dimension(type, i);
        if (!length || output->array_length > UINT32_MAX / length) return 0;
        output->array_length *= length;
    }
    return 1;
}

static int vox_metal_append_resource(VoxMetalTranslatedProgram* program,
                                     VoxMetalShaderResource resource, char const* name)
{
    if (program->resource_count >= SIZE_MAX / sizeof(resource) - 1) return 0;
    char* copy = vox_metal_string_copy(name);
    if (!copy) return 0;
    void* grown = realloc(program->resources, (program->resource_count + 1) * sizeof(resource));
    if (!grown) { free(copy); return 0; }
    program->resources = grown;
    resource.name = copy;
    program->resources[program->resource_count++] = resource;
    return 1;
}

static int vox_metal_reflect_resources(VoxMetalTranslatedProgram* program, spvc_compiler compiler,
                                      spvc_compiler original_names, int stage)
{
    spvc_resources resources;
    if (spvc_compiler_create_shader_resources(compiler, &resources) != SPVC_SUCCESS) return 0;
    spvc_resource_type kinds[] = {SPVC_RESOURCE_TYPE_STAGE_INPUT, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER,
        SPVC_RESOURCE_TYPE_SAMPLED_IMAGE, SPVC_RESOURCE_TYPE_SEPARATE_IMAGE, SPVC_RESOURCE_TYPE_SEPARATE_SAMPLERS};
    for (size_t k = 0; k < sizeof(kinds) / sizeof(*kinds); ++k) {
        spvc_reflected_resource const* list;
        size_t count;
        if (spvc_resources_get_resource_list_for_type(resources, kinds[k], &list, &count) != SPVC_SUCCESS) return 0;
        for (size_t i = 0; i < count; ++i) {
            spvc_reflected_resource const* item = &list[i];
            VoxMetalShaderResource resource = {0};
            resource.kind = kinds[k]; resource.stage = stage;
            resource.location = spvc_compiler_get_decoration(compiler, item->id, SpvDecorationLocation);
            resource.binding = spvc_compiler_msl_get_automatic_resource_binding(compiler, item->id);
            resource.secondary_binding = spvc_compiler_msl_get_automatic_resource_binding_secondary(compiler, item->id);
            if (kinds[k] != SPVC_RESOURCE_TYPE_STAGE_INPUT && resource.binding == UINT32_MAX) continue;
            spvc_type type = spvc_compiler_get_type_handle(compiler, item->type_id);
            if (!vox_metal_reflect_type(type, &resource)) return 0;
            if (kinds[k] == SPVC_RESOURCE_TYPE_UNIFORM_BUFFER) {
                spvc_type structure = spvc_compiler_get_type_handle(compiler, item->base_type_id);
                size_t size;
                if (spvc_compiler_get_declared_struct_size(compiler, structure, &size) != SPVC_SUCCESS) return 0;
                resource.byte_size = size;
                if (!vox_metal_append_resource(program, resource, spvc_compiler_get_name(original_names, item->id))) return 0;
                for (unsigned member = 0; member < spvc_type_get_num_member_types(structure); ++member) {
                    VoxMetalShaderResource field = resource;
                    field.kind = 100; /* Uniform-block member, including lowered plain uniforms. */
                    spvc_type member_type = spvc_compiler_get_type_handle(compiler, spvc_type_get_member_type(structure, member));
                    if (!vox_metal_reflect_type(member_type, &field)
                        || spvc_compiler_type_struct_member_offset(compiler, structure, member, &field.offset) != SPVC_SUCCESS
                        || spvc_compiler_get_declared_struct_member_size(compiler, structure, member, &size) != SPVC_SUCCESS) return 0;
                    field.byte_size = size;
                    if (spvc_type_get_num_array_dimensions(member_type))
                        if (spvc_compiler_type_struct_member_array_stride(compiler, structure, member, &field.array_stride) != SPVC_SUCCESS) return 0;
                    if (field.columns > 1)
                        if (spvc_compiler_type_struct_member_matrix_stride(compiler, structure, member, &field.matrix_stride) != SPVC_SUCCESS) return 0;
                    if (!vox_metal_append_resource(program, field, spvc_compiler_get_member_name(original_names, item->base_type_id, member))) return 0;
                }
            } else if (!vox_metal_append_resource(program, resource, spvc_compiler_get_name(original_names, item->id))) return 0;
        }
    }
    return 1;
}

static int vox_metal_emit_stage(VoxMetalTranslatedProgram* output, glslang_program_t* program,
                                int stage, char* log, size_t capacity)
{
    glslang_stage_t shader_stage = stage ? GLSLANG_STAGE_FRAGMENT : GLSLANG_STAGE_VERTEX;
    glslang_program_SPIRV_generate(program, shader_stage);
    size_t words = glslang_program_SPIRV_get_size(program);
    if (!words) { if (capacity) snprintf(log, capacity, "%s", glslang_program_SPIRV_get_messages(program)); return 0; }
    spvc_context context = NULL;
    spvc_parsed_ir ir;
    spvc_compiler compiler;
    spvc_compiler original_names;
    spvc_compiler_options options;
    char const* source = NULL;
    int success = spvc_context_create(&context) == SPVC_SUCCESS;
    if (success) success = spvc_context_parse_spirv(context, glslang_program_SPIRV_get_ptr(program), words, &ir) == SPVC_SUCCESS;
    if (success) success = spvc_context_create_compiler(context, SPVC_BACKEND_NONE, ir, SPVC_CAPTURE_MODE_COPY, &original_names) == SPVC_SUCCESS;
    if (success) success = spvc_context_create_compiler(context, SPVC_BACKEND_MSL, ir, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_create_compiler_options(compiler, &options) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_MSL_VERSION, SPVC_MAKE_MSL_VERSION(2, 0, 0)) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_FIXUP_DEPTH_CONVENTION, SPVC_TRUE) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_FLIP_VERTEX_Y, SPVC_TRUE) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_FORCE_ZERO_INITIALIZED_VARIABLES, SPVC_TRUE) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_install_compiler_options(compiler, options) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_compile(compiler, &source) == SPVC_SUCCESS;
    if (success) {
        output->msl[stage] = vox_metal_string_copy(source);
        output->entry[stage] = vox_metal_string_copy(spvc_compiler_get_cleansed_entry_point_name(compiler, "main", stage ? SpvExecutionModelFragment : SpvExecutionModelVertex));
        success = output->msl[stage] && output->entry[stage] && vox_metal_reflect_resources(output, compiler, original_names, stage);
    }
    if (!success && capacity) {
        char const* message = context ? spvc_context_get_last_error_string(context) : NULL;
        snprintf(log, capacity, "%s", message && *message ? message : "Metal shader translation allocation failed");
    }
    if (context) spvc_context_destroy(context);
    return success;
}

static VoxMetalTranslatedProgram* vox_metal_translate_program(char const* vertex, int vertex_length,
    char const* fragment, int fragment_length, int context_version, char* log, size_t capacity)
{
    if (capacity) log[0] = 0;
    if (!vertex || !fragment || vertex_length < 0 || fragment_length < 0 || (context_version != 2 && context_version != 3)) return NULL;
    vox_essl_prepare();
    if (!vox_essl_initialized) { if (capacity) snprintf(log, capacity, "ESSL compiler unavailable"); return NULL; }
    glslang_resource_t resources = *glslang_default_resource();
    resources.max_draw_buffers = 8;
    resources.max_vertex_attribs = 16;
    resources.max_vertex_uniform_components = resources.max_fragment_uniform_components = 4096;
    resources.max_vertex_uniform_vectors = resources.max_fragment_uniform_vectors = 1024;
    resources.max_varying_vectors = 16;
    resources.max_varying_components = resources.max_varying_floats = 64;
    char const* sources[] = {vertex, fragment};
    int lengths[] = {vertex_length, fragment_length};
    glslang_shader_t* original[2] = {NULL, NULL};
    glslang_shader_t* lowered[2] = {NULL, NULL};
    glslang_program_t* original_program = glslang_program_create();
    glslang_program_t* program = glslang_program_create();
    VoxMetalTranslatedProgram* output = calloc(1, sizeof(*output));
    int versions[2] = {0, 0};
    int success = program && original_program && output;
    for (int i = 0; success && i < 2; ++i) {
        char* code = vox_glsl_desktop_source_with_resources(sources[i], lengths[i], i, context_version, &resources);
        if (!code) { success = 0; break; }
        versions[i] = strstr(code, "#define _webgl_native_version 300\n") ? 300 : 100;
        char* preprocessed = NULL;
        success = vox_essl_validate_preprocessed(sources[i], lengths[i], i, versions[i], &resources, log, capacity, &preprocessed);
        glslang_input_t input = {0};
        input.language = GLSLANG_SOURCE_GLSL; input.stage = i ? GLSLANG_STAGE_FRAGMENT : GLSLANG_STAGE_VERTEX;
        input.client = GLSLANG_CLIENT_NONE; input.target_language = GLSLANG_TARGET_NONE;
        input.code = preprocessed; input.default_version = 100; input.default_profile = GLSLANG_ES_PROFILE; input.resource = &resources;
        if (success) original[i] = glslang_shader_create(&input);
        if (success) success = original[i] && glslang_shader_preprocess(original[i], &input) && glslang_shader_parse(original[i], &input);
        if (!success && original[i] && capacity) snprintf(log, capacity, "%s", glslang_shader_get_info_log(original[i]));
        if (success) glslang_program_add_shader(original_program, original[i]);
        free(preprocessed);
        input.client = GLSLANG_CLIENT_VULKAN; input.client_version = GLSLANG_TARGET_VULKAN_1_0;
        input.target_language = GLSLANG_TARGET_SPV; input.target_language_version = GLSLANG_TARGET_SPV_1_0;
        input.default_version = 410; input.default_profile = GLSLANG_CORE_PROFILE;
        input.messages = GLSLANG_MSG_SPV_RULES_BIT | GLSLANG_MSG_VULKAN_RULES_BIT; input.code = code;
        if (success) lowered[i] = glslang_shader_create(&input);
        if (success && lowered[i]) {
            glslang_shader_set_options(lowered[i], GLSLANG_SHADER_AUTO_MAP_BINDINGS | GLSLANG_SHADER_AUTO_MAP_LOCATIONS | GLSLANG_SHADER_VULKAN_RULES_RELAXED);
            glslang_shader_set_default_uniform_block_name(lowered[i], i ? "_webgl_native_fragment_uniforms" : "_webgl_native_vertex_uniforms");
            glslang_shader_set_default_uniform_block_set_and_binding(lowered[i], 31, 0);
            success = glslang_shader_preprocess(lowered[i], &input) && glslang_shader_parse(lowered[i], &input);
            if (!success && capacity) snprintf(log, capacity, "%s", glslang_shader_get_info_log(lowered[i]));
        } else success = 0;
        if (success) glslang_program_add_shader(program, lowered[i]);
        free(code);
    }
    if (success && versions[0] != versions[1]) {
        success = 0; if (capacity) snprintf(log, capacity, "Vertex and fragment ESSL versions differ");
    }
    if (success) {
        success = glslang_program_link(original_program, GLSLANG_MSG_DEFAULT_BIT);
        if (!success && capacity) snprintf(log, capacity, "%s", glslang_program_get_info_log(original_program));
    }
    if (success) {
        success = glslang_program_link(program, GLSLANG_MSG_SPV_RULES_BIT | GLSLANG_MSG_VULKAN_RULES_BIT) && glslang_program_map_io(program);
        if (!success && capacity) snprintf(log, capacity, "%s", glslang_program_get_info_log(program));
    }
    if (success) success = vox_metal_emit_stage(output, program, 0, log, capacity) && vox_metal_emit_stage(output, program, 1, log, capacity);
    if (program) glslang_program_delete(program);
    if (original_program) glslang_program_delete(original_program);
    for (int i = 0; i < 2; ++i) { if (original[i]) glslang_shader_delete(original[i]); if (lowered[i]) glslang_shader_delete(lowered[i]); }
    if (!success) {
        if (capacity && !*log) snprintf(log, capacity, "Metal shader translation failed");
        vox_metal_translation_destroy(output); return NULL;
    }
    return output;
}
#endif
