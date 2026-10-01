module libjs

fn run_function_intrinsic_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'function-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_default_numeric_and_uri_functions_inherit_call_apply_bind_and_to_string() {
	for source, expected in {
		'parseInt.call(null,"2a",16);':                                                                '42'
		'parseInt.call.call(parseInt,null,"2a",16);':                                                  '42'
		'parseInt.bind(null,"2a")(16);':                                                               '42'
		'parseInt.bind(null,"2a").bind(null,16)();':                                                   '42'
		'parseInt.bind(null,"2a").length;':                                                            '1'
		'parseInt.bind(null,"2a").name;':                                                              '"bound parseInt"'
		'parseInt.bind(null,"2a",16).length;':                                                         '0'
		'isFinite.apply(null);':                                                                       'false'
		'globalThis.length=2; globalThis[0]="2a"; globalThis[1]=16; parseInt.apply(null,globalThis);': '42'
		'encodeURIComponent.call(null,"a b");':                                                        '"a%20b"'
		'parseInt.toString();':                                                                        '"function parseInt() { [native code] }"'
		'parseInt.bind(null).toString();':                                                             '"function () { [native code] }"'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert run_function_intrinsic_source(mut vm, source)!.str() == expected, source
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	}
}

fn test_restricted_properties_and_apply_failures_remain_isolated_across_scripts() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for source in ['parseInt.caller;', 'parseInt.arguments;', 'parseInt.caller=42;',
		'parseInt.bind(null).arguments;', 'parseInt.apply(null,"42");', 'parseInt.call.call(42);',
		'parseInt.bind.call(42);'] {
		if _ := run_function_intrinsic_source(mut vm, source) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	assert run_function_intrinsic_source(mut vm, 'parseInt("42");')!.number == 42
}

fn test_realms_own_distinct_function_prototypes_and_shared_restricted_throwers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	first := vm.realm()
	create_simple_execution_context(mut vm)
	second := vm.realm()
	assert first.function_prototype_record() != second.function_prototype_record()
	assert first.throw_type_error_function? != second.throw_type_error_function?
	for realm in [first, second] {
		function :=
			realm.global_object_record().get(mut vm, PropertyName.from_str('parseInt'))!.as_object()
		assert function.internal_get_prototype_of()? == realm.function_prototype_record()
		for name in ['caller', 'arguments'] {
			descriptor :=
				realm.function_prototype_record().internal_get_own_property(PropertyName.from_str(name))?
			assert descriptor.getter?.as_object() == realm.throw_type_error_function?
			assert descriptor.setter?.as_object() == realm.throw_type_error_function?
		}
	}
	vm.pop_execution_context()
	assert vm.realm() == first
}
