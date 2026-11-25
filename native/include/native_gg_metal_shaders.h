// Staged inside Sokol's Metal backend after _sg_mtl_compile_library.
#include "../../platform/native_state.h"
#include <pthread.h>

enum { VOX_GG_METAL_SHADER_LIBRARY_LIMIT = 32 };

typedef struct {
    char *source;
    NSString *text;
    dispatch_group_t completion;
    id<MTLLibrary> library;
    NSError *error;
    bool off_thread;
} VoxGGMetalShaderLibrary;

// Only the drawing thread reads or changes the queue. Metal writes each
// result into its own slot and signals the join before it can be consumed.
typedef struct {
    MTLCompileOptions *options;
    int major, minor;
    bool fast_math;
    pthread_t owner;
    size_t count, reused, ready;
    VoxGGMetalShaderLibrary jobs[VOX_GG_METAL_SHADER_LIBRARY_LIMIT];
} VoxGGMetalShaderLibraries;

VOX_NATIVE_STATE VoxGGMetalShaderLibraries vox_gg_metal_shader_libraries;

bool vox_gg_metal_begin_shader_libraries(void) {
    VoxGGMetalShaderLibraries *batch = &vox_gg_metal_shader_libraries;
    const char *enabled = getenv("VOX_PARALLEL_GG_METAL_SHADER_LIBRARIES");
    if (batch->options || !_sg.valid || !_sg_v_mtl_compile_options.language_major
        || !enabled || strcmp(enabled, "1") != 0 || getenv("VOX_SERIAL_GG_METAL_SHADERS")) {
        return false;
    }
    batch->options = _sg_v_mtl_new_compile_options();
    batch->major = _sg_v_mtl_compile_options.language_major;
    batch->minor = _sg_v_mtl_compile_options.language_minor;
    batch->fast_math = _sg_v_mtl_compile_options.fast_math;
    batch->owner = getenv("VOX_GG_METAL_SHADER_DIAGNOSTICS") ? pthread_self() : NULL;
    return batch->options != nil;
}

static VoxGGMetalShaderLibrary *vox_gg_metal_find_shader_library(const char *source) {
    VoxGGMetalShaderLibraries *batch = &vox_gg_metal_shader_libraries;
    for (size_t i = 0; i < batch->count; ++i) {
        if (strcmp(batch->jobs[i].source, source) == 0) return &batch->jobs[i];
    }
    return NULL;
}

void vox_gg_metal_submit_shader_library(const char *source) {
    VoxGGMetalShaderLibraries *batch = &vox_gg_metal_shader_libraries;
    if (!batch->options || !source || batch->count == VOX_GG_METAL_SHADER_LIBRARY_LIMIT
        || vox_gg_metal_find_shader_library(source)) return;
    char *copy = strdup(source);
    if (!copy) return;
    NSString *text = [[NSString alloc] initWithUTF8String:copy];
    if (!text) { free(copy); return; }
    VoxGGMetalShaderLibrary *job = &batch->jobs[batch->count++];
    job->source = copy;
    job->text = text;
    dispatch_group_t completion = dispatch_group_create();
    job->completion = completion;
    pthread_t owner = batch->owner;
    id<MTLDevice> device = _sg.mtl.device;
    MTLCompileOptions *options = batch->options;
    dispatch_group_enter(completion);
    // Cached Metal libraries can complete inline. Dispatch the request so
    // the drawing thread stays out of both the lookup and the compiler.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            job->off_thread = owner && !pthread_equal(owner, pthread_self());
            [device newLibraryWithSource:text options:options
                completionHandler:^(id<MTLLibrary> library, NSError *error) {
                    job->library = library;
                    job->error = error;
                    _SG_OBJC_RETAIN(library);
                    _SG_OBJC_RETAIN(error);
                    dispatch_group_leave(completion);
                }];
        }
    });
}

static VoxGGMetalShaderLibrary *vox_gg_metal_prepared_shader_library(const char *source) {
    const VoxGGMetalShaderLibraries *batch = &vox_gg_metal_shader_libraries;
    if (!batch->count || batch->major != _sg_v_mtl_compile_options.language_major
        || batch->minor != _sg_v_mtl_compile_options.language_minor
        || batch->fast_math != _sg_v_mtl_compile_options.fast_math) return NULL;
    return vox_gg_metal_find_shader_library(source);
}

static id<MTLLibrary> vox_gg_metal_read_shader_library(VoxGGMetalShaderLibrary *job) {
    VoxGGMetalShaderLibraries *batch = &vox_gg_metal_shader_libraries;
    bool ready = batch->owner && dispatch_group_wait(job->completion, DISPATCH_TIME_NOW) == 0;
    if (!ready) dispatch_group_wait(job->completion, DISPATCH_TIME_FOREVER);
    batch->reused++;
    batch->ready += ready;
    if (job->error) {
        _SG_ERROR(METAL_SHADER_COMPILATION_FAILED);
        _SG_LOGMSG(METAL_SHADER_COMPILATION_OUTPUT, [job->error.localizedDescription UTF8String]);
    }
    id<MTLLibrary> library = job->library;
    _SG_OBJC_RETAIN(library);
    return library;
}

