module libjs

// Translated from LibJS/Runtime/DeclarativeEnvironment.{h,cpp}. The upstream
// environment-shape cache and parallel binding vectors are folded into one
// binding list; deleted bindings keep their slot so indices stay stable.

pub struct DeclarativeBinding {
pub mut:
	name           Utf16String
	value          Value
	strict         bool
	mutable_       bool
	can_be_deleted bool
	initialized    bool
	deleted        bool
}

@[heap]
pub struct DeclarativeEnvironment {
	EnvironmentBase
pub mut:
	bindings          []DeclarativeBinding
	catch_environment bool
	serial_number     u64
}

pub fn DeclarativeEnvironment.create(outer ?Environment) &DeclarativeEnvironment {
	return &DeclarativeEnvironment{
		kind:        .declarative
		outer:       outer
		declarative: true
	}
}

fn (environment &DeclarativeEnvironment) find_binding_index(name Utf16String) int {
	for index, binding in environment.bindings {
		if !binding.deleted && binding.name == name {
			return index
		}
	}
	return -1
}

pub fn (environment &DeclarativeEnvironment) is_catch_environment() bool {
	return environment.catch_environment
}

pub fn (mut environment DeclarativeEnvironment) set_is_catch_environment(value bool) {
	environment.catch_environment = value
}

pub fn (environment &DeclarativeEnvironment) environment_serial_number() u64 {
	return environment.serial_number
}

pub fn (environment &DeclarativeEnvironment) binding_count() int {
	return environment.bindings.count(!it.deleted)
}

// This is not a method defined in the spec; upstream keeps it for debugging.
pub fn (environment &DeclarativeEnvironment) binding_names() []Utf16String {
	mut names := []Utf16String{}
	for binding in environment.bindings {
		if !binding.deleted {
			names << binding.name
		}
	}
	return names
}

pub fn (environment &DeclarativeEnvironment) has_binding_named(name Utf16String) bool {
	return environment.find_binding_index(name) >= 0
}

pub fn (environment &DeclarativeEnvironment) binding_is_mutable_by_name(name Utf16String) bool {
	index := environment.find_binding_index(name)
	if index < 0 {
		panic('binding_is_mutable_by_name: no binding named ${name.str()}')
	}
	return environment.bindings[index].mutable_
}

// 9.1.1.1.1 HasBinding ( N ), https://tc39.es/ecma262/#sec-declarative-environment-records-hasbinding-n
pub fn (environment &DeclarativeEnvironment) has_binding(mut vm VM, name Utf16String) !(bool, ?int) {
	index := environment.find_binding_index(name)
	if index < 0 {
		return false, none
	}
	if environment.is_permanently_screwed_by_eval() {
		return true, none
	}
	return true, index
}

// 9.1.1.1.2 CreateMutableBinding ( N, D ), https://tc39.es/ecma262/#sec-declarative-environment-records-createmutablebinding-n-d
pub fn (mut environment DeclarativeEnvironment) create_mutable_binding(mut vm VM, name Utf16String, can_be_deleted bool) ! {
	// 1. Assert: envRec does not already have a binding for N.
	// NOTE: Upstream skips this to avoid an O(n) traversal.
	// 2. Create a mutable binding in envRec for N and record that it is uninitialized.
	environment.bindings << DeclarativeBinding{
		name:           name
		mutable_:       true
		can_be_deleted: can_be_deleted
	}
	environment.serial_number++
	// 3. Return unused.
}

// 9.1.1.1.3 CreateImmutableBinding ( N, S ), https://tc39.es/ecma262/#sec-declarative-environment-records-createimmutablebinding-n-s
pub fn (mut environment DeclarativeEnvironment) create_immutable_binding(mut vm VM, name Utf16String, strict bool) ! {
	// 2. Create an immutable binding in envRec for N and record that it is uninitialized.
	//    If S is true, record that the newly created binding is a strict binding.
	environment.bindings << DeclarativeBinding{
		name:   name
		strict: strict
	}
	environment.serial_number++
	// 3. Return unused.
}

// 9.1.1.1.4 InitializeBinding ( N, V ), https://tc39.es/ecma262/#sec-declarative-environment-records-initializebinding-n-v
pub fn (mut environment DeclarativeEnvironment) initialize_binding(mut vm VM, name Utf16String, value Value, hint InitializeBindingHint) ! {
	index := environment.find_binding_index(name)
	if index < 0 {
		panic('InitializeBinding: no binding named ${name.str()}')
	}
	return environment.initialize_binding_direct(mut vm, index, value, hint)
}

