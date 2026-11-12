module metal

#include "@DIR/texture_darwin.h"
fn C.vox_metal_texture_create(voidptr, i32, i32) voidptr
fn C.vox_metal_texture_destroy(voidptr)
fn C.vox_metal_texture_sampler(voidptr, i32, i32, i32, i32) i32
