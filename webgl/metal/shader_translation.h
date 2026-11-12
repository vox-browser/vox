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
    uint32_t image_dimension,image_arrayed,image_depth,image_scalar_type;
    uint32_t semantic_type;
} VoxMetalShaderResource;

typedef struct {
    char* name;
    char* metal_name;
    uint32_t rows, columns, array_length, base_type;
    uint32_t offset, array_stride, matrix_stride;
} VoxMetalFeedbackField;

typedef struct {
    char* essl[2];
    char* feedback_msl;
    VoxMetalFeedbackField* feedback_fields;
    size_t feedback_count;
    char* msl[2];
    char* entry[2];
    VoxMetalShaderResource* resources;
    size_t resource_count;
} VoxMetalTranslatedProgram;

typedef struct { char const* name; uint32_t location; } VoxMetalAttributeBinding;

static int vox_metal_statement_has_token(char const* start, size_t length, char const* name)
{
    for (size_t i = 0; i < length;) {
        if (!vox_glsl_identifier_start(start[i])) { ++i; continue; }
        size_t begin = i++;
        while (i < length && vox_glsl_identifier(start[i])) ++i;
        if (vox_glsl_equal(start + begin, i - begin, name)) return 1;
    }
    return 0;
}

/* The original ESSL has already been validated and preprocessed. Only the
 * presence of a location qualifier matters; glslang evaluated its expression. */
static int vox_metal_explicit_attribute(char const* source, char const* name)
{
    size_t length = strlen(source), begin = 0;
    char* clean = vox_glsl_without_comments(source, length);
    if (!clean) return -1;
    unsigned depth = 0;
    int explicit_location = 0;
    for (size_t i = 0; i < length && !explicit_location; ++i) {
        if (clean[i] == '{') ++depth;
        else if (clean[i] == '}') { if (depth) --depth; if (!depth) begin = i + 1; }
        else if (!depth && clean[i] == ';') {
            char const* text = clean + begin;
            size_t count = i - begin;
            explicit_location = vox_metal_statement_has_token(text, count, "layout")
                && vox_metal_statement_has_token(text, count, "location")
                && vox_metal_statement_has_token(text, count, "in")
                && vox_metal_statement_has_token(text, count, name);
            begin = i + 1;
        }
    }
    free(clean);
    return explicit_location;
}

static int vox_metal_bind_attributes(spvc_compiler compiler, char const* source,
    VoxMetalAttributeBinding const* bindings, size_t binding_count)
{
    spvc_set active;
    spvc_resources resources;
    spvc_reflected_resource const* inputs;
    size_t count;
    if (spvc_compiler_get_active_interface_variables(compiler, &active) != SPVC_SUCCESS
        || spvc_compiler_create_shader_resources_for_active_variables(compiler, &resources, active) != SPVC_SUCCESS
        || spvc_resources_get_resource_list_for_type(resources, SPVC_RESOURCE_TYPE_STAGE_INPUT, &inputs, &count) != SPVC_SUCCESS
        || count > 16) return 0;
    uint32_t locations[16], spans[16], occupied = 0;
    for (size_t i = 0; i < count; ++i) {
        spvc_type type = spvc_compiler_get_type_handle(compiler, inputs[i].type_id);
        uint64_t span = spvc_type_get_columns(type);
        for (unsigned j = 0; j < spvc_type_get_num_array_dimensions(type); ++j) {
            if (!spvc_type_array_dimension_is_literal(type, j)) return 0;
            span *= spvc_type_get_array_dimension(type, j);
            if (span > 16) return 0;
        }
        if (!span || span > 16) return 0;
        spans[i] = (uint32_t)span;
        int explicit_location = vox_metal_explicit_attribute(source, inputs[i].name);
        if (explicit_location < 0) return 0;
        locations[i] = explicit_location ? spvc_compiler_get_decoration(compiler, inputs[i].id, SpvDecorationLocation) : UINT32_MAX;
        if (!explicit_location)
            for (size_t j = 0; j < binding_count; ++j)
                if (!strcmp(bindings[j].name, inputs[i].name)) locations[i] = bindings[j].location;
        if (locations[i] != UINT32_MAX) {
            if (locations[i] >= 16 || span > 16 - locations[i]) return 0;
            uint32_t mask = ((1u << span) - 1) << locations[i];
            if (occupied & mask) return 0;
            occupied |= mask;
        }
    }
    for (size_t i = 0; i < count; ++i) {
        if (locations[i] == UINT32_MAX) {
            uint32_t location = 0, mask = (1u << spans[i]) - 1;
            while (location + spans[i] <= 16 && (occupied & (mask << location))) ++location;
            if (location + spans[i] > 16) return 0;
            locations[i] = location; occupied |= mask << location;
        }
        spvc_compiler_set_decoration(compiler, inputs[i].id, SpvDecorationLocation, locations[i]);
    }
    return 1;
}

