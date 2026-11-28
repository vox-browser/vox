// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn regexp_constructor_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'regexp-constructor.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_regexp_call_returns_input_only_for_matching_constructor_and_undefined_flags() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_constructor_eval(mut vm, 'var r=/a/g;RegExp(r)===r&&RegExp(r,undefined)===r&&new RegExp(r)!==r&&RegExp(r,"i").flags==="i"')!.as_bool()
	assert regexp_constructor_eval(mut vm, 'var r=/a/g;r.constructor=function Other(){};var copy=RegExp(r);copy!==r&&copy.source==="a"&&copy.flags==="g"')!.as_bool()
	assert regexp_constructor_eval(mut vm, 'var r=/a/g;r[Symbol.match]=false;var copy=RegExp(r);copy!==r&&copy.source==="a"&&copy.flags==="g"')!.as_bool()
}

fn test_regexp_generic_sources_observe_match_once_then_source_flags_and_coercion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_constructor_eval(mut vm, 'var order="",pattern={get [Symbol.match](){order+="match;";return true},get source(){order+="source;";return {toString(){order+="pattern;";return "a"}}},get flags(){order+="flags;";return {toString(){order+="convert;";return "g"}}}};var r=new RegExp(pattern);r.source==="a"&&r.flags==="g"&&order==="match;source;flags;pattern;convert;"')!.as_bool()
	assert regexp_constructor_eval(mut vm, 'order="";var r=new RegExp(pattern,"i");r.flags==="i"&&order==="match;source;pattern;"')!.as_bool()
}

fn test_regexp_subclasses_and_species_retain_actual_new_target_prototypes() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert regexp_constructor_eval(mut vm, 'class R extends RegExp{}var r=new R("a","g");r instanceof R&&r instanceof RegExp&&r.test("a")&&R[Symbol.species]===R&&RegExp[Symbol.species]===RegExp&&RegExp(r)!==r')!.as_bool()
	assert regexp_constructor_eval(mut vm, 'var marker={},r=/a/,same=false;Object.defineProperty(r,Symbol.match,{get(){throw marker}});try{new RegExp(r)}catch(e){same=e===marker}same')!.as_bool()
}

@[heap]
struct RegExpPrototypeOrder {
mut:
	seen bool
}

fn test_regexp_reads_new_target_prototype_before_converting_pattern() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut state := &RegExpPrototypeOrder{}
	target := NativeFunction.create_constructor(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value { return js_undefined() },
		fn (mut vm VM, _ &Object) !&Object { return Object.create(vm.realm(), none) },
		0, PropertyName.from_str('Target')).object
	mut object := target
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('prototype'), fn [state] (mut vm VM) !Value {
		mut seen := unsafe { &RegExpPrototypeOrder(state) }; seen.seen = true
		return Value.from_object(vm.realm().regexp_prototype or { panic('Missing RegExp prototype') })
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	check := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [state] (mut vm VM) !Value {
		if !state.seen { return vm.throw_error(.type_error, 'Pattern converted before prototype lookup') }
		return Value.from_string(vm.create_string_from_str('a'))
	}, 0, PropertyName.from_str('check'), none)
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('Target'), Value.from_object(target), 0)
	global.define_direct_property(PropertyName.from_str('check'), Value.from_object(check.object), 0)
	assert regexp_constructor_eval(mut vm, 'Reflect.construct(RegExp,[{toString:check}],Target).source==="a"')!.as_bool()
	assert state.seen
}
