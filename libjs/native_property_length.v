module libjs

$if test {
	__global native_lengths_disabled bool
	pub fn set_native_lengths_for_testing(enabled bool) { native_lengths_disabled = !enabled }
}

fn use_native_lengths() bool {
	$if test { if native_lengths_disabled { return false } }
	return true
}

fn native_length_helpers() string {
	sample := NativeInvocation{vm: unsafe { nil }, executable: unsafe { nil }}
	offset := uint(&sample.property_length_step) - uint(&sample)
	return 'typedef uint8_t (*LengthRead)(void*,void*,void*,double*);
_Static_assert(sizeof(LengthRead)==${sizeof(voidptr)}, "Length callback size");
static int property_length(void *state,void *plan,void *values,double *out) {
 LengthRead fn; memcpy(&fn,(char*)state+${offset},sizeof(fn));
 return fn && fn(state,plan,values,out);
}'
}

fn native_length_instruction(instruction Instruction, executable &Executable, pc u32) string {
	if !use_native_lengths() || instruction.op != .get_property { return '' }
	kind := instruction.rhs.operand_type() or { return '' }
	if kind != .constant { return '' }
	index := instruction.rhs.index()
	if index >= u32(executable.constants.len) { return '' }
	key := executable.constants[index]
	if !key.is_string() || !PropertyName.from_primitive_string(key.as_string()).is_length_property() { return '' }
	plan := native_property_plan(instruction, executable, pc) or { return '' }
	dst := instruction.dst.slot(executable, 0, true) or { return '' }
	return '{ static const uint32_t plan[]={${plan}}; double n; if(!property_length(state,(void*)plan,v,&n)) goto SLOW; BUDGET v[${dst}]=num(n); }'
}

// A nonthrowing, allocation-free guard/read. It invokes no user code and never
// consumes budget. Generated C charges a successful read once; every rejected
// read goes through the ordinary callback, including bounds/TDZ/budget errors.
fn native_length_read(opaque voidptr, opaque_plan voidptr, values voidptr, output &f64) u8 {
	if !use_native_lengths() || !use_native_property_reads() { return 0 }
	invocation := unsafe { &NativeInvocation(opaque) }
	executable := invocation.executable
	plan := unsafe { &u32(opaque_plan) }
	pc := unsafe { plan[0] }
	if pc >= u32(executable.instructions.len) { return 0 }
	instruction := &executable.instructions[pc]
	if instruction.op != .get_property || !native_property_layout_matches(executable, plan)
		|| instruction.lhs.raw != unsafe { plan[4] }
		|| instruction.rhs.raw != unsafe { plan[5] }
		|| instruction.dst.raw != unsafe { plan[6] } { return 0 }
	mut vm := invocation.vm
	frame := vm.current_context()
	if frame.values.data != values { return 0 }
	if unsafe { plan[1] >= u32(frame.values.len) || plan[2] >= u32(frame.values.len) || plan[3] >= u32(frame.values.len) } { return 0 }
	left := unsafe { (&Value(values))[plan[1]] }
	right := unsafe { (&Value(values))[plan[2]] }
	if !right.is_string() || !PropertyName.from_primitive_string(right.as_string()).is_length_property() { return 0 }
	mut length := f64(0)
	if left.is_string() {
		length = f64(left.as_string().utf16.data.len)
	} else if left.is_object() && use_direct_property_reads() {
		object := left.as_object()
		if object.proxy_object != none || object.host_properties != none || object.typed_array != none
			|| object.string_object != none || object.arguments_object != none || object.legacy_platform_object != none { return 0 }
		array := object.array_object or { return 0 }
		length = f64(array.length)
	} else { return 0 }
	unsafe { *output = length }
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.native_length_steps++ }
	}
	return 1
}