static char* vox_metal_string_copy(char const* value)
{
    if (!value) return NULL;
    size_t size = strlen(value) + 1;
    char* copy = malloc(size);
    if (copy) memcpy(copy, value, size);
    return copy;
}

// SPIRV-Cross emits this padded-struct wrapper even when Metal's structure
// already has the exact stride. Metal rejects the resulting zero-length char
// array. A partial specialization preserves sizeof(T), with no extra byte.
static char* vox_metal_msl_layout_source(char const* source)
{
    char const* padding=strstr(source,"char padding[stride - sizeof(T)];");
    char const* end=padding?strstr(padding,"};"):NULL;
    if(!end) return vox_metal_string_copy(source);
    end+=2;
    char const* specialization="\ntemplate<typename T> struct spvPaddedArrayElement<T, sizeof(T)> { T data; };\n";
    size_t before=(size_t)(end-source),extra=strlen(specialization),length=strlen(source);
    if(length>SIZE_MAX-extra-1) return NULL;
    char* result=malloc(length+extra+1);
    if(!result) return NULL;
    memcpy(result,source,before);memcpy(result+before,specialization,extra);memcpy(result+before+extra,end,length-before+1);
    return result;
}

static void vox_metal_translation_destroy(VoxMetalTranslatedProgram* program)
{
    if (!program) return;
    for (int i = 0; i < 2; ++i) { free(program->msl[i]); free(program->entry[i]);free(program->essl[i]); }
    for (size_t i = 0; i < program->resource_count; ++i) free(program->resources[i].name);
    free(program->feedback_msl);
    for(size_t i=0;i<program->feedback_count;++i) { free(program->feedback_fields[i].name);free(program->feedback_fields[i].metal_name); }
    free(program->feedback_fields);
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

/* Vulkan UBO storage represents booleans as uint. Recover only global
 * uniform declarations from validated, macro-expanded ESSL, never local bools
 * that happen to shadow another uniform's name. */
static int vox_metal_boolean_uniform(char const* source,char const* name)
{
    if(!source || !name) return 0;
    unsigned depth=0,brackets=0;
    int uniform=0,boolean=0;
    for(size_t i=0;source[i];) {
        char c=source[i];
        if(c=='{') { ++depth;++i;continue; }
        if(c=='}') { if(depth) --depth;boolean=0;++i;continue; }
        if(c=='[') { ++brackets;++i;continue; }
        if(c==']') { if(brackets) --brackets;++i;continue; }
        if(c==';') { boolean=0;if(!depth) uniform=0;++i;continue; }
        if(!vox_glsl_identifier_start(c)) { ++i;continue; }
        size_t begin=i++;
        while(vox_glsl_identifier(source[i])) ++i;
        size_t length=i-begin;
        if(!depth && vox_glsl_equal(source+begin,length,"uniform")) { uniform=1;continue; }
        if(!uniform || brackets || depth) continue;
        if(vox_glsl_equal(source+begin,length,"bool") || vox_glsl_equal(source+begin,length,"bvec2")
            || vox_glsl_equal(source+begin,length,"bvec3") || vox_glsl_equal(source+begin,length,"bvec4")) { boolean=1;continue; }
        if(boolean && vox_glsl_equal(source+begin,length,name)) return 1;
    }
    return 0;
}

static int vox_metal_boolean_member(char const* source,char const* type_name,char const* name)
{
    if(!source || !type_name || !name) return 0;
    unsigned depth=0;int expect_type=0,target=0,inside=0,boolean=0;
    for(size_t i=0;source[i];) {
        char c=source[i];
        if(c=='{') { ++depth;if(depth==1 && target) inside=1;++i;continue; }
        if(c=='}') { if(depth) --depth;if(!depth) { inside=target=0; } boolean=0;++i;continue; }
        if(c==';') { boolean=0;if(!depth) target=expect_type=0;++i;continue; }
        if(!vox_glsl_identifier_start(c)) { ++i;continue; }
        size_t begin=i++;
        while(vox_glsl_identifier(source[i])) ++i;
        size_t length=i-begin;
        if(!depth && expect_type) { target=vox_glsl_equal(source+begin,length,type_name);expect_type=0;continue; }
        if(!depth && (vox_glsl_equal(source+begin,length,"struct") || vox_glsl_equal(source+begin,length,"uniform"))) { expect_type=1;continue; }
        if(!inside || depth!=1) continue;
        if(vox_glsl_equal(source+begin,length,"bool") || vox_glsl_equal(source+begin,length,"bvec2")
            || vox_glsl_equal(source+begin,length,"bvec3") || vox_glsl_equal(source+begin,length,"bvec4")) { boolean=1;continue; }
        if(boolean && vox_glsl_equal(source+begin,length,name)) return 1;
    }
    return 0;
}

static int vox_metal_reflect_uniform_member(VoxMetalTranslatedProgram* program,
    spvc_compiler compiler,spvc_compiler original_names,spvc_type_id parent_id,unsigned member,
    VoxMetalShaderResource block,char const* prefix,uint32_t base_offset,unsigned nesting)
{
    if(nesting>32) return 0;
    spvc_type parent=spvc_compiler_get_type_handle(compiler,parent_id);
    spvc_type_id id=spvc_type_get_member_type(parent,member);
    spvc_type type=spvc_compiler_get_type_handle(compiler,id);
    VoxMetalShaderResource field=block;field.kind=100;field.array_stride=field.matrix_stride=field.semantic_type=0;
    size_t size=0;
    uint32_t relative=0;
    if(!vox_metal_reflect_type(type,&field)
        || spvc_compiler_type_struct_member_offset(compiler,parent,member,&relative)!=SPVC_SUCCESS
        || spvc_compiler_get_declared_struct_member_size(compiler,parent,member,&size)!=SPVC_SUCCESS
        || relative>UINT32_MAX-base_offset) return 0;
    field.offset=base_offset+relative;field.byte_size=size;
    char const* leaf=spvc_compiler_get_member_name(original_names,spvc_type_get_base_type_id(parent),member);
    char name[2048];
    int length=snprintf(name,sizeof(name),"%s%s%s",prefix,*prefix?".":"",leaf);
    if(length<0 || (size_t)length>=sizeof(name)) return 0;
    unsigned dimensions=spvc_type_get_num_array_dimensions(type);
    if(dimensions && spvc_compiler_type_struct_member_array_stride(compiler,parent,member,&field.array_stride)!=SPVC_SUCCESS) return 0;
    if(field.base_type==SPVC_BASETYPE_STRUCT) {
        if(dimensions>1 || field.array_length>4096) return 0;
        for(uint32_t element=0;element<field.array_length;++element) {
            char path[2048];
            length=dimensions?snprintf(path,sizeof(path),"%s[%u]",name,element):snprintf(path,sizeof(path),"%s",name);
            if(length<0 || (size_t)length>=sizeof(path)) return 0;
            uint64_t offset=(uint64_t)field.offset+(uint64_t)element*field.array_stride;
            if(offset>UINT32_MAX) return 0;
            for(unsigned child=0;child<spvc_type_get_num_member_types(type);++child)
                if(!vox_metal_reflect_uniform_member(program,compiler,original_names,id,child,block,path,(uint32_t)offset,nesting+1)) return 0;
        }
        return 1;
    }
    if(field.columns>1 && spvc_compiler_type_struct_member_matrix_stride(compiler,parent,member,&field.matrix_stride)!=SPVC_SUCCESS) return 0;
    char const* type_name=spvc_compiler_get_name(original_names,spvc_type_get_base_type_id(parent));
    if(field.base_type==SPVC_BASETYPE_UINT32 && (vox_metal_boolean_member(program->essl[field.stage],type_name,leaf)
        || (type_name && !strncmp(type_name,"_webgl_native_",14) && vox_metal_boolean_uniform(program->essl[field.stage],leaf)))) field.semantic_type=SPVC_BASETYPE_BOOLEAN;
    return vox_metal_append_resource(program,field,name);
}

static int vox_metal_reflect_resources(VoxMetalTranslatedProgram* program, spvc_compiler compiler,
                                      spvc_compiler original_names, int stage)
{
    spvc_resources resources;
    spvc_set active;
    if (spvc_compiler_get_active_interface_variables(compiler, &active) != SPVC_SUCCESS
        || spvc_compiler_create_shader_resources_for_active_variables(compiler, &resources, active) != SPVC_SUCCESS) return 0;
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
            if (kinds[k] == SPVC_RESOURCE_TYPE_SAMPLED_IMAGE || kinds[k] == SPVC_RESOURCE_TYPE_SEPARATE_IMAGE) {
                resource.image_dimension=spvc_type_get_image_dimension(type);
                resource.image_arrayed=spvc_type_get_image_arrayed(type);
                resource.image_depth=spvc_type_get_image_is_depth(type);
                spvc_type scalar=spvc_compiler_get_type_handle(compiler,spvc_type_get_image_sampled_type(type));
                resource.image_scalar_type=spvc_type_get_basetype(scalar);
            }
            if (kinds[k] == SPVC_RESOURCE_TYPE_UNIFORM_BUFFER) {
                spvc_type structure = spvc_compiler_get_type_handle(compiler, item->base_type_id);
                size_t size;
                if (spvc_compiler_get_declared_struct_size(compiler, structure, &size) != SPVC_SUCCESS) return 0;
                resource.byte_size = (size+15)&~(size_t)15;
                char const* block_name = spvc_compiler_get_name(original_names, item->base_type_id);
                if (!block_name || !*block_name) block_name = spvc_compiler_get_name(original_names, item->id);
                if (!vox_metal_append_resource(program, resource, block_name)) return 0;
                spvc_buffer_range const* ranges = NULL;
                size_t range_count = 0;
                int plain_uniforms = block_name && !strncmp(block_name, "_webgl_native_", sizeof("_webgl_native_") - 1);
                if (plain_uniforms && spvc_compiler_get_active_buffer_ranges(compiler, item->id, &ranges, &range_count) != SPVC_SUCCESS) return 0;
                for (unsigned member = 0; member < spvc_type_get_num_member_types(structure); ++member) {
                    if (plain_uniforms) {
                        int used = 0;
                        for (size_t j = 0; j < range_count; ++j) if (ranges[j].index == member) used = 1;
                        if (!used) continue;
                    }
                    if(!vox_metal_reflect_uniform_member(program,compiler,original_names,item->base_type_id,member,resource,"",0,0)) return 0;
                }
            } else if (!vox_metal_append_resource(program, resource, spvc_compiler_get_name(original_names, item->id))) return 0;
        }
    }
    return 1;
}

