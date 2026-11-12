#ifndef VOX_METAL_SHADER_PROGRAM_H
#define VOX_METAL_SHADER_PROGRAM_H
#include "drawing_buffer_darwin.h"
#include "shader_translation.h"

typedef struct {
    CFTypeRef device, vertex, fragment, feedback;
    uint64_t feedback_stride;
    VoxMetalTranslatedProgram* translated;
} VoxMetalShaderProgram;

static void vox_metal_program_destroy(void* handle)
{
    VoxMetalShaderProgram* program = handle;
    if (!program) return;
    if (program->feedback) CFRelease(program->feedback);
    if (program->vertex) CFRelease(program->vertex);
    if (program->fragment) CFRelease(program->fragment);
    if (program->device) CFRelease(program->device);
    vox_metal_translation_destroy(program->translated);
    free(program);
}

static void* vox_metal_program_build(void* target, VoxMetalTranslatedProgram* translated, char* log, uint64_t capacity)
{
    VoxMetalDrawingBuffer* context = target;
    if (capacity) log[0] = 0;
    if (!context) { vox_metal_translation_destroy(translated); if (capacity) snprintf(log, capacity, "Metal drawing buffer is closed"); return NULL; }
    VoxMetalShaderProgram* program = calloc(1, sizeof(*program));
    if (!program) { vox_metal_translation_destroy(translated); return NULL; }
    program->translated = translated;
    program->feedback_stride = translated ? translated->direct_feedback_stride : 0;
    if (!program->translated) { vox_metal_program_destroy(program); return NULL; }
    program->device = CFRetain(context->device);
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)program->device;
        for (int stage = 0; stage < 2; ++stage) {
            NSError* error = nil;
            MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
            options.languageVersion = MTLLanguageVersion2_0;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
            if (@available(macOS 15.0, *)) options.mathMode = MTLMathModeSafe;
            else
#endif
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                options.fastMathEnabled = NO;
#pragma clang diagnostic pop
            }
            id<MTLLibrary> library = [device newLibraryWithSource:
                [NSString stringWithUTF8String:program->translated->msl[stage]] options:options error:&error];
            vox_metal_drop_owned(options);
            if (!library) {
                if (capacity) snprintf(log, capacity, "%s", error.localizedDescription.UTF8String ?: "Metal library compilation failed");
                vox_metal_program_destroy(program); return NULL;
            }
            id<MTLFunction> function = [library newFunctionWithName:[NSString stringWithUTF8String:program->translated->entry[stage]]];
            if (function) {
                if (stage) program->fragment = CFRetain((__bridge CFTypeRef)function);
                else program->vertex = CFRetain((__bridge CFTypeRef)function);
            }
            vox_metal_drop_owned(function);
            vox_metal_drop_owned(library);
            if (!function) {
                if (capacity) snprintf(log, capacity, "Metal shader entry point unavailable");
                vox_metal_program_destroy(program); return NULL;
            }
        }
    }
    return program;
}

static void* vox_metal_program_create_bound(void* target, char const* vertex, int vertex_length,
    char const* fragment, int fragment_length, int version,
    VoxMetalAttributeBinding const* bindings, uint64_t binding_count, char* log, uint64_t capacity)
{
    if (!target) { if (capacity) snprintf(log,capacity,"Metal drawing buffer is closed"); return NULL; }
    VoxMetalTranslatedProgram* translated = vox_metal_translate_program_bound(vertex,vertex_length,fragment,fragment_length,version,bindings,binding_count,log,capacity);
    if (!translated) return NULL;
    return vox_metal_program_build(target,translated,log,capacity);
}

static void* vox_metal_program_create(void* target, char const* vertex, int vertex_length,
    char const* fragment, int fragment_length, int version, char* log, uint64_t capacity)
{
    return vox_metal_program_create_bound(target, vertex, vertex_length, fragment, fragment_length,
        version, NULL, 0, log, capacity);
}

static int vox_metal_program_feedback(void* handle,char* log,uint64_t capacity)
{
    VoxMetalShaderProgram* program=handle;
    if(capacity) log[0]=0;
    if(!program) return 0;
    if(program->feedback) return 1;
    if(!program->translated->feedback_msl) { if(capacity) snprintf(log,capacity,"Transform feedback is unavailable for this translation");return 0; }
    for(size_t i=0;i<program->translated->resource_count;++i) {
        VoxMetalShaderResource* field=program->translated->resources+i;
        if(field->stage==0 && field->kind==SPVC_RESOURCE_TYPE_UNIFORM_BUFFER && field->binding>=13) {
            if(capacity) snprintf(log,capacity,"Transform feedback requires two reserved vertex buffer slots");return 0;
        }
    }
    @autoreleasepool {
        NSError* error=nil;
        MTLCompileOptions* options=[[MTLCompileOptions alloc] init];
        options.languageVersion=MTLLanguageVersion2_0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        options.fastMathEnabled=NO;
#pragma clang diagnostic pop
        id<MTLLibrary> library=[(__bridge id<MTLDevice>)program->device newLibraryWithSource:
            [NSString stringWithUTF8String:program->translated->feedback_msl] options:options error:&error];
        vox_metal_drop_owned(options);
        if(!library) { if(capacity) snprintf(log,capacity,"%s",error.localizedDescription.UTF8String ?: "Metal feedback compilation failed");return 0; }
        id<MTLFunction> function=[library newFunctionWithName:[NSString stringWithUTF8String:program->translated->direct_feedback_stride ? "vox_capture" : program->translated->entry[0]]];
        if(function) program->feedback=CFRetain((__bridge CFTypeRef)function);
        vox_metal_drop_owned(function);vox_metal_drop_owned(library);
        return program->feedback!=NULL;
    }
}

static uint64_t vox_metal_feedback_stride(void* handle) { return handle?((VoxMetalShaderProgram*)handle)->feedback_stride:0; }
static uint64_t vox_metal_feedback_count(void* handle) { return handle?((VoxMetalShaderProgram*)handle)->translated->feedback_count:0; }
static int vox_metal_feedback_field(void* handle,uint64_t index,VoxMetalFeedbackField* output) {
    VoxMetalShaderProgram* program=handle;
    if(!program || !output || index>=program->translated->feedback_count) return 0;
    *output=program->translated->feedback_fields[index];return 1;
}

static char const* vox_metal_program_source(void* handle, int stage)
{
    VoxMetalShaderProgram* program = handle;
    return program && (stage == 0 || stage == 1) ? program->translated->msl[stage] : NULL;
}

static uint64_t vox_metal_program_resource_count(void* handle)
{
    VoxMetalShaderProgram* program = handle;
    return program ? program->translated->resource_count : 0;
}

static int vox_metal_program_resource(void* handle, uint64_t index, VoxMetalShaderResource* resource)
{
    VoxMetalShaderProgram* program = handle;
    if (!program || !resource || index >= program->translated->resource_count) return 0;
    *resource = program->translated->resources[index];
    return 1;
}
#endif
