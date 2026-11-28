module builtin

// Staged by tools/buildtools/runtime.v in place of V's fixed-array bounds
// checks. V builds the panic message inside these @[inline] functions, and
// clang declined to inline that body: on the archived github.com/vlang/v page
// the out-of-line v_fixed_index calls took 5.8% of the style pass samples.
// The message moves to cold helpers; each index keeps a compare and branch.

@[markused; noinline]
fn v_fixed_index_out_of_range(i i64, len int) {
	panic('fixed array index out of range (index: ' + i.str() + ', len: ' + i64(len).str() + ')')
}

@[markused; noinline]
fn v_fixed_index_u64_out_of_range(i u64, len int) {
	panic('fixed array index out of range (index: ' + i.str() + ', len: ' + i64(len).str() + ')')
}

@[inline; markused]
fn v_fixed_index(i int, len int) int {
	$if !no_bounds_checking {
		if i < 0 || i >= len {
			v_fixed_index_out_of_range(i64(i), len)
		}
	}
	return i
}

@[inline; markused]
fn v_fixed_index_i64(i i64, len int) int {
	$if !no_bounds_checking {
		if i < 0 || i >= i64(len) {
			v_fixed_index_out_of_range(i, len)
		}
	}
	return int(i)
}

@[inline; markused]
fn v_fixed_index_u64(i u64, len int) int {
	$if !no_bounds_checking {
		if i >= u64(len) {
			v_fixed_index_u64_out_of_range(i, len)
		}
	}
	return int(i)
}
