module libjs

// Rust/src/bytecode/codegen.rs::generate_{assignment,update}_expression and
// Interpreter/SlowPaths.cpp::asm_slow_path_put_by_value, using host-owned
// ordinary data objects until object literals and intrinsic prototypes exist.
fn run_property_mutation(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'mutations.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn mutation_host(mut vm VM) &Object {
	mut prototype := Object.create(vm.realm(), none)
	prototype.create_data_property(mut vm, PropertyName.from_str('inherited'), Value.from_i32(2)) or {
		panic(err)
	}
	mut host := Object.create(vm.realm(), prototype)
	host.create_data_property(mut vm, PropertyName.from_str('answer'), Value.from_i32(2)) or {
		panic(err)
	}
	mut global := vm.get_global_object()
	global.create_data_property(mut vm, PropertyName.from_str('host'), Value.from_object(host)) or {
		panic(err)
	}
	return host
}

fn test_compiled_data_property_assignments_and_numeric_updates() {
	for source, expected in {
		'host.answer=42;':                              '42'
		'host["answer"]+=40;':                          '42'
		'host.answer*=21;':                             '42'
		'host.answer**=5;':                             '32'
		'host.answer-=3;':                              '-1'
		'host.answer/=4;':                              '0.5'
		'host.answer%=2;':                              '0'
		'host.answer&=1;':                              '0'
		'host.answer|=1;':                              '3'
		'host.answer^=3;':                              '1'
		'host.answer<<=2;':                             '8'
		'host.answer>>=1;':                             '1'
		'host.answer>>>=1;':                            '1'
		'host.answer++;':                               '2'
		'++host.answer;':                               '3'
		'host.answer--;':                               '2'
		'--host.answer;':                               '1'
		'host.answer="41"; host.answer++;':             '41'
		'host.answer="41"; ++host.answer;':             '42'
		'host.answer=41n; ++host.answer;':              '42n'
		'host.answer=41n; host.answer++; host.answer;': '42n'
		'host.answer=42n; --host.answer;':              '41n'
		'host[3n]=42; host[3];':                        '42'
		'host.inherited+=40; host.inherited;':          '42'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		host := mutation_host(mut vm)
		assert run_property_mutation(mut vm, source)!.str() == expected, source
		assert host.prototype?.get(mut vm, PropertyName.from_str('inherited'))!.number == 2
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
}

fn test_member_assignments_retain_base_key_and_old_value_before_rhs() {
	for source, expected in {
		'var saved=host; host.answer=(host=null,42); saved.answer;':   '42'
		'var saved=host; host.answer+=(host=null,40); saved.answer;':  '42'
		'var key="answer"; host[key]=(key="other",42); host.answer;':  '42'
		'var key="answer"; host[key]+=(key="other",40); host.answer;': '42'
		'host.answer+=(host.answer=100,40); host.answer;':             '42'
		'var count=0; host[(count++,"answer")]+=40; count;':           '1'
		'var count=0; host[(count++,"answer")]++; count;':             '1'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mutation_host(mut vm)
		assert run_property_mutation(mut vm, source)!.str() == expected, source
	}
}

fn test_member_logical_assignments_short_circuit_the_rhs_and_write() {
	for source, expected in {
		'host.answer&&=42;':                                     '42'
		'host.answer||=42;':                                     '2'
		'host.answer=NULL; host.answer NULLISH=42;':             '42'
		'var count=0; host.answer||=(count++,42); count;':       '0'
		'var count=0; host.answer NULLISH=(count++,42); count;': '0'
		'host.answer=0; host.answer&&=42;':                      '0'
		'host.answer=0; host.answer NULLISH=42;':                '0'
		'host.answer=undefined; host.answer||=42;':              '42'
		'host.answer=undefined; host.answer NULLISH=42;':        '42'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mutation_host(mut vm)
		// Avoid C's ??= trigraph in generated V test literals.
		actual_source := source.replace('NULLISH', '?'.repeat(2)).replace('NULL', 'null')
		assert run_property_mutation(mut vm, actual_source)!.str() == expected, actual_source
	}
}

@[heap]
struct MutationOrder {
mut:
	events []string
}

fn install_mutation_order(mut vm VM, mut order MutationOrder, host &Object, throw_rhs bool) {
	mut global := vm.get_global_object()
	base := NativeFunction.create(mut vm, vm.realm(), none, fn [mut order, host] (mut vm VM) !Value {
		order.events << 'base'
		return Value.from_object(host)
	}, 0, PropertyName.from_str('base'), none)
	rhs := NativeFunction.create(mut vm, vm.realm(), none, fn [mut order, throw_rhs] (mut vm VM) !Value {
		order.events << 'rhs'
		if throw_rhs { return throw_completion(Value.from_i32(17)) }
		return Value.from_i32(40)
	}, 0, PropertyName.from_str('rhs'), none)
	mut key := Object.create(vm.realm(), none)
	coerce := NativeFunction.create(mut vm, vm.realm(), none, fn [mut order] (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		order.events << 'key'
		return Value.from_string(vm.create_string_from_str('answer'))
	}, 1, PropertyName.from_str('coerce'), none)
	key.create_data_property(mut vm, PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coerce.object)) or { panic(err) }
	global.create_data_property(mut vm, PropertyName.from_str('key'), Value.from_object(key)) or {
		panic(err)
	}
	global.create_data_property(mut vm, PropertyName.from_str('base'),
		Value.from_object(base.object)) or { panic(err) }
	global.create_data_property(mut vm, PropertyName.from_str('rhs'), Value.from_object(rhs.object)) or {
		panic(err)
	}
}

