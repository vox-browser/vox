// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn array_binding_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-binding.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_array_binding_defaults_holes_rest_and_nested_object_array_patterns() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert array_binding_eval(mut vm, 'let [a,,b=2,...rest]=[20,99,undefined,3,4];a+b+rest[0]+rest[1]')!.number == 29
	assert array_binding_eval(mut vm, 'const [first,{x:second},[third=2]]=[20,{x:20},[]];first+second+third')!.number == 42
	assert array_binding_eval(mut vm, 'let {values:[left,right=22]}={values:[20]};left+right')!.number == 42
	assert array_binding_eval(mut vm, 'var [letter,...characters]="A😀B";letter+characters[0]+characters[1]+":"+characters.length')!.as_string().str() == 'A😀B:2'
	assert array_binding_eval(mut vm, 'let [nothing=42,present=99]=[undefined,null];nothing===42&&present===null')!.as_bool()
	assert array_binding_eval(mut vm, 'let [fn=function(){return 42}]=[];fn.name+":"+fn()')!.as_string().str() == 'fn:42'
}

fn test_array_binding_lexical_tdz_hoisting_constants_and_for_of_patterns() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert array_binding_eval(mut vm, 'function f(){var before=typeof n;var [n=42]=[];return before+":"+n};f()')!.as_string().str() == 'undefined:42'
	assert array_binding_eval(mut vm, 'var tdz=false;try{let [early=later,later=1]=[]}catch(e){tdz=e instanceof ReferenceError};tdz')!.as_bool()
	assert array_binding_eval(mut vm, 'var immutable=false;try{const [fixed]=[1];fixed=2}catch(e){immutable=e instanceof TypeError};immutable')!.as_bool()
	assert array_binding_eval(mut vm, 'var sum=0;for(const [a,b=2] of [[20,20],[0]]){sum+=a+b};sum')!.number == 42
	assert array_binding_eval(mut vm, 'var result=0;for(const {pair:[a,b]} of [{pair:[20,22]}]){result=a+b};result')!.number == 42
}

fn test_array_binding_elisions_do_not_read_value_and_exhaustion_does_not_repeat_next() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert array_binding_eval(mut vm, 'var reads=0,calls=0,closed=0;var source={};source[Symbol.iterator]=function(){return {next:function(){calls++;var result={done:false};Object.defineProperty(result,"value",{get:function(){reads++;throw 42}});return result},return:function(){closed++;return {}}}};let [,]=source;reads===0&&calls===1&&closed===1')!.as_bool()
	assert array_binding_eval(mut vm, 'calls=0;closed=0;source[Symbol.iterator]=function(){return {next:function(){calls++;return {done:true}},return:function(){closed++;return {}}}};let [a=20,b=22,...rest]=source;a+b===42&&calls===1&&closed===0&&rest.length===0')!.as_bool()
	assert array_binding_eval(mut vm, 'calls=0;closed=0;let []=source;calls===0&&closed===1')!.as_bool()
}

fn test_array_binding_closes_on_initializer_errors_preserving_original_throw_and_scope() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert array_binding_eval(mut vm, 'var closed=0,reason={};var source={};source[Symbol.iterator]=function(){return {next:function(){return {value:undefined}},return:function(){closed++;throw 123}}};function fail(){throw reason};var caught=false;try{let [item=fail()]=source}catch(e){caught=e===reason};caught&&closed===1&&typeof item==="undefined"')!.as_bool()
	assert array_binding_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next:function(){throw reason},return:function(){closed++;return {}}}};try{let [item]=source}catch(e){caught=e===reason};caught&&closed===0')!.as_bool()
	assert array_binding_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next:function(){return {value:1}},return:function(){closed++;return 0}}};try{let [item]=source}catch(e){caught=e instanceof TypeError};caught&&closed===1')!.as_bool()
}

fn test_array_binding_module_live_exports_and_rest_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('export const [a,b=22]=[20];export default a+b', vm.realm(), 'array-binding.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	assert record.export_value(mut vm, utf16_string('default'))!.number == 42
	array_binding_eval(mut vm, 'var infinite={};infinite[Symbol.iterator]=function(){return {next:function(){return {value:1,done:false}}}}')!
	mut script := Script.parse('let [...all]=infinite;', vm.realm(), 'rest-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100 }) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert array_binding_eval(mut vm, '6*7')!.number == 42
		return
	}
	assert false, 'Array rest must share the caller instruction budget'
}
