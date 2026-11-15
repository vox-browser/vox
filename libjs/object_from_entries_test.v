// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn from_entries_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'from-entries.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_from_entries_uses_intrinsic_object_and_defines_ordinary_data_properties() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert from_entries_eval(mut vm, 'var symbol=Symbol("key"),value={},o=Object.fromEntries([["x",1],["x",42],[symbol,value],["__proto__",value],["missing"]]);var d=Object.getOwnPropertyDescriptor(o,"x");o.x===42&&o[symbol]===value&&Object.getPrototypeOf(o)===Object.prototype&&Object.hasOwn(o,"__proto__")&&o.__proto__===value&&Object.hasOwn(o,"missing")&&o.missing===undefined&&d.writable&&d.enumerable&&d.configurable')!.as_bool()
	assert from_entries_eval(mut vm, 'var calls=0,receiver={get prototype(){calls++;throw 1}};var o2=Object.fromEntries.call(receiver,[["answer",42]]);o2.answer===42&&calls===0&&Object.getPrototypeOf(o2)===Object.prototype')!.as_bool()
	assert from_entries_eval(mut vm, 'var inherited=0;Object.defineProperty(Object.prototype,"entrySetter",{set(v){inherited++},configurable:true});var own=Object.fromEntries([["entrySetter",42]]);delete Object.prototype.entrySetter;inherited===0&&Object.hasOwn(own,"entrySetter")&&own.entrySetter===42')!.as_bool()
	method := vm.realm().object_constructor_record().internal_get_own_property(PropertyName.from_str('fromEntries'))?
	assert method.writable? && method.configurable? && !method.enumerable?
	function := method.value?
	assert !function.is_constructor()
	assert function.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert function.as_object().get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'fromEntries'
}

fn test_from_entries_reads_both_entry_properties_before_converting_the_key() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert from_entries_eval(mut vm, 'var log="",key={toString(){log+="key;";return "answer"}},entry={get 0(){log+="zero;";return key},get 1(){log+="one;";return 42}};Object.fromEntries([entry]).answer===42&&log==="zero;one;key;"')!.as_bool()
	assert from_entries_eval(mut vm, 'Object.fromEntries(new Map([["left",20],["right",22]])).left===20&&Object.fromEntries([[{},42]])["[object Object]"]===42')!.as_bool()
}

fn test_from_entries_closes_on_invalid_entries_getters_and_key_errors() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert from_entries_eval(mut vm, 'var closed=0,marker={},entry=1,source={};source[Symbol.iterator]=function(){return {next(){return {value:entry,done:false}},return(){closed++;throw 9}}};var caught=false;try{Object.fromEntries(source)}catch(e){caught=e instanceof TypeError}caught&&closed===1')!.as_bool()
	assert from_entries_eval(mut vm, 'closed=0;entry={get 0(){throw marker}};try{Object.fromEntries(source)}catch(e){caught=e===marker}caught&&closed===1')!.as_bool()
	assert from_entries_eval(mut vm, 'closed=0;var converted=0;entry={0:{toString(){converted++;throw 7}},get 1(){throw marker}};try{Object.fromEntries(source)}catch(e){caught=e===marker}caught&&closed===1&&converted===0')!.as_bool()
	assert from_entries_eval(mut vm, 'closed=0;entry={0:{toString(){throw marker}},1:42};try{Object.fromEntries(source)}catch(e){caught=e===marker}caught&&closed===1')!.as_bool()
}

fn test_from_entries_preserves_iterator_protocol_errors_without_closing_after_failed_steps() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	for step in ['throw marker', 'return {get done(){throw marker}}', 'return {done:false,get value(){throw marker}}'] {
		assert from_entries_eval(mut vm, 'var closed=0,marker={},source={};source[Symbol.iterator]=function(){return {next(){${step}},return(){closed++;return {}}}};var same=false;try{Object.fromEntries(source)}catch(e){same=e===marker}same&&closed===0')!.as_bool()
	}
	for source in ['Object.fromEntries(null)', 'Object.fromEntries(undefined)', 'Object.fromEntries({})', 'Object.fromEntries(["ab"])'] {
		from_entries_eval(mut vm, source) or {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			continue
		}
		assert false, source
	}
}

fn test_from_entries_shares_the_callers_budget_for_unbounded_iterables() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	from_entries_eval(mut vm, 'var infinite={};infinite[Symbol.iterator]=function(){return {next(){return {value:["x",1],done:false}}}}')!
	mut script := Script.parse('Object.fromEntries(infinite)', vm.realm(), 'from-entries-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100}) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert from_entries_eval(mut vm, '6*7')!.number == 42
		return
	}
	assert false, 'Object.fromEntries must consume the caller execution budget'
}
