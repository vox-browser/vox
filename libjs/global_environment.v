module libjs

// Translated from LibJS/Runtime/GlobalEnvironment.{h,cpp}.

@[heap]
pub struct GlobalEnvironment {
	EnvironmentBase
pub mut:
	object_record      &ObjectEnvironment      // [[ObjectRecord]]
	global_this_value  &Object                 // [[GlobalThisValue]]
	declarative_record &DeclarativeEnvironment // [[DeclarativeRecord]]
}

// 9.1.2.5 NewGlobalEnvironment ( G, thisValue ), https://tc39.es/ecma262/#sec-newglobalenvironment
pub fn GlobalEnvironment.create(global_object &Object, this_value &Object) &GlobalEnvironment {
	return &GlobalEnvironment{
		kind:               .global
		object_record:      ObjectEnvironment.create(global_object, false, none)
		global_this_value:  this_value
		declarative_record: DeclarativeEnvironment.create(none)
	}
}

pub fn (environment &GlobalEnvironment) has_this_binding() bool {
	return true
}

// 9.1.1.4.11 GetThisBinding ( ), https://tc39.es/ecma262/#sec-global-environment-records-getthisbinding
pub fn (environment &GlobalEnvironment) get_this_binding(mut vm VM) !Value {
	// 1. Return envRec.[[GlobalThisValue]].
	return Value.from_object(environment.global_this_value)
}

// 9.1.1.4.1 HasBinding ( N ), https://tc39.es/ecma262/#sec-global-environment-records-hasbinding-n
pub fn (environment &GlobalEnvironment) has_binding(mut vm VM, name Utf16String) !(bool, ?int) {
	// 2. If ! DclRec.HasBinding(N) is true, return true.
	if environment.declarative_record.has_binding_named(name) {
		return true, none
	}
	// 4. Return ? ObjRec.HasBinding(N).
	return environment.object_record.has_binding(mut vm, name)
}

// 9.1.1.4.2 CreateMutableBinding ( N, D ), https://tc39.es/ecma262/#sec-global-environment-records-createmutablebinding-n-d
pub fn (mut environment GlobalEnvironment) create_mutable_binding(mut vm VM, name Utf16String, can_be_deleted bool) ! {
	// 2. If ! DclRec.HasBinding(N) is true, throw a TypeError exception.
	if environment.declarative_record.has_binding_named(name) {
		return vm.throw_error_type(.type_error, .global_environment_already_has_binding, name.str())
	}
	// 3. Return ! DclRec.CreateMutableBinding(N, D).
	environment.declarative_record.create_mutable_binding(mut vm, name, can_be_deleted)!
}

// 9.1.1.4.3 CreateImmutableBinding ( N, S ), https://tc39.es/ecma262/#sec-global-environment-records-createimmutablebinding-n-s
pub fn (mut environment GlobalEnvironment) create_immutable_binding(mut vm VM, name Utf16String, strict bool) ! {
	// 2. If ! DclRec.HasBinding(N) is true, throw a TypeError exception.
	if environment.declarative_record.has_binding_named(name) {
		return vm.throw_error_type(.type_error, .global_environment_already_has_binding, name.str())
	}
	// 3. Return ! DclRec.CreateImmutableBinding(N, S).
	environment.declarative_record.create_immutable_binding(mut vm, name, strict)!
}

// 9.1.1.4.4 InitializeBinding ( N, V, hint ), https://tc39.es/ecma262/#sec-global-environment-records-initializebinding-n-v
pub fn (mut environment GlobalEnvironment) initialize_binding(mut vm VM, name Utf16String, value Value, hint InitializeBindingHint) ! {
	// 2. If ! DclRec.HasBinding(N) is true, then
	if environment.declarative_record.has_binding_named(name) {
		// a. Return ! DclRec.InitializeBinding(N, V, hint).
		return environment.declarative_record.initialize_binding(mut vm, name, value, hint)
	}
	// 3. Assert: If the binding exists, it must be in the object Environment Record.
	// 4. Assert: hint is normal.
	if hint != .normal {
		panic('GlobalEnvironment.initialize_binding requires the normal hint for object bindings')
	}
	// 6. Return ? ObjRec.InitializeBinding(N, V, normal).
	return environment.object_record.initialize_binding(mut vm, name, value, .normal)
}

