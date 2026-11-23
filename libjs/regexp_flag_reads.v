module libjs

$if test {
	__global intrinsic_regexp_flags_disabled bool
	pub fn set_intrinsic_regexp_flags_for_testing(enabled bool) {
		intrinsic_regexp_flags_disabled = !enabled
	}
}

fn use_intrinsic_regexp_flags() bool {
	$if test {
		if intrinsic_regexp_flags_disabled { return false }
	}
	return true
}

// The eight observable Get operations still run in order. Only the immutable
// spelling is shared; values and overridden accessors are never cached.
const regexp_flag_spellings = make_regexp_flag_spellings()

fn make_regexp_flag_spellings() [256]string {
	mut result := [256]string{}
	for bits in 0 .. 256 {
		mut spelling := ''
		for index, character in 'dgimsuvy' {
			if bits & (1 << index) != 0 { spelling += character.ascii_str() }
		}
		result[bits] = spelling
	}
	return result
}

// The ordinary lookup has already selected this exact getter, including any
// proxy/host lookup hooks. A branded intrinsic flag getter on a real RegExp
// reads one immutable internal slot and cannot invoke author code. Keep the
// ordinary call for incompatible receivers, prototype special cases and stack
// exhaustion, so those errors retain their native frame and realm.
fn (mut vm VM) intrinsic_regexp_flag_value(getter Value, receiver Value) ?Value {
	if !use_intrinsic_regexp_flags() || !receiver.is_object() { return none }
	object := receiver.as_object()
	regex := object.regexp_object or { return none }
	if !getter.is_function() { return none }
	function := getter.as_function()
	if function is NativeFunction {
		flag := function.intrinsic_regexp_flag or { return none }
		if prototype := function.realm_.regexp_prototype {
			if voidptr(prototype) == voidptr(object) { return none }
		}
		if vm.did_reach_stack_space_limit() { return none }
		stack := vm.interpreter_stack()
		if stack.top_ + frame_size_in_bytes(0) > stack.limit { return none }
		if mut tier := vm.native_tier {
			if tier.diagnostics { tier.activity.regexp_flag_getter_reads++ }
		}
		return Value.from_bool(regex.flags.has(flag))
	}
	return none
}
