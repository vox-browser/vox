module libjs

fn environment_test_vm() &VM {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	return vm
}

fn thrown_error_message(err IError) string {
	error_object := thrown_value(err).as_object()
	kind := error_object.error_kind() or { panic('thrown value is not an error object') }
	message := error_object.error_message() or { '' }
	return '${kind.name()}: ${message}'
}

fn test_declarative_environments_follow_the_binding_lifecycle() {
	mut vm := environment_test_vm()
	mut environment := DeclarativeEnvironment.create(none)
	x := utf16_string('x')
	exists, missing_index := environment.has_binding(mut vm, x)!
	assert !exists && missing_index == none
	environment.create_mutable_binding(mut vm, x, false)!
	found, index := environment.has_binding(mut vm, x)!
	assert found && index? == 0
	environment.get_binding_value(mut vm, x, true) or {
		assert thrown_error_message(err) == 'ReferenceError: Binding x is not initialized'
	}
	environment.set_mutable_binding(mut vm, x, Value.from_i32(1), true) or {
		assert thrown_error_message(err) == 'ReferenceError: Binding x is not initialized'
	}
	environment.initialize_binding(mut vm, x, Value.from_i32(1), .normal)!
	assert environment.get_binding_value(mut vm, x, false)!.as_i32() == 1
	environment.set_mutable_binding(mut vm, x, Value.from_i32(2), true)!
	assert environment.get_binding_value(mut vm, x, false)!.as_i32() == 2
	assert environment.binding_is_mutable_by_name(x)
	assert !environment.delete_binding(mut vm, x)!
	// Sloppy assignment to an unknown name creates a deletable binding.
	y := utf16_string('y')
	environment.set_mutable_binding(mut vm, y, Value.from_i32(3), false)!
	assert environment.binding_names().len == 2
	assert environment.delete_binding(mut vm, y)!
	assert environment.binding_count() == 1
	assert environment.binding_names().map(it.str()) == ['x']
	environment.set_mutable_binding(mut vm, y, Value.from_i32(3), true) or {
		assert thrown_error_message(err) == "ReferenceError: 'y' is not defined"
	}
	constant := utf16_string('constant')
	environment.create_immutable_binding(mut vm, constant, true)!
	environment.initialize_binding(mut vm, constant, Value.from_bool(true), .normal)!
	environment.set_mutable_binding(mut vm, constant, Value.from_bool(false), false) or {
		assert thrown_error_message(err) == 'TypeError: Invalid assignment to const variable'
	}
	sloppy_constant := utf16_string('sloppy')
	environment.create_immutable_binding(mut vm, sloppy_constant, false)!
	environment.initialize_binding(mut vm, sloppy_constant, Value.from_i32(4), .normal)!
	environment.set_mutable_binding(mut vm, sloppy_constant, Value.from_i32(5), false)!
	assert environment.get_binding_value(mut vm, sloppy_constant, false)!.as_i32() == 4
	initialize_or_set := utf16_string('either')
	environment.create_mutable_binding(mut vm, initialize_or_set, false)!
	environment.initialize_or_set_mutable_binding(mut vm, initialize_or_set, Value.from_i32(6))!
	environment.initialize_or_set_mutable_binding(mut vm, initialize_or_set, Value.from_i32(7))!
	assert environment.get_binding_value(mut vm, initialize_or_set, false)!.as_i32() == 7
	assert environment.environment_serial_number() > 0
	environment.create_mutable_binding(mut vm, utf16_string('disposable'), false)!
	environment.initialize_binding(mut vm, utf16_string('disposable'), js_undefined(), .sync_dispose) or {
		assert thrown_value(err).as_object().error_kind()? == .internal_error
		return
	}
	assert false, 'disposable bindings must report their pending translation'
}

