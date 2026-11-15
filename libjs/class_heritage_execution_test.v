// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn heritage_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'heritage.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000}) or {
		if is_throw_completion(err) { return error(thrown_value(err).as_object().error_message() or { thrown_value(err).str() }) }
		return err
	}
}

fn check_heritage(source string) !bool {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	return heritage_eval(mut vm, source)!.as_bool()
}

fn test_derived_classes_inherit_prototypes_static_methods_and_forward_new_target() {
	assert check_heritage('class Base{constructor(v){this.value=v;this.target=new.target}read(){return this.value}static self(){return this}}class Child extends Base{}var c=new Child(42);c.read()===42&&c.target===Child&&c instanceof Child&&c instanceof Base&&Child.self()===Child&&Object.getPrototypeOf(Child)===Base&&Object.getPrototypeOf(Child.prototype)===Base.prototype&&Child.length===0')!
	assert check_heritage('function Parent(v){this.value=v;this.target=new.target};class Derived extends Parent{constructor(v=40){super(v+2)}}var c=new Derived();c.value===42&&c.target===Derived&&c instanceof Parent&&c instanceof Derived')!
	assert check_heritage('class ChildObject extends Object{}var c=new ChildObject(42);c instanceof ChildObject&&Object.getPrototypeOf(c)===ChildObject.prototype')!
	assert check_heritage('function Box(){this.target=(()=>new.target)()};var b=new Box();b.target===Box&&Box()===undefined&&globalThis.target===undefined')!
	assert check_heritage('Array.prototype[Symbol.iterator]=function(){throw 9};class B{constructor(){this.value=arguments[0]}}class C extends B{};new C(42).value===42')!
}

fn test_derived_constructor_this_and_return_rules() {
	assert check_heritage('class B{}class C extends B{constructor(){var caught=false;try{this.x=1}catch(e){caught=e instanceof ReferenceError};super();this.answer=caught?42:0}}new C().answer===42')!
	assert check_heritage('class C extends Object{constructor(){return {answer:42}}};new C().answer===42')!
	assert check_heritage('class C extends null{constructor(){return {answer:42}}};new C().answer===42&&Object.getPrototypeOf(C.prototype)===null&&Object.getPrototypeOf(C)===Object.getPrototypeOf(Object)')!
	for body in ['return 1', 'super();return null', 'super();return false'] {
		assert check_heritage('class C extends Object{constructor(){'+body+'}};var caught=false;try{new C()}catch(e){caught=e instanceof TypeError};caught')!
	}
	for body in ['', 'return undefined'] {
		assert check_heritage('class C extends Object{constructor(){'+body+'}};var caught=false;try{new C()}catch(e){caught=e instanceof ReferenceError};caught')!
	}
	assert check_heritage('class C extends null{};var caught=false;try{new C()}catch(e){caught=e instanceof TypeError};caught')!
	assert check_heritage('class B{constructor(){return {answer:42}}}class C extends B{constructor(){super()}};new C().answer===42')!
}

fn test_super_call_retains_callee_before_arguments_and_constructs_before_binding_this() {
	assert check_heritage('function A(){this.kind=1};function B(){this.kind=2};class C extends A{constructor(){super(Object.setPrototypeOf(C,B))}}var first=new C(),second=new C();first.kind===1&&second.kind===2')!
	assert check_heritage('var count=0;class B{constructor(){this.id=++count}}class C extends B{constructor(){super();try{super()}catch(e){this.error=e instanceof ReferenceError}}};var c=new C();count===2&&c.id===1&&c.error')!
	assert check_heritage('class B{constructor(v){this.value=v}}class C extends B{constructor(){(()=>super(42))()}};new C().value===42')!
	assert check_heritage('var count=0;class C extends Object{constructor(){super(count++)}};Object.setPrototypeOf(C,{});var caught=false;try{new C()}catch(e){caught=e instanceof TypeError};caught&&count===1')!
}

fn test_heritage_validation_observable_order_and_class_name_tdz() {
	for value in ['undefined', '1', '{}', '(()=>1)'] {
		assert check_heritage('var caught=false;try{class C extends '+value+'{}}catch(e){caught=e instanceof TypeError};caught')!
	}
	assert check_heritage('function B(){};B.prototype=1;var caught=false;try{class C extends B{}}catch(e){caught=e instanceof TypeError};caught')!
	assert check_heritage('var Self=Object,caught=false;try{var C=class Self extends Self{}}catch(e){caught=e instanceof ReferenceError};caught')!
	assert check_heritage('var order="";function base(){order+="b";return Object};function key(){order+="k";return "read"};class C extends base(){[key()](){return 42}};order==="bk"&&new C().read()===42')!
}

fn test_derived_classes_execute_from_native_cache_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-heritage-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert heritage_eval(mut vm, 'class B{constructor(v){this.value=v}read(){return this.value}}class C extends B{constructor(v=40){super(v+2)}};new C().read()')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 4 && stats.compiler_invocations == 0 && activity.entries >= 4 }
		vm.close_native_code()!
	}
}
