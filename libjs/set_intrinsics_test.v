// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn set_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'set.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 }) or {
		if is_throw_completion(err) { return error(thrown_value(err).as_object().error_message() or { thrown_value(err).str() }) }
		return err
	}
}

fn test_set_same_value_zero_identity_and_no_user_coercion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert set_eval(mut vm, 'var a={},b={};a.toString=function(){throw 1};var s=new Set([NaN,NaN,-0,+0,a,b,a,undefined]);s.size===5&&s.has(NaN)&&s.has(0)&&s.has(a)&&s.add(1)===s&&s.delete(b)&&!s.delete(b)&&!s.has(b)')!.as_bool()
	assert set_eval(mut vm, 'var z=new Set([-0]);1/z.values().next().value===Infinity')!.as_bool()
	assert set_eval(mut vm, 'new Set("A😀A").size===2&&new Set(null).size===0')!.as_bool()
}

fn test_set_iteration_is_live_ordered_and_stays_exhausted() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert set_eval(mut vm, 'var s=new Set([1,2,3]);var it=s.values();var out=it.next().value;s.delete(2);s.add(4);out+":"+it.next().value+":"+it.next().value')!.as_string().str() == '1:3:4'
	assert set_eval(mut vm, 's.clear();s.add(5);var value=it.next().value;var done=it.next().done;s.add(6);value===5&&done&&it.next().done')!.as_bool()
	assert set_eval(mut vm, 'var s=new Set([2,1]);var out="";for(var entry of s.entries()){out+=entry[0]+":"+entry[1]+","};out')!.as_string().str() == '2:2,1:1,'
	assert set_eval(mut vm, 's.keys===s.values&&s.values===s[Symbol.iterator]&&s[Symbol.iterator]()[Symbol.iterator]() instanceof Object&&Object.prototype.toString.call(s)==="[object Set]"')!.as_bool()
}

fn test_set_for_each_observes_mutations_and_callback_receiver() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert set_eval(mut vm, 'var s=new Set([1,2,3]),ctx={},out="";s.forEach(function(v,k,self){if(v!==k||self!==s||this!==ctx)throw 1;out+=v;if(v===1){s.delete(2);s.add(4)}if(v===3){s.clear();s.add(5)}},ctx);out+":"+s.size')!.as_string().str() == '135:1'
	assert set_eval(mut vm, 'var caught=false;try{Set.prototype.add.call({},1)}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	assert set_eval(mut vm, 'var caught=false;try{Set()}catch(e){caught=e instanceof TypeError};caught&&Set[Symbol.species]===Set')!.as_bool()
}

fn test_set_constructor_observes_adder_and_closes_on_its_exception() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert set_eval(mut vm, 'var original=Set.prototype.add,closed=0,reason={},source={};source[Symbol.iterator]=function(){return {next:function(){return {value:1}},return:function(){closed++;throw 99}}};Set.prototype.add=function(){throw reason};var caught=false;try{new Set(source)}catch(e){caught=e===reason};Set.prototype.add=original;caught&&closed===1')!.as_bool()
	assert set_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next:function(){throw reason},return:function(){closed++;return {}}}};try{new Set(source)}catch(e){caught=e===reason};caught&&closed===0')!.as_bool()
	assert set_eval(mut vm, 'var observed=0;source[Symbol.iterator]=function(){observed++;return {next:function(){return {done:true}}}};Set.prototype.add=0;try{new Set(source)}catch(e){caught=e instanceof TypeError};Set.prototype.add=original;caught&&observed===0')!.as_bool()
}
