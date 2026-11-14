module libjs

// Translated from LibJS/Runtime/Reference.{h,cpp} and EnvironmentCoordinate.h.
// Boolean and Symbol bases use translated ToObject wrappers. String references
// first use the Source virtual length/index lookup; remaining primitive wrappers
// and prototypes are pending. Objects/environments use ordinary internal methods.

pub const environment_coordinate_invalid_marker = u32(0xfffffffe)

pub struct EnvironmentCoordinate {
pub:
	hops  u32 = environment_coordinate_invalid_marker
	index u32 = environment_coordinate_invalid_marker
}

pub fn (coordinate EnvironmentCoordinate) is_valid() bool {
	return coordinate.hops != environment_coordinate_invalid_marker
		&& coordinate.index != environment_coordinate_invalid_marker
}

pub enum ReferenceBaseType as u8 {
	unresolvable
	value
	environment
}

pub struct Reference {
pub:
	base_type              ReferenceBaseType = .unresolvable
	name                   PropertyName // [[ReferencedName]]
	private_name           ?PrivateName // Private Name alternative of [[ReferencedName]]
	strict                 bool         // [[Strict]]
	base_value             Value        // [[Base]] for property references
	this_value             ?Value       // [[ThisValue]]
	base_environment       ?Environment // [[Base]] for environment references
	environment_coordinate ?EnvironmentCoordinate
}

pub fn Reference.unresolvable(name Utf16String, strict bool) Reference {
	return Reference{
		base_type: .unresolvable
		name:      PropertyName.from_utf16(name)
		strict:    strict
	}
}

pub fn Reference.for_environment(environment Environment, name Utf16String, strict bool, coordinate ?EnvironmentCoordinate) Reference {
	return Reference{
		base_type: .environment
		// Environment bindings retain a string [[ReferencedName]], including
		// strings supplied through the runtime API that resemble an index.
		name:                   PropertyName{
			string_value: name
		}
		strict:                 strict
		base_environment:       environment
		environment_coordinate: coordinate
	}
}

pub fn Reference.for_value(base Value, name PropertyName, this_value ?Value, strict bool) Reference {
	return Reference{
		base_type:  .value
		name:       name
		strict:     strict
		base_value: base
		this_value: this_value
	}
}

pub fn Reference.for_private(base Value, name PrivateName) Reference {
	return Reference{
		base_type: .value
		base_value: base
		private_name: name
		strict: true
	}
}

// Reference.cpp::MakePrivateReference.
pub fn make_private_reference(vm &VM, base Value, identifier Utf16String) Reference {
	environment := vm.running_execution_context().private_environment or {
		panic('MakePrivateReference requires a private environment')
	}
	return Reference.for_private(base, environment.resolve_private_identifier(identifier))
}

pub fn (reference Reference) is_private_reference() bool {
	return reference.private_name != none
}

pub fn (reference Reference) base() Value {
	if reference.base_type != .value {
		panic('Reference.base() on a ${reference.base_type} reference')
	}
	return reference.base_value
}

pub fn (reference Reference) base_environment_record() Environment {
	if reference.base_type != .environment {
		panic('Reference.base_environment_record() on a ${reference.base_type} reference')
	}
	return reference.base_environment or { panic('environment reference without an environment') }
}

pub fn (reference Reference) is_strict() bool {
	return reference.strict
}

// 6.2.4.2 IsUnresolvableReference ( V ), https://tc39.es/ecma262/#sec-isunresolvablereference
pub fn (reference Reference) is_unresolvable() bool {
	return reference.base_type == .unresolvable
}

// 6.2.4.1 IsPropertyReference ( V ), https://tc39.es/ecma262/#sec-ispropertyreference
pub fn (reference Reference) is_property_reference() bool {
	if reference.is_unresolvable() {
		return false
	}
	if reference.base_type == .environment {
		return false
	}
	return true
}

// 6.2.4.7 GetThisValue ( V ), https://tc39.es/ecma262/#sec-getthisvalue
pub fn (reference Reference) get_this_value() Value {
	if !reference.is_property_reference() {
		panic('GetThisValue on a non-property reference')
	}
	if this_value := reference.this_value {
		return this_value
	}
	return reference.base_value
}

// 6.2.4.3 IsSuperReference ( V ), https://tc39.es/ecma262/#sec-issuperreference
pub fn (reference Reference) is_super_reference() bool {
	return reference.this_value != none
}

// Note: Non-standard helper.
pub fn (reference Reference) is_environment_reference() bool {
	return reference.base_type == .environment
}

fn (reference Reference) throw_reference_error(mut vm VM) IError {
	return vm.throw_error_type(.reference_error, .unknown_identifier, reference.name.str())
}

fn (reference Reference) base_object(mut vm VM) !&Object {
	if reference.base_value.is_object() {
		return reference.base_value.as_object()
	}
	// Value.cpp::ToObject's Boolean case. [[Get]] and [[Set]] still receive the
	// original primitive through GetThisValue, rather than the temporary wrapper.
	if reference.base_value.is_boolean() {
		return BooleanObject.create(vm.realm(), reference.base_value.as_bool()).object
	}
	// Value.cpp::ToObject's Symbol case retains the same primitive symbol.
	if reference.base_value.is_symbol() {
		return SymbolObject.create(vm.realm(), reference.base_value.as_symbol()).object
	}
	if reference.base_value.is_string() || reference.base_value.is_number() || reference.base_value.is_bigint() {
		return reference.base_value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())
	}
	// 7.1.18 ToObject ( argument ) throws for undefined and null; primitive
	// wrappers belong to the pending object-model translation.
	if reference.base_value.is_nullish() {
		if reference.is_private_reference() {
			return vm.throw_error_type(.type_error, .to_object_null_or_undefined)
		}
		return vm.throw_error_type(.type_error, .to_object_null_or_undefined_with_property,
			reference.name.str(), reference.base_value.str())
	}
	return vm.throw_error(.internal_error,
		'Property references on primitive values require the object model translation')
}

