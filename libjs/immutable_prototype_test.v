module libjs

fn test_set_immutable_prototype_uses_identity_and_never_mutates_the_object() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	other := Object.create(vm.realm(), none)
	for extensible in [true, false] {
		mut object := Object.create(vm.realm(), none)
		object.extensible = extensible
		assert object.set_immutable_prototype(none)
		assert !object.set_immutable_prototype(parent)
		assert object.prototype == none
		object.prototype = parent
		assert object.set_immutable_prototype(parent)
		assert !object.set_immutable_prototype(other)
		assert !object.set_immutable_prototype(none)
		assert voidptr(object.prototype?) == voidptr(parent)
	}
}

fn test_immutable_internal_method_dispatch_keeps_ordinary_objects_mutable() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut root := Object.create(vm.realm(), none)
	root.immutable_prototype = true
	mut ordinary := Object.create(vm.realm(), root)
	assert root.internal_set_prototype_of(none)
	assert !root.internal_set_prototype_of(ordinary)
	assert root.extensible && root.prototype == none
	assert ordinary.internal_set_prototype_of(none)
	assert ordinary.prototype == none
	assert ordinary.internal_set_prototype_of(root)
	assert voidptr(ordinary.prototype?) == voidptr(root)
	root.internal_prevent_extensions()
	assert root.internal_set_prototype_of(none)
	assert !root.internal_set_prototype_of(ordinary)
	mut child := Object.create(vm.realm(), ordinary)
	assert !ordinary.internal_set_prototype_of(child)
	assert voidptr(ordinary.prototype?) == voidptr(root)
}
