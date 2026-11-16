module libjs

import math

// Translated from LibJS/Runtime/Realm.{h,cpp}. The Intrinsics prototype graph
// and global bindings use the source-defined prototype ancestry.
// The ordinary global object supplies the translated value, function and
// constructor properties.

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
	object_prototype               ?&Object
	object_constructor             ?&Object
	math_object                    ?&Object
	reflect_object                 ?&Object
	proxy_constructor              ?&Object
	intl_object ?&Object
	intl_locale_prototype ?&Object
	intl_locale_constructor ?&Object
	intl_date_time_format_prototype ?&Object
	intl_date_time_format_constructor ?&Object
	intl_list_format_prototype ?&Object
	intl_list_format_constructor ?&Object
	intl_number_format_prototype ?&Object
	intl_number_format_constructor ?&Object
	intl_relative_time_format_prototype ?&Object
	intl_relative_time_format_constructor ?&Object
	intl_collator_prototype ?&Object
	intl_collator_constructor ?&Object
	intl_default_collator ?&IntlCollator
	intl_default_collator_locale string
	intl_default_locale string = 'en-US'
	intl_core_data ?&IntlCoreData
	intl_date_locales map[string]&IntlDateLocaleData
	json_object                    ?&Object
	date_prototype                 ?&Object
	date_constructor               ?&Object
	error_prototypes               map[ErrorKind]&Object
	error_constructors             map[ErrorKind]&Object
	function_prototype             ?&Object                 // %Function.prototype%
	function_constructor           ?&Object
	function_executable_cache map[voidptr][]FunctionExecutableCacheEntry
	function_compilation_activity FunctionCompilationActivity
	async_function_prototype ?&Object
	generator_function_prototype ?&Object
	generator_prototype ?&Object
	async_generator_function_prototype ?&Object
	async_generator_prototype ?&Object
	async_iterator_prototype ?&Object
	array_prototype ?&Object
	array_prototype_values Value // Intrinsic identity, independent of user mutations.
	array_constructor ?&Object
	template_objects map[string]&TemplateObjectEntry
	map_prototype ?&Object
	map_constructor ?&Object
	map_iterator_prototype ?&Object
	weak_map_prototype ?&Object
	weak_map_constructor ?&Object
	weak_set_prototype ?&Object
	weak_set_constructor ?&Object
	weak_ref_prototype ?&Object
	weak_ref_constructor ?&Object
	promise_prototype ?&Object
	promise_constructor ?&Object
	set_prototype ?&Object
	set_constructor ?&Object
	set_iterator_prototype ?&Object
	iterator_prototype ?&Object
	array_iterator_prototype ?&Object
	string_iterator_prototype ?&Object
	string_prototype ?&Object
	string_constructor ?&Object
	regexp_prototype ?&Object
	regexp_constructor ?&Object
	regexp_string_iterator_prototype ?&Object
	throw_type_error_function      ?&Object
	boolean_prototype              ?&Object
	boolean_constructor            ?&Object
	number_prototype               ?&Object
	number_constructor             ?&Object
	bigint_prototype               ?&Object
	bigint_constructor             ?&Object
	parse_int_function             ?&Object
	parse_float_function           ?&Object
	symbol_prototype               ?&Object
	symbol_constructor             ?&Object
	array_buffer_prototype         ?&Object
	array_buffer_constructor       ?&Object
	typed_array_prototype          ?&Object
	typed_array_constructor        ?&Object
	typed_array_prototypes         map[BufferElementType]&Object
	typed_array_constructors       map[BufferElementType]&Object
	data_view_prototype            ?&Object
	data_view_constructor          ?&Object
	shared_array_buffer_prototype  ?&Object
	shared_array_buffer_constructor ?&Object
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

pub fn (realm &Realm) object_prototype_record() &Object {
	return realm.object_prototype or { panic('Realm has no Object prototype yet') }
}

pub fn (realm &Realm) object_constructor_record() &Object {
	return realm.object_constructor or { panic('Realm has no Object constructor yet') }
}

pub fn (realm &Realm) promise_constructor_record() &Object {
	return realm.promise_constructor or { panic('Realm has no Promise constructor yet') }
}

