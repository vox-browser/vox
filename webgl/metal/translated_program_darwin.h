#ifndef VOX_METAL_TRANSLATED_PROGRAM_H
#define VOX_METAL_TRANSLATED_PROGRAM_H
#include "shader_program_darwin.h"
#include <mach-o/dyld.h>
static int vox_metal_direct_compiler_unloaded(void) {
    for(uint32_t i=0;i<_dyld_image_count();++i) { char const* name=_dyld_get_image_name(i);if(strstr(name,"glslang") || strstr(name,"spirv-cross")) return 0; }
    return 1;
}

/* Own copies of V-generated MSL and reflection; no shader parsing here. */
static void* vox_metal_translation_from_msl(char const* vertex, char const* fragment, char const* feedback, uint64_t stride) {
    if(!vertex || !fragment) return NULL;
    VoxMetalTranslatedProgram* result=calloc(1,sizeof(*result));
    if(!result) return NULL;
    result->msl[0]=vox_metal_string_copy(vertex);result->msl[1]=vox_metal_string_copy(fragment);
    result->entry[0]=vox_metal_string_copy("vox_main");result->entry[1]=vox_metal_string_copy("vox_main");
    if(stride) { result->feedback_msl=vox_metal_string_copy(feedback);result->direct_feedback_stride=stride; }
    if(!result->msl[0] || !result->msl[1] || !result->entry[0] || !result->entry[1] || (stride && !result->feedback_msl)) { vox_metal_translation_destroy(result);return NULL; }
    return result;
}
static int vox_metal_translation_resource(void* handle, VoxMetalShaderResource const* field) {
    if(!handle || !field || !field->name) return 0;
    return vox_metal_append_resource(handle,*field,field->name);
}
static int vox_metal_translation_feedback(void* handle,VoxMetalFeedbackField const* field) {
    VoxMetalTranslatedProgram* program=handle;
    if(!program || !field || !field->name || program->feedback_count>=4096) return 0;
    char* name=vox_metal_string_copy(field->name);
    char* metal_name=vox_metal_string_copy(field->name);
    void* grown=realloc(program->feedback_fields,(program->feedback_count+1)*sizeof(*field));
    if(!name || !metal_name || !grown) { free(name);free(metal_name);if(grown) program->feedback_fields=grown;return 0; }
    program->feedback_fields=grown;
    VoxMetalFeedbackField copy=*field;copy.name=name;copy.metal_name=metal_name;
    program->feedback_fields[program->feedback_count++]=copy;
    return 1;
}
static int vox_metal_validate_msl(void* target,char const* source,char* log,uint64_t capacity) {
    vox_metal_shader_log(log,capacity,"");
    VoxMetalDrawingBuffer* context=target;
    if(!context || !source) return 0;
    @autoreleasepool {
        NSError* error=nil;
        MTLCompileOptions* options=[[MTLCompileOptions alloc] init];options.languageVersion=MTLLanguageVersion2_0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        options.fastMathEnabled=NO;
#pragma clang diagnostic pop
        id<MTLLibrary> library=[(__bridge id<MTLDevice>)context->device newLibraryWithSource:[NSString stringWithUTF8String:source] options:options error:&error];
        vox_metal_drop_owned(options);
        if(!library) {vox_metal_shader_log(log,capacity,error.localizedDescription.UTF8String);return 0;}
        vox_metal_drop_owned(library);return 1;
    }
}
#endif
