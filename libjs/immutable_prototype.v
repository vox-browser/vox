module libjs

// Object.cpp::SetImmutablePrototype, selected by ObjectPrototype's
// [[SetPrototypeOf]] override. Prototype identity is independent of extensibility.
pub fn (object &Object) set_immutable_prototype(prototype ?&Object) bool {
	current := object.internal_get_prototype_of() or { return prototype == none }
	proposed := prototype or { return false }
	return voidptr(current) == voidptr(proposed)
}
