module libjs

// Translated from LibJS/Runtime/ErrorTypes.h: the message table used by
// VM.throw_error_type() for spec-defined error conditions. Each template
// substitutes "{}" placeholders in argument order like the upstream formatter.
pub enum ErrorType {
	accessor_bad_field
	accessor_value_or_writable
	agent_cannot_suspend
	array_max_size
	async_disposable_stack_already_disposed
	bad_arg_count_many
	bad_arg_count_one
	big_int_bad_operator
	big_int_bad_operator_other_type
	big_int_from_non_integral
	big_int_invalid_value
	big_int_size_exceeded
	binding_not_initialized
	buffer_out_of_bounds
	byte_length_exceeds_max_byte_length
	byte_length_less_than_previous_byte_length
	call_stack_size_exceeded
	cannot_be_held_weakly
	cannot_declare_global_function
	cannot_declare_global_variable
	class_constructor_without_new
	class_extends_value_invalid_prototype
	class_extends_value_not_a_constructor_or_null
	class_is_abstract
	constructor_without_new
	convert
	data_view_out_of_range_byte_offset
	derived_constructor_returning_invalid_value
	desc_write_non_writable
	detached_array_buffer
	detach_key_mismatch
	disposable_stack_already_disposed
	division_by_zero
	dynamic_import_not_allowed
	finalization_registry_same_target_and_value
	fixed_array_buffer
	generator_already_executing
	generator_brand_mismatch
	get_capabilities_executor_called_multiple_times
	get_legacy_reg_exp_static_property_this_value_mismatch
	get_legacy_reg_exp_static_property_value_empty
	global_environment_already_has_binding
	import_attribute_unsupported
	index_out_of_range
	in_operator_with_object
	instance_of_operator_bad_prototype
	intl_fractional_unit_followed_by_non_fractional_unit
	intl_fractional_units_mixed_with_always_display
	intl_invalid_date_time_format_option
	intl_invalid_key
	intl_invalid_language_tag
	intl_invalid_rounding_increment
	intl_invalid_rounding_increment_for_fraction_digits
	intl_invalid_rounding_increment_for_rounding_type
	intl_invalid_time
	intl_invalid_unit
	intl_minimum_exceeds_maximum
	intl_non_numeric_or2_digit_after_numeric_or2_digit
	intl_number_is_na_n_or_out_of_range
	intl_option_undefined
	intl_temporal_format_is_null
	intl_temporal_format_range_type_mismatch
	intl_temporal_invalid_calendar
	intl_temporal_zoned_date_time
	invalid_assign_to_const
	invalid_code_point
	invalid_enumeration_value
	invalid_fraction_digits
	invalid_hint
	invalid_index
	invalid_left_hand_assignment
	invalid_length
	invalid_normalization_form
	invalid_or_ambiguous_export_entry
	invalid_precision
	invalid_radix
	invalid_restricted_floating_point_parameter
	invalid_time_value
	is_not_a
	is_not_a_evaluated_from
	is_not_an
	is_undefined
	iterable_next_bad_return
	iterable_return_bad_return
	json_big_int
	json_circular
	json_malformed
	json_raw_json_non_primitive
	math_sum_precise_overflow
	missing_required_property
	module_no_environment
	module_not_found
	negative_exponent
	no_dispose_method
	not_a_constructor
	not_a_function
	not_an_integer_or_undefined
	not_an_object
	not_an_object_of_type
	not_an_object_or_null
	not_an_object_or_string
	not_a_shared_array_buffer
	not_a_string
	not_a_symbol
	not_enough_memory_to_allocate
	not_implemented
	not_iterable
	not_object_coercible
	not_undefined
	number_is_na_n
	number_is_na_n_or_infinity
	number_is_negative
	object_define_own_property_returned_false
	object_delete_returned_false
	object_freeze_failed
	object_prevent_extensions_returned_false
	object_prototype_wrong_type
	object_seal_failed
	object_set_prototype_of_returned_false
	object_set_returned_false
	option_is_not_valid_value
	out_of_memory
	overload_resolution_failed
	private_field_already_declared
	private_field_not_declared
	private_field_does_not_exist_on_object
	private_field_get_accessor_without_getter
	private_field_set_accessor_without_setter
	private_field_set_method
	promise_executor_not_a_function
	proxy_construct_bad_return_type
	proxy_constructor_bad_type
	proxy_get_own_descriptor_return
	proxy_get_prototype_of_return
	proxy_is_extensible_return
	proxy_own_property_keys_duplicates
	proxy_own_property_keys_non_extensible_new_property
	proxy_own_property_keys_non_extensible_skipped_property
	proxy_own_property_keys_not_string_or_symbol
	proxy_own_property_keys_skipped_nonconfigurable_property
	proxy_prevent_extensions_return
	proxy_revoked
	reduce_no_initial
	reference_nullish_delete_property
	reference_nullish_set_property
	reference_primitive_set_property
	reference_unresolvable
	reg_exp_backtrack_limit_exceeded
	reg_exp_compile_error
	reg_exp_object_bad_flag
	reg_exp_object_incompatible_flags
	reg_exp_object_repeated_flag
	restricted_function_properties_access
	restricted_global_property
	set_legacy_reg_exp_static_property_this_value_mismatch
	shared_array_buffer
	species_constructor_did_not_create
	species_constructor_returned
	string_non_global_reg_exp
	string_repeat_count_must_be
	string_repeat_count_must_not_overflow
	string_size_must_not_overflow
	temporal_different_calendars
	temporal_different_time_zones
	temporal_disambiguate_possible_epoch_ns_reject_more_than_one
	temporal_disambiguate_possible_epoch_ns_reject_zero
	temporal_invalid_calendar
	temporal_invalid_calendar_field_name
	temporal_invalid_calendar_identifier
	temporal_invalid_calendar_string
	temporal_invalid_critical_annotation
	temporal_invalid_duration
	temporal_invalid_duration_like_object
	temporal_invalid_duration_property_value_non_integral
	temporal_invalid_duration_string
	temporal_invalid_epoch_nanoseconds
	temporal_invalid_instant_string
	temporal_invalid_iso_date
	temporal_invalid_iso_date_time
	temporal_invalid_largest_unit
	temporal_invalid_month_code
	temporal_invalid_plain_date
	temporal_invalid_plain_date_time
	temporal_invalid_plain_month_day
	temporal_invalid_plain_time
	temporal_invalid_plain_year_month
	temporal_invalid_plain_year_month_addition
	temporal_invalid_time
	temporal_invalid_time_like_field
	temporal_invalid_time_zone_name
	temporal_invalid_time_zone_string
	temporal_invalid_unit_range
	temporal_invalid_zoned_date_time_offset
	temporal_invalid_zoned_date_time_string
	temporal_missing_options_object
	temporal_missing_starting_point
	temporal_missing_units
	temporal_object_must_be_partial_temporal_object
	this_has_not_been_initialized
	this_is_already_initialized
	to_object_null_or_undefined
	to_object_null_or_undefined_with_name
	to_object_null_or_undefined_with_property
	to_object_null_or_undefined_with_property_and_name
	top_level_variable_already_declared
	eval_var_hoisting_conflict
	to_primitive_returned_object
	typed_array_content_type_mismatch
	typed_array_invalid_buffer_length
	typed_array_invalid_byte_offset
	typed_array_invalid_copy
	typed_array_invalid_integer_index
	typed_array_invalid_target_offset
	typed_array_out_of_range_byte_offset
	typed_array_out_of_range_byte_offset_or_length
	typed_array_overflow
	typed_array_overflow_or_out_of_bounds
	typed_array_prototype_one_arg
	typed_array_type_is_not
	unknown_identifier
	unsupported_delete_super_property
	uri_malformed
	wrapped_function_call_throw_completion
	wrapped_function_copy_name_and_length_throw_completion
	yield_from_iterator_missing_throw_method
	zip_iterator_not_enough_results
}

