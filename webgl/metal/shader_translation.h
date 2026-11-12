/* Shader source and reflection supplied by the V compiler. No parser libraries. */
#ifndef VOX_METAL_SHADER_TRANSLATION_H
#define VOX_METAL_SHADER_TRANSLATION_H
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
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
    char* feedback_msl;
    VoxMetalFeedbackField* feedback_fields;
    size_t feedback_count;
    uint64_t direct_feedback_stride;
    char* msl[2];
    char* entry[2];
    VoxMetalShaderResource* resources;
    size_t resource_count;
} VoxMetalTranslatedProgram;

typedef struct { char const* name; uint32_t location; } VoxMetalAttributeBinding;


enum { VOX_SHADER_BOOL=2, VOX_SHADER_FLOAT=13 };
static char* vox_metal_string_copy(char const* value) {
    if(!value) return NULL;
    size_t size=strlen(value)+1;char* copy=malloc(size);
    if(copy) memcpy(copy,value,size);return copy;
}
static void vox_metal_translation_destroy(VoxMetalTranslatedProgram* program) {
    if(!program) return;
    for(int i=0;i<2;++i) {free(program->msl[i]);free(program->entry[i]);}
    for(size_t i=0;i<program->resource_count;++i) free(program->resources[i].name);
    for(size_t i=0;i<program->feedback_count;++i) {free(program->feedback_fields[i].name);free(program->feedback_fields[i].metal_name);}
    free(program->feedback_fields);free(program->feedback_msl);free(program->resources);free(program);
}
static int vox_metal_append_resource(VoxMetalTranslatedProgram* program,VoxMetalShaderResource resource,char const* name) {
    if(!program || !name || program->resource_count>=SIZE_MAX/sizeof(resource)-1) return 0;
    char* copy=vox_metal_string_copy(name);
    if(!copy) return 0;
    void* grown=realloc(program->resources,(program->resource_count+1)*sizeof(resource));
    if(!grown) {free(copy);return 0;}
    program->resources=grown;resource.name=copy;program->resources[program->resource_count++]=resource;return 1;
}
static void vox_metal_shader_log(char* log,uint64_t capacity,char const* message) {
    if(log && capacity) snprintf(log,(size_t)capacity,"%s",message?message:"");
}
#endif
