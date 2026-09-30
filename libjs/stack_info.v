module libjs

// Translated from AK/StackInfo.{h,cpp}: the native thread stack bounds used by
// VM.did_reach_stack_space_limit().

pub struct StackInfo {
pub:
	base usize
	top  usize
	size usize
}

pub fn StackInfo.new() StackInfo {
	base, size := native_stack_bounds()
	return StackInfo{
		base: base
		top:  base + size
		size: size
	}
}

// size_free reports the bytes between the current stack pointer and the base.
pub fn (info StackInfo) size_free() usize {
	pointer := current_stack_pointer()
	if pointer <= info.base || pointer > info.top {
		// Called from another thread than the one the VM was created on.
		return 0
	}
	return pointer - info.base
}