pub fn (realm &Realm) math_object_record() &Object {
	return realm.math_object or { panic('Realm has no Math object yet') }
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

pub fn (realm &Realm) array_buffer_prototype_record() &Object {
	return realm.array_buffer_prototype or { panic('Realm has no ArrayBuffer prototype yet') }
}

pub fn (realm &Realm) array_buffer_constructor_record() &Object {
	return realm.array_buffer_constructor or { panic('Realm has no ArrayBuffer constructor yet') }
}

pub fn (realm &Realm) data_view_prototype_record() &Object {
	return realm.data_view_prototype or { panic('Realm has no DataView prototype yet') }
}

pub fn (realm &Realm) data_view_constructor_record() &Object {
	return realm.data_view_constructor or { panic('Realm has no DataView constructor yet') }
}

pub fn (realm &Realm) shared_array_buffer_prototype_record() &Object {
	return realm.shared_array_buffer_prototype or { panic('Realm has no SharedArrayBuffer prototype yet') }
}

pub fn (realm &Realm) shared_array_buffer_constructor_record() &Object {
	return realm.shared_array_buffer_constructor or { panic('Realm has no SharedArrayBuffer constructor yet') }
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
	// Intrinsics.cpp allocates the Object root before Function.prototype and
	// initializes it after the function intrinsic is available.
	object_prototype := ObjectPrototype.create(realm)
	realm.object_prototype = object_prototype.object
	function_prototype := FunctionPrototype.create(mut vm, realm, object_prototype.object)
	realm.function_prototype = function_prototype.object
	realm.function_constructor = FunctionConstructor.create(mut vm, realm).object
	mut function_prototype_object := function_prototype.object
	function_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(realm.function_constructor or { panic('Missing Function constructor') }), attribute_writable | attribute_configurable)
	mut async_function_prototype := Object.create(realm, realm.function_prototype)
	async_function_prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('AsyncFunction')), attribute_configurable)
	realm.async_function_prototype = async_function_prototype
	object_prototype.initialize(mut vm, realm, realm_primitive_prototypes())
	realm.object_constructor = ObjectConstructor.create(mut vm, realm).object
	initialize_error_intrinsics(mut vm, mut realm)
	realm.math_object = MathObject.create(mut vm, realm, object_prototype.object).object
	thrower := create_throw_type_error_function(mut vm, realm, function_prototype.object)
	realm.throw_type_error_function = thrower
	mut prototype_object := function_prototype.object
	prototype_object.add_restricted_function_properties(thrower)
	boolean_prototype := BooleanPrototype.create(mut vm, realm, object_prototype.object)
	realm.boolean_prototype = boolean_prototype.object
	boolean_constructor := BooleanConstructor.create(mut vm, realm)
	realm.boolean_constructor = boolean_constructor.object
	// Intrinsics.cpp::initialize_constructor installs the companion back-reference.
	mut boolean_prototype_object := boolean_prototype.object
	boolean_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(boolean_constructor.object), attribute_writable | attribute_configurable)
	symbol_prototype := SymbolPrototype.create(mut vm, realm, object_prototype.object)
	realm.symbol_prototype = symbol_prototype.object
	symbol_constructor := SymbolConstructor.create(mut vm, realm)
	realm.symbol_constructor = symbol_constructor.object
	mut symbol_prototype_object := symbol_prototype.object
	symbol_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(symbol_constructor.object), attribute_writable | attribute_configurable)
	array_buffer_prototype := ArrayBufferPrototype.create(mut vm, realm, object_prototype.object)
	realm.array_buffer_prototype = array_buffer_prototype.object
	array_buffer_constructor := ArrayBufferConstructor.create(mut vm, realm)
	realm.array_buffer_constructor = array_buffer_constructor.object
	mut array_buffer_prototype_object := array_buffer_prototype.object
	array_buffer_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(array_buffer_constructor.object),
		attribute_writable | attribute_configurable)
	data_view_prototype := DataViewPrototype.create(mut vm, realm, object_prototype.object)
	realm.data_view_prototype = data_view_prototype.object
	data_view_constructor := DataViewConstructor.create(mut vm, realm)
	realm.data_view_constructor = data_view_constructor.object
	mut data_view_prototype_object := data_view_prototype.object
	data_view_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(data_view_constructor.object),
		attribute_writable | attribute_configurable)
	shared_array_buffer_prototype := SharedArrayBufferPrototype.create(mut vm, realm, object_prototype.object)
	realm.shared_array_buffer_prototype = shared_array_buffer_prototype.object
	shared_array_buffer_constructor := SharedArrayBufferConstructor.create(mut vm, realm)
	realm.shared_array_buffer_constructor = shared_array_buffer_constructor.object
	mut shared_array_buffer_prototype_object := shared_array_buffer_prototype.object
	shared_array_buffer_prototype_object.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(shared_array_buffer_constructor.object), attribute_writable | attribute_configurable)
	initialize_collection_intrinsics(mut vm, mut realm)!
	initialize_number_intrinsics(mut vm, mut realm)
	initialize_bigint_intrinsics(mut vm, mut realm)
	realm.reflect_object = ReflectObject.create(mut vm, realm, realm.object_prototype_record(), realm.array_prototype_record()).object
	initialize_iterator_intrinsics(mut vm, mut realm)
	initialize_typed_array_intrinsics(mut vm, mut realm)
	initialize_generator_creation_intrinsics(mut vm, mut realm)
	initialize_set_intrinsics(mut vm, mut realm)
	initialize_map_intrinsics(mut vm, mut realm)
	initialize_weak_map_intrinsics(mut vm, mut realm)
	initialize_weak_set_intrinsics(mut vm, mut realm)
	initialize_weak_ref_intrinsics(mut vm, mut realm)
	initialize_proxy_intrinsics(mut vm, mut realm)
	initialize_intl_intrinsics(mut vm, mut realm)
	initialize_intl_date_time_format(mut vm, mut realm)
	initialize_intl_list_format(mut vm, mut realm)
	initialize_intl_number_format(mut vm, mut realm)
	initialize_intl_relative_time_format(mut vm, mut realm)
	initialize_intl_collator(mut vm, mut realm)
	initialize_regexp_intrinsics(mut vm, mut realm)
	realm.json_object = create_json_object(mut vm, realm)
	initialize_date_intrinsics(mut vm, mut realm)
	initialize_promise_intrinsics(mut vm, mut realm)
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
		Object.create(realm, object_prototype.object)
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
	global.define_direct_property(PropertyName.from_str('Function'),
		Value.from_object(realm.function_constructor or { panic('Missing Function constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Array'),
		Value.from_object(realm.array_constructor or { panic('Missing Array constructor') }),
		attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('ArrayBuffer'),
		Value.from_object(realm.array_buffer_constructor_record()),
		attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Boolean'),
		Value.from_object(realm.boolean_constructor_record()),
		attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('BigInt'),
		Value.from_object(realm.bigint_constructor or { panic('Missing BigInt constructor') }), attribute_writable | attribute_configurable)
	for kind, constructor in realm.typed_array_constructors { global.define_direct_property(PropertyName.from_str(kind.typed_array_name()), Value.from_object(constructor), attribute_writable | attribute_configurable) }
	global.define_direct_property(PropertyName.from_str('DataView'),
		Value.from_object(realm.data_view_constructor_record()),
		attribute_writable | attribute_configurable)
	for kind in [ErrorKind.error, .eval_error, .internal_error] {
		global.define_direct_property(PropertyName.from_str(kind.name()), Value.from_object(realm.error_constructors[kind] or { panic('Missing error constructor') }), attribute_writable | attribute_configurable)
	}
	global.define_direct_property(PropertyName.from_str('Map'),
		Value.from_object(realm.map_constructor or { panic('Missing Map constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Object'),
		Value.from_object(realm.object_constructor_record()), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Number'),
		Value.from_object(realm.number_constructor or { panic('Missing Number constructor') }), attribute_writable | attribute_configurable)
	for kind in [ErrorKind.range_error, .reference_error] {
		global.define_direct_property(PropertyName.from_str(kind.name()), Value.from_object(realm.error_constructors[kind] or { panic('Missing error constructor') }), attribute_writable | attribute_configurable)
	}
	global.define_direct_property(PropertyName.from_str('RegExp'),
		Value.from_object(realm.regexp_constructor or { panic('Missing RegExp constructor') }),
		attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Set'),
		Value.from_object(realm.set_constructor or { panic('Missing Set constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('SharedArrayBuffer'),
		Value.from_object(realm.shared_array_buffer_constructor_record()), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('String'),
		Value.from_object(realm.string_constructor or { panic('Missing String constructor') }),
		attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Symbol'),
		Value.from_object(realm.symbol_constructor_record()),
		attribute_writable | attribute_configurable)
	for kind in [ErrorKind.syntax_error, .type_error, .uri_error] {
		global.define_direct_property(PropertyName.from_str(kind.name()), Value.from_object(realm.error_constructors[kind] or { panic('Missing error constructor') }), attribute_writable | attribute_configurable)
	}
	// Other intrinsic properties follow constructors in GlobalObject.cpp.
	global.define_direct_property(PropertyName.from_str('WeakMap'),
		Value.from_object(realm.weak_map_constructor or { panic('Missing WeakMap constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('WeakSet'),
		Value.from_object(realm.weak_set_constructor or { panic('Missing WeakSet constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('WeakRef'),
		Value.from_object(realm.weak_ref_constructor or { panic('Missing WeakRef constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Date'),
		Value.from_object(realm.date_constructor or { panic('Missing Date constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Promise'),
		Value.from_object(realm.promise_constructor or { panic('Missing Promise constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('JSON'),
		Value.from_object(realm.json_object or { panic('Missing JSON object') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Intl'), Value.from_object(realm.intl_object or { panic('Missing Intl namespace') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Math'),
		Value.from_object(realm.math_object_record()), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Proxy'),
		Value.from_object(realm.proxy_constructor or { panic('Missing Proxy constructor') }), attribute_writable | attribute_configurable)
	global.define_direct_property(PropertyName.from_str('Reflect'),
		Value.from_object(realm.reflect_object or { panic('Missing Reflect object') }), attribute_writable | attribute_configurable)
	set_default_global_legacy_functions(mut vm, realm)
	// 19. Create any host-defined global object properties on global.
	// 20. Return unused.
	return new_context
}

pub fn (realm &Realm) array_prototype_record() &Object {
	return realm.array_prototype or { panic('Realm has no Array prototype') }
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
