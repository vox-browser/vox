#ifndef VOX_METAL_SHADER_PROGRAM_H
#define VOX_METAL_SHADER_PROGRAM_H
#include "drawing_buffer_darwin.h"
#include "shader_translation.h"

typedef struct {
    CFTypeRef device, vertex, fragment;
    VoxMetalTranslatedProgram* translated;
} VoxMetalShaderProgram;

static void vox_metal_program_destroy(void* handle)
{
    VoxMetalShaderProgram* program = handle;
    if (!program) return;
    if (program->vertex) CFRelease(program->vertex);
    if (program->fragment) CFRelease(program->fragment);
    if (program->device) CFRelease(program->device);
    vox_metal_translation_destroy(program->translated);
    free(program);
}

static void* vox_metal_program_create(void* target, char const* vertex, int vertex_length,
    char const* fragment, int fragment_length, int version, char* log, uint64_t capacity)
{
    VoxMetalDrawingBuffer* context = target;
    if (capacity) log[0] = 0;
    if (!context) { if (capacity) snprintf(log, capacity, "Metal drawing buffer is closed"); return NULL; }
    VoxMetalShaderProgram* program = calloc(1, sizeof(*program));
    if (!program) return NULL;
    program->translated = vox_metal_translate_program(vertex, vertex_length, fragment, fragment_length, version, log, capacity);
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