// format returns the upstream message template with "{}" placeholders.
pub fn (error_type ErrorType) format() string {
	return match error_type {
		.accessor_bad_field { 'Accessor descriptor\'s \'{}\' field must be a function or undefined' }
		.accessor_value_or_writable { 'Accessor property descriptor cannot specify a value or writable key' }
		.agent_cannot_suspend { 'Agent is not allowed to suspend' }
		.array_max_size { 'Maximum array size exceeded' }
		.async_disposable_stack_already_disposed { 'AsyncDisposableStack is already disposed' }
		.bad_arg_count_many { '{}() needs {} arguments' }
		.bad_arg_count_one { '{}() needs one argument' }
		.big_int_bad_operator { 'Cannot use {} operator with BigInt' }
		.big_int_bad_operator_other_type { 'Cannot use {} operator with BigInt and other type' }
		.big_int_from_non_integral { 'Cannot convert non-integral number to BigInt' }
		.big_int_invalid_value { 'Invalid value for BigInt: {}' }
		.big_int_size_exceeded { 'Maximum BigInt size exceeded' }
		.binding_not_initialized { 'Binding {} is not initialized' }
		.buffer_out_of_bounds { '{} contains a property which references a value at an index not contained within its buffer\'s bounds' }
		.byte_length_exceeds_max_byte_length { 'ArrayBuffer byte length of {} exceeds the max byte length of {}' }
		.byte_length_less_than_previous_byte_length { 'SharedArrayBuffer byte length of {} is less than the previous byte length of {}' }
		.call_stack_size_exceeded { 'Call stack size limit exceeded' }
		.cannot_be_held_weakly { '{} cannot be held weakly' }
		.cannot_declare_global_function { 'Cannot declare global function of name \'{}\'' }
		.cannot_declare_global_variable { 'Cannot declare global variable of name \'{}\'' }
		.class_constructor_without_new { 'Class constructor {} must be called with \'new\'' }
		.class_extends_value_invalid_prototype { 'Class extends value has an invalid prototype {}' }
		.class_extends_value_not_a_constructor_or_null { 'Class extends value {} is not a constructor or null' }
		.class_is_abstract { 'Abstract class {} cannot be constructed directly' }
		.constructor_without_new { '{} constructor must be called with \'new\'' }
		.convert { 'Cannot convert {} to {}' }
		.data_view_out_of_range_byte_offset { 'Data view byte offset {} is out of range for buffer with length {}' }
		.derived_constructor_returning_invalid_value { 'Derived constructor return invalid value' }
		.desc_write_non_writable { 'Cannot write to non-writable property \'{}\'' }
		.detached_array_buffer { 'ArrayBuffer is detached' }
		.detach_key_mismatch { 'Provided detach key {} does not match the ArrayBuffer\'s detach key {}' }
		.disposable_stack_already_disposed { 'DisposableStack already disposed values' }
		.division_by_zero { 'Division by zero' }
		.dynamic_import_not_allowed { 'Dynamic Imports are not allowed' }
		.finalization_registry_same_target_and_value { 'Target and held value must not be the same' }
		.fixed_array_buffer { 'ArrayBuffer is not resizable' }
		.generator_already_executing { 'Generator is already executing' }
		.generator_brand_mismatch { 'Generator brand \'{}\' does not match generator brand \'{}\')' }
		.get_capabilities_executor_called_multiple_times { 'GetCapabilitiesExecutor was called multiple times' }
		.get_legacy_reg_exp_static_property_this_value_mismatch { 'Legacy RegExp static property getter must be called with the RegExp constructor for the this value' }
		.get_legacy_reg_exp_static_property_value_empty { 'Legacy RegExp static property getter value is empty' }
		.global_environment_already_has_binding { 'Global environment already has binding \'{}\'' }
		.import_attribute_unsupported { 'Every import attribute is not supported' }
		.index_out_of_range { 'Index {} is out of range of array length {}' }
		.in_operator_with_object { '\'in\' operator must be used on an object' }
		.instance_of_operator_bad_prototype { '\'prototype\' property of {} is not an object' }
		.intl_fractional_unit_followed_by_non_fractional_unit { 'Non-fractional unit {} is not allowed after a fractional unit' }
		.intl_fractional_units_mixed_with_always_display { 'Fractional unit {} may not be used with {} value of \'always\'' }
		.intl_invalid_date_time_format_option { 'Option {} cannot be set when also providing {}' }
		.intl_invalid_key { '{} is not a valid key' }
		.intl_invalid_language_tag { '{} is not a structurally valid language tag' }
		.intl_invalid_rounding_increment { '{} is not a valid rounding increment' }
		.intl_invalid_rounding_increment_for_fraction_digits { '{} is not a valid rounding increment for inequal min/max fraction digits' }
		.intl_invalid_rounding_increment_for_rounding_type { '{} is not a valid rounding increment for rounding type {}' }
		.intl_invalid_time { 'Time value must be between -8.64E15 and 8.64E15' }
		.intl_invalid_unit { 'Unit {} is not a valid time unit' }
		.intl_minimum_exceeds_maximum { 'Minimum value {} is larger than maximum value {}' }
		.intl_non_numeric_or2_digit_after_numeric_or2_digit { 'Styles other than \'fractional\', numeric\', or \'2-digit\' may not be used in smaller units after being used in larger units' }
		.intl_number_is_na_n_or_out_of_range { 'Value {} is NaN or is not between {} and {}' }
		.intl_option_undefined { 'Option {} must be defined when option {} is {}' }
		.intl_temporal_format_is_null { 'Unable to determine format for {}' }
		.intl_temporal_format_range_type_mismatch { 'Cannot format a date-time range with different date-time types' }
		.intl_temporal_invalid_calendar { 'Cannot format {} with calendar \'{}\' in locale with calendar \'{}\'' }
		.intl_temporal_zoned_date_time { 'Cannot format Temporal.ZonedDateTime, use Temporal.ZonedDateTime.prototype.toLocaleString' }
		.invalid_assign_to_const { 'Invalid assignment to const variable' }
		.invalid_code_point { 'Invalid code point {}, must be an integer no less than 0 and no greater than 0x10FFFF' }
		.invalid_enumeration_value { 'Invalid value \'{}\' for enumeration type \'{}\'' }
		.invalid_fraction_digits { 'Fraction Digits must be an integer no less than 0, and no greater than 100' }
		.invalid_hint { 'Invalid hint: "{}"' }
		.invalid_index { 'Index must be a positive integer no greater than 2^53-1' }
		.invalid_left_hand_assignment { 'Invalid left-hand side in assignment' }
		.invalid_length { 'Invalid {} length' }
		.invalid_normalization_form { 'The normalization form must be one of NFC, NFD, NFKC, NFKD. Got \'{}\'' }
		.invalid_or_ambiguous_export_entry { 'Invalid or ambiguous export entry \'{}\'' }
		.invalid_precision { 'Precision must be an integer no less than 1, and no greater than 100' }
		.invalid_radix { 'Radix must be an integer no less than 2, and no greater than 36' }
		.invalid_restricted_floating_point_parameter { 'Expected {} to be a finite floating-point number' }
		.invalid_time_value { 'Invalid time value' }
		.is_not_a { '{} is not a {}' }
		.is_not_a_evaluated_from { '{} is not a {} (evaluated from \'{}\')' }
		.is_not_an { '{} is not an {}' }
		.is_undefined { '{} is undefined' }
		.iterable_next_bad_return { 'iterator.next() returned a non-object value' }
		.iterable_return_bad_return { 'iterator.return() returned a non-object value' }
		.json_big_int { 'Cannot serialize BigInt value to JSON' }
		.json_circular { 'Cannot stringify circular object' }
		.json_malformed { 'Malformed JSON string' }
		.json_raw_json_non_primitive { 'JSON.rawJSON cannot accept object or array as outermost value' }
		.math_sum_precise_overflow { 'Overflow in Math.sumPrecise' }
		.missing_required_property { 'Required property {} is missing or undefined' }
		.module_no_environment { 'Cannot find module environment for imported binding' }
		.module_not_found { 'Cannot find/open module: \'{}\'' }
		.negative_exponent { 'Exponent must be positive' }
		.no_dispose_method { '{} does not have dispose method' }
		.not_a_constructor { '{} is not a constructor' }
		.not_a_function { '{} is not a function' }
		.not_an_integer_or_undefined { '{} is neither an integer nor undefined' }
		.not_an_object { '{} is not an object' }
		.not_an_object_of_type { 'Not an object of type {}' }
		.not_an_object_or_null { '{} is neither an object nor null' }
		.not_an_object_or_string { '{} is neither an object nor a string' }
		.not_a_shared_array_buffer { 'The array buffer object must be a SharedArrayBuffer' }
		.not_a_string { '{} is not a string' }
		.not_a_symbol { '{} is not a symbol' }
		.not_enough_memory_to_allocate { 'Not enough memory to allocate {} bytes' }
		.not_implemented { 'TODO({} is not implemented in LibJS)' }
		.not_iterable { '{} is not iterable' }
		.not_object_coercible { '{} cannot be converted to an object' }
		.not_undefined { '{} is not undefined' }
		.number_is_na_n { '{} must not be NaN' }
		.number_is_na_n_or_infinity { 'Number must not be NaN or Infinity' }
		.number_is_negative { '{} must not be negative' }
		.object_define_own_property_returned_false { 'Object\'s [[DefineOwnProperty]] method returned false' }
		.object_delete_returned_false { 'Object\'s [[Delete]] method returned false' }
		.object_freeze_failed { 'Could not freeze object' }
		.object_prevent_extensions_returned_false { 'Object\'s [[PreventExtensions]] method returned false' }
		.object_prototype_wrong_type { 'Prototype must be an object or null' }
		.object_seal_failed { 'Could not seal object' }
		.object_set_prototype_of_returned_false { 'Object\'s [[SetPrototypeOf]] method returned false' }
		.object_set_returned_false { 'Object\'s [[Set]] method returned false' }
		.option_is_not_valid_value { '{} is not a valid value for option {}' }
		.out_of_memory { 'Out of memory' }
		.overload_resolution_failed { 'Overload resolution failed' }
		.private_field_already_declared { 'Private field \'{}\' has already been declared' }
		.private_field_not_declared { 'Reference to undeclared private field or method \'{}\'' }
		.private_field_does_not_exist_on_object { 'Private field \'{}\' does not exist on object' }
		.private_field_get_accessor_without_getter { 'Cannot get private field \'{}\' as accessor without getter' }
		.private_field_set_accessor_without_setter { 'Cannot set private field \'{}\' as accessor without setter' }
		.private_field_set_method { 'Cannot set private method \'{}\'' }
		.promise_executor_not_a_function { 'Promise executor must be a function' }
		.proxy_construct_bad_return_type { 'Proxy handler\'s construct trap violates invariant: must return an object' }
		.proxy_constructor_bad_type { 'Expected {} argument of Proxy constructor to be object, got {}' }
		.proxy_get_own_descriptor_return { 'Proxy handler\'s getOwnPropertyDescriptor trap violates invariant: must return an object or undefined' }
		.proxy_get_prototype_of_return { 'Proxy handler\'s getPrototypeOf trap violates invariant: must return an object or null' }
		.proxy_is_extensible_return { 'Proxy handler\'s isExtensible trap violates invariant: return value must match the target\'s extensibility' }
		.proxy_own_property_keys_duplicates { 'Proxy handler\'s ownKeys trap violates invariant: the result list may not contain duplicate elements' }
		.proxy_own_property_keys_non_extensible_new_property { 'Proxy handler\'s ownKeys trap violates invariant: cannot report new property \'{}\' of non-extensible object' }
		.proxy_own_property_keys_non_extensible_skipped_property { 'Proxy handler\'s ownKeys trap violates invariant: cannot skip property \'{}\' of non-extensible object' }
		.proxy_own_property_keys_not_string_or_symbol { 'Proxy handler\'s ownKeys trap violates invariant: the type of each result list element is either String or Symbol' }
		.proxy_own_property_keys_skipped_nonconfigurable_property { 'Proxy handler\'s ownKeys trap violates invariant: cannot skip non-configurable property \'{}\'' }
		.proxy_prevent_extensions_return { 'Proxy handler\'s preventExtensions trap violates invariant: cannot return true if the target object is extensible' }
		.proxy_revoked { 'An operation was performed on a revoked Proxy object' }
		.reduce_no_initial { 'Reduce of empty array with no initial value' }
		.reference_nullish_delete_property { 'Cannot delete property \'{}\' of {}' }
		.reference_nullish_set_property { 'Cannot set property \'{}\' of {}' }
		.reference_primitive_set_property { 'Cannot set property \'{}\' of {} \'{}\'' }
		.reference_unresolvable { 'Unresolvable reference' }
		.reg_exp_backtrack_limit_exceeded { 'Regular expression backtrack limit exceeded' }
		.reg_exp_compile_error { 'RegExp compile error: {}' }
		.reg_exp_object_bad_flag { 'Invalid RegExp flag \'{}\'' }
		.reg_exp_object_incompatible_flags { 'RegExp flag \'{}\' is incompatible with flag \'{}\'' }
		.reg_exp_object_repeated_flag { 'Repeated RegExp flag \'{}\'' }
		.restricted_function_properties_access { 'Restricted function properties like \'callee\', \'caller\' and \'arguments\' may not be accessed in strict mode' }
		.restricted_global_property { 'Cannot declare global property \'{}\'' }
		.set_legacy_reg_exp_static_property_this_value_mismatch { 'Legacy RegExp static property setter must be called with the RegExp constructor for the this value' }
		.shared_array_buffer { 'The array buffer object cannot be a SharedArrayBuffer' }
		.species_constructor_did_not_create { 'Species constructor did not create {}' }
		.species_constructor_returned { 'Species constructor returned {}' }
		.string_non_global_reg_exp { 'RegExp argument is non-global' }
		.string_repeat_count_must_be { 'repeat count must be a {} number' }
		.string_repeat_count_must_not_overflow { 'repeat count must not overflow' }
		.string_size_must_not_overflow { 'string size must not overflow' }
		.temporal_different_calendars { 'Cannot compare dates from two different calendars' }
		.temporal_different_time_zones { 'Cannot compare dates from two different time zones' }
		.temporal_disambiguate_possible_epoch_ns_reject_more_than_one { 'Cannot disambiguate two or more possible epoch nanoseconds' }
		.temporal_disambiguate_possible_epoch_ns_reject_zero { 'Cannot disambiguate zero possible epoch nanoseconds' }
		.temporal_invalid_calendar { 'Invalid calendar' }
		.temporal_invalid_calendar_field_name { 'Invalid calendar field \'{}\'' }
		.temporal_invalid_calendar_identifier { 'Invalid calendar identifier \'{}\'' }
		.temporal_invalid_calendar_string { 'Invalid calendar string \'{}\'' }
		.temporal_invalid_critical_annotation { 'Invalid critical annotation: \'{}={}\'' }
		.temporal_invalid_duration { 'Invalid duration' }
		.temporal_invalid_duration_like_object { 'Invalid duration-like object' }
		.temporal_invalid_duration_property_value_non_integral { 'Invalid value for duration property \'{}\': must be an integer, got {}' }
		.temporal_invalid_duration_string { 'Invalid duration string \'{}\'' }
		.temporal_invalid_epoch_nanoseconds { 'Invalid epoch nanoseconds value, must be in range -86400 * 10^17 to 86400 * 10^17' }
		.temporal_invalid_instant_string { 'Invalid instant string \'{}\'' }
		.temporal_invalid_iso_date { 'Invalid ISO date' }
		.temporal_invalid_iso_date_time { 'Invalid ISO date time' }
		.temporal_invalid_largest_unit { 'Largest unit must not be {}' }
		.temporal_invalid_month_code { 'Invalid month code' }
		.temporal_invalid_plain_date { 'Invalid plain date' }
		.temporal_invalid_plain_date_time { 'Invalid plain date time' }
		.temporal_invalid_plain_month_day { 'Invalid plain month day' }
		.temporal_invalid_plain_time { 'Invalid plain time' }
		.temporal_invalid_plain_year_month { 'Invalid plain year month' }
		.temporal_invalid_plain_year_month_addition { 'Only years and months may be {} Temporal.PlainYearMonth' }
		.temporal_invalid_time { 'Invalid time' }
		.temporal_invalid_time_like_field { 'Invalid value {} for time field \'{}\'' }
		.temporal_invalid_time_zone_name { 'Invalid time zone name \'{}\'' }
		.temporal_invalid_time_zone_string { 'Invalid time zone string \'{}\'' }
		.temporal_invalid_unit_range { 'Invalid unit range, {} is larger than {}' }
		.temporal_invalid_zoned_date_time_offset { 'Invalid offset for the provided date and time in the current time zone' }
		.temporal_invalid_zoned_date_time_string { 'Invalid zoned date time string \'{}\'' }
		.temporal_missing_options_object { 'Required options object is missing or undefined' }
		.temporal_missing_starting_point { 'A starting point is required for comparing {}' }
		.temporal_missing_units { 'One or both of smallestUnit or largestUnit is required' }
		.temporal_object_must_be_partial_temporal_object { 'Object must be a partial Temporal object' }
		.this_has_not_been_initialized { '|this| has not been initialized' }
		.this_is_already_initialized { '|this| is already initialized' }
		.to_object_null_or_undefined { 'ToObject on null or undefined' }
		.to_object_null_or_undefined_with_name { '"{}" is {}' }
		.to_object_null_or_undefined_with_property { 'Cannot access property "{}" on {} object' }
		.to_object_null_or_undefined_with_property_and_name { 'Cannot access property "{}" on {} object "{}"' }
		.top_level_variable_already_declared { 'Redeclaration of top level variable \'{}\'' }
		.eval_var_hoisting_conflict { 'Cannot declare var \'{}\': there is already a lexical declaration with that name in scope' }
		.to_primitive_returned_object { 'Can\'t convert {} to primitive with hint "{}", its @@toPrimitive method returned an object' }
		.typed_array_content_type_mismatch { 'Can\'t create {} from {}' }
		.typed_array_invalid_buffer_length { 'Invalid buffer length for {}: must be a multiple of {}, got {}' }
		.typed_array_invalid_byte_offset { 'Invalid byte offset for {}: must be a multiple of {}, got {}' }
		.typed_array_invalid_copy { 'Copy between arrays of different content types ({} and {}) is prohibited' }
		.typed_array_invalid_integer_index { 'Invalid integer index: {}' }
		.typed_array_invalid_target_offset { 'Invalid target offset: must be {}' }
		.typed_array_out_of_range_byte_offset { 'Typed array byte offset {} is out of range for buffer with length {}' }
		.typed_array_out_of_range_byte_offset_or_length { 'Typed array range {}:{} is out of range for buffer with length {}' }
		.typed_array_overflow { 'Overflow in {}' }
		.typed_array_overflow_or_out_of_bounds { 'Overflow or out of bounds in {}' }
		.typed_array_prototype_one_arg { 'TypedArray.prototype.{}() requires at least one argument' }
		.typed_array_type_is_not { 'Typed array {} element type is not {}' }
		.unknown_identifier { '\'{}\' is not defined' }
		.unsupported_delete_super_property { 'Can\'t delete a property on \'super\'' }
		.uri_malformed { 'URI malformed' }
		.wrapped_function_call_throw_completion { 'Call of wrapped target function did not complete normally' }
		.wrapped_function_copy_name_and_length_throw_completion { 'Trying to copy target name and length did not complete normally' }
		.yield_from_iterator_missing_throw_method { 'yield* protocol violation: iterator must have a throw method' }
		.zip_iterator_not_enough_results { 'Not enough iterator results in \'strict\' mode' }
	}
}