void vox_gg_metal_end_shader_libraries(void) {
    VoxGGMetalShaderLibraries *batch = &vox_gg_metal_shader_libraries;
    if (!batch->options) return;
    size_t valid = 0, off_thread = 0;
    for (size_t i = 0; i < batch->count; ++i) {
        VoxGGMetalShaderLibrary *job = &batch->jobs[i];
        dispatch_group_wait(job->completion, DISPATCH_TIME_FOREVER);
        valid += job->library != nil;
        off_thread += job->off_thread;
        free(job->source);
        _SG_OBJC_RELEASE(job->text);
        _SG_OBJC_RELEASE(job->completion);
        _SG_OBJC_RELEASE(job->library);
        _SG_OBJC_RELEASE(job->error);
    }
    if (batch->owner) {
        fprintf(stderr, "VOX_GG_METAL_SHADER_LIBRARIES submitted=%zu off_thread=%zu valid=%zu reused=%zu ready=%zu\n",
            batch->count, off_thread, valid, batch->reused, batch->ready);
    }
    batch->count = batch->reused = batch->ready = 0;
    _SG_OBJC_RELEASE(batch->options);
}

static id<MTLLibrary> vox_gg_metal_compile_vertex_source(const sg_shader_desc *desc) {
    VoxGGMetalShaderLibrary *prepared = desc->label ? NULL : vox_gg_metal_prepared_shader_library(desc->vs.source);
    return prepared ? vox_gg_metal_read_shader_library(prepared) : _sg_mtl_compile_library(desc->vs.source);
}

static void vox_gg_metal_compile_shader_sources(const sg_shader_desc *desc,
    id<MTLLibrary> __strong *vertex, id<MTLLibrary> __strong *fragment) {
    // GG canvas explicitly selects MSL options. Other Sokol users retain
    // their original compilation schedule.
    if (!_sg_v_mtl_compile_options.language_major
        || getenv("VOX_SERIAL_GG_METAL_SHADERS")) {
        *vertex = _sg_mtl_compile_library(desc->vs.source);
        *fragment = _sg_mtl_compile_library(desc->fs.source);
        return;
    }
    if (!desc->label) {
        VoxGGMetalShaderLibrary *vs = vox_gg_metal_prepared_shader_library(desc->vs.source);
        VoxGGMetalShaderLibrary *fs = vox_gg_metal_prepared_shader_library(desc->fs.source);
        if (vs || fs) {
            *vertex = vs ? vox_gg_metal_read_shader_library(vs) : _sg_mtl_compile_library(desc->vs.source);
            *fragment = fs ? vox_gg_metal_read_shader_library(fs) : _sg_mtl_compile_library(desc->fs.source);
            return;
        }
    }

    // Only the Metal compiler sees the worker inputs. Sokol's compile
    // options, error logger and resource pool are accessed on the owner.
    id<MTLDevice> device = _sg.mtl.device;
    MTLCompileOptions *options = _sg_v_mtl_new_compile_options();
    const char *source = desc->fs.source;
    dispatch_group_t group = dispatch_group_create();
    bool diagnostics = getenv("VOX_GG_METAL_SHADER_DIAGNOSTICS") != NULL;
    pthread_t caller = diagnostics ? pthread_self() : NULL;
    __block id<MTLLibrary> library = nil;
    __block NSError *failure = nil;
    __block bool off_thread = false;
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSError *error = nil;
            library = [device newLibraryWithSource:[NSString stringWithUTF8String:source]
                options:options error:&error];
            failure = error;
            _SG_OBJC_RETAIN(failure);
            if (diagnostics) off_thread = !pthread_equal(caller, pthread_self());
        }
    });
    *vertex = _sg_mtl_compile_library(desc->vs.source);
    bool ready = diagnostics && dispatch_group_wait(group, DISPATCH_TIME_NOW) == 0;
    if (!ready) dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    *fragment = library;
    if (failure) {
        _SG_ERROR(METAL_SHADER_COMPILATION_FAILED);
        _SG_LOGMSG(METAL_SHADER_COMPILATION_OUTPUT, [failure.localizedDescription UTF8String]);
        _SG_OBJC_RELEASE(failure);
    }
    if (diagnostics) {
        fprintf(stderr, "VOX_GG_METAL_SHADER_PAIR off_thread=%d ready_at_join=%d vertex=%d fragment=%d\n",
            off_thread, ready, *vertex != nil, *fragment != nil);
    }
    _SG_OBJC_RELEASE(options);
    _SG_OBJC_RELEASE(group);
}
