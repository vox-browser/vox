module libjs

// `array << value` is a helper call that checks capacity and copies the
// element bytes. Per-call stacks push one small element into existing
// capacity almost every time; only growth needs the helper.
@[inline]
fn push_within_capacity[T](mut values []T, value T) {
	if values.len < values.cap {
		unsafe {
			mut data := &T(values.data)
			data[values.len] = value
			values.len++
		}
		return
	}
	values << value
}

// array.last() followed by delete_last(), with one emptiness check.
@[inline]
fn pop_last[T](mut values []T, empty_message string) T {
	if values.len == 0 { panic(empty_message) }
	unsafe {
		values.len--
		return (&T(values.data))[values.len]
	}
}
