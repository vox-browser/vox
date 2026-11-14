// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn error_intrinsic_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'errors.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_error_intrinsics_use_native_prototype_and_constructor_chains() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	for kind in [ErrorKind.error, .eval_error, .internal_error, .range_error, .reference_error,
		.syntax_error, .type_error, .uri_error] {
		constructor := realm.error_constructors[kind] or { panic('Missing constructor') }
		prototype := realm.error_prototypes[kind] or { panic('Missing prototype') }
		assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == kind.name()
		assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
		assert prototype.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == kind.name()
		assert prototype.error_data == none
		assert voidptr(prototype.internal_get_prototype_of()?) == voidptr(if kind == .error {
			realm.object_prototype_record()
		} else {
			realm.error_prototypes[.error] or { panic('Missing Error prototype') }
		})
		assert voidptr(constructor.internal_get_prototype_of()?) == voidptr(if kind == .error {
			realm.function_prototype_record()
		} else {
			realm.error_constructors[.error] or { panic('Missing Error constructor') }
		})
		global := realm.global_object_record().internal_get_own_property(PropertyName.from_str(kind.name()))?
		assert voidptr(global.value?.as_object()) == voidptr(constructor)
		assert global.writable? && global.configurable? && !global.enumerable?
		for constructed in [false, true] {
			object := if constructed {
				construct(mut vm, Value.from_object(constructor), [Value.from_i32(42)], none)!
			} else {
				call(mut vm, Value.from_object(constructor), js_null(), [Value.from_i32(42)])!.as_object()
			}
			assert object.error_kind()? == kind
			assert voidptr(object.internal_get_prototype_of()?) == voidptr(prototype)
			assert object.error_message()? == '42'
		}
	}
}

fn test_script_errors_and_explicit_errors_are_stringifiable_and_branded() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert error_intrinsic_eval(mut vm, 'String(new TypeError("boom"))+":"+(TypeError("x") instanceof Error)+":"+Error.isError(new RangeError())+":"+Error.isError(Object.create(Error.prototype))')!.as_string().str() == 'TypeError: boom:true:true:false'
	assert error_intrinsic_eval(mut vm, 'try{missingName}catch(e){e instanceof ReferenceError && e instanceof Error && Error.isError(e) && String(e).indexOf("ReferenceError:")===0}')!.as_bool()
	assert error_intrinsic_eval(mut vm, 'var e=Error();Object.hasOwn(e,"message")+":"+e.message+":"+e.name+":"+e.toString()')!.as_string().str() == 'false::Error:Error'
	assert error_intrinsic_eval(mut vm, 'Error.prototype.toString.call({name:"",message:"😀"})+":"+Error.prototype.toString.call({name:"Named"})+":"+Error.prototype.toString.call({message:"x"})')!.as_string().str() == '😀:Named:Error: x'
}

fn test_error_cause_and_message_conversion_follow_specified_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert error_intrinsic_eval(mut vm, 'var order="";var options={};Object.defineProperty(options,"cause",{get:function(){order+="c";return 17}});var e=Error({toString:function(){order+="m";return "message"}},options);var d=Object.getOwnPropertyDescriptor(e,"cause");order+":"+e.message+":"+e.cause+":"+d.enumerable+":"+d.writable+":"+d.configurable')!.as_string().str() == 'mc:message:17:false:true:true'
	assert error_intrinsic_eval(mut vm, 'var inherited=Object.create({cause:undefined});Object.hasOwn(Error(undefined,inherited),"cause")+":"+Object.hasOwn(Error("x",42),"cause")')!.as_string().str() == 'true:false'
	assert error_intrinsic_eval(mut vm, 'var touched=0;var opts={};Object.defineProperty(opts,"cause",{get:function(){touched++;return 1}});try{Error({toString:function(){throw 42}},opts)}catch(e){touched+=e};touched')!.number == 42
	assert error_intrinsic_eval(mut vm, 'var conversion="";var fake={};Object.defineProperty(fake,"name",{get:function(){conversion+="n";return {toString:function(){conversion+="N";return "E"}}}});Object.defineProperty(fake,"message",{get:function(){conversion+="m";return {toString:function(){conversion+="M";return "x"}}}});Error.prototype.toString.call(fake)+":"+conversion')!.as_string().str() == 'E: x:nNmM'
}

fn test_error_stack_getter_caches_and_setter_defines_an_own_data_property() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert error_intrinsic_eval(mut vm, 'var e=new Error("first");var before=e.stack;e.message="changed";(e.stack===before)+":"+(before.indexOf("Error: first\\n")===0)+":"+Object.hasOwn(e,"stack")')!.as_string().str() == 'true:true:false'
	assert error_intrinsic_eval(mut vm, 'e.stack=42;var d=Object.getOwnPropertyDescriptor(e,"stack");e.stack+":"+d.writable+":"+d.enumerable+":"+d.configurable')!.as_string().str() == '42:true:true:true'
	assert error_intrinsic_eval(mut vm, 'Object.getOwnPropertyDescriptor(Error.prototype,"stack").get.call({})')!.is_undefined()
	assert error_intrinsic_eval(mut vm, 'var n=0;try{Object.getOwnPropertyDescriptor(Error.prototype,"stack").set.call({})}catch(e){n++};try{Error.prototype.toString.call(1)}catch(e){n++};n')!.number == 2
}

fn test_error_construction_honors_new_target_before_message_and_foreign_fallback() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	constructor := Value.from_object(local.error_constructors[.type_error] or { panic('Missing TypeError') })
	custom := Object.create(local, none)
	for value in [Value.from_object(custom), js_null(), Value.from_i32(42)] {
		target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
			fn (mut vm VM) !Value { return js_undefined() },
			fn (mut vm VM, target &Object) !&Object { return Object.create(vm.realm(), none) }, 0, PropertyName.from_str('Derived'))
		mut object := target.object
		object.define_direct_property(PropertyName.from_str('prototype'), value, 0)
		created := construct(mut vm, constructor, [Value.from_string(vm.create_string_from_str('x'))], object)!
		assert created.error_kind()? == .type_error
		assert voidptr(created.internal_get_prototype_of()?) == voidptr(if value.is_object() {
			custom
		} else {
			foreign.error_prototypes[.type_error] or { panic('Missing prototype') }
		})
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
