module metal

#include "@DIR/gpu_buffer_darwin.h"

fn C.vox_metal_gpu_buffer_create(voidptr, u64) voidptr
fn C.vox_metal_gpu_buffer_destroy(voidptr)
fn C.vox_metal_gpu_buffer_transfer(voidptr, u64, u64, voidptr, i32) i32
