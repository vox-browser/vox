module libjs

import math

$if test {
	__global internal_regexp_replace_results_disabled bool
	pub fn set_internal_regexp_replace_results_for_testing(enabled bool) {
		internal_regexp_replace_results_disabled = !enabled
	}
}

// RegExpExec's intrinsic result is not exposed by @@replace. Keep its captures
// in an internal record instead of constructing an ordinary JavaScript array
// which is immediately read back. Custom exec results retain every Get/coercion.
struct RegExpReplaceResult {
	matched bool
	object ?&Object
	values []Value
	position uint
	groups Value = js_undefined()
}

struct RegExpReplaceParts {
	matched &PrimitiveString
	position uint
	captures []Value
	named Value
}

fn (mut regex RegExpObject) builtin_replace_result(mut vm VM, text &PrimitiveString) !RegExpReplaceResult {
	slots := regex.builtin_exec_slots(mut vm, text, true)!
	if slots.len == 0 { return RegExpReplaceResult{} }
	mut values := []Value{cap: slots.len / 2}
	for index := 0; index < slots.len; index += 2 {
		values << if slots[index] < 0 { js_undefined() } else {
			Value.from_string(vm.create_string(utf16_string_from_code_units(text.utf16.data[int(slots[index])..int(slots[index + 1])])))
		}
	}
	mut groups := js_undefined()
	if regex.engine.program.named_groups.len > 0 {
		mut named := Object.create(vm.realm(), none)
		for group in regex.engine.program.named_groups {
			key := PropertyName.from_str(group.name)
			if !named.has_own_property(key) || named.get(mut vm, key)!.is_undefined() {
				named.create_data_property_or_throw(mut vm, key, values[int(group.index)])!
			}
		}
		groups = Value.from_object(named)
	}
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.regexp_replace_results++ }
	}
	return RegExpReplaceResult{matched: true, values: values, position: uint(slots[0]), groups: groups}
}

fn ordinary_replace_result(result Value) RegExpReplaceResult {
	return if result.is_null() { RegExpReplaceResult{} } else {
		RegExpReplaceResult{matched: true, object: result.as_object()}
	}
}

// This is the same native call boundary as NativeFunction.call_in_frame, with
// a typed internal return. In particular, budget failures and incompatible
// receivers see the original exec function, realm, arguments and stack frame.
fn (mut function NativeFunction) call_replace_exec_in_frame(mut vm VM, object &Object, text &PrimitiveString) !RegExpReplaceResult {
	caller := vm.current_context()
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut callee := stack.allocate_reusable(0, []Value{}, 1) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	callee.copy_call_arguments([Value.from_string(text)])
	callee.passed_argument_count = 1
	callee.function = FunctionObject(&function)
	callee.realm = function.realm_
	callee.this_value = Value.from_object(object)
	callee.call_environment = caller.call_environment
	callee.lexical_environment = caller.lexical_environment
	callee.variable_environment = caller.variable_environment
	callee.private_environment = caller.private_environment
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_current_context() }
	mut regex := regexp_receiver(mut vm)!
	return regex.builtin_replace_result(mut vm, text)
}

fn regexp_exec_for_replace(mut vm VM, object &Object, text &PrimitiveString) !RegExpReplaceResult {
	$if test {
		if internal_regexp_replace_results_disabled || builtin_profile_enabled {
			return ordinary_replace_result(regexp_exec(mut vm, object, text)!)
		}
	}
	exec := object.get(mut vm, PropertyName.from_str('exec'))!
	if exec.is_function() {
		mut function := exec.as_function()
		if mut function is NativeFunction {
			if function.intrinsic_regexp_exec {
				return function.call_replace_exec_in_frame(mut vm, object, text)
			}
		}
		result := call(mut vm, exec, Value.from_object(object), [Value.from_string(text)])!
		if !result.is_object() && !result.is_null() {
			return vm.throw_error(.type_error, 'RegExp exec must return an object or null')
		}
		return ordinary_replace_result(result)
	}
	mut regex := object.regexp_object or { return vm.throw_error(.type_error, 'RegExp exec requires RegExp internal slots') }
	return regex.builtin_replace_result(mut vm, text)
}

fn (result RegExpReplaceResult) match_text(mut vm VM) !&PrimitiveString {
	if object := result.object {
		return object.get(mut vm, PropertyName.from_number(0))!.to_primitive_string(mut vm)
	}
	return result.values[0].as_string()
}

fn (result RegExpReplaceResult) parts(mut vm VM, input_length uint) !RegExpReplaceParts {
	if object := result.object {
		length := length_of_array_like(mut vm, object)!
		count := if length == 0 { u64(0) } else { length - 1 }
		matched := object.get(mut vm, PropertyName.from_number(0))!.to_primitive_string(mut vm)!
		position := uint(math.min(math.max(object.get(mut vm, PropertyName.from_str('index'))!.to_integer_or_infinity(mut vm)!, 0), f64(input_length)))
		mut captures := []Value{}
		for index := u64(1); index <= count; index++ {
			vm.consume_execution_budget()!
			capture := object.get(mut vm, PropertyName.from_str(index.str()))!
			captures << if capture.is_undefined() { capture } else { Value.from_string(capture.to_primitive_string(mut vm)!) }
		}
		return RegExpReplaceParts{matched, position, captures, object.get(mut vm, PropertyName.from_str('groups'))!}
	}
	mut captures := []Value{cap: result.values.len - 1}
	for index in 1 .. result.values.len {
		vm.consume_execution_budget()!
		captures << result.values[index]
	}
	return RegExpReplaceParts{result.values[0].as_string(), result.position, captures, result.groups}
}
