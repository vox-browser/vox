// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn for_in_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'for-in.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_for_in_preserves_own_key_order_and_prototype_shadowing_without_value_getters() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert for_in_eval(mut vm, 'var p={inherited:1,hidden:2,a:3};var o=Object.create(p);o.b=4;o[2]=5;o[1]=6;o.a=7;Object.defineProperty(o,"hidden",{value:8});o[Symbol("skip")]=9;var keys="";for(var k in o){keys+=k+","};keys')!.as_string().str() == '1,2,b,a,inherited,'
	assert for_in_eval(mut vm, 'var calls=0;Object.defineProperty(o,"live",{enumerable:true,get:function(){calls++;throw 42}});var found=false;for(var k in o){if(k==="live")found=true};found+":"+calls+":"+typeof k')!.as_string().str() == 'true:0:string'
}

fn test_for_in_snapshots_names_skips_deletions_and_does_not_add_new_names() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert for_in_eval(mut vm, 'var o={first:1,last:2};var visited="";for(var k in o){visited+=k+",";delete o.last;o.added=3};visited')!.as_string().str() == 'first,'
	assert for_in_eval(mut vm, 'var p={inherited:1};var child=Object.create(p);child.own=2;var names="";for(var k in child){names+=k+",";delete p.inherited};names')!.as_string().str() == 'own,'
	assert for_in_eval(mut vm, 'var a=[];for(var k in [1,,3]){a.push(k)};a.join(",")')!.as_string().str() == '0,2'
}

fn test_for_in_var_hoisting_primitive_wrapping_nullish_and_assignment_targets() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert for_in_eval(mut vm, 'function f(){var before=typeof key;for(var key in {a:1,b:2}){};return before+":"+key};f()')!.as_string().str() == 'undefined:b'
	assert for_in_eval(mut vm, 'var key=42;for(var key in null){};for(var key in undefined){};key')!.number == 42
	assert for_in_eval(mut vm, 'var out="";for(var k in "ab"){out+=k};for(var k in 42){out+="bad"};out')!.as_string().str() == '01'
	assert for_in_eval(mut vm, 'var holder={};var count=0;for(holder[count++] in {x:1,y:2}){};holder[0]+holder[1]+":"+count')!.as_string().str() == 'xy:2'
	assert for_in_eval(mut vm, 'var x=1;for(var x=42 in null){};x')!.number == 42
}

fn test_for_in_lexical_tdz_constants_and_distinct_closure_environments() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert for_in_eval(mut vm, 'var callbacks=[];for(let key in {a:1,b:2,c:3}){callbacks.push(function(){return key})};callbacks[0]()+callbacks[1]()+callbacks[2]()+":"+typeof key')!.as_string().str() == 'abc:undefined'
	assert for_in_eval(mut vm, 'var lengths=0;for(const {length:n} in {aa:1,bbbb:2}){lengths+=n};lengths')!.number == 6
	assert for_in_eval(mut vm, 'var outside=42;var caught=false;try{for(let outside in outside){}}catch(e){caught=e instanceof ReferenceError};outside+":"+caught')!.as_string().str() == '42:true'
	assert for_in_eval(mut vm, 'var immutable=false;try{for(const k in {a:1}){k="b"}}catch(e){immutable=e instanceof TypeError};immutable')!.as_bool()
}

fn test_for_in_break_continue_return_and_errors_restore_enclosing_scopes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert for_in_eval(mut vm, 'var seen="";for(let k in {a:1,b:2,c:3,d:4}){let local=k;if(k==="a")continue;if(k==="c")break;seen+=local};seen+":"+typeof local+":"+typeof k')!.as_string().str() == 'b:undefined:undefined'
	assert for_in_eval(mut vm, 'function first(){for(const k in {answer:42}){return k};return "missing"};first()')!.as_string().str() == 'answer'
	assert for_in_eval(mut vm, 'var outer="safe";try{for(let outer in {a:1}){let inner=1;throw outer}}catch(e){outer+=e};outer+":"+typeof inner')!.as_string().str() == 'safea:undefined'
	assert for_in_eval(mut vm, 'var nested="";for(let a in {x:1,y:2}){for(let b in {a:1,b:2}){if(b==="a")continue;nested+=a+b}};nested')!.as_string().str() == 'xbyb'
}

fn test_for_in_module_lexical_bindings_and_live_export_updates() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('export let result="";for(const k in {a:1,b:2}){result+=k}', vm.realm(), 'for-in.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	assert record.export_value(mut vm, utf16_string('result'))!.as_string().str() == 'ab'
}

fn test_for_in_enumeration_consumes_shared_budget_and_invalid_targets_are_rejected() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	for index in 0 .. 200 {
		object.define_direct_property(PropertyName.from_number(u32(index)), Value.from_i32(1), attribute_enumerable)
	}
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('many'), Value.from_object(object), 0)
	mut script := Script.parse('for(var k in many){}', vm.realm(), 'for-in-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 20 }) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert for_in_eval(mut vm, '6*7')!.number == 42
		mut executable := script.compile(mut vm)!
		for mut instruction in executable.instructions {
			if instruction.op == .property_name_iterator_next {
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
	assert false, 'for-in enumeration must share the caller budget'
}
