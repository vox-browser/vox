// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/WeakRef{,Constructor,Prototype}.cpp. The existing disappearing-link
// adapter stores the target weakly; non-collecting builds retain its encoded
// identity. AddToKeptObjects keeps successful reads stable until job cleanup.
@[heap]
pub struct WeakRefObject {
	target WeakCellReference
	target_tag ValueTag
}

fn initialize_weak_ref_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.weak_ref_prototype = prototype
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'WeakRef constructor requires new') },
		weak_ref_construct, 1, PropertyName.from_str('WeakRef')).object
	realm.weak_ref_constructor = constructor
	mut function := constructor
	function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('WeakRef')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut prototype, 'deref', 0, weak_ref_deref)
}

fn weak_ref_construct(mut vm VM, new_target &Object) !&Object {
	value := vm.argument(0)
	if !can_be_held_weakly(value) { return vm.throw_error_type(.type_error, .cannot_be_held_weakly, value.str()) }
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.weak_ref_prototype or { panic('Missing WeakRef prototype') } })!
	mut object := Object.create(vm.realm(), prototype)
	object.mut_slots().weak_ref = &WeakRefObject{target: WeakCellReference.create(value.cell)!, target_tag: value.tag}
	vm.add_to_kept_objects(value)
	return object
}

fn weak_ref_deref(mut vm VM) !Value {
	value := vm.this_value()
	if value.is_object() {
		if reference := value.as_object().slots.weak_ref {
			cell := reference.target.cell()
			if cell == unsafe { nil } { return js_undefined() }
			target := Value{tag: reference.target_tag, cell: cell}
			vm.add_to_kept_objects(target)
			return target
		}
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'WeakRef')
}

fn (mut vm VM) add_to_kept_objects(value Value) {
	if !vm.kept_objects.any(it.cell == value.cell) { vm.kept_objects << value }
}

// ClearKeptObjects runs after a full microtask checkpoint, not after each
// nested function or individual Promise reaction. Clear the retained backing
// slots too, so a conservative collector cannot keep old targets alive.
pub fn (mut vm VM) clear_kept_objects() {
	for index in 0 .. vm.kept_objects.len { vm.kept_objects[index] = js_undefined() }
	vm.kept_objects.clear()
}

pub fn (mut vm VM) set_external_promise_job_queue(external bool) {
	vm.promise_jobs_external = external
}
