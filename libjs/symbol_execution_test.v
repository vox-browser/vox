module libjs

fn execute_symbol_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'symbols.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_compiled_symbol_calls_primitive_methods_registry_and_property_keys() {
	for source, expected in {
		'typeof Symbol();': '"symbol"'
		'Symbol().description;': 'undefined'
		'Symbol("").description;': '""'
		'Symbol(null).description;': '"null"'
		'Symbol(false).description;': '"false"'
		'Symbol("key").toString();': '"Symbol(key)"'
		'Symbol("key") === Symbol("key");': 'false'
		'Symbol.for("key") === Symbol.for("key");': 'true'
		'var s=Symbol(); s.valueOf() === s;': 'true'
		'var s=Symbol(); s[Symbol.toPrimitive](globalThis) === s;': 'true'
		'Symbol.keyFor(Symbol.for("key"));': '"key"'
		'Symbol.keyFor(Symbol("key"));': 'undefined'
		'Symbol.keyFor(Symbol.iterator);': 'undefined'
		'Symbol.iterator.description;': '"Symbol.iterator"'
		'Symbol.prototype.constructor === Symbol;': 'true'
		'Symbol().constructor === Symbol;': 'true'
		'Symbol.for.call(null,"key") === Symbol.for("key");': 'true'
		'globalThis[Symbol.for("key")]=42; globalThis[Symbol.for("key")];': '42'
		'globalThis[Symbol("key")]=42; globalThis[Symbol("key")];': 'undefined'
		'delete Symbol().description;': 'true'
		'var s=Symbol(); s.extra=42; s.extra;': 'undefined'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert execute_symbol_source(mut vm, source)!.str() == expected, source
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	}
}

fn test_compiled_symbol_errors_preserve_sources_and_allow_subsequent_execution() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for source in ['new Symbol("key");', 'new (Symbol.bind(null,"key"))();',
		'Symbol(Symbol());', 'Symbol.for(Symbol());', 'Symbol.keyFor();', 'Symbol.keyFor(42);',
		'Symbol.prototype.toString();', 'Symbol.prototype.description;',
		'"use strict"; Symbol().description="changed";', '"use strict"; Symbol().extra=42;'] {
		if _ := execute_symbol_source(mut vm, source) { assert false, source }
		else {
			object := thrown_value(err).as_object()
			assert object.error_kind()? == .type_error
			assert object.error_data?.stack_string(false).contains('symbols.js:1:'), source
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	assert execute_symbol_source(mut vm, 'Symbol.for("key").description;')!.as_string().str() == 'key'
}

@[heap]
struct SymbolReceiverTrace {
mut:
	receiver Value
	argument Value
}

fn test_symbol_primitive_accessors_and_symbol_keyed_mutations_keep_the_original_receiver() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut trace := &SymbolReceiverTrace{}
	mut prototype := realm.symbol_prototype_record()
	prototype.define_native_accessor(mut vm, realm, PropertyName.from_str('receiver'), fn (mut vm VM) !Value {
		assert vm.this_value().is_symbol()
		return vm.this_value()
	}, fn [mut trace] (mut vm VM) !Value {
		trace.receiver = vm.this_value()
		trace.argument = vm.argument(0)
		return js_undefined()
	}, attribute_configurable, realm.function_prototype)
	assert execute_symbol_source(mut vm, 'var s=Symbol("key"); s.receiver === s;')!.as_bool()
	assert execute_symbol_source(mut vm, '"use strict"; s.receiver=42;')!.number == 42
	assert trace.receiver == execute_symbol_source(mut vm, 's;')!
	assert trace.argument.number == 42
	symbol := Symbol.create(utf16_string('boxed'), .unique)
	mut wrapper := SymbolObject.create(realm, symbol).object
	mut global := vm.get_global_object()
	global.define_direct_property(PropertyName.from_str('boxed'), Value.from_object(wrapper), 7)
	assert execute_symbol_source(mut vm, 'globalThis[boxed]=42; globalThis[boxed.valueOf()];')!.number == 42
	assert global.get(mut vm, PropertyName.from_symbol(symbol))!.number == 42
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
