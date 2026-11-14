module libjs

fn object_binding_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'object-bindings.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_object_bindings_run_aliases_nested_defaults_and_rest_in_source_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_binding_eval(mut vm, 'let {a:x,b:{c:y=2},d=x+1,...rest}={a:20,b:{},keep:19};x+y+d+rest.keep')!.number == 62
	assert object_binding_eval(mut vm, 'const {missing=42,present=99}={present:null};missing+":"+(present===null)')!.as_string().str() == '42:true'
	assert object_binding_eval(mut vm, 'let calls=0;let key={toString:function(){calls++;return "a"}};let {[key]:a,...others}={a:40,b:2};calls+":"+(a+others.b)+":"+("a" in others)')!.as_string().str() == '1:42:false'
	assert object_binding_eval(mut vm, 'let {0:first,...tail}="ab";first+tail[1]')!.as_string().str() == 'ab'
	assert object_binding_eval(mut vm, 'let {fn=function(){return 42}}={};fn.name+":"+fn()')!.as_string().str() == 'fn:42'
}

fn test_object_bindings_preserve_hoisting_lexical_tdz_and_const_assignment_errors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_binding_eval(mut vm, 'function f(){var before=typeof n;var {n=42}={};return before+":"+n}f()')!.as_string().str() == 'undefined:42'
	assert object_binding_eval(mut vm, 'try{let {later=before,before=1}={}}catch(e){e.message}')!.as_string().str().contains('before')
	assert object_binding_eval(mut vm, 'let outside=40;{let {outside:inner=2}={};outside+=inner}outside')!.number == 42
	assert object_binding_eval(mut vm, 'let caught=0;try{const {fixed}={fixed:1};fixed=2}catch(e){caught=42}caught')!.number == 42
	for source in ['let {}=null;', 'var {x}=undefined;'] {
		object_binding_eval(mut vm, source) or {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			continue
		}
		assert false, source
	}
}

fn test_object_rest_copies_only_own_enumerable_keys_including_symbols_and_proto_data() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), vm.realm().object_prototype)
	key := Symbol.create(utf16_string('secret'), .unique)
	object.define_direct_property(PropertyName.from_str('pick'), Value.from_i32(1), attribute_writable | attribute_enumerable | attribute_configurable)
	object.define_direct_property(PropertyName.from_str('hidden'), Value.from_i32(100), 0)
	object.define_direct_property(PropertyName.from_str('__proto__'), Value.from_i32(21), attribute_writable | attribute_enumerable | attribute_configurable)
	object.define_direct_property(PropertyName.from_symbol(key), Value.from_i32(20), attribute_writable | attribute_enumerable | attribute_configurable)
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('source'), Value.from_object(object), attribute_writable | attribute_enumerable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('secret'), Value.from_symbol(key), attribute_writable | attribute_enumerable | attribute_configurable)
	assert object_binding_eval(mut vm, 'var {pick,...rest}=source;rest[secret]+rest.__proto__+pick+":"+("hidden" in rest)')!.as_string().str() == '42:false'
	assert object_binding_eval(mut vm, 'let {[secret]:removed,...without}=source;removed+":"+(secret in without)')!.as_string().str() == '20:false'
	result := global.get(mut vm, PropertyName.from_str('rest'))!.as_object()
	assert voidptr(result.internal_get_prototype_of()?) == voidptr(vm.realm().object_prototype_record())
}

fn test_module_object_binding_exports_are_initialized_in_the_module_environment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('export const {a:x,b:y=22}={a:20};export default x+y;', vm.realm(), 'bindings.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	assert record.export_value(mut vm, utf16_string('x'))!.number == 20
	assert record.export_value(mut vm, utf16_string('y'))!.number == 22
	assert record.export_value(mut vm, utf16_string('default'))!.number == 42
}

@[heap]
struct BindingGetterLog {
mut:
	calls []string
}

fn test_object_rest_skips_excluded_getters_and_rechecks_descriptors_after_mutation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), vm.realm().object_prototype)
	prototype.define_direct_property(PropertyName.from_str('inherited'), Value.from_i32(99), attribute_enumerable)
	mut source := Object.create(vm.realm(), prototype)
	log := &BindingGetterLog{}
	for name in ['pick', 'first', 'hidden'] {
		getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
			fn [source, log, name] (mut vm VM) !Value {
				assert voidptr(vm.this_value().as_object()) == voidptr(source)
				mut calls := unsafe { &BindingGetterLog(log) }
				calls.calls << name
				if name == 'first' {
					mut object := unsafe { &Object(source) }
					object.internal_delete(PropertyName.from_str('last'))
					object.define_direct_property(PropertyName.from_str('added'), Value.from_i32(100), attribute_enumerable)
				}
				return Value.from_i32(if name == 'pick' { 1 } else { 41 })
			}, 0, PropertyName.from_str(name), 'get')
		source.define_direct_accessor(PropertyName.from_str(name), getter.object, none, if name == 'hidden' {
			u8(0)
		} else {
			attribute_enumerable
		})
	}
	source.define_direct_property(PropertyName.from_str('last'), Value.from_i32(100), attribute_enumerable | attribute_configurable)
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('changes'), Value.from_object(source), 0)
	actual := object_binding_eval(mut vm, 'var {pick,...after}=changes;(pick+after.first)+":"+("last" in after)+":"+("added" in after)+":"+("hidden" in after)+":"+("inherited" in after)')!
	assert actual.as_string().str() == '42:false:false:false:false'
	assert log.calls == ['pick', 'first']
}

fn test_object_rest_consumes_the_callers_instruction_budget_and_recovers_after_exhaustion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut source := Object.create(vm.realm(), none)
	for index in 0 .. 200 {
		source.define_direct_property(PropertyName.from_number(u32(index)), Value.from_i32(1), attribute_enumerable)
	}
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('mass'), Value.from_object(source), 0)
	mut script := Script.parse('var {...partial}=mass;', vm.realm(), 'rest-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 20 }) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert object_binding_eval(mut vm, '6*7')!.number == 42
		return
	}
	assert false, 'Object rest must not bypass the outer execution budget'
}
