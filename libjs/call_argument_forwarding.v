module libjs

$if test {
	__global call_argument_forwarding_disabled bool
	pub fn set_call_argument_forwarding_for_testing(enabled bool) {
		call_argument_forwarding_disabled = !enabled
	}
}

// Function.prototype.call's frame owns this tail for the entire synchronous
// call. Only the existing concrete copying callees may borrow it; custom,
// proxy, bound and suspending implementations retain the owning-slice path.
fn (mut vm VM) forwarded_call_arguments(target Value) ?[]Value {
	$if test { if call_argument_forwarding_disabled { return none } }
	frame := vm.current_context()
	count := int(frame.argument_count)
	if count <= 1 || count > frame.values.len || !can_borrow_call_arguments(target) { return none }
	start := frame.arguments_offset() + 1
	if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.forwarded_call_slices++ } }
	return unsafe { borrow_argument_values(&frame.values[start], count - 1) }
}
