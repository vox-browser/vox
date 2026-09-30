module libjs

// Runtime/Accessor.h. V heap allocation replaces vm.heap().allocate; callable
// Object pointers retain FunctionObject identity and keep their implementations
// alive. An absent pointer represents JavaScript undefined.
@[heap]
pub struct Accessor {
pub mut:
	getter           ?&Object
	setter           ?&Object
	cached_value_key ?&Symbol
}

pub fn Accessor.create(getter ?&Object, setter ?&Object, cached_value_key ?&Symbol) &Accessor {
	if function := getter { assert function.callable != none
	 }
	if function := setter { assert function.callable != none
	 }
	if key := cached_value_key { assert key.is_private()
	 }
	return &Accessor{
		getter:           getter
		setter:           setter
		cached_value_key: cached_value_key
	}
}

pub fn (mut accessor Accessor) set_getter(getter ?&Object) {
	if function := getter { assert function.callable != none
	 }
	accessor.getter = getter
}

pub fn (mut accessor Accessor) set_setter(setter ?&Object) {
	if function := setter { assert function.callable != none
	 }
	accessor.setter = setter
}

pub fn (mut accessor Accessor) set_cached_value_key(key ?&Symbol) {
	if symbol := key { assert symbol.is_private()
	 }
	accessor.cached_value_key = key
}

fn accessor_function(value Value) ?&Object {
	assert value.is_function() || value.is_undefined()
	if value.is_undefined() { return none }
	return value.as_object()
}

fn accessor_function_value(function ?&Object) Value {
	if object := function { return Value.from_object(object) }
	return js_undefined()
}
