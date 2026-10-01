module libjs

// Runtime/AbstractOperations.cpp::SpeciesConstructor. Native and bound
// constructors already share IsConstructor through their translated slots.
pub fn species_constructor(mut vm VM, object &Object, default_constructor &Object) !&Object {
	assert default_constructor.callable != none
	constructor := object.get(mut vm, PropertyName.from_str('constructor'))!
	if constructor.is_undefined() { return default_constructor }
	if !constructor.is_object() {
		return vm.throw_error_type(.type_error, .not_a_constructor, constructor.str())
	}
	species := constructor.as_object().get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_species()))!
	if species.is_nullish() { return default_constructor }
	if species.is_constructor() { return species.as_object() }
	return vm.throw_error_type(.type_error, .not_a_constructor, species.str())
}
