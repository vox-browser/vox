module libjs

// Translated from LibJS/Runtime/FunctionEnvironment.{h,cpp}. GetSuperBase and
// HasSuperBinding need the ECMAScript function object's [[HomeObject]], which is
// part of the pending function-object translation.

@[heap]
pub struct FunctionEnvironment {
	DeclarativeEnvironment
pub mut:
	this_value      Value           // [[ThisValue]]
	function_object ?FunctionObject // [[FunctionObject]]
	new_target      Value = js_undefined() // [[NewTarget]]
}

pub fn FunctionEnvironment.create(outer ?Environment) &FunctionEnvironment {
	return &FunctionEnvironment{
		kind:        .function
		outer:       outer
		declarative: true
	}
}

pub fn (environment &FunctionEnvironment) this_binding_status() ThisBindingStatus {
	return environment.this_binding_status
}

pub fn (mut environment FunctionEnvironment) set_this_binding_status(status ThisBindingStatus) {
	environment.this_binding_status = status
}

pub fn (mut environment FunctionEnvironment) set_function_object(function FunctionObject) {
	environment.function_object = function
}

pub fn (mut environment FunctionEnvironment) set_new_target(new_target Value) {
	if new_target.is_special_empty_value() {
		panic('set_new_target: the special empty value is not a valid new.target')
	}
	environment.new_target = new_target
}

// 9.1.1.3.1 BindThisValue ( V ), https://tc39.es/ecma262/#sec-bindthisvalue
pub fn (mut environment FunctionEnvironment) bind_this_value(mut vm VM, this_value Value) !Value {
	// 1. Assert: envRec.[[ThisBindingStatus]] is not lexical.
	if environment.this_binding_status == .lexical {
		panic('BindThisValue on a lexical this binding')
	}
	// 2. If envRec.[[ThisBindingStatus]] is initialized, throw a ReferenceError exception.
	if environment.this_binding_status == .initialized {
		return vm.throw_error_type(.reference_error, .this_is_already_initialized)
	}
	// 3. Set envRec.[[ThisValue]] to V.
	environment.this_value = this_value
	// 4. Set envRec.[[ThisBindingStatus]] to initialized.
	environment.this_binding_status = .initialized
	// 5. Return V.
	return this_value
}

// 9.1.1.3.2 HasThisBinding ( ), https://tc39.es/ecma262/#sec-function-environment-records-hasthisbinding
pub fn (environment &FunctionEnvironment) has_this_binding() bool {
	if environment.this_binding_status == .lexical {
		return false
	}
	return true
}

// 9.1.1.3.4 GetThisBinding ( ), https://tc39.es/ecma262/#sec-function-environment-records-getthisbinding
pub fn (environment &FunctionEnvironment) get_this_binding(mut vm VM) !Value {
	// 1. Assert: envRec.[[ThisBindingStatus]] is not lexical.
	if environment.this_binding_status == .lexical {
		panic('GetThisBinding on a lexical this binding')
	}
	// 2. If envRec.[[ThisBindingStatus]] is uninitialized, throw a ReferenceError exception.
	if environment.this_binding_status == .uninitialized {
		return vm.throw_error_type(.reference_error, .this_has_not_been_initialized)
	}
	// 3. Return envRec.[[ThisValue]].
	return environment.this_value
}
