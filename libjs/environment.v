module libjs

// Translated from LibJS/Runtime/Environment.{h,cpp} and the environment records
// the VM resolves bindings through. Upstream environments are GC cells with
// virtual methods; here Environment is an interface and EnvironmentBase carries
// the shared [[OuterEnv]] and eval-poisoning state.

pub enum InitializeBindingHint {
	normal
	sync_dispose
	async_dispose
}

pub enum ThisBindingStatus {
	lexical
	initialized
	uninitialized
}

pub enum EnvironmentKind {
	declarative
	function
	object
	global
	module
}

pub interface Environment {
	has_this_binding() bool
	get_this_binding(mut vm VM) !Value
	with_base_object() ?&Object
	outer_environment() ?Environment
	is_declarative_environment() bool
	is_global_environment() bool
	is_function_environment() bool
	is_object_environment() bool
	is_catch_environment() bool
	is_permanently_screwed_by_eval() bool
	// HasBinding also reports the binding index for declarative environments so
	// callers can cache an EnvironmentCoordinate.
	has_binding(mut vm VM, name Utf16String) !(bool, ?int)
mut:
	create_mutable_binding(mut vm VM, name Utf16String, can_be_deleted bool) !
	create_immutable_binding(mut vm VM, name Utf16String, strict bool) !
	initialize_binding(mut vm VM, name Utf16String, value Value, hint InitializeBindingHint) !
	set_mutable_binding(mut vm VM, name Utf16String, value Value, strict bool) !
	get_binding_value(mut vm VM, name Utf16String, strict bool) !Value
	delete_binding(mut vm VM, name Utf16String) !bool
	set_permanently_screwed_by_eval()
}

pub struct EnvironmentBase {
pub mut:
	kind        EnvironmentKind
	outer       ?Environment // [[OuterEnv]]
	declarative bool
	// Set on environments within a function when direct eval() runs in that
	// function; it propagates up to the function boundary and disables caching.
	permanently_screwed_by_eval bool
	// [[ThisBindingStatus]] belongs to FunctionEnvironment; it lives here to pack.
	this_binding_status ThisBindingStatus = .uninitialized
}

pub fn (base &EnvironmentBase) has_this_binding() bool {
	return false
}

pub fn (base &EnvironmentBase) get_this_binding(mut vm VM) !Value {
	return js_undefined()
}

pub fn (base &EnvironmentBase) with_base_object() ?&Object {
	return none
}

pub fn (base &EnvironmentBase) outer_environment() ?Environment {
	return base.outer
}

pub fn (base &EnvironmentBase) is_declarative_environment() bool {
	return base.declarative
}

pub fn (base &EnvironmentBase) is_global_environment() bool {
	return base.kind == .global
}

pub fn (base &EnvironmentBase) is_function_environment() bool {
	return base.kind == .function
}

pub fn (base &EnvironmentBase) is_object_environment() bool {
	return base.kind == .object
}

pub fn (base &EnvironmentBase) is_catch_environment() bool {
	return false
}

pub fn (base &EnvironmentBase) is_permanently_screwed_by_eval() bool {
	return base.permanently_screwed_by_eval
}

pub fn (mut base EnvironmentBase) set_permanently_screwed_by_eval() {
	if base.permanently_screwed_by_eval {
		return
	}
	base.permanently_screwed_by_eval = true
	// Stop propagation at function or global boundaries. Eval can only inject
	// vars into its containing function's variable environment.
	if base.is_function_environment() || base.is_global_environment() {
		return
	}
	mut outer := base.outer or { return }
	outer.set_permanently_screwed_by_eval()
}

// Interface values store the object pointer first; this recovers it so records
// can be compared and rooted by identity like upstream GC pointers.
pub fn environment_identity(environment Environment) voidptr {
	return unsafe { *(&voidptr(&environment)) }
}

pub fn same_environment(a Environment, b Environment) bool {
	return environment_identity(a) == environment_identity(b)
}

// 9.4.3 GetThisEnvironment ( ), https://tc39.es/ecma262/#sec-getthisenvironment
pub fn get_this_environment(vm &VM) Environment {
	// 1. Let env be the running execution context's LexicalEnvironment.
	mut environment := vm.lexical_environment()
	// 2. Repeat,
	for {
		env := environment or { break }
		// a. Let exists be env.HasThisBinding().
		// b. If exists is true, return env.
		if env.has_this_binding() {
			return env
		}
		// c. Let outer be env.[[OuterEnv]].
		// d. Assert: outer is not null.
		// e. Set env to outer.
		environment = env.outer_environment()
	}
	panic('GetThisEnvironment: no environment in the chain has a this binding')
}