fn test_eval_poisoning_propagates_to_the_function_boundary_and_hides_indices() {
	mut vm := environment_test_vm()
	mut outermost := DeclarativeEnvironment.create(none)
	mut function := FunctionEnvironment.create(Environment(outermost))
	mut middle := DeclarativeEnvironment.create(Environment(function))
	mut innermost := DeclarativeEnvironment.create(Environment(middle))
	innermost.create_mutable_binding(mut vm, utf16_string('a'), false)!
	innermost.set_permanently_screwed_by_eval()
	assert innermost.is_permanently_screwed_by_eval()
	assert middle.is_permanently_screwed_by_eval()
	assert function.is_permanently_screwed_by_eval()
	assert !outermost.is_permanently_screwed_by_eval()
	exists, index := innermost.has_binding(mut vm, utf16_string('a'))!
	assert exists && index == none
	assert function.is_function_environment()
	assert function.is_declarative_environment()
	assert !middle.is_function_environment()
	assert same_environment(middle.outer_environment()?, Environment(function))
	middle.set_is_catch_environment(true)
	assert middle.is_catch_environment()
	assert !Environment(middle).is_global_environment()
}

fn test_function_environments_guard_the_this_binding() {
	mut vm := environment_test_vm()
	mut environment := FunctionEnvironment.create(none)
	assert environment.this_binding_status() == .uninitialized
	assert environment.has_this_binding()
	environment.get_this_binding(mut vm) or {
		assert thrown_error_message(err) == 'ReferenceError: |this| has not been initialized'
	}
	bound := environment.bind_this_value(mut vm, Value.from_i32(5))!
	assert bound.as_i32() == 5
	assert environment.this_binding_status() == .initialized
	assert environment.get_this_binding(mut vm)!.as_i32() == 5
	environment.bind_this_value(mut vm, Value.from_i32(6)) or {
		assert thrown_error_message(err) == 'ReferenceError: |this| is already initialized'
	}
	environment.set_this_binding_status(.lexical)
	assert !environment.has_this_binding()
	assert environment.new_target.is_undefined()
	target := Object.create(vm.realm(), none)
	environment.set_new_target(Value.from_object(target))
	assert voidptr(environment.new_target.as_object()) == voidptr(target)
}

fn test_object_environments_delegate_to_the_binding_object_and_unscopables() {
	mut vm := environment_test_vm()
	realm := vm.realm()
	mut binding_object := Object.create(realm, none)
	x := utf16_string('x')
	mut environment := ObjectEnvironment.create(binding_object, false, none)
	assert environment.with_base_object() == none
	exists, _ := environment.has_binding(mut vm, x)!
	assert !exists
	environment.create_mutable_binding(mut vm, x, true)!
	found, _ := environment.has_binding(mut vm, x)!
	assert found
	assert binding_object.get(PropertyName.from_str('x')).is_undefined()
	environment.initialize_binding(mut vm, x, Value.from_i32(1), .normal)!
	assert environment.get_binding_value(mut vm, x, true)!.as_i32() == 1
	environment.set_mutable_binding(mut vm, x, Value.from_i32(2), true)!
	assert binding_object.get(PropertyName.from_str('x')).as_i32() == 2
	assert environment.get_binding_value(mut vm, utf16_string('missing'), false)!.is_undefined()
	environment.get_binding_value(mut vm, utf16_string('missing'), true) or {
		assert thrown_error_message(err) == "ReferenceError: 'missing' is not defined"
	}
	environment.set_mutable_binding(mut vm, utf16_string('missing'), js_null(), true) or {
		assert thrown_error_message(err) == "ReferenceError: 'missing' is not defined"
	}
	binding_object.define_direct_property(PropertyName.from_str('locked'), Value.from_i32(0), attribute_configurable)
	environment.set_mutable_binding(mut vm, utf16_string('locked'), Value.from_i32(1), true) or {
		assert thrown_error_message(err) == "TypeError: Cannot write to non-writable property 'locked'"
	}
	assert environment.delete_binding(mut vm, x)!
	assert !binding_object.has_own_property(PropertyName.from_str('x'))

	mut with_object := Object.create(realm, none)
	assert with_object.create_data_property(PropertyName.from_str('hidden'), Value.from_i32(1))
	assert with_object.create_data_property(PropertyName.from_str('shown'), Value.from_i32(2))
	mut unscopables := Object.create(realm, none)
	assert unscopables.create_data_property(PropertyName.from_str('hidden'), Value.from_bool(true))
	assert unscopables.create_data_property(PropertyName.from_str('shown'), Value.from_i32(0))
	assert with_object.create_data_property(PropertyName.from_symbol(vm.well_known_symbol_unscopables()),
		Value.from_object(unscopables))
	mut with_environment := ObjectEnvironment.create(with_object, true, none)
	assert voidptr(with_environment.with_base_object()?) == voidptr(with_object)
	hidden, _ := with_environment.has_binding(mut vm, utf16_string('hidden'))!
	assert !hidden
	shown, _ := with_environment.has_binding(mut vm, utf16_string('shown'))!
	assert shown
	assert with_environment.get_binding_value(mut vm, utf16_string('shown'), false)!.as_i32() == 2
	assert with_environment.is_object_environment()
}

