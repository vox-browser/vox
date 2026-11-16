module libjs

$if test {
	__global borrowed_call_arguments_disabled bool
	__global borrowed_call_arguments_diagnostic bool
	__global borrowed_call_arguments_count u64
	pub fn set_borrowed_call_arguments_for_testing(enabled bool) { borrowed_call_arguments_disabled = !enabled }
	pub fn diagnose_borrowed_call_arguments_for_testing(enabled bool) u64 {
		previous := borrowed_call_arguments_count
		borrowed_call_arguments_count = 0
		borrowed_call_arguments_diagnostic = enabled
		return previous
	}
}

fn can_borrow_call_arguments(value Value) bool {
	$if test { if borrowed_call_arguments_disabled { return false } }
	if !value.is_object() { return false }
	object := value.as_object()
	if object.proxy_object != none { return false }
	callable := object.callable or { return false }
	eligible := if callable is NativeFunction { true }
		else if callable is ECMAScriptFunction { callable.data.kind == .normal }
		else { false }
	$if test { if eligible && borrowed_call_arguments_diagnostic { borrowed_call_arguments_count++ } }
	return eligible
}

// The caller owns and bounds the stack storage for the entire synchronous call.
// Only callees that copy the slice may receive it; no append/free is permitted.
@[unsafe]
fn borrow_argument_values(data &Value, count int) []Value {
	return array{ data: unsafe { data }, len: count, cap: count, element_size: int(sizeof(Value)) }
}
