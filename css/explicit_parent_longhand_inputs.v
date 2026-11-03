module css

import os

const disable_explicit_parent_longhand_inputs = os.getenv('VOX_DISABLE_EXPLICIT_PARENT_LONGHAND_INPUTS') != ''
const explicit_parent_longhand_input_diagnostics = os.getenv('VOX_EXPLICIT_PARENT_LONGHAND_INPUT_DIAGNOSTICS') != ''
__global explicit_parent_longhand_inputs_reported bool

fn longhand_has_explicit_noninherited_parent(property StyleProperty) bool {
	if disable_explicit_parent_longhand_inputs || computed_interpolation_is_inherited_property(property.property_id)
		|| property.value.css_value_handle == unsafe { nil } { return false }
	box := unsafe { &TypedStyleValueBox(property.value.css_value_handle) }
	return box.value is KeywordStyleValue && box.value.keyword_ == .inherit
}

fn explicit_parent_longhand_hash(parent &ComputedProperties, id PropertyID) ?u64 {
	value := parent.raw_property_at_index(int(id) - int(first_longhand_property_id()))
	if value == unsafe { nil } { return u64(0) }
	if !computed_longhand_reuse_value_is_simple(value) { return none }
	return computed_longhand_reuse_value_hash(value)
}

fn explicit_parent_longhand_snapshot(parent &ComputedProperties, id PropertyID) ?ComputedLonghandReuseInput {
	value := parent.raw_property_at_index(int(id) - int(first_longhand_property_id()))
	if value == unsafe { nil } { return ComputedLonghandReuseInput{id:id, value:unsafe { nil }} }
	if !computed_longhand_reuse_value_is_simple(value) { return none }
	return ComputedLonghandReuseInput{
		id:id, value:value, typed_handle:value.css_value_handle
		snapshot:computed_longhand_reuse_snapshot(value), semantic:true
	}
}

fn report_explicit_parent_longhand_inputs(inputs []ComputedLonghandReuseInput) {
	if !explicit_parent_longhand_input_diagnostics || explicit_parent_longhand_inputs_reported { return }
	for input in inputs {
		if !computed_interpolation_is_inherited_property(input.id) {
			explicit_parent_longhand_inputs_reported = true
			eprintln('VOX_EXPLICIT_PARENT_LONGHAND_INPUT property=${string_from_property_id(input.id)}')
			return
		}
	}
}
