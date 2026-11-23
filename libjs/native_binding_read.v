module libjs

$if test {
	__global native_binding_reads_disabled bool
	pub fn set_native_binding_reads_for_testing(enabled bool) { native_binding_reads_disabled = !enabled }
}

// Compiler ownership covers the stream through nested callbacks. Mutable and
// embedding-created streams keep the ordinary checked instruction dispatcher.
fn (vm &VM) native_binding_executable_owned(executable &Executable) bool {
	$if test { if native_binding_reads_disabled { return false } }
	if !use_compiler_validation() || !use_native_dynamic_dispatch() || !use_fast_binding_reads()
		|| !use_compact_reference_reads() || !use_direct_declarative_reads() { return false }
	owner := vm.compiler_validation_owner or { return false }
	validation := executable.compiler_validation or { return false }
	return voidptr(validation.owner) == voidptr(owner)
		&& validation.shape == executable.validation_shape(0)
		&& validation.instructions == executable.instructions.data
		&& validation.handlers == executable.exception_handlers.data
}

fn native_binding_helpers() string {
	sample := NativeInvocation{ vm: unsafe { nil }, executable: unsafe { nil } }
	offset := uint(&sample.binding_read_step) - uint(&sample)
	return 'typedef uint8_t (*BindingRead)(void*,void*,void*,void*);
static int binding_read(void *state,void *plan,void *values,NV *out) {
 BindingRead fn; memcpy(&fn,(char*)state+${offset},sizeof(fn));
 return fn && fn(state,plan,values,out);
}'
}

fn native_binding_instruction(instruction Instruction, executable &Executable, pc u32) string {
	if instruction.op !in [.get_binding, .get_callee_and_this] { return '' }
	dst := instruction.dst.slot(executable, 0, true) or { return '' }
	receiver := if instruction.op == .get_callee_and_this {
		instruction.rhs.slot(executable, 0, true) or { return '' }
	} else { u32(0) }
	callee := instruction.op == .get_callee_and_this
	store_receiver := if callee { 'v[${receiver}]=(NV){.tag=${int(ValueTag.undefined)}};' } else { '' }
	return '{ static const uint32_t plan[]={${pc},${instruction.identifier},${dst},${receiver},${int(callee)}}; NV result; if(!binding_read(state,(void*)plan,v,&result)) goto SLOW; BUDGET v[${dst}]=result; ${store_receiver} }'
}

fn native_binding_read(opaque voidptr, opaque_plan voidptr, values voidptr, output voidptr) u8 {
	invocation := unsafe { &NativeInvocation(opaque) }
	if invocation.binding_read_step == unsafe { nil } { return 0 }
	plan := unsafe { &u32(opaque_plan) }
	executable := invocation.executable
	mut vm := invocation.vm
	frame := vm.current_context()
	if frame.exposed || frame.values.data != values { return 0 }
	if unsafe { plan[0] >= u32(executable.instructions.len) || plan[1] >= u32(executable.identifier_table.len)
		|| plan[2] >= u32(frame.values.len) || (plan[4] != 0 && plan[3] >= u32(frame.values.len)) } { return 0 }
	name := executable.get_identifier(unsafe { plan[1] })
	value := vm.native_binding_value(name) or { return 0 }
	if value.is_special_empty_value() { return 0 }
	unsafe { *(&Value(output)) = value }
	return 1
}

fn (mut vm VM) record_native_binding_read(declarative bool) {
	if mut tier := vm.native_tier {
		if tier.diagnostics {
			tier.activity.native_binding_steps++
			tier.activity.compact_reference_reads++
			if declarative { tier.activity.direct_declarative_binding_reads++ }
		}
	}
}

// Concrete lexical records and ordinary own global data have no lookup hooks.
// With, proxies, host records, accessors, TDZ and missing names fall back before
// invoking author code. C charges a successful lookup exactly once; its zero-
// budget check runs before this callback.
fn (mut vm VM) native_binding_value(name Utf16String) ?Value {
	mut environment := vm.current_context().lexical_environment
	for {
		mut current := environment or { return none }
		if mut current is FunctionEnvironment {
			index := current.find_binding_index(name)
			if index >= 0 {
				binding := &current.bindings[index]
				if !binding.initialized || binding.value.is_special_empty_value() { return none }
				vm.record_native_binding_read(true)
				return binding.value
			}
		} else if mut current is DeclarativeEnvironment {
			index := current.find_binding_index(name)
			if index >= 0 {
				binding := &current.bindings[index]
				if !binding.initialized || binding.value.is_special_empty_value() { return none }
				vm.record_native_binding_read(true)
				return binding.value
			}
		} else if mut current is GlobalEnvironment {
			value := vm.own_global_data_binding(current, name) or { return none }
			if value.is_special_empty_value() { return none }
			vm.record_native_binding_read(false)
			return value
		} else { return none }
		environment = current.outer_environment()
	}
	return none
}
