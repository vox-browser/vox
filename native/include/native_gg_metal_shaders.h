// Staged inside Sokol's Metal backend after _sg_mtl_compile_library.
#include <pthread.h>

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
