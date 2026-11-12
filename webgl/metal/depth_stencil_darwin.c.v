module metal

#include "@DIR/depth_stencil_darwin.h"
fn C.vox_metal_depth_stencil_create(voidptr, i32, i32) voidptr
fn C.vox_metal_depth_stencil_destroy(voidptr)
fn C.vox_metal_depth_stencil_clear(voidptr, f64, u32) i32

fn C.vox_metal_depth_stencil_from_textures(voidptr,voidptr) voidptr
fn C.vox_metal_depth_stencil_view(voidptr,i32,&u32) voidptr