static int vox_metal_emit_stage(VoxMetalTranslatedProgram* output, glslang_program_t* program,
                                int stage, char const* lowered_source, VoxMetalAttributeBinding const* bindings,
                                size_t binding_count, char* log, size_t capacity)
{
    glslang_stage_t shader_stage = stage ? GLSLANG_STAGE_FRAGMENT : GLSLANG_STAGE_VERTEX;
    glslang_program_SPIRV_generate(program, shader_stage);
    size_t words = glslang_program_SPIRV_get_size(program);
    if (!words) { if (capacity) snprintf(log, capacity, "%s", glslang_program_SPIRV_get_messages(program)); return 0; }
    spvc_context context = NULL;
    spvc_parsed_ir ir;
    spvc_compiler compiler;
    spvc_compiler feedback_compiler;
    spvc_compiler original_names;
    spvc_compiler_options options;
    char const* source = NULL;
    int success = spvc_context_create(&context) == SPVC_SUCCESS;
    if (success) success = spvc_context_parse_spirv(context, glslang_program_SPIRV_get_ptr(program), words, &ir) == SPVC_SUCCESS;
    if (success) success = spvc_context_create_compiler(context, SPVC_BACKEND_NONE, ir, SPVC_CAPTURE_MODE_COPY, &original_names) == SPVC_SUCCESS;
    if (success && !stage) success=spvc_context_create_compiler(context,SPVC_BACKEND_MSL,ir,SPVC_CAPTURE_MODE_COPY,&feedback_compiler)==SPVC_SUCCESS;
    if (success) success = spvc_context_create_compiler(context, SPVC_BACKEND_MSL, ir, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler) == SPVC_SUCCESS;
    if (success && !stage) success = vox_metal_bind_attributes(compiler, lowered_source, bindings, binding_count);
    spvc_set active;
    if (success) success = spvc_compiler_get_active_interface_variables(compiler, &active) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_set_enabled_interface_variables(compiler, active) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_create_compiler_options(compiler, &options) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_MSL_VERSION, SPVC_MAKE_MSL_VERSION(2, 0, 0)) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_FIXUP_DEPTH_CONVENTION, SPVC_TRUE) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_FLIP_VERTEX_Y, SPVC_TRUE) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_FORCE_ZERO_INITIALIZED_VARIABLES, SPVC_TRUE) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_install_compiler_options(compiler, options) == SPVC_SUCCESS;
    if (success) success = spvc_compiler_compile(compiler, &source) == SPVC_SUCCESS;
    if (success) {
        output->msl[stage] = vox_metal_msl_layout_source(source);
        output->entry[stage] = vox_metal_string_copy(spvc_compiler_get_cleansed_entry_point_name(compiler, "main", stage ? SpvExecutionModelFragment : SpvExecutionModelVertex));
        success = output->msl[stage] && output->entry[stage] && vox_metal_reflect_resources(output, compiler, original_names, stage);
    }
    if(success && !stage) {
        compiler=feedback_compiler;
        success=vox_metal_bind_attributes(compiler,lowered_source,bindings,binding_count)
            && spvc_compiler_get_active_interface_variables(compiler,&active)==SPVC_SUCCESS
            && spvc_compiler_set_enabled_interface_variables(compiler,active)==SPVC_SUCCESS
            && spvc_compiler_create_compiler_options(compiler,&options)==SPVC_SUCCESS
            && spvc_compiler_options_set_uint(options,SPVC_COMPILER_OPTION_MSL_VERSION,SPVC_MAKE_MSL_VERSION(2,0,0))==SPVC_SUCCESS;
        if(success) success=spvc_compiler_options_set_bool(options,SPVC_COMPILER_OPTION_MSL_CAPTURE_OUTPUT_TO_BUFFER,SPVC_TRUE)==SPVC_SUCCESS
            && spvc_compiler_options_set_bool(options,SPVC_COMPILER_OPTION_MSL_DISABLE_RASTERIZATION,SPVC_TRUE)==SPVC_SUCCESS
            && spvc_compiler_options_set_uint(options,SPVC_COMPILER_OPTION_MSL_SHADER_OUTPUT_BUFFER_INDEX,13)==SPVC_SUCCESS
            && spvc_compiler_options_set_uint(options,SPVC_COMPILER_OPTION_MSL_INDIRECT_PARAMS_BUFFER_INDEX,14)==SPVC_SUCCESS
            && spvc_compiler_install_compiler_options(compiler,options)==SPVC_SUCCESS
            && spvc_compiler_compile(compiler,&source)==SPVC_SUCCESS;
        if(success) { output->feedback_msl=vox_metal_msl_layout_source(source);success=output->feedback_msl!=NULL; }
        spvc_resources reflected;
        spvc_reflected_resource const* fields=NULL;
        size_t count=0;
        if(success) success=spvc_compiler_create_shader_resources(compiler,&reflected)==SPVC_SUCCESS
            && spvc_resources_get_resource_list_for_type(reflected,SPVC_RESOURCE_TYPE_STAGE_OUTPUT,&fields,&count)==SPVC_SUCCESS;
        if(success) {
            output->feedback_fields=calloc(count+1,sizeof(VoxMetalFeedbackField));
            success=output->feedback_fields!=NULL;
        }
        for(size_t i=0;success && i<count;++i) {
            VoxMetalShaderResource type={0};
            success=vox_metal_reflect_type(spvc_compiler_get_type_handle(compiler,fields[i].type_id),&type);
            VoxMetalFeedbackField* field=output->feedback_fields+output->feedback_count++;
            field->name=vox_metal_string_copy(spvc_compiler_get_name(original_names,fields[i].id));
            field->metal_name=vox_metal_string_copy(spvc_compiler_get_name(compiler,fields[i].id));
            field->rows=type.rows;field->columns=type.columns;field->array_length=type.array_length;field->base_type=type.base_type;
            success=success && field->name && field->metal_name;
        }
        if(success) {
            VoxMetalFeedbackField* field=output->feedback_fields+output->feedback_count++;
            field->name=vox_metal_string_copy("gl_Position");field->metal_name=vox_metal_string_copy("gl_Position");
            field->rows=4;field->columns=field->array_length=1;field->base_type=SPVC_BASETYPE_FP32;
            success=field->name && field->metal_name;
        }
    }
    if (!success && capacity) {
        char const* message = context ? spvc_context_get_last_error_string(context) : NULL;
        snprintf(log, capacity, "%s", message && *message ? message : "Metal shader translation allocation failed");
    }
    if (context) spvc_context_destroy(context);
    return success;
}

