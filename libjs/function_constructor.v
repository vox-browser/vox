// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/FunctionConstructor.cpp. Dynamic functions use the translated
// frontend and ordinary bytecode/native cache, with a global defining scope.
@[heap]
pub struct FunctionConstructor {
pub:
	object &Object
}

pub fn FunctionConstructor.create(mut vm VM, realm &Realm) &FunctionConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		function_constructor_call, function_constructor_construct, PropertyName.from_str('Function'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(realm.function_prototype_record()), 0)
	object.set_function_length(1)
	object.set_function_name(mut vm, PropertyName.from_str('Function'), none)
	return &FunctionConstructor{ object: object }
}

fn function_constructor_call(mut vm VM) !Value {
	constructor := vm.realm().function_constructor or { return error('Missing Function intrinsic') }
	return Value.from_object(function_constructor_construct(mut vm, constructor)!)
}

fn dynamic_function_source(parameters string, body string) string {
	return '(function anonymous(' + parameters + '\n) {\n' + body + '\n})'
}

fn parse_dynamic_function(mut vm VM, source string) !(&Script, FunctionId) {
	script := Script.parse(source, vm.realm(), 'anonymous', unsafe { nil }) or {
		return vm.throw_error(.syntax_error, err.msg())
	}
	program := script.parsed.program.kind.program_data or { return error('Missing dynamic function program') }
	if program.scope.children.len != 1 {
		return vm.throw_error(.syntax_error, 'Invalid dynamic function source')
	}
	statement := program.scope.children[0]
	expression := statement.kind.expression or { return vm.throw_error(.syntax_error, 'Invalid dynamic function source') }
	if expression.kind.tag != .function_expr {
		return vm.throw_error(.syntax_error, 'Invalid dynamic function source')
	}
	id := expression.kind.function_id
	data := script.parsed.function_table.get(id)
	// Reject parameter/body strings that escape their separate grammar goals.
	if data.source_text_start != 1 || data.source_text_end != u32(utf16_string(source).len() - 1) {
		return vm.throw_error(.syntax_error, 'Invalid dynamic function boundary')
	}
	return script, id
}

fn function_constructor_construct(mut vm VM, new_target &Object) !&Object {
	mut parameter_args := []Value{}
	mut parameter_strings := []Utf16String{}
	mut parameter_texts := []string{}
	count := int(vm.argument_count())
	for index in 0 .. if count > 0 { count - 1 } else { 0 } {
		argument := vm.argument(u32(index))
		text := argument.to_primitive_string(mut vm)!.utf16
		parameter_args << argument
		parameter_strings << text
		parameter_texts << text.str()
	}
	body_arg := if count > 0 {
		vm.argument(u32(count - 1))
	} else {
		Value.from_string(vm.create_string_from_str(''))
	}
	body_string := body_arg.to_primitive_string(mut vm)!.utf16
	parameters := parameter_texts.join(',')
	source := dynamic_function_source(parameters, body_string.str())
	vm.host_ensure_can_compile_strings(vm.realm(), parameter_strings, body_string,
		utf16_string(source[1..source.len - 1]), .function, parameter_args, body_arg)!
	parse_dynamic_function(mut vm, dynamic_function_source(parameters, ''))!
	parse_dynamic_function(mut vm, dynamic_function_source('', body_string.str()))!
	mut script, id := parse_dynamic_function(mut vm, source)!
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object {
		return realm.function_prototype_record()
	})!
	executable := script.compile(mut vm)!
	data := script.parsed.function_table.get(id)
	mut object := create_ecmascript_function_in_environment(mut vm, executable, data, false, utf16_string('anonymous'), true,
		Environment(vm.realm().global_environment_record()), none, vm.get_active_script_or_module())!
	object.internal_set_prototype_of(prototype)
	return object
}
