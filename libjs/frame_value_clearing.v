module libjs

$if test {
	__global direct_frame_clears_disabled bool
	__global direct_frame_clears_diagnostics bool
	__global direct_frame_clears u64
	pub fn set_direct_frame_clears_for_testing(enabled bool) {
		direct_frame_clears_disabled = !enabled
	}
	pub fn diagnose_direct_frame_clears_for_testing(enabled bool) u64 {
		previous := direct_frame_clears
		direct_frame_clears = 0
		direct_frame_clears_diagnostics = enabled
		return previous
	}
}

fn use_direct_frame_clears() bool {
	$if test {
		if direct_frame_clears_disabled { return false }
	}
	return true
}

fn (mut context ExecutionContext) clear_reused_values() {
	if context.values.len == 0 { return }
	// Retain the ordinary first write, including V's storage uniqueness check.
	// No callback or array mutation occurs before the remaining bounded stores.
	context.values[0] = js_undefined()
	values := unsafe { &Value(context.values.data) }
	for index in 1 .. context.values.len {
		unsafe { values[index] = js_undefined() }
	}
	$if test {
		if direct_frame_clears_diagnostics { direct_frame_clears++ }
	}
}