static VoxMetalTranslatedProgram* vox_metal_translate_program_bound(char const* vertex, int vertex_length,
    char const* fragment, int fragment_length, int context_version,
    VoxMetalAttributeBinding const* bindings, size_t binding_count, char* log, size_t capacity)
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
    char* lowered_sources[2] = {NULL, NULL};
    int success = program && original_program && output;
    for (int i = 0; success && i < 2; ++i) {
        char* code = vox_glsl_desktop_source_with_resources(sources[i], lengths[i], i, context_version, &resources);
        lowered_sources[i] = code;
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
        if(success) { output->essl[i]=vox_metal_string_copy(preprocessed);success=output->essl[i]!=NULL; }
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
    if (success) success = vox_metal_emit_stage(output, program, 0, lowered_sources[0], bindings, binding_count, log, capacity)
        && vox_metal_emit_stage(output, program, 1, lowered_sources[1], NULL, 0, log, capacity);
    if (program) glslang_program_delete(program);
    if (original_program) glslang_program_delete(original_program);
    for (int i = 0; i < 2; ++i) { if (original[i]) glslang_shader_delete(original[i]); if (lowered[i]) glslang_shader_delete(lowered[i]); free(lowered_sources[i]); }
    if (!success) {
        if (capacity && !*log) snprintf(log, capacity, "Metal shader translation failed");
        vox_metal_translation_destroy(output); return NULL;
    }
    return output;
}

static VoxMetalTranslatedProgram* vox_metal_translate_program(char const* vertex, int vertex_length,
    char const* fragment, int fragment_length, int context_version, char* log, size_t capacity)
{
    return vox_metal_translate_program_bound(vertex, vertex_length, fragment, fragment_length,
        context_version, NULL, 0, log, capacity);
}
#endif
