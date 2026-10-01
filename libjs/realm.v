module libjs

import math

// Translated from LibJS/Runtime/Realm.{h,cpp}. The Intrinsics prototype graph
// and remaining global bindings belong to the pending builtin translation.
// The ordinary global object supplies value/function properties and Boolean/Symbol.

pub interface RealmHostDefined {
	is_principal_host_defined() bool
	is_synthetic_host_defined() bool
}

// 9.3 Realms, https://tc39.es/ecma262/#realm-record
@[heap]
pub struct Realm {
pub mut:
	global_object                  ?&Object                 // [[GlobalObject]]
	global_environment             ?&GlobalEnvironment      // [[GlobalEnv]]
	global_declarative_environment ?&DeclarativeEnvironment // Cached from GlobalEnv
	host_defined                   ?RealmHostDefined        // [[HostDefined]]
	function_prototype ?&Object // Translated intrinsic; Object prototype graph pending
	throw_type_error_function ?&Object
	boolean_prototype ?&Object
	boolean_constructor ?&Object
	symbol_prototype ?&Object
	symbol_constructor ?&Object
}

pub fn Realm.create() &Realm {
	return &Realm{}
}

pub fn (realm &Realm) global_object_record() &Object {
	return realm.global_object or { panic('Realm has no global object yet') }
}

pub fn (realm &Realm) global_environment_record() &GlobalEnvironment {
	return realm.global_environment or { panic('Realm has no global environment yet') }
}

pub fn (realm &Realm) function_prototype_record() &Object {
	return realm.function_prototype or { panic('Realm has no Function prototype yet') }
}

pub fn (realm &Realm) boolean_prototype_record() &Object {
	return realm.boolean_prototype or { panic('Realm has no Boolean prototype yet') }
}

pub fn (realm &Realm) boolean_constructor_record() &Object {
	return realm.boolean_constructor or { panic('Realm has no Boolean constructor yet') }
}

pub fn (realm &Realm) symbol_prototype_record() &Object {
	return realm.symbol_prototype or { panic('Realm has no Symbol prototype yet') }
}

pub fn (realm &Realm) symbol_constructor_record() &Object {
	return realm.symbol_constructor or { panic('Realm has no Symbol constructor yet') }
}

pub fn (mut realm Realm) set_global_environment(environment &GlobalEnvironment) {
	realm.global_environment = environment
	realm.global_declarative_environment = environment.declarative_record
}

pub struct RealmGlobalHooks {
pub:
	create_global_object     fn (realm &Realm) &Object = unsafe { nil }
	create_global_this_value fn (realm &Realm) &Object = unsafe { nil }
}