// 9.1.1.4.5 SetMutableBinding ( N, V, S ), https://tc39.es/ecma262/#sec-global-environment-records-setmutablebinding-n-v-s
pub fn (mut environment GlobalEnvironment) set_mutable_binding(mut vm VM, name Utf16String, value Value, strict bool) ! {
	// 2. If ! DclRec.HasBinding(N) is true, then
	if environment.declarative_record.has_binding_named(name) {
		// a. Return ? DclRec.SetMutableBinding(N, V, S).
		return environment.declarative_record.set_mutable_binding(mut vm, name, value, strict)
	}
	// 4. Return ? ObjRec.SetMutableBinding(N, V, S).
	return environment.object_record.set_mutable_binding(mut vm, name, value, strict)
}

// 9.1.1.4.6 GetBindingValue ( N, S ), https://tc39.es/ecma262/#sec-global-environment-records-getbindingvalue-n-s
pub fn (mut environment GlobalEnvironment) get_binding_value(mut vm VM, name Utf16String, strict bool) !Value {
	// 2. If ! DclRec.HasBinding(N) is true, then
	exists, index := environment.declarative_record.has_binding(mut vm, name)!
	if exists {
		// a. Return ? DclRec.GetBindingValue(N, S).
		if binding_index := index {
			return environment.declarative_record.get_binding_value_direct(mut vm, binding_index)
		}
		return environment.declarative_record.get_binding_value(mut vm, name, strict)
	}
	// 4. Return ? ObjRec.GetBindingValue(N, S).
	return environment.object_record.get_binding_value(mut vm, name, strict)
}

// 9.1.1.4.7 DeleteBinding ( N ), https://tc39.es/ecma262/#sec-global-environment-records-deletebinding-n
pub fn (mut environment GlobalEnvironment) delete_binding(mut vm VM, name Utf16String) !bool {
	// 2. If ! DclRec.HasBinding(N) is true, then
	if environment.declarative_record.has_binding_named(name) {
		// a. Return ! DclRec.DeleteBinding(N).
		return environment.declarative_record.delete_binding(mut vm, name)
	}
	// 5. Let existingProp be ? HasOwnProperty(globalObject, N).
	existing_prop := environment.object_record.binding_object.has_own_property(PropertyName.from_utf16(name))
	// 6. If existingProp is true, then
	if existing_prop {
		// a. Return ? ObjRec.DeleteBinding(N).
		return environment.object_record.delete_binding(mut vm, name)
	}
	// 7. Return true.
	return true
}

// 9.1.1.4.12 HasLexicalDeclaration ( envRec, N ), https://tc39.es/ecma262/#sec-haslexicaldeclaration
pub fn (environment &GlobalEnvironment) has_lexical_declaration(name Utf16String) bool {
	// 2. Return ! DclRec.HasBinding(N).
	return environment.declarative_record.has_binding_named(name)
}

// 9.1.1.4.13 HasRestrictedGlobalProperty ( envRec, N ), https://tc39.es/ecma262/#sec-hasrestrictedglobalproperty
pub fn (environment &GlobalEnvironment) has_restricted_global_property(name Utf16String) bool {
	// 3. Let existingProp be ? globalObject.[[GetOwnProperty]](N).
	existing_prop := environment.object_record.binding_object.internal_get_own_property(PropertyName.from_utf16(name)) or {
		// 4. If existingProp is undefined, return false.
		return false
	}
	// 5. If existingProp.[[Configurable]] is true, return false.
	if existing_prop.configurable or { false } {
		return false
	}
	// 6. Return true.
	return true
}

