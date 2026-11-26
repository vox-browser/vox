module libjs

// Parser lists gather their elements on a per-parser scratch stack and are
// copied once into an exact-size array. Grown from two slots by doubling,
// each list copied its elements again at every step and, with the prealloc
// arena, left every outgrown buffer behind; lists are short and their
// elements large (Statement 552, CallArgument 320, Expression 264 bytes).
// A nested list pushes above its enclosing list's elements and takes its
// own back before the enclosing list continues, so each list's elements stay
// contiguous from the mark it started at.
@[inline]
fn take_scratch_list[T](mut scratch []T, mark int) []T {
	result := scratch[mark..].clone()
	unsafe {
		scratch.len = mark
	}
	return result
}