// 9.3.1 InitializeHostDefinedRealm ( ), https://tc39.es/ecma262/#sec-initializehostdefinedrealm
// The returned context stays pushed on the VM's execution context stack.
pub fn initialize_host_defined_realm(mut vm VM, hooks RealmGlobalHooks) !&ExecutionContext {
	// 1. Let realm be a new Realm Record.
	mut realm := Realm.create()
	// 2. Perform CreateIntrinsics(realm).
	// Intrinsics.cpp: initialize the translated Function prototype and shared
	// thrower before exposing them to global creation hooks. The remaining
	// intrinsic graph, including %Object.prototype%, is pending.
	function_prototype := FunctionPrototype.create(mut vm, realm, none)
	realm.function_prototype = function_prototype.object
	thrower := create_throw_type_error_function(mut vm, realm, function_prototype.object)
	realm.throw_type_error_function = thrower
	mut prototype_object := function_prototype.object
	prototype_object.add_restricted_function_properties(thrower)
	boolean_prototype := BooleanPrototype.create(mut vm, realm, none)
	realm.boolean_prototype = boolean_prototype.object
	boolean_constructor := BooleanConstructor.create(mut vm, realm)
	realm.boolean_constructor = boolean_constructor.object
	// Intrinsics.cpp::initialize_constructor installs the companion back-reference.
	mut boolean_prototype_object := boolean_prototype.object
	boolean_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(boolean_constructor.object), attribute_writable | attribute_configurable)
	symbol_prototype := SymbolPrototype.create(mut vm, realm, none)
	realm.symbol_prototype = symbol_prototype.object
	symbol_constructor := SymbolConstructor.create(mut vm, realm)
	realm.symbol_constructor = symbol_constructor.object
	mut symbol_prototype_object := symbol_prototype.object
	symbol_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(symbol_constructor.object), attribute_writable | attribute_configurable)
	// 4. Set realm.[[GlobalObject]] to undefined.
	// 5. Set realm.[[GlobalEnv]] to undefined.
	// 7. Let newContext be a new execution context.
	mut new_context := ExecutionContext.create(0, []Value{}, 0)
	// 8. Set the Function of newContext to null.
	new_context.function = none
	// 9. Set the Realm of newContext to realm.
	new_context.realm = realm
	// 10. Set the ScriptOrModule of newContext to null.
	new_context.script_or_module = ScriptOrModule{}
	// 11. Push newContext onto the execution context stack; newContext is now the running execution context.
	vm.push_execution_context(mut new_context)
	// 12. If the host requires use of an exotic object to serve as realm's global object, then
	mut global := if hooks.create_global_object != unsafe { nil } {
		// a. Let global be such an object created in a host-defined manner.
		hooks.create_global_object(realm)
	} else {
		// 13. Else, a. Let global be OrdinaryObjectCreate(realm.[[Intrinsics]].[[%Object.prototype%]]).
		// NOTE: %Object.prototype% is part of the pending intrinsics translation.
		Object.create(realm, none)
	}
	global.class_name = 'GlobalObject'
	// 14. If the host requires that the this binding in realm's global scope return an object other than the global object, then
	this_value := if hooks.create_global_this_value != unsafe { nil } {
		// a. Let thisValue be such an object created in a host-defined manner.
		hooks.create_global_this_value(realm)
	} else {
		// 15. Else, a. Let thisValue be global.
		global
	}
	// 16. Set realm.[[GlobalObject]] to global.
	realm.global_object = global
	// 17. Set realm.[[GlobalEnv]] to NewGlobalEnvironment(global, thisValue).
	realm.set_global_environment(GlobalEnvironment.create(global, this_value))
	// 18. Perform ? SetDefaultGlobalBindings(realm).
	set_default_global_numeric_functions(mut vm, realm)
	set_default_global_uri_functions(mut vm, realm)
	set_default_global_value_bindings(realm)
	// GlobalObject.cpp installs intrinsic constructor properties after values.
	// Eager materialization replaces the engine-private intrinsic accessor map.
	global.define_direct_property(PropertyName.from_str('Boolean'),
		Value.from_object(realm.boolean_constructor_record()), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Symbol'),
		Value.from_object(realm.symbol_constructor_record()), attribute_writable | attribute_configurable)
	set_default_global_legacy_functions(mut vm, realm)
	// 19. Create any host-defined global object properties on global.
	// 20. Return unused.
	return new_context
}

// Runtime/GlobalObject.cpp::set_default_global_bindings, value properties only.
// Other intrinsic constructors and their prototypes remain separate runtime work.
fn set_default_global_value_bindings(realm &Realm) {
	mut global := realm.global_object_record()
	global.define_direct_property(PropertyName.from_str('globalThis'),
		Value.from_object(realm.global_environment_record().global_this_value),
		attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Infinity'), Value.from_f64(math.inf(1)), 0)
	global.define_direct_property(PropertyName.from_str('NaN'), Value.from_f64(math.nan()), 0)
	global.define_direct_property(PropertyName.from_str('undefined'), js_undefined(), 0)
}

// create_simple_execution_context<GlobalObjectType>(VM&)
pub fn create_simple_execution_context(mut vm VM) &ExecutionContext {
	return initialize_host_defined_realm(mut vm, RealmGlobalHooks{}) or {
		panic('InitializeHostDefinedRealm failed: ${err.msg()}')
	}
}
