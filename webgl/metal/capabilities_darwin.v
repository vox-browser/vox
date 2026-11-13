module metal

#include "@DIR/capabilities_darwin.h"
fn C.vox_metal_device_sample_mask(voidptr) u32

pub fn (target &DrawingBuffer) sample_counts() []int {
    mask:=C.vox_metal_device_sample_mask(target.handle)
    mut result:=[]int{}
    for count in [8,4,2,1] { if mask & (u32(1)<<count)!=0 { result<<count } }
    return result
}

fn C.vox_metal_device_float_filtering(voidptr) i32
pub fn (target &DrawingBuffer) supports_float_filtering() bool { return C.vox_metal_device_float_filtering(target.handle)==1 }
