module libjs

// Translated from LibJS/Runtime/ObjectEnvironment.{h,cpp}.

@[heap]
pub struct ObjectEnvironment {
	EnvironmentBase
pub mut:
	binding_object   &Object // [[BindingObject]]
	with_environment bool    // [[IsWithEnvironment]]
}

pub fn ObjectEnvironment.create(binding_object &Object, is_with_environment bool, outer ?Environment) &ObjectEnvironment {
	return &ObjectEnvironment{
		kind:             .object
		outer:            outer
		binding_object:   binding_object
		with_environment: is_with_environment
	}
}

pub fn (environment &ObjectEnvironment) is_with_environment() bool {
	return environment.with_environment
}

// 9.1.1.2.10 WithBaseObject ( ), https://tc39.es/ecma262/#sec-object-environment-records-withbaseobject
pub fn (environment &ObjectEnvironment) with_base_object() ?&Object {
	if environment.with_environment {
		return environment.binding_object
	}
	return none
}

// 9.1.1.2.1 HasBinding ( N ), https://tc39.es/ecma262/#sec-object-environment-records-hasbinding-n
pub fn (environment &ObjectEnvironment) has_binding(mut vm VM, name Utf16String) !(bool, ?int) {
	key := PropertyName.from_utf16(name)
	// 2. Let foundBinding be ? HasProperty(bindingObject, N).
	found_binding := environment.binding_object.has_property(key)
	// 3. If foundBinding is false, return false.
	if !found_binding {
		return false, none
	}
	// 4. If envRec.[[IsWithEnvironment]] is false, return true.
	if !environment.with_environment {
		return true, none
	}
	// 5. Let unscopables be ? Get(bindingObject, @@unscopables).
	unscopables := environment.binding_object.get(PropertyName.from_symbol(vm.well_known_symbol_unscopables()))
	// 6. If Type(unscopables) is Object, then
	if unscopables.is_object() {
		// a. Let blocked be ToBoolean(? Get(unscopables, N)).
		blocked := unscopables.as_object().get(key).to_boolean()
		// b. If blocked is true, return false.
		if blocked {
			return false, none
		}
	}
	// 7. Return true.
	return true, none
}

// 9.1.1.2.2 CreateMutableBinding ( N, D ), https://tc39.es/ecma262/#sec-object-environment-records-createmutablebinding-n-d
pub fn (mut environment ObjectEnvironment) create_mutable_binding(mut vm VM, name Utf16String, can_be_deleted bool) ! {
	// 2. Perform ? DefinePropertyOrThrow(bindingObject, N, PropertyDescriptor { [[Value]]: undefined, [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: D }).
	environment.binding_object.define_property_or_throw(mut vm, PropertyName.from_utf16(name),
		PropertyDescriptor{
		value:        js_undefined()
		writable:     true
		enumerable:   true
		configurable: can_be_deleted
	})!
	// 3. Return unused.
}

// 9.1.1.2.3 CreateImmutableBinding ( N, S ), https://tc39.es/ecma262/#sec-object-environment-records-createimmutablebinding-n-s
pub fn (mut environment ObjectEnvironment) create_immutable_binding(mut vm VM, name Utf16String, strict bool) ! {
	// "The CreateImmutableBinding concrete method of an object Environment Record is never used within this specification."
	panic('ObjectEnvironment.create_immutable_binding is never used')
}

// 9.1.1.2.4 InitializeBinding ( N, V ), https://tc39.es/ecma262/#sec-object-environment-records-initializebinding-n-v
pub fn (mut environment ObjectEnvironment) initialize_binding(mut vm VM, name Utf16String, value Value, hint InitializeBindingHint) ! {
	// 1. Assert: hint is normal.
	if hint != .normal {
		panic('ObjectEnvironment.initialize_binding requires the normal hint')
	}
	// 2. Perform ? envRec.SetMutableBinding(N, V, false).
	environment.set_mutable_binding(mut vm, name, value, false)!
	// 3. Return unused.
}

// 9.1.1.2.5 SetMutableBinding ( N, V, S ), https://tc39.es/ecma262/#sec-object-environment-records-setmutablebinding-n-v-s
pub fn (mut environment ObjectEnvironment) set_mutable_binding(mut vm VM, name Utf16String, value Value, strict bool) ! {
	key := PropertyName.from_utf16(name)
	// OPTIMIZATION: Non-with environments in sloppy mode skip the HasProperty
	//               check because it only feeds strict-mode errors.
	if !environment.with_environment && !strict {
		return environment.binding_object.set(mut vm, key, value, .no)
	}
	// 2. Let stillExists be ? HasProperty(bindingObject, N).
	still_exists := environment.binding_object.has_property(key)
	// 3. If stillExists is false and S is true, throw a ReferenceError exception.
	if !still_exists && strict {
		return vm.throw_error_type(.reference_error, .unknown_identifier, name.str())
	}
	// 4. Perform ? Set(bindingObject, N, V, S).
	environment.binding_object.set(mut vm, key, value, if strict { .yes } else { .no }) or {
		// Nothing like this in the spec; upstream produces a nicer error than the
		// generic Object::set() failure when the property is read-only.
		if strict {
			if property := environment.binding_object.internal_get_own_property(key) {
				if !(property.writable or { true }) {
					return vm.throw_error_type(.type_error, .desc_write_non_writable, name.str())
				}
			}
		}
		return err
	}
	// 5. Return unused.
}

// 9.1.1.2.6 GetBindingValue ( N, S ), https://tc39.es/ecma262/#sec-object-environment-records-getbindingvalue-n-s
pub fn (mut environment ObjectEnvironment) get_binding_value(mut vm VM, name Utf16String, strict bool) !Value {
	key := PropertyName.from_utf16(name)
	// OPTIMIZATION: Non-with environments in sloppy mode combine HasProperty and Get.
	if !environment.with_environment && !strict {
		return environment.binding_object.get(key)
	}
	// 2. Let value be ? HasProperty(bindingObject, N).
	value := environment.binding_object.has_property(key)
	// 3. If value is false, then
	if !value {
		// a. If S is false, return undefined; otherwise throw a ReferenceError exception.
		if !strict {
			return js_undefined()
		}
		return vm.throw_error_type(.reference_error, .unknown_identifier, name.str())
	}
	// 4. Return ? Get(bindingObject, N).
	return environment.binding_object.get(key)
}

// 9.1.1.2.7 DeleteBinding ( N ), https://tc39.es/ecma262/#sec-object-environment-records-deletebinding-n
pub fn (mut environment ObjectEnvironment) delete_binding(mut vm VM, name Utf16String) !bool {
	// 2. Return ? bindingObject.[[Delete]](N).
	return environment.binding_object.internal_delete(PropertyName.from_utf16(name))
}