pub fn (mut environment DeclarativeEnvironment) initialize_binding_direct(mut vm VM, index int, value Value, hint InitializeBindingHint) ! {
	// 1. Assert: envRec must have an uninitialized binding for N.
	if environment.bindings[index].initialized {
		panic('InitializeBinding: binding ${environment.bindings[index].name.str()} is already initialized')
	}
	if value.is_special_empty_value() {
		panic('InitializeBinding: the special empty value cannot initialize a binding')
	}
	// 2. If hint is not normal, perform ? AddDisposableResource(envRec.[[DisposeCapability]], V, hint).
	if hint != .normal {
		return vm.throw_error(.internal_error, 'Disposable bindings require the explicit resource management translation')
	}
	// 3. Set the bound value for N in envRec to V.
	environment.bindings[index].value = value
	environment.bindings[index].initialized = true
	// 5. Return unused.
}

// 9.1.1.1.5 SetMutableBinding ( N, V, S ), https://tc39.es/ecma262/#sec-declarative-environment-records-setmutablebinding-n-v-s
pub fn (mut environment DeclarativeEnvironment) set_mutable_binding(mut vm VM, name Utf16String, value Value, strict bool) ! {
	// 1. If envRec does not have a binding for N, then
	index := environment.find_binding_index(name)
	if index < 0 {
		// a. If S is true, throw a ReferenceError exception.
		if strict {
			return vm.throw_error_type(.reference_error, .unknown_identifier, name.str())
		}
		// b. Perform ! envRec.CreateMutableBinding(N, true).
		environment.create_mutable_binding(mut vm, name, true)!
		// c. Perform ! envRec.InitializeBinding(N, V, normal).
		environment.initialize_binding(mut vm, name, value, .normal)!
		// d. Return unused.
		return
	}
	// 2-5. (extracted into a non-standard function below)
	environment.set_mutable_binding_direct(mut vm, index, value, strict)!
	// 6. Return unused.
}

pub fn (mut environment DeclarativeEnvironment) set_mutable_binding_direct(mut vm VM, index int, value Value, strict_argument bool) ! {
	mut strict := strict_argument
	binding := environment.bindings[index]
	// 2. If the binding for N in envRec is a strict binding, set S to true.
	if binding.strict {
		strict = true
	}
	// 3. If the binding for N in envRec has not yet been initialized, throw a ReferenceError exception.
	if !binding.initialized {
		return vm.throw_error_type(.reference_error, .binding_not_initialized, binding.name.str())
	}
	// 4. Else if the binding for N in envRec is a mutable binding, change its bound value to V.
	if binding.mutable_ {
		environment.bindings[index].value = value
	} else if strict {
		// 5. Else, if S is true, throw a TypeError exception.
		return vm.throw_error_type(.type_error, .invalid_assign_to_const)
	}
}

// 9.1.1.1.6 GetBindingValue ( N, S ), https://tc39.es/ecma262/#sec-declarative-environment-records-getbindingvalue-n-s
pub fn (mut environment DeclarativeEnvironment) get_binding_value(mut vm VM, name Utf16String, strict bool) !Value {
	// 1. Assert: envRec has a binding for N.
	index := environment.find_binding_index(name)
	if index < 0 {
		panic('GetBindingValue: no binding named ${name.str()}')
	}
	// 2-3. (extracted into a non-standard function below)
	return environment.get_binding_value_direct(mut vm, index)
}

pub fn (environment &DeclarativeEnvironment) get_binding_value_direct(mut vm VM, index int) !Value {
	binding := environment.bindings[index]
	// 2. If the binding for N in envRec is an uninitialized binding, throw a ReferenceError exception.
	if !binding.initialized {
		return vm.throw_error_type(.reference_error, .binding_not_initialized, binding.name.str())
	}
	// 3. Return the value currently bound to N in envRec.
	return binding.value
}

// 9.1.1.1.7 DeleteBinding ( N ), https://tc39.es/ecma262/#sec-declarative-environment-records-deletebinding-n
pub fn (mut environment DeclarativeEnvironment) delete_binding(mut vm VM, name Utf16String) !bool {
	// 1. Assert: envRec has a binding for the name that is the value of N.
	index := environment.find_binding_index(name)
	if index < 0 {
		panic('DeleteBinding: no binding named ${name.str()}')
	}
	// 2. If the binding for N in envRec cannot be deleted, return false.
	if !environment.bindings[index].can_be_deleted {
		return false
	}
	// 3. Remove the binding for N from envRec.
	// NOTE: The slot stays in place so indices of later bindings do not move.
	environment.bindings[index].deleted = true
	environment.bindings[index].name = Utf16String.new()
	environment.serial_number++
	// 4. Return true.
	return true
}

pub fn (mut environment DeclarativeEnvironment) initialize_or_set_mutable_binding(mut vm VM, name Utf16String, value Value) ! {
	index := environment.find_binding_index(name)
	if index < 0 {
		panic('initialize_or_set_mutable_binding: no binding named ${name.str()}')
	}
	if !environment.bindings[index].initialized {
		environment.initialize_binding_direct(mut vm, index, value, .normal)!
	} else {
		environment.set_mutable_binding_direct(mut vm, index, value, false)!
	}
}