// 6.2.4.5 GetValue ( V ), https://tc39.es/ecma262/#sec-getvalue
pub fn (reference Reference) get_value(mut vm VM) !Value {
	// 3. If IsUnresolvableReference(V) is true, throw a ReferenceError exception.
	if reference.is_unresolvable() {
		return reference.throw_reference_error(mut vm)
	}
	// 4. If IsPropertyReference(V) is true, then
	if reference.is_property_reference() {
		if private_name := reference.private_name {
			base_obj := reference.base_object(mut vm)!
			return base_obj.private_get(mut vm, private_name)
		}
		// Reference.cpp defers ToObject and first asks the actual string cell
		// for its virtual length/index property. Prototype lookup remains below.
		if reference.base_value.is_string() {
			if value := reference.base_value.as_string().get_own_property(mut vm, reference.name) {
				return value
			}
		}
		base_obj := reference.base_object(mut vm)!
		// c. Return ? baseObj.[[Get]](V.[[ReferencedName]], GetThisValue(V)).
		return base_obj.internal_get(mut vm, reference.name, reference.get_this_value())!
	}
	// 5. Else,
	// b. Assert: base is an Environment Record.
	mut environment := reference.base_environment_record()
	// c. Return ? base.GetBindingValue(V.[[ReferencedName]], V.[[Strict]]).
	return environment.get_binding_value(mut vm, reference.name.as_string(), reference.strict)
}

// 6.2.4.6 PutValue ( V, W ), https://tc39.es/ecma262/#sec-putvalue
pub fn (reference Reference) put_value(mut vm VM, value Value) ! {
	// 4. If IsUnresolvableReference(V) is true, then
	if reference.is_unresolvable() {
		// a. If V.[[Strict]] is true, throw a ReferenceError exception.
		if reference.strict {
			return reference.throw_reference_error(mut vm)
		}
		// b. Let globalObj be GetGlobalObject().
		mut global_object := vm.get_global_object()
		// c. Perform ? Set(globalObj, V.[[ReferencedName]], W, false).
		global_object.set(mut vm, reference.name, value, .no)!
		// d. Return unused.
		return
	}
	// 5. If IsPropertyReference(V) is true, then
	if reference.is_property_reference() {
		// a. Let baseObj be ? ToObject(V.[[Base]]).
		mut base_obj := reference.base_object(mut vm)!
		if private_name := reference.private_name {
			return base_obj.private_set(mut vm, private_name, value)
		}
		// c. Let succeeded be ? baseObj.[[Set]](V.[[ReferencedName]], W, GetThisValue(V)).
		succeeded := base_obj.internal_set(mut vm, reference.name, value, reference.get_this_value())!
		// d. If succeeded is false and V.[[Strict]] is true, throw a TypeError exception.
		if !succeeded && reference.strict {
			return vm.throw_error_type(.type_error, .reference_nullish_set_property,
				reference.name.str(), reference.base_value.str())
		}
		// e. Return unused.
		return
	}
	// 6. Else,
	// b. Assert: base is an Environment Record.
	mut environment := reference.base_environment_record()
	// c. Return ? base.SetMutableBinding(V.[[ReferencedName]], W, V.[[Strict]]).
	return environment.set_mutable_binding(mut vm, reference.name.as_string(), value,
		reference.strict)
}

// 13.5.1.2 Runtime Semantics: Evaluation, https://tc39.es/ecma262/#sec-delete-operator-runtime-semantics-evaluation
pub fn (reference Reference) delete_(mut vm VM) !bool {
	assert !reference.is_private_reference()
	// 4. If IsUnresolvableReference(ref) is true, then
	if reference.is_unresolvable() {
		// a. Assert: ref.[[Strict]] is false.
		if reference.strict {
			panic('delete of an unresolvable reference in strict mode')
		}
		// b. Return true.
		return true
	}
	// 5. If IsPropertyReference(ref) is true, then
	if reference.is_property_reference() {
		// b. If IsSuperReference(ref) is true, throw a ReferenceError exception.
		if reference.is_super_reference() {
			return vm.throw_error_type(.reference_error, .unsupported_delete_super_property)
		}
		// c. Let baseObj be ? ToObject(ref.[[Base]]).
		if reference.base_value.is_nullish() {
			return vm.throw_error_type(.type_error, .to_object_null_or_undefined)
		}
		mut base_obj := reference.base_object(mut vm)!
		// d. Let deleteStatus be ? baseObj.[[Delete]](ref.[[ReferencedName]]).
		delete_status := base_obj.internal_delete(reference.name)
		// e. If deleteStatus is false and ref.[[Strict]] is true, throw a TypeError exception.
		if !delete_status && reference.strict {
			return vm.throw_error_type(.type_error, .reference_nullish_delete_property,
				reference.name.str(), reference.base_value.str())
		}
		// f. Return deleteStatus.
		return delete_status
	}
	// 6. Else,
	// b. Assert: base is an Environment Record.
	mut environment := reference.base_environment_record()
	// c. Return ? base.DeleteBinding(ref.[[ReferencedName]]).
	return environment.delete_binding(mut vm, reference.name.as_string())
}

pub fn (reference Reference) initialize_referenced_binding(mut vm VM, value Value, hint InitializeBindingHint) ! {
	if reference.is_unresolvable() {
		panic('InitializeReferencedBinding on an unresolvable reference')
	}
	mut environment := reference.base_environment_record()
	return environment.initialize_binding(mut vm, reference.name.as_string(), value, hint)
}