fn test_global_environments_prefer_lexical_declarations_over_global_properties() {
	mut vm := environment_test_vm()
	realm := vm.realm()
	mut global := vm.realm().global_environment_record()
	assert global.has_this_binding()
	assert voidptr(global.get_this_binding(mut vm)!.as_object()) == voidptr(realm.global_object_record())
	lexical := utf16_string('lexical')
	global.create_immutable_binding(mut vm, lexical, true)!
	global.create_mutable_binding(mut vm, lexical, false) or {
		assert thrown_error_message(err) == "TypeError: Global environment already has binding 'lexical'"
	}
	global.initialize_binding(mut vm, lexical, Value.from_i32(1), .normal)!
	assert global.has_lexical_declaration(lexical)
	assert global.get_binding_value(mut vm, lexical, true)!.as_i32() == 1
	global.set_mutable_binding(mut vm, lexical, Value.from_i32(2), true) or {
		assert thrown_error_message(err) == 'TypeError: Invalid assignment to const variable'
	}
	assert !global.delete_binding(mut vm, lexical)!
	variable := utf16_string('variable')
	assert global.can_declare_global_var(variable)
	global.create_global_var_binding(mut vm, variable, true)!
	mut global_object := realm.global_object_record()
	assert global_object.has_own_property(PropertyName.from_str('variable'))
	exists, _ := global.has_binding(mut vm, variable)!
	assert exists
	global.set_mutable_binding(mut vm, variable, Value.from_i32(3), true)!
	assert global.get_binding_value(mut vm, variable, true)!.as_i32() == 3
	assert global.delete_binding(mut vm, variable)!
	assert !global_object.has_own_property(PropertyName.from_str('variable'))
	assert global.delete_binding(mut vm, utf16_string('never-declared'))!
	function := utf16_string('fn')
	assert global.can_declare_global_function(function)
	global.create_global_function_binding(mut vm, function, Value.from_i32(4), false)!
	descriptor := global_object.internal_get_own_property(PropertyName.from_str('fn'))?
	assert descriptor.value?.as_i32() == 4
	assert descriptor.writable? && descriptor.enumerable? && !descriptor.configurable?
	assert global.can_declare_global_function(function)
	assert global.has_restricted_global_property(function)
	assert !global.has_restricted_global_property(utf16_string('absent'))
	global_object.define_direct_property(PropertyName.from_str('sealed'), Value.from_i32(0), 0)
	assert !global.can_declare_global_function(utf16_string('sealed'))
	global.create_global_function_binding(mut vm, utf16_string('sealed'), Value.from_i32(1), false) or {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	global_object.extensible = false
	assert !global.can_declare_global_var(utf16_string('new-var'))
	assert !global.can_declare_global_function(utf16_string('new-fn'))
	assert Environment(global).is_global_environment()
	assert vm.global_declarative_environment().has_binding_named(lexical)
}

fn test_private_environments_resolve_names_through_outer_records() {
	mut vm := environment_test_vm()
	mut outer := PrivateEnvironment.create(mut vm, none)
	mut inner := PrivateEnvironment.create(mut vm, outer)
	assert outer.unique_id != inner.unique_id
	outer.add_private_name(utf16_string('#shared'))
	outer.add_private_name(utf16_string('#shared'))
	inner.add_private_name(utf16_string('#own'))
	assert outer.private_names.len == 1
	assert inner.contains_private_identifier(utf16_string('#shared'))
	assert inner.contains_private_identifier(utf16_string('#own'))
	assert !outer.contains_private_identifier(utf16_string('#own'))
	resolved := inner.resolve_private_identifier(utf16_string('#shared'))
	assert resolved.unique_id == outer.unique_id
	assert resolved == PrivateName{outer.unique_id, utf16_string('#shared')}
	assert inner.resolve_private_identifier(utf16_string('#own')).unique_id == inner.unique_id
}

fn test_references_read_write_and_delete_through_environments_and_objects() {
	mut vm := environment_test_vm()
	realm := vm.realm()
	mut environment := DeclarativeEnvironment.create(none)
	x := utf16_string('x')
	environment.create_mutable_binding(mut vm, x, true)!
	reference := Reference.for_environment(Environment(environment), x, false, EnvironmentCoordinate{
		hops:  0
		index: 0
	})
	assert reference.is_environment_reference()
	assert !reference.is_property_reference()
	assert reference.environment_coordinate?.is_valid()
	assert !EnvironmentCoordinate{}.is_valid()
	reference.initialize_referenced_binding(mut vm, Value.from_i32(1), .normal)!
	assert reference.get_value(mut vm)!.as_i32() == 1
	reference.put_value(mut vm, Value.from_i32(2))!
	assert environment.get_binding_value(mut vm, x, false)!.as_i32() == 2
	assert reference.delete_(mut vm)!
	assert !environment.has_binding_named(x)

	unresolvable := Reference.unresolvable(utf16_string('ghost'), false)
	assert unresolvable.is_unresolvable()
	unresolvable.get_value(mut vm) or {
		assert thrown_error_message(err) == "ReferenceError: 'ghost' is not defined"
	}
	unresolvable.put_value(mut vm, Value.from_i32(3))!
	assert vm.get_global_object().get(PropertyName.from_str('ghost')).as_i32() == 3
	assert unresolvable.delete_(mut vm)!
	strict_unresolvable := Reference.unresolvable(utf16_string('ghost'), true)
	strict_unresolvable.put_value(mut vm, Value.from_i32(4)) or {
		assert thrown_error_message(err) == "ReferenceError: 'ghost' is not defined"
	}

	mut object := Object.create(realm, none)
	property := Reference.for_value(Value.from_object(object), PropertyName.from_str('p'), none, true)
	assert property.is_property_reference()
	assert !property.is_super_reference()
	assert same_value(property.get_this_value(), Value.from_object(object))
	assert property.get_value(mut vm)!.is_undefined()
	property.put_value(mut vm, Value.from_i32(5))!
	assert object.get(PropertyName.from_str('p')).as_i32() == 5
	assert property.delete_(mut vm)!
	object.define_direct_property(PropertyName.from_str('p'), Value.from_i32(6), 0)
	property.put_value(mut vm, Value.from_i32(7)) or {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	property.delete_(mut vm) or {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	super_reference := Reference.for_value(Value.from_object(object), PropertyName.from_str('p'), Value.from_i32(9),
		true)
	assert super_reference.is_super_reference()
	assert super_reference.get_this_value().as_i32() == 9
	super_reference.delete_(mut vm) or {
		assert thrown_error_message(err) == "ReferenceError: Can't delete a property on 'super'"
	}
	nullish := Reference.for_value(js_undefined(), PropertyName.from_str('p'), none, false)
	nullish.get_value(mut vm) or {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}