// upstream_name returns the identifier used by the upstream ErrorType table.
pub fn (error_type ErrorType) upstream_name() string {
	return match error_type {
		.accessor_bad_field { 'AccessorBadField' }
		.accessor_value_or_writable { 'AccessorValueOrWritable' }
		.agent_cannot_suspend { 'AgentCannotSuspend' }
		.array_max_size { 'ArrayMaxSize' }
		.async_disposable_stack_already_disposed { 'AsyncDisposableStackAlreadyDisposed' }
		.bad_arg_count_many { 'BadArgCountMany' }
		.bad_arg_count_one { 'BadArgCountOne' }
		.big_int_bad_operator { 'BigIntBadOperator' }
		.big_int_bad_operator_other_type { 'BigIntBadOperatorOtherType' }
		.big_int_from_non_integral { 'BigIntFromNonIntegral' }
		.big_int_invalid_value { 'BigIntInvalidValue' }
		.big_int_size_exceeded { 'BigIntSizeExceeded' }
		.binding_not_initialized { 'BindingNotInitialized' }
		.buffer_out_of_bounds { 'BufferOutOfBounds' }
		.byte_length_exceeds_max_byte_length { 'ByteLengthExceedsMaxByteLength' }
		.byte_length_less_than_previous_byte_length { 'ByteLengthLessThanPreviousByteLength' }
		.call_stack_size_exceeded { 'CallStackSizeExceeded' }
		.cannot_be_held_weakly { 'CannotBeHeldWeakly' }
		.cannot_declare_global_function { 'CannotDeclareGlobalFunction' }
		.cannot_declare_global_variable { 'CannotDeclareGlobalVariable' }
		.class_constructor_without_new { 'ClassConstructorWithoutNew' }
		.class_extends_value_invalid_prototype { 'ClassExtendsValueInvalidPrototype' }
		.class_extends_value_not_a_constructor_or_null { 'ClassExtendsValueNotAConstructorOrNull' }
		.class_is_abstract { 'ClassIsAbstract' }
		.constructor_without_new { 'ConstructorWithoutNew' }
		.convert { 'Convert' }
		.data_view_out_of_range_byte_offset { 'DataViewOutOfRangeByteOffset' }
		.derived_constructor_returning_invalid_value { 'DerivedConstructorReturningInvalidValue' }
		.desc_write_non_writable { 'DescWriteNonWritable' }
		.detached_array_buffer { 'DetachedArrayBuffer' }
		.detach_key_mismatch { 'DetachKeyMismatch' }
		.disposable_stack_already_disposed { 'DisposableStackAlreadyDisposed' }
		.division_by_zero { 'DivisionByZero' }
		.dynamic_import_not_allowed { 'DynamicImportNotAllowed' }
		.finalization_registry_same_target_and_value { 'FinalizationRegistrySameTargetAndValue' }
		.fixed_array_buffer { 'FixedArrayBuffer' }
		.generator_already_executing { 'GeneratorAlreadyExecuting' }
		.generator_brand_mismatch { 'GeneratorBrandMismatch' }
		.get_capabilities_executor_called_multiple_times { 'GetCapabilitiesExecutorCalledMultipleTimes' }
		.get_legacy_reg_exp_static_property_this_value_mismatch { 'GetLegacyRegExpStaticPropertyThisValueMismatch' }
		.get_legacy_reg_exp_static_property_value_empty { 'GetLegacyRegExpStaticPropertyValueEmpty' }
		.global_environment_already_has_binding { 'GlobalEnvironmentAlreadyHasBinding' }
		.import_attribute_unsupported { 'ImportAttributeUnsupported' }
		.index_out_of_range { 'IndexOutOfRange' }
		.in_operator_with_object { 'InOperatorWithObject' }
		.instance_of_operator_bad_prototype { 'InstanceOfOperatorBadPrototype' }
		.intl_fractional_unit_followed_by_non_fractional_unit { 'IntlFractionalUnitFollowedByNonFractionalUnit' }
		.intl_fractional_units_mixed_with_always_display { 'IntlFractionalUnitsMixedWithAlwaysDisplay' }
		.intl_invalid_date_time_format_option { 'IntlInvalidDateTimeFormatOption' }
		.intl_invalid_key { 'IntlInvalidKey' }
		.intl_invalid_language_tag { 'IntlInvalidLanguageTag' }
		.intl_invalid_rounding_increment { 'IntlInvalidRoundingIncrement' }
		.intl_invalid_rounding_increment_for_fraction_digits { 'IntlInvalidRoundingIncrementForFractionDigits' }
		.intl_invalid_rounding_increment_for_rounding_type { 'IntlInvalidRoundingIncrementForRoundingType' }
		.intl_invalid_time { 'IntlInvalidTime' }
		.intl_invalid_unit { 'IntlInvalidUnit' }
		.intl_minimum_exceeds_maximum { 'IntlMinimumExceedsMaximum' }
		.intl_non_numeric_or2_digit_after_numeric_or2_digit { 'IntlNonNumericOr2DigitAfterNumericOr2Digit' }
		.intl_number_is_na_n_or_out_of_range { 'IntlNumberIsNaNOrOutOfRange' }
		.intl_option_undefined { 'IntlOptionUndefined' }
		.intl_temporal_format_is_null { 'IntlTemporalFormatIsNull' }
		.intl_temporal_format_range_type_mismatch { 'IntlTemporalFormatRangeTypeMismatch' }
		.intl_temporal_invalid_calendar { 'IntlTemporalInvalidCalendar' }
		.intl_temporal_zoned_date_time { 'IntlTemporalZonedDateTime' }
		.invalid_assign_to_const { 'InvalidAssignToConst' }
		.invalid_code_point { 'InvalidCodePoint' }
		.invalid_enumeration_value { 'InvalidEnumerationValue' }
		.invalid_fraction_digits { 'InvalidFractionDigits' }
		.invalid_hint { 'InvalidHint' }
		.invalid_index { 'InvalidIndex' }
		.invalid_left_hand_assignment { 'InvalidLeftHandAssignment' }
		.invalid_length { 'InvalidLength' }
		.invalid_normalization_form { 'InvalidNormalizationForm' }
		.invalid_or_ambiguous_export_entry { 'InvalidOrAmbiguousExportEntry' }
		.invalid_precision { 'InvalidPrecision' }
		.invalid_radix { 'InvalidRadix' }
		.invalid_restricted_floating_point_parameter { 'InvalidRestrictedFloatingPointParameter' }
		.invalid_time_value { 'InvalidTimeValue' }
		.is_not_a { 'IsNotA' }
		.is_not_a_evaluated_from { 'IsNotAEvaluatedFrom' }
		.is_not_an { 'IsNotAn' }
		.is_undefined { 'IsUndefined' }
		.iterable_next_bad_return { 'IterableNextBadReturn' }
		.iterable_return_bad_return { 'IterableReturnBadReturn' }
		.json_big_int { 'JsonBigInt' }
		.json_circular { 'JsonCircular' }
		.json_malformed { 'JsonMalformed' }
		.json_raw_json_non_primitive { 'JsonRawJSONNonPrimitive' }
		.math_sum_precise_overflow { 'MathSumPreciseOverflow' }
		.missing_required_property { 'MissingRequiredProperty' }
		.module_no_environment { 'ModuleNoEnvironment' }
		.module_not_found { 'ModuleNotFound' }
		.negative_exponent { 'NegativeExponent' }
		.no_dispose_method { 'NoDisposeMethod' }
		.not_a_constructor { 'NotAConstructor' }
		.not_a_function { 'NotAFunction' }
		.not_an_integer_or_undefined { 'NotAnIntegerOrUndefined' }
		.not_an_object { 'NotAnObject' }
		.not_an_object_of_type { 'NotAnObjectOfType' }
		.not_an_object_or_null { 'NotAnObjectOrNull' }
		.not_an_object_or_string { 'NotAnObjectOrString' }
		.not_a_shared_array_buffer { 'NotASharedArrayBuffer' }
		.not_a_string { 'NotAString' }
		.not_a_symbol { 'NotASymbol' }
		.not_enough_memory_to_allocate { 'NotEnoughMemoryToAllocate' }
		.not_implemented { 'NotImplemented' }
		.not_iterable { 'NotIterable' }
		.not_object_coercible { 'NotObjectCoercible' }
		.not_undefined { 'NotUndefined' }
		.number_is_na_n { 'NumberIsNaN' }
		.number_is_na_n_or_infinity { 'NumberIsNaNOrInfinity' }
		.number_is_negative { 'NumberIsNegative' }
		.object_define_own_property_returned_false { 'ObjectDefineOwnPropertyReturnedFalse' }
		.object_delete_returned_false { 'ObjectDeleteReturnedFalse' }
		.object_freeze_failed { 'ObjectFreezeFailed' }
		.object_prevent_extensions_returned_false { 'ObjectPreventExtensionsReturnedFalse' }
		.object_prototype_wrong_type { 'ObjectPrototypeWrongType' }
		.object_seal_failed { 'ObjectSealFailed' }
		.object_set_prototype_of_returned_false { 'ObjectSetPrototypeOfReturnedFalse' }
		.object_set_returned_false { 'ObjectSetReturnedFalse' }
		.option_is_not_valid_value { 'OptionIsNotValidValue' }
		.out_of_memory { 'OutOfMemory' }
		.overload_resolution_failed { 'OverloadResolutionFailed' }
		.private_field_already_declared { 'PrivateFieldAlreadyDeclared' }
		.private_field_not_declared { 'PrivateFieldNotDeclared' }
		.private_field_does_not_exist_on_object { 'PrivateFieldDoesNotExistOnObject' }
		.private_field_get_accessor_without_getter { 'PrivateFieldGetAccessorWithoutGetter' }
		.private_field_set_accessor_without_setter { 'PrivateFieldSetAccessorWithoutSetter' }
		.private_field_set_method { 'PrivateFieldSetMethod' }
		.promise_executor_not_a_function { 'PromiseExecutorNotAFunction' }
		.proxy_construct_bad_return_type { 'ProxyConstructBadReturnType' }
		.proxy_constructor_bad_type { 'ProxyConstructorBadType' }
		.proxy_get_own_descriptor_return { 'ProxyGetOwnDescriptorReturn' }
		.proxy_get_prototype_of_return { 'ProxyGetPrototypeOfReturn' }
		.proxy_is_extensible_return { 'ProxyIsExtensibleReturn' }
		.proxy_own_property_keys_duplicates { 'ProxyOwnPropertyKeysDuplicates' }
		.proxy_own_property_keys_non_extensible_new_property { 'ProxyOwnPropertyKeysNonExtensibleNewProperty' }
		.proxy_own_property_keys_non_extensible_skipped_property { 'ProxyOwnPropertyKeysNonExtensibleSkippedProperty' }
		.proxy_own_property_keys_not_string_or_symbol { 'ProxyOwnPropertyKeysNotStringOrSymbol' }
		.proxy_own_property_keys_skipped_nonconfigurable_property { 'ProxyOwnPropertyKeysSkippedNonconfigurableProperty' }
		.proxy_prevent_extensions_return { 'ProxyPreventExtensionsReturn' }
		.proxy_revoked { 'ProxyRevoked' }
		.reduce_no_initial { 'ReduceNoInitial' }
		.reference_nullish_delete_property { 'ReferenceNullishDeleteProperty' }
		.reference_nullish_set_property { 'ReferenceNullishSetProperty' }
		.reference_primitive_set_property { 'ReferencePrimitiveSetProperty' }
		.reference_unresolvable { 'ReferenceUnresolvable' }
		.reg_exp_backtrack_limit_exceeded { 'RegExpBacktrackLimitExceeded' }
		.reg_exp_compile_error { 'RegExpCompileError' }
		.reg_exp_object_bad_flag { 'RegExpObjectBadFlag' }
		.reg_exp_object_incompatible_flags { 'RegExpObjectIncompatibleFlags' }
		.reg_exp_object_repeated_flag { 'RegExpObjectRepeatedFlag' }
		.restricted_function_properties_access { 'RestrictedFunctionPropertiesAccess' }
		.restricted_global_property { 'RestrictedGlobalProperty' }
		.set_legacy_reg_exp_static_property_this_value_mismatch { 'SetLegacyRegExpStaticPropertyThisValueMismatch' }
		.shared_array_buffer { 'SharedArrayBuffer' }
		.species_constructor_did_not_create { 'SpeciesConstructorDidNotCreate' }
		.species_constructor_returned { 'SpeciesConstructorReturned' }
		.string_non_global_reg_exp { 'StringNonGlobalRegExp' }
		.string_repeat_count_must_be { 'StringRepeatCountMustBe' }
		.string_repeat_count_must_not_overflow { 'StringRepeatCountMustNotOverflow' }
		.string_size_must_not_overflow { 'StringSizeMustNotOverflow' }
		.temporal_different_calendars { 'TemporalDifferentCalendars' }
		.temporal_different_time_zones { 'TemporalDifferentTimeZones' }
		.temporal_disambiguate_possible_epoch_ns_reject_more_than_one { 'TemporalDisambiguatePossibleEpochNSRejectMoreThanOne' }
		.temporal_disambiguate_possible_epoch_ns_reject_zero { 'TemporalDisambiguatePossibleEpochNSRejectZero' }
		.temporal_invalid_calendar { 'TemporalInvalidCalendar' }
		.temporal_invalid_calendar_field_name { 'TemporalInvalidCalendarFieldName' }
		.temporal_invalid_calendar_identifier { 'TemporalInvalidCalendarIdentifier' }
		.temporal_invalid_calendar_string { 'TemporalInvalidCalendarString' }
		.temporal_invalid_critical_annotation { 'TemporalInvalidCriticalAnnotation' }
		.temporal_invalid_duration { 'TemporalInvalidDuration' }
		.temporal_invalid_duration_like_object { 'TemporalInvalidDurationLikeObject' }
		.temporal_invalid_duration_property_value_non_integral { 'TemporalInvalidDurationPropertyValueNonIntegral' }
		.temporal_invalid_duration_string { 'TemporalInvalidDurationString' }
		.temporal_invalid_epoch_nanoseconds { 'TemporalInvalidEpochNanoseconds' }
		.temporal_invalid_instant_string { 'TemporalInvalidInstantString' }
		.temporal_invalid_iso_date { 'TemporalInvalidISODate' }
		.temporal_invalid_iso_date_time { 'TemporalInvalidISODateTime' }
		.temporal_invalid_largest_unit { 'TemporalInvalidLargestUnit' }
		.temporal_invalid_month_code { 'TemporalInvalidMonthCode' }
		.temporal_invalid_plain_date { 'TemporalInvalidPlainDate' }
		.temporal_invalid_plain_date_time { 'TemporalInvalidPlainDateTime' }
		.temporal_invalid_plain_month_day { 'TemporalInvalidPlainMonthDay' }
		.temporal_invalid_plain_time { 'TemporalInvalidPlainTime' }
		.temporal_invalid_plain_year_month { 'TemporalInvalidPlainYearMonth' }
		.temporal_invalid_plain_year_month_addition { 'TemporalInvalidPlainYearMonthAddition' }
		.temporal_invalid_time { 'TemporalInvalidTime' }
		.temporal_invalid_time_like_field { 'TemporalInvalidTimeLikeField' }
		.temporal_invalid_time_zone_name { 'TemporalInvalidTimeZoneName' }
		.temporal_invalid_time_zone_string { 'TemporalInvalidTimeZoneString' }
		.temporal_invalid_unit_range { 'TemporalInvalidUnitRange' }
		.temporal_invalid_zoned_date_time_offset { 'TemporalInvalidZonedDateTimeOffset' }
		.temporal_invalid_zoned_date_time_string { 'TemporalInvalidZonedDateTimeString' }
		.temporal_missing_options_object { 'TemporalMissingOptionsObject' }
		.temporal_missing_starting_point { 'TemporalMissingStartingPoint' }
		.temporal_missing_units { 'TemporalMissingUnits' }
		.temporal_object_must_be_partial_temporal_object { 'TemporalObjectMustBePartialTemporalObject' }
		.this_has_not_been_initialized { 'ThisHasNotBeenInitialized' }
		.this_is_already_initialized { 'ThisIsAlreadyInitialized' }
		.to_object_null_or_undefined { 'ToObjectNullOrUndefined' }
		.to_object_null_or_undefined_with_name { 'ToObjectNullOrUndefinedWithName' }
		.to_object_null_or_undefined_with_property { 'ToObjectNullOrUndefinedWithProperty' }
		.to_object_null_or_undefined_with_property_and_name { 'ToObjectNullOrUndefinedWithPropertyAndName' }
		.top_level_variable_already_declared { 'TopLevelVariableAlreadyDeclared' }
		.eval_var_hoisting_conflict { 'EvalVarHoistingConflict' }
		.to_primitive_returned_object { 'ToPrimitiveReturnedObject' }
		.typed_array_content_type_mismatch { 'TypedArrayContentTypeMismatch' }
		.typed_array_invalid_buffer_length { 'TypedArrayInvalidBufferLength' }
		.typed_array_invalid_byte_offset { 'TypedArrayInvalidByteOffset' }
		.typed_array_invalid_copy { 'TypedArrayInvalidCopy' }
		.typed_array_invalid_integer_index { 'TypedArrayInvalidIntegerIndex' }
		.typed_array_invalid_target_offset { 'TypedArrayInvalidTargetOffset' }
		.typed_array_out_of_range_byte_offset { 'TypedArrayOutOfRangeByteOffset' }
		.typed_array_out_of_range_byte_offset_or_length { 'TypedArrayOutOfRangeByteOffsetOrLength' }
		.typed_array_overflow { 'TypedArrayOverflow' }
		.typed_array_overflow_or_out_of_bounds { 'TypedArrayOverflowOrOutOfBounds' }
		.typed_array_prototype_one_arg { 'TypedArrayPrototypeOneArg' }
		.typed_array_type_is_not { 'TypedArrayTypeIsNot' }
		.unknown_identifier { 'UnknownIdentifier' }
		.unsupported_delete_super_property { 'UnsupportedDeleteSuperProperty' }
		.uri_malformed { 'URIMalformed' }
		.wrapped_function_call_throw_completion { 'WrappedFunctionCallThrowCompletion' }
		.wrapped_function_copy_name_and_length_throw_completion { 'WrappedFunctionCopyNameAndLengthThrowCompletion' }
		.yield_from_iterator_missing_throw_method { 'YieldFromIteratorMissingThrowMethod' }
		.zip_iterator_not_enough_results { 'ZipIteratorNotEnoughResults' }
	}
}

// message returns the template itself; placeholder-free error types use it
// directly and the remaining types are formatted through formatted().
pub fn (error_type ErrorType) message() string {
	return error_type.format()
}

// formatted substitutes each "{}" placeholder in order. Placeholders without a
// matching argument stay in place; surplus arguments are ignored.
pub fn (error_type ErrorType) formatted(args ...string) string {
	return format_error_message(error_type.format(), args)
}

pub fn format_error_message(template string, args []string) string {
	mut result := []u8{cap: template.len + 16}
	mut next_argument := 0
	mut i := 0
	for i < template.len {
		if template[i] == `{` && i + 1 < template.len && template[i + 1] == `}`
			&& next_argument < args.len {
			result << args[next_argument].bytes()
			next_argument++
			i += 2
			continue
		}
		result << template[i]
		i++
	}
	return result.bytestr()
}
