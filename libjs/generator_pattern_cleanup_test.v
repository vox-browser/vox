// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn generator_pattern_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'generator-pattern-cleanup.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_generator_return_closes_binding_and_assignment_pattern_iterators_before_finally() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_pattern_eval(mut vm, 'var log="",body=0,source={};source[Symbol.iterator]=()=>({next(){return {value:undefined}},return(){log+="array;";return {}}});function* g(){try{let [value=yield 1]=source;body++}finally{log+="finally;"}}var i=g();i.next();var r=i.return(42);r.done&&r.value===42&&body===0&&log==="array;finally;"')!.as_bool()
	assert generator_pattern_eval(mut vm, 'log="";var value;function* assign(){try{[value=yield 1]=source;body++}finally{log+="finally;"}}var i=assign();i.next();var r=i.return(42);r.done&&r.value===42&&value===undefined&&body===0&&log==="array;finally;"')!.as_bool()
}

fn test_generator_return_during_member_target_evaluation_closes_before_any_step_or_write() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_pattern_eval(mut vm, 'var nexts=0,closed=0,target={},source={};source[Symbol.iterator]=()=>({next(){nexts++;return {value:42}},return(){closed++;return {}}});function* g(){[target[yield "key"]]=source}var i=g();var first=i.next(),last=i.return(7);first.value==="key"&&last.done&&last.value===7&&nexts===0&&closed===1&&Object.keys(target).length===0')!.as_bool()
}

fn test_generator_return_in_for_of_binding_default_closes_inner_then_outer_iterator() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_pattern_eval(mut vm, 'var log="",body=0,inner={},outer={};inner[Symbol.iterator]=()=>({next(){return {value:undefined}},return(){log+="inner;";return {}}});outer[Symbol.iterator]=()=>({next(){return {value:inner}},return(){log+="outer;";return {}}});function* g(){try{for(const [value=yield 1] of outer){body++}}finally{log+="finally;"}}var i=g();i.next();var result=i.return(42);result.done&&result.value===42&&body===0&&log==="inner;outer;finally;"')!.as_bool()
}

fn test_generator_pattern_close_error_overrides_return_but_still_closes_outer_iterator() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_pattern_eval(mut vm, 'var log="",marker={},inner={},outer={};inner[Symbol.iterator]=()=>({next(){return {value:undefined}},return(){log+="inner;";throw marker}});outer[Symbol.iterator]=()=>({next(){return {value:inner}},return(){log+="outer;";throw 9}});function* g(){try{let [[value=yield 1]]=outer}finally{log+="finally;"}}var i=g();i.next();var same=false;try{i.return(42)}catch(e){same=e===marker}same&&i.next().done&&log==="inner;outer;finally;"')!.as_bool()
}
