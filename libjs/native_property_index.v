module libjs

$if test {
	__global native_indices_disabled bool
	pub fn set_native_indices_for_testing(enabled bool) { native_indices_disabled = !enabled }
}

fn use_native_indices() bool {
	$if test { if native_indices_disabled { return false } }
	return true
}

fn native_index_helpers() string {
	sample := NativeInvocation{vm: unsafe { nil }, executable: unsafe { nil }}
	offset := uint(&sample.property_index_step) - uint(&sample)
	return 'typedef uint8_t (*IndexRead)(void*,void*,void*,void*);
_Static_assert(sizeof(IndexRead)==${sizeof(voidptr)}, "Index callback size");
static int property_index(void *state,void *plan,void *values,NV *out) {
 IndexRead fn; memcpy(&fn,(char*)state+${offset},sizeof(fn));
 return fn && fn(state,plan,values,out);
}'
}

fn native_index_instruction(instruction Instruction, executable &Executable, pc u32) string {
	if !use_native_indices() || instruction.op != .get_property { return '' }
	kind := instruction.rhs.operand_type() or { return '' }
	if kind == .constant {
		index := instruction.rhs.index()
		if index >= u32(executable.constants.len) || !executable.constants[index].is_number() { return '' }
	}
	plan := native_property_plan(instruction, executable, pc) or { return '' }
	dst := instruction.dst.slot(executable, 0, true) or { return '' }
	return '{ static const uint32_t plan[]={${plan}}; NV result; if(!property_index(state,(void*)plan,v,&result)) goto SLOW; BUDGET v[${dst}]=result; }'
}

// Only live own data cells qualify. Holes, inherited values, accessors, proxies
// and every exotic provider go through the ordinary property machinery.
fn native_index_read(opaque voidptr, opaque_plan voidptr, values voidptr, output voidptr) u8 {
	if !use_native_indices() || !use_native_property_reads() || !use_direct_property_reads() { return 0 }
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
	if !right.is_number() || !left.is_object() { return 0 }
	number := right.number
	if !(number >= 0 && number < f64(0xffffffff)) { return 0 }
	index := u32(number)
	if f64(index) != number { return 0 }
	object := left.as_object()
	if object.proxy_object != none || object.host_properties != none || object.typed_array != none
		|| object.string_object != none || object.arguments_object != none || object.legacy_platform_object != none { return 0 }
	key := PropertyName.from_number(index)
	position := native_index_position(object, key)
	if position < 0 { return 0 }
	value := object.properties[position].value
	if value.is_accessor() { return 0 }
	unsafe { *(&Value(output)) = value }
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.native_index_steps++ }
	}
	return 1
}

fn native_index_position(object &Object, key PropertyName) int {
	if object.properties.len < property_lookup_hint_minimum { return object.find_own_property_linear(key) }
	// Reuse an existing hint, validating its live key. A miss falls back instead
	// of allocating a hint table in this nonthrowing native operation.
	$if test { if property_lookup_hints_disabled_for_test { return -1 } }
	if hints := object.property_lookup_hints {
		if position := hints.positions[property_lookup_hash(key)] {
			if position >= 0 && position < object.properties.len && object.properties[position].key.equals(key) {
				$if test { if property_lookup_hints_diagnostic_for_test { property_lookup_hint_hits_for_test++ } }
				return position
			}
		}
	}
	return -1
}
