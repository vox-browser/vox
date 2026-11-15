// SPDX-License-Identifier: BSD-2-Clause
module libjs

@[heap]
struct SuperPropertyBase {
	base Value
	receiver Value
}

// ResolveThisBinding precedes computed-key evaluation, then GetSuperBase reads
// the home object's current prototype. Later getters/RHS code cannot redirect
// the saved base or receiver.
fn resolve_super_reference(mut vm VM, receiver Value) !Value {
	environment := get_this_environment(vm)
	if environment is FunctionEnvironment {
		if !environment.has_super_binding() { return vm.throw_error(.reference_error, 'Super property requires a method home object') }
		mut object := Object.create(vm.realm(), none)
		object.class_name = '#SuperReference'
		object.super_property_base = &SuperPropertyBase{base: environment.get_super_base(), receiver: receiver}
		return Value.from_object(object)
	}
	return vm.throw_error(.reference_error, 'Super property requires a function environment')
}

fn super_property_base(mut vm VM, value Value) !&SuperPropertyBase {
	if value.is_object() {
		if reference := value.as_object().super_property_base { return reference }
	}
	return vm.throw_error(.internal_error, 'Invalid super property reference')
}
