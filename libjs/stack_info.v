module libjs

#include "@DIR/stack_info_host.h"

fn C.vox_ak_current_frame_address() uint

// Translated from AK/StackInfo.{h,cpp}: the native thread stack bounds used by
// VM.did_reach_stack_space_limit().

pub struct StackInfo {
pub:
	base uint
	top  uint
	size uint
}

pub fn StackInfo.new() StackInfo {
	base, size := native_stack_bounds()
	return StackInfo{
		base: base
		top:  base + size
		size: size
	}
}

// AK/StackInfo.h reads the current frame address and subtracts the owned base.
pub fn (info StackInfo) size_free() uint {
	pointer := C.vox_ak_current_frame_address()
	return pointer - info.base
}
