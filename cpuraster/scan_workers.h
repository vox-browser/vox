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
static bool vox_scan_workers_with_caller_range(void *context, int32_t lines, int32_t lanes,
    bool caller_first, VoxRasterScan scan) {
    dispatch_group_t group = dispatch_group_create();
    if (!group) return false;
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    VoxRasterScanBatch batch = {context, lines, lanes, scan, fegetround()};
    VoxRasterScanWorker workers[VOX_SCAN_WORKERS_MAX - 1];
    for (int32_t worker = 0; worker < lanes - 1; ++worker) {
        workers[worker] = (VoxRasterScanWorker){&batch, worker + caller_first};
        dispatch_group_async_f(group, queue, &workers[worker], vox_scan_worker_joined_dispatch);
    }
    vox_scan_worker_range(&batch, caller_first ? 0 : lanes - 1);
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#if !__has_feature(objc_arc)
    dispatch_release(group);
#endif
    return true;
}

static bool vox_scan_workers_with_caller(void *context, int32_t lines, int32_t lanes, VoxRasterScan scan) {
    return vox_scan_workers_with_caller_range(context, lines, lanes, false, scan);
}

typedef struct {
    VoxRasterScanBatch batch;
    void *groups[VOX_SCAN_WORKERS_MAX];
    int32_t group_count;
    VoxRasterScanWorker workers[VOX_SCAN_WORKERS_MAX];
} VoxRasterBackgroundScan;

// Consuming a group makes later reads of that range cheap. Only the ticket
// owner can wait for or release groups.
static bool vox_scan_worker_wait_group(VoxRasterBackgroundScan *work, int32_t slot) {
    if (!work->groups[slot]) return true;
#if __has_feature(objc_arc)
    dispatch_group_t group = (__bridge_transfer dispatch_group_t)work->groups[slot];
#else
    dispatch_group_t group = (dispatch_group_t)work->groups[slot];
#endif
    work->groups[slot] = NULL;
    bool ready = dispatch_group_wait(group, DISPATCH_TIME_NOW) == 0;
    if (!ready) dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#if !__has_feature(objc_arc)
    dispatch_release(group);
#endif
    return ready;
}

static void *vox_scan_worker_start(void *context, int32_t lines, int32_t lanes, bool by_range,
    VoxRasterScan scan) {
    VoxRasterBackgroundScan *work = (VoxRasterBackgroundScan *)malloc(sizeof *work);
    if (!work) return NULL;
    work->group_count = by_range ? lanes : 1;
    for (int32_t slot = 0; slot < work->group_count; ++slot) {
        dispatch_group_t group = dispatch_group_create();
        if (!group) {
            for (int32_t created = 0; created < slot; ++created) vox_scan_worker_wait_group(work, created);
            free(work);
            return NULL;
        }
#if __has_feature(objc_arc)
        work->groups[slot] = (__bridge_retained void *)group;
#else
        work->groups[slot] = (void *)group;
#endif
    }
    work->batch = (VoxRasterScanBatch){context, lines, lanes, scan, fegetround()};
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    for (int32_t lane = 0; lane < lanes; ++lane) {
        work->workers[lane] = (VoxRasterScanWorker){&work->batch, lane};
#if __has_feature(objc_arc)
        dispatch_group_t group = (__bridge dispatch_group_t)work->groups[by_range ? lane : 0];
#else
        dispatch_group_t group = (dispatch_group_t)work->groups[by_range ? lane : 0];
#endif
        dispatch_group_async_f(group, queue, &work->workers[lane], vox_scan_worker_joined_dispatch);
    }
    return work;
}

static bool vox_scan_worker_wait_index(void *ticket, int32_t index) {
    VoxRasterBackgroundScan *work = (VoxRasterBackgroundScan *)ticket;
    // Invert the floor division used by vox_scan_worker_range().
    int32_t slot = ((int64_t)(index + 1) * work->group_count - 1) / work->batch.lines;
    return vox_scan_worker_wait_group(work, slot);
}

static bool vox_scan_worker_join(void *ticket) {
    VoxRasterBackgroundScan *work = (VoxRasterBackgroundScan *)ticket;
    bool ready = true;
    for (int32_t slot = 0; slot < work->group_count; ++slot)
        ready &= vox_scan_worker_wait_group(work, slot);
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
