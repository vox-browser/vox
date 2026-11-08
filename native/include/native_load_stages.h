#ifndef VOX_NATIVE_LOAD_STAGES_H
#define VOX_NATIVE_LOAD_STAGES_H
#include <stdint.h>
#include "../../platform/native_state.h"

// Installed only for the opt-in diagnostic. V owns identities and restores
// its JavaScript nesting state across the native boundary.
typedef uint64_t (*VoxNativeLoadStageBegin)(const char *);
typedef void (*VoxNativeLoadStageFinish)(uint64_t);
VOX_NATIVE_STATE VoxNativeLoadStageBegin vox_native_load_stage_begin;
VOX_NATIVE_STATE VoxNativeLoadStageFinish vox_native_load_stage_finish;

typedef struct {
    uint64_t token;
    VoxNativeLoadStageFinish finish;
} VoxNativeLoadStage;

static void native_set_load_stage_callbacks(VoxNativeLoadStageBegin begin,
    VoxNativeLoadStageFinish finish) {
    vox_native_load_stage_begin = begin;
    vox_native_load_stage_finish = finish;
}

static VoxNativeLoadStage native_begin_load_stage(const char *label) {
    if (!vox_native_load_stage_begin || !vox_native_load_stage_finish)
        return (VoxNativeLoadStage){0};
    return (VoxNativeLoadStage){vox_native_load_stage_begin(label),
        vox_native_load_stage_finish};
}

static void native_finish_load_stage(VoxNativeLoadStage stage) {
    if (stage.token) stage.finish(stage.token);
}
#endif