// 9.1.1.4.14 CanDeclareGlobalVar ( envRec, N ), https://tc39.es/ecma262/#sec-candeclareglobalvar
pub fn (environment &GlobalEnvironment) can_declare_global_var(name Utf16String) bool {
	global_object := environment.object_record.binding_object
	// 3. Let hasProperty be ? HasOwnProperty(globalObject, N).
	// 4. If hasProperty is true, return true.
	if global_object.has_own_property(PropertyName.from_utf16(name)) {
		return true
	}
	// 5. Return ? IsExtensible(globalObject).
	return global_object.extensible
}

// 9.1.1.4.15 CanDeclareGlobalFunction ( envRec, N ), https://tc39.es/ecma262/#sec-candeclareglobalfunction
pub fn (environment &GlobalEnvironment) can_declare_global_function(name Utf16String) bool {
	global_object := environment.object_record.binding_object
	// 3. Let existingProp be ? globalObject.[[GetOwnProperty]](N).
	existing_prop := global_object.internal_get_own_property(PropertyName.from_utf16(name)) or {
		// 4. If existingProp is undefined, return ? IsExtensible(globalObject).
		return global_object.extensible
	}
	// 5. If existingProp.[[Configurable]] is true, return true.
	if existing_prop.configurable or { false } {
		return true
	}
	// 6. If IsDataDescriptor(existingProp) is true and existingProp has attribute values { [[Writable]]: true, [[Enumerable]]: true }, return true.
	if existing_prop.is_data_descriptor() && (existing_prop.writable or { false })
		&& (existing_prop.enumerable or { false }) {
		return true
	}
	// 7. Return false.
	return false
}

// 9.1.1.4.16 CreateGlobalVarBinding ( envRec, N, D ), https://tc39.es/ecma262/#sec-createglobalvarbinding
pub fn (mut environment GlobalEnvironment) create_global_var_binding(mut vm VM, name Utf16String, can_be_deleted bool) ! {
	global_object := environment.object_record.binding_object
	// 3. Let hasProperty be ? HasOwnProperty(globalObject, N).
	has_property := global_object.has_own_property(PropertyName.from_utf16(name))
	// 4. Let extensible be ? IsExtensible(globalObject).
	extensible := global_object.extensible
	// 5. If hasProperty is false and extensible is true, then
	if !has_property && extensible {
		// a. Perform ? ObjRec.CreateMutableBinding(N, D).
		environment.object_record.create_mutable_binding(mut vm, name, can_be_deleted)!
		// b. Perform ? ObjRec.InitializeBinding(N, undefined, normal).
		environment.object_record.initialize_binding(mut vm, name, js_undefined(), .normal)!
	}
	// 6. Return unused.
}

// 9.1.1.4.17 CreateGlobalFunctionBinding ( envRec, N, V, D ), https://tc39.es/ecma262/#sec-createglobalfunctionbinding
pub fn (mut environment GlobalEnvironment) create_global_function_binding(mut vm VM, name Utf16String, value Value, can_be_deleted bool) ! {
	key := PropertyName.from_utf16(name)
	// 3. Let existingProp be ? globalObject.[[GetOwnProperty]](N).
	existing_prop := environment.object_record.binding_object.internal_get_own_property(key)
	// 4. If existingProp is undefined or existingProp.[[Configurable]] is true, then
	mut descriptor := PropertyDescriptor{
		value: value
	}
	mut missing_or_configurable := true
	if existing := existing_prop {
		missing_or_configurable = existing.configurable or { false }
	}
	if missing_or_configurable {
		// a. Let desc be the PropertyDescriptor { [[Value]]: V, [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: D }.
		descriptor.writable = true
		descriptor.enumerable = true
		descriptor.configurable = can_be_deleted
	}
	// 5. Else, a. Let desc be the PropertyDescriptor { [[Value]]: V }.
	// 6. Perform ? DefinePropertyOrThrow(globalObject, N, desc).
	environment.object_record.binding_object.define_property_or_throw(mut vm, key, descriptor)!
	// 7. Perform ? Set(globalObject, N, V, false).
	environment.object_record.binding_object.set(mut vm, key, value, .no)!
	// 8. Return unused.
}
