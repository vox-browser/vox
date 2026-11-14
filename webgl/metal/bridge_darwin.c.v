module metal

#flag darwin -framework Metal -framework Foundation -framework CoreFoundation
#include "@DIR/drawing_buffer_darwin.h"

fn C.vox_metal_buffer_create() voidptr
fn C.vox_metal_buffer_destroy(voidptr)
fn C.vox_metal_buffer_resize(voidptr, i32, i32) i32
fn C.vox_metal_buffer_clear(voidptr, f64, f64, f64, f64) i32
fn C.vox_metal_buffer_transfer(voidptr, voidptr, u64, i32) i32
