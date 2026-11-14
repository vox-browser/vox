// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn for_of_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'for-of.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 }) or {
		if is_throw_completion(err) {
			value := thrown_value(err)
			message := if value.is_object() {
				value.as_object().error_message() or { value.str() }
			} else {
				value.str()
			}
			return error('${source}: ${message}')
		}
		return err
	}
}

fn for_of_fixture(mut vm VM) ! {
	create_simple_execution_context(mut vm)
	for_of_eval(mut vm, 'var closed="";function iterable(values,label){var result={};result[Symbol.iterator]=function(){var index=0;return {next:function(){return index<values.length?{value:values[index++],done:false}:{done:true}},return:function(){closed+=label;return {done:true}}}};return result}')!
}

fn test_for_of_builtin_values_primitives_holes_and_lexical_iteration_environments() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	assert for_of_eval(mut vm, 'var values="";for(var item of [1,,3]){values+=item+","};values')!.as_string().str() == '1,undefined,3,'
	assert for_of_eval(mut vm, 'var chars="";for(const v of "A😀\\ud800"){chars+=v+","};chars')!.as_string().utf16 == utf16_string_from_code_units([
		u16(`A`),
		`,`,
		0xd83d,
		0xde00,
		`,`,
		0xd800,
		`,`,
	])
	assert for_of_eval(mut vm, 'var callbacks=[];for(let v of [1,2,3]){callbacks.push(function(){return v})};callbacks[0]()+callbacks[1]()+callbacks[2]()+":"+typeof v')!.as_string().str() == '6:undefined'
	assert for_of_eval(mut vm, 'var sum=0;for(const {length:n} of ["aa","bbbb"]){sum+=n};sum')!.number == 6
	assert for_of_eval(mut vm, 'var outer=[1];var tdz=false;try{for(let outer of outer){}}catch(e){tdz=e instanceof ReferenceError};tdz&&outer[0]===1')!.as_bool()
}

fn test_for_of_exhaustion_and_continue_do_not_close_break_closes_once() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	assert for_of_eval(mut vm, 'var total=0;for(const v of iterable([1,2,3],"x")){if(v===2)continue;total+=v};total+":"+closed')!.as_string().str() == '4:'
	assert for_of_eval(mut vm, 'for(let v of iterable([1,2,3],"b")){let local=v;if(v===1)continue;break};closed+":"+typeof local')!.as_string().str() == 'b:undefined'
	assert for_of_eval(mut vm, 'closed="";for(var a of iterable([1,2],"o")){for(var b of iterable([3,4],"i")){break}};closed')!.as_string().str() == 'ii'
}

fn test_for_of_return_evaluates_value_before_closing_and_unwinds_nested_loops() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	assert for_of_eval(mut vm, 'function f(){for(let outer of iterable([1],"o")){for(const inner of iterable([2],"i")){let local=3;return (closed+="v",outer+inner+local)}}};f()+":"+closed')!.as_string().str() == '6:vio'
	assert for_of_eval(mut vm, 'closed="";function mixed(){for(const v of iterable([42],"c")){for(const k in {key:1}){while(true){return v+k}}}};mixed()+":"+closed')!.as_string().str() == '42key:c'
	assert for_of_eval(mut vm, 'closed="";function nestedFunction(){for(const v of iterable([1,2],"x")){functionValue=function(){return 42};if(functionValue()!==42)throw 1};return closed};nestedFunction()')!.as_string().str() == ''
}

fn test_for_of_throw_and_binding_failures_close_preserving_the_original_throw() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	assert for_of_eval(mut vm, 'var reason={};var caught=false;try{for(let v of iterable([1],"t")){let local=1;throw reason}}catch(e){caught=e===reason};caught&&closed==="t"&&typeof local==="undefined"')!.as_bool()
	assert for_of_eval(mut vm, 'closed="";var holder={};Object.defineProperty(holder,"value",{set:function(v){throw reason}});try{for(holder.value of iterable([1],"s")){}}catch(e){caught=e===reason};caught&&closed==="s"')!.as_bool()
	assert for_of_eval(mut vm, 'closed="";var throwing=iterable([1],"unused");throwing[Symbol.iterator]=function(){return {next:function(){return {value:1}},return:function(){closed+="r";throw 123}}};try{for(const v of throwing){throw reason}}catch(e){caught=e===reason};caught&&closed==="r"')!.as_bool()
}

fn test_for_of_next_done_and_value_errors_do_not_close_and_body_catches_stay_inside_loop() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	for mode in ['next', 'done', 'value'] {
		assert for_of_eval(mut vm, 'closed="";var mode="${mode}";var source={};source[Symbol.iterator]=function(){return {next:function(){if(mode==="next")throw 42;var step={};Object.defineProperty(step,mode,{get:function(){throw 42}});return step},return:function(){closed+="bad";return {}}}};var caught=false;try{for(const v of source){}}catch(e){caught=e===42};caught&&closed===""')!.as_bool()
	}
	assert for_of_eval(mut vm, 'closed="";var count=0;for(const v of iterable([1,2],"x")){try{throw v}catch(e){count+=e}};count===3&&closed===""')!.as_bool()
}

fn test_for_of_close_errors_reach_surrounding_handlers_once_without_entering_body_catches() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	assert for_of_eval(mut vm, 'var reason={};var source={};source[Symbol.iterator]=function(){return {next:function(){return {value:42}},return:function(){closed+="r";throw reason}}};function f(){try{for(const v of source){try{return v}catch(e){closed+="bad"}}}catch(e){return e===reason}};f()&&closed==="r"')!.as_bool()
	assert for_of_eval(mut vm, 'closed="";var caught=false;try{for(const outer of iterable([1],"o")){for(const inner of source){break}}}catch(e){caught=e===reason};caught&&closed==="ro"')!.as_bool()
	assert for_of_eval(mut vm, 'closed="";source[Symbol.iterator]=function(){return {next:function(){return {value:1}},return:function(){closed+="r";return 0}}};try{for(const v of source){break}}catch(e){caught=e instanceof TypeError};caught&&closed==="r"')!.as_bool()
}

fn test_for_of_member_targets_and_module_live_exports() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	assert for_of_eval(mut vm, 'var holder={};var count=0;for(holder[count++] of ["a","b"]){};holder[0]+holder[1]+":"+count')!.as_string().str() == 'ab:2'
	mut record := SourceTextModule.parse('export let sum=0;for(const v of [1,2,3]){sum+=v}', vm.realm(), 'for-of.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	assert record.export_value(mut vm, utf16_string('sum'))!.number == 6
}

fn test_for_of_shared_budget_and_bytecode_iterator_exit_validation() {
	mut vm := VM.create()
	for_of_fixture(mut vm)!
	mut script := Script.parse('for(const value of [1,2,3]){while(true){}}', vm.realm(), 'for-of-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 50 }) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert for_of_eval(mut vm, '6*7')!.number == 42
		mut executable := script.compile(mut vm)!
		for mut instruction in executable.instructions {
			if instruction.op == .sync_iterator_next {
				instruction.target = executable.bytecode_length
				break
			}
		}
		executable.validate(0) or {
			assert err.msg().contains('Jump target out of range')
			return
		}
		assert false, 'Iterator exit target must be validated'
		return
	}
	assert false, 'for-of must share the caller instruction budget'
}
