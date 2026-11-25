// Included inside the staged Sokol Metal implementation.
#include "../../platform/native_state.h"
#include <pthread.h>

enum { VOX_GG_METAL_PIPELINE_BATCH_CAPACITY = 64 };

typedef struct {
    _sg_pipeline_t *pipeline;
    uint32_t slot_id;
    MTLRenderPipelineDescriptor *descriptor;
    id<MTLRenderPipelineState> render;
    id<MTLDepthStencilState> depth;
    NSError *error;
    bool off_thread;
} VoxGGMetalPipelineCompile;

// The drawing thread owns the batch and the Sokol slots. Each Metal
// completion writes only to its own job until the group has joined.
typedef struct {
    dispatch_group_t group;
    size_t count;
    pthread_t owner;
    VoxGGMetalPipelineCompile jobs[VOX_GG_METAL_PIPELINE_BATCH_CAPACITY];
} VoxGGMetalPipelineBatch;

VOX_NATIVE_STATE VoxGGMetalPipelineBatch vox_gg_metal_pipeline_batch;

#define VOX_GG_METAL_PIPELINE_PENDING(pip) \
    ((pip)->slot.state == SG_RESOURCESTATE_ALLOC && vox_gg_metal_pipeline_batch.group != NULL)

bool vox_gg_metal_begin_pipeline_batch(void) {
    const char *enabled = getenv("VOX_PARALLEL_GG_METAL_PIPELINES");
    if (vox_gg_metal_pipeline_batch.group || !_sg.valid
        || !enabled || strcmp(enabled, "1") != 0) return false;
    vox_gg_metal_pipeline_batch.group = dispatch_group_create();
    vox_gg_metal_pipeline_batch.owner = getenv("VOX_GG_METAL_PIPELINE_DIAGNOSTICS")
        ? pthread_self() : NULL;
    return true;
}

static sg_resource_state vox_gg_metal_publish_pipeline(_sg_pipeline_t *pipeline,
    id<MTLRenderPipelineState> render, id<MTLDepthStencilState> depth, NSError *error) {
    if (!render) {
        _SG_ERROR(METAL_CREATE_RPS_FAILED);
        _SG_LOGMSG(METAL_CREATE_RPS_OUTPUT, [error.localizedDescription UTF8String]);
        return SG_RESOURCESTATE_FAILED;
    }
    if (!depth) {
        _SG_ERROR(METAL_CREATE_DSS_FAILED);
        return SG_RESOURCESTATE_FAILED;
    }
    pipeline->mtl.rps = _sg_mtl_add_resource(render);
    pipeline->mtl.dss = _sg_mtl_add_resource(depth);
    return SG_RESOURCESTATE_VALID;
}

static sg_resource_state vox_gg_metal_create_pipeline_states(_sg_pipeline_t *pipeline,
    MTLRenderPipelineDescriptor *render, MTLDepthStencilDescriptor *depth) {
    id<MTLDevice> device = _sg.mtl.device;
    dispatch_group_t group = vox_gg_metal_pipeline_batch.group;
    if (group && vox_gg_metal_pipeline_batch.count < VOX_GG_METAL_PIPELINE_BATCH_CAPACITY) {
        VoxGGMetalPipelineCompile *job =
            &vox_gg_metal_pipeline_batch.jobs[vox_gg_metal_pipeline_batch.count++];
        job->pipeline = pipeline;
        job->slot_id = pipeline->slot.id;
        job->descriptor = render;
        pthread_t owner = vox_gg_metal_pipeline_batch.owner;
        dispatch_group_enter(group);
        [device newRenderPipelineStateWithDescriptor:render
            completionHandler:^(id<MTLRenderPipelineState> state, NSError *error) {
                job->render = state;
                job->error = error;
                _SG_OBJC_RETAIN(state);
                _SG_OBJC_RETAIN(error);
                job->off_thread = owner && !pthread_equal(owner, pthread_self());
                dispatch_group_leave(group);
            }];
        job->depth = [device newDepthStencilStateWithDescriptor:depth];
        _SG_OBJC_RELEASE(depth);
        return SG_RESOURCESTATE_ALLOC;
    }

    NSError *error = nil;
    id<MTLRenderPipelineState> state = [device newRenderPipelineStateWithDescriptor:render error:&error];
    id<MTLDepthStencilState> stencil = state ? [device newDepthStencilStateWithDescriptor:depth] : nil;
    sg_resource_state result = vox_gg_metal_publish_pipeline(pipeline, state, stencil, error);
    _SG_OBJC_RELEASE(render);
    _SG_OBJC_RELEASE(depth);
    _SG_OBJC_RELEASE(state);
    _SG_OBJC_RELEASE(stencil);
    return result;
}

void vox_gg_metal_end_pipeline_batch(void) {
    dispatch_group_t group = vox_gg_metal_pipeline_batch.group;
    if (!group) return;
    bool diagnostics = vox_gg_metal_pipeline_batch.owner != NULL;
    bool ready = diagnostics && dispatch_group_wait(group, DISPATCH_TIME_NOW) == 0;
    if (!ready) dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    size_t count = vox_gg_metal_pipeline_batch.count;
    size_t off_thread = 0, valid = 0;
    for (size_t index = 0; index < count; ++index) {
        VoxGGMetalPipelineCompile *job = &vox_gg_metal_pipeline_batch.jobs[index];
        _sg_pipeline_t *pipeline = job->pipeline;
        // A destroyed slot may already have been reused for another pipeline.
        if (pipeline->slot.id == job->slot_id && pipeline->slot.state == SG_RESOURCESTATE_ALLOC) {
            pipeline->slot.state = vox_gg_metal_publish_pipeline(pipeline, job->render, job->depth, job->error);
            valid += pipeline->slot.state == SG_RESOURCESTATE_VALID;
        }
        off_thread += job->off_thread;
        _SG_OBJC_RELEASE(job->descriptor);
        _SG_OBJC_RELEASE(job->render);
        _SG_OBJC_RELEASE(job->depth);
        _SG_OBJC_RELEASE(job->error);
    }
    vox_gg_metal_pipeline_batch.count = 0;
    _SG_OBJC_RELEASE(vox_gg_metal_pipeline_batch.group);
    if (diagnostics) {
        fprintf(stderr, "VOX_GG_METAL_PIPELINE_BATCH submitted=%zu completed_off_thread=%zu valid=%zu ready_at_join=%d\n",
            count, off_thread, valid, ready);
    }
}
