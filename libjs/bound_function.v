module libjs

// Runtime/BoundFunction.{h,cpp}: BoundFunctionCreate and [[Call]]. The native
// target owns callee-frame allocation in this port; forwarding therefore builds
// the concatenated argument list rather than shifting a shared frame in place.
// Constructor forwarding remains a dependency of the construction slice.
@[heap]
pub struct BoundFunction {
pub:
	object                &Object
	bound_target_function &Object
	bound_this            Value
	bound_arguments       []Value
}

pub fn BoundFunction.create(realm &Realm, target &Object, bound_this Value, arguments []Value) &BoundFunction {
	assert target.callable != none
	mut object := Object.create(realm, target.internal_get_prototype_of())
	object.class_name = 'Function'
	function := &BoundFunction{
		object:                object
		bound_target_function: target
		bound_this:            bound_this
		bound_arguments:       arguments.clone()
	}
	object.callable = FunctionObject(function)
	object.bound_function = function
	return function
}

pub fn (function &BoundFunction) realm() ?&Realm {
	// BoundFunction inherits FunctionObject's null realm; GetFunctionRealm
	// separately follows [[BoundTargetFunction]] when the operation needs it.
	return none
}

pub fn (function &BoundFunction) name_for_call_stack() Utf16String {
	return Value.from_object(function.bound_target_function).as_function().name_for_call_stack()
}

pub fn (mut function BoundFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	mut combined := function.bound_arguments.clone()
	combined << arguments
	mut target := Value.from_object(function.bound_target_function).as_function()
	return target.internal_call(mut vm, function.bound_this, combined)
}
