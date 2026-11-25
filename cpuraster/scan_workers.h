#ifndef VOX_CPU_RASTER_SCAN_WORKERS_H
#define VOX_CPU_RASTER_SCAN_WORKERS_H

#include <fenv.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#if defined(__APPLE__)
#include <dispatch/dispatch.h>
#else
#include <pthread.h>
#endif

typedef void (*VoxRasterScan)(void *, int32_t, int32_t);
#define VOX_SCAN_WORKERS_MAX 4

typedef struct {
    void *context;
    int32_t lines, lanes;
    VoxRasterScan scan;
    int rounding;
} VoxRasterScanBatch;

typedef struct {
    const VoxRasterScanBatch *batch;
    int32_t lane;
} VoxRasterScanWorker;

static bool vox_scan_workers_disabled(void) {
    const char *value = getenv("VOX_SERIAL_CPU_RASTER");
    return value && value[0] == '1' && value[1] == '\0';
}

static void vox_scan_worker_range(const VoxRasterScanBatch *batch, int32_t lane) {
    int32_t first = (int64_t)batch->lines * lane / batch->lanes;
    int32_t end = (int64_t)batch->lines * (lane + 1) / batch->lanes;
    // A reused OS worker may have a different floating-point environment.
    int saved_rounding = fegetround();
    if (saved_rounding != batch->rounding) fesetround(batch->rounding);
    batch->scan(batch->context, first, end);
    if (saved_rounding != batch->rounding) fesetround(saved_rounding);
}

#if defined(__APPLE__)
static void vox_scan_worker_dispatch(void *context, size_t lane) {
    vox_scan_worker_range(context, (int32_t)lane);
}

static void vox_scan_worker_joined_dispatch(void *context) {
    const VoxRasterScanWorker *worker = (const VoxRasterScanWorker *)context;
    vox_scan_worker_range(worker->batch, worker->lane);
}

// Submit the background ranges explicitly so the caller cannot execute them
// inline, including when dispatch_apply would keep a short batch on one lane.
static bool vox_scan_workers_with_caller(void *context, int32_t lines, int32_t lanes, VoxRasterScan scan) {
    dispatch_group_t group = dispatch_group_create();
    if (!group) return false;
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    VoxRasterScanBatch batch = {context, lines, lanes, scan, fegetround()};
    VoxRasterScanWorker workers[VOX_SCAN_WORKERS_MAX - 1];
    for (int32_t lane = 0; lane < lanes - 1; ++lane) {
        workers[lane] = (VoxRasterScanWorker){&batch, lane};
        dispatch_group_async_f(group, queue, &workers[lane], vox_scan_worker_joined_dispatch);
    }
    vox_scan_worker_range(&batch, lanes - 1);
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#if !__has_feature(objc_arc)
    dispatch_release(group);
#endif
    return true;
}

typedef struct {
    VoxRasterScanBatch batch;
    void *group;
    VoxRasterScanWorker workers[VOX_SCAN_WORKERS_MAX];
} VoxRasterBackgroundScan;

static void *vox_scan_worker_start(void *context, int32_t lines, int32_t lanes, VoxRasterScan scan) {
    VoxRasterBackgroundScan *work = (VoxRasterBackgroundScan *)malloc(sizeof *work);
    if (!work) return NULL;
    dispatch_group_t group = dispatch_group_create();
    if (!group) {
        free(work);
        return NULL;
    }
#if __has_feature(objc_arc)
    work->group = (__bridge_retained void *)group;
#else
    work->group = (void *)group;
#endif
    work->batch = (VoxRasterScanBatch){context, lines, lanes, scan, fegetround()};
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    for (int32_t lane = 0; lane < lanes; ++lane) {
        work->workers[lane] = (VoxRasterScanWorker){&work->batch, lane};
        dispatch_group_async_f(group, queue, &work->workers[lane], vox_scan_worker_joined_dispatch);
    }
    return work;
}

static bool vox_scan_worker_join(void *ticket) {
    VoxRasterBackgroundScan *work = (VoxRasterBackgroundScan *)ticket;
#if __has_feature(objc_arc)
    dispatch_group_t group = (__bridge_transfer dispatch_group_t)work->group;
#else
    dispatch_group_t group = (dispatch_group_t)work->group;
#endif
    bool ready = dispatch_group_wait(group, DISPATCH_TIME_NOW) == 0;
    if (!ready) dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#if !__has_feature(objc_arc)
    dispatch_release(group);
#endif
    free(work);
    return ready;
}
#else
static void *vox_scan_worker_thread(void *context) {
    const VoxRasterScanWorker *worker = context;
    vox_scan_worker_range(worker->batch, worker->lane);
    return NULL;
}
#endif

static void vox_scan_workers_run(void *context, int32_t lines, int32_t lanes, VoxRasterScan scan) {
    VoxRasterScanBatch batch = {context, lines, lanes, scan, fegetround()};
#if defined(__APPLE__)
    dispatch_apply_f((size_t)lanes, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),
        &batch, vox_scan_worker_dispatch);
#else
    // If a worker cannot be started, run its disjoint range on the caller.
    pthread_t threads[VOX_SCAN_WORKERS_MAX - 1];
    VoxRasterScanWorker workers[VOX_SCAN_WORKERS_MAX - 1];
    int32_t started = 0;
    for (int32_t lane = 1; lane < lanes; ++lane) {
        workers[started] = (VoxRasterScanWorker){&batch, lane};
        if (pthread_create(&threads[started], NULL, vox_scan_worker_thread, &workers[started]) == 0)
            ++started;
        else
            vox_scan_worker_range(&batch, lane);
    }
    vox_scan_worker_range(&batch, 0);
    for (int32_t worker = 0; worker < started; ++worker)
        pthread_join(threads[worker], NULL);
#endif
}

#endif