fn test_computed_writes_preserve_upstream_coercion_and_abrupt_completion_order() {
	for source, expected in {
		'base()[key]=rhs();':   ['base', 'rhs', 'key']
		'base()[key]+=rhs();':  ['base', 'key', 'rhs', 'key']
		'base()[key]++;':       ['base', 'key', 'key']
		'++base()[key];':       ['base', 'key', 'key']
		'base()[key]||=rhs();': ['base', 'key']
		'base()[key]&&=rhs();': ['base', 'key', 'rhs', 'key']
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		host := mutation_host(mut vm)
		mut order := &MutationOrder{}
		install_mutation_order(mut vm, mut order, host, false)
		run_property_mutation(mut vm, source)!
		assert order.events == expected, source
	}
	mut vm := VM.create()
	base_frame := create_simple_execution_context(mut vm)
	host := mutation_host(mut vm)
	mut order := &MutationOrder{}
	install_mutation_order(mut vm, mut order, host, true)
	if _ := run_property_mutation(mut vm, 'base()[key]=rhs();') {
		assert false
	} else {
		assert thrown_value(err).as_i32() == 17
	}
	assert order.events == ['base', 'rhs']
	assert host.get(mut vm, PropertyName.from_str('answer'))!.number == 2
	assert vm.running_execution_context() == base_frame
	assert vm.interpreter_stack().depth() == 0
	assert run_property_mutation(mut vm, 'host.answer;')!.number == 2
}

fn test_failed_property_writes_distinguish_sloppy_and_strict_execution() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut host := mutation_host(mut vm)
	host.define_direct_property(PropertyName.from_str('fixed'), Value.from_i32(2), 0)
	host.extensible = false
	assert run_property_mutation(mut vm, 'host.fixed=42;')!.number == 42
	assert run_property_mutation(mut vm, 'host.missing=42;')!.number == 42
	assert run_property_mutation(mut vm, 'host.fixed||=42;')!.number == 2
	assert run_property_mutation(mut vm, '"use strict"; host.fixed||=42;')!.number == 2
	for source in ['"use strict"; host.fixed=42;', '"use strict"; host.missing=42;',
		'"use strict"; ++host.fixed;', '"use strict"; null.answer=42;', 'undefined.answer=42;'] {
		if _ := run_property_mutation(mut vm, source) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert vm.running_execution_context() == base
		assert vm.interpreter_stack().depth() == 0
	}
	assert host.get(mut vm, PropertyName.from_str('fixed'))!.number == 2
	assert !host.has_own_property(PropertyName.from_str('missing'))
}

fn test_property_write_source_operand_is_validated_before_execution() {
	mut executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [js_undefined()]
		instructions:               [
			Instruction{
				op:  .put_property
				lhs: Operand.constant(0)
				rhs: Operand.constant(0)
				src: Operand.register(5)
			},
		]
		bytecode_length:            1
	}
	if _ := executable.validate(0) { assert false
	 }
	executable.instructions[0].src = Operand.constant(0)
	executable.validate(0)!
}

// Ladybird 74a0613d1d798d90562a25af9aeb7abac6d2cfb5.
fn test_computed_writes_reject_nullish_bases_before_key_conversion() {
	for base in ['null', 'undefined'] {
		for prefix in ['', '"use strict"; '] {
			mut vm := VM.create()
			context := create_simple_execution_context(mut vm)
			host := mutation_host(mut vm)
			mut order := &MutationOrder{}
			install_mutation_order(mut vm, mut order, host, false)
			if _ := run_property_mutation(mut vm, '${prefix}${base}[key]=rhs();') {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
			assert order.events == ['rhs']
			assert host.get(mut vm, PropertyName.from_str('answer'))!.number == 2
			assert vm.running_execution_context() == context
			assert vm.interpreter_stack().depth() == 0
		}
	}
}
