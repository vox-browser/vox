module libjs

@[heap]
struct SpeciesTestLog {
mut:
	events []string
}

fn test_species_constructor_default_custom_and_bound_selection_preserves_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	default_constructor := vm.realm().boolean_constructor_record()
	mut object := Object.create(vm.realm(), none)
	assert voidptr(species_constructor(mut vm, object, default_constructor)!) == voidptr(default_constructor)
	for constructor in [js_null(), Value.from_i32(0), Value.from_bool(false)] {
		object.define_direct_property(PropertyName.from_str('constructor'), constructor, 7)
		if _ := species_constructor(mut vm, object, default_constructor) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	mut constructor := Object.create(vm.realm(), none)
	object.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), 7)
	for species in [js_undefined(), js_null()] {
		constructor.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()), species, 7)
		assert voidptr(species_constructor(mut vm, object, default_constructor)!) == voidptr(default_constructor)
	}
	other_context := initialize_host_defined_realm(mut vm, RealmGlobalHooks{})!
	custom := vm.realm().boolean_constructor_record()
	vm.pop_execution_context()
	assert voidptr(other_context.realm?) != voidptr(vm.realm())
	bound := BoundFunction.create(vm.realm(), custom, js_null(), []Value{})
	for species in [custom, bound.object] {
		constructor.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()), Value.from_object(species), 7)
		assert voidptr(species_constructor(mut vm, object, default_constructor)!) == voidptr(species)
	}
	for species in [Value.from_i32(1), Value.from_object(constructor),
		Value.from_object(vm.realm().function_prototype_record())] {
		constructor.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()), species, 7)
		if _ := species_constructor(mut vm, object, default_constructor) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

fn test_species_constructor_observes_getters_once_in_order_and_propagates_original_errors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	default_constructor := vm.realm().boolean_constructor_record()
	for mode in ['success', 'constructor throws', 'species throws'] {
		mut log := &SpeciesTestLog{}
		mut constructor := Object.create(vm.realm(), none)
		constructor.define_native_accessor(mut vm, vm.realm(), PropertyName.from_symbol(vm.well_known_symbol_species()),
			fn [mut log, mode, default_constructor] (mut vm VM) !Value {
			log.events << 'species'
			if mode == 'species throws' { return throw_completion(Value.from_i32(42)) }
			return Value.from_object(default_constructor)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		mut object := Object.create(vm.realm(), none)
		object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('constructor'),
			fn [mut log, mode, constructor] (mut vm VM) !Value {
			log.events << 'constructor'
			if mode == 'constructor throws' { return throw_completion(Value.from_i32(17)) }
			return Value.from_object(constructor)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		if selected := species_constructor(mut vm, object, default_constructor) {
			assert mode == 'success' && voidptr(selected) == voidptr(default_constructor)
		} else { assert thrown_value(err).number == if mode == 'constructor throws' { 17 } else { 42 } }
		assert log.events == if mode == 'constructor throws' { ['constructor'] } else { ['constructor', 'species'] }
	}
}
