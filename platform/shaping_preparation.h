#ifndef VOX_SHAPING_PREPARATION_H
#define VOX_SHAPING_PREPARATION_H
#include "native_state.h"

VOX_NATIVE_STATE _Thread_local void *vox_ascii_shape_batch;

static inline void *vox_ascii_shape_batch_get(void)
{
    return vox_ascii_shape_batch;
}

static inline void vox_ascii_shape_batch_set(void *batch)
{
    vox_ascii_shape_batch = batch;
}

#endif
