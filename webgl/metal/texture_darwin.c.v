module metal

#include "@DIR/texture_darwin.h"
fn C.vox_metal_texture_create(voidptr, i32, i32) voidptr
fn C.vox_metal_texture_destroy(voidptr)
fn C.vox_metal_texture_sampler(voidptr, i32, i32, i32, i32) i32
fn C.vox_metal_texture_storage(voidptr, u32, u32, u32, u32, u32, u32, u32, u32) voidptr
fn C.vox_metal_texture_region(voidptr,u32,u32,u32,u32,u32,u32,u32,u32,u32,voidptr,u64,i32) i32
fn C.vox_metal_texture_attachment(voidptr,u32,u32) voidptr
fn C.vox_metal_texture_mipmaps(voidptr) i32
fn C.vox_metal_texture_set_sampler(voidptr,voidptr) i32
fn C.vox_metal_texture_copy(voidptr,u32,u32,u32,u32,u32,voidptr,u32,u32,u32,u32,u32,u32,u32,u32) i32
