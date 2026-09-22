// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ARIA/StateAndProperties.{h,cpp}.
module aria

pub enum StateAndProperty {
	aria_active_descendant
	aria_atomic
	aria_auto_complete
	aria_braille_label
	aria_braille_role_description
	aria_busy
	aria_checked
	aria_col_count
	aria_col_index
	aria_col_index_text
	aria_col_span
	aria_controls
	aria_current
	aria_described_by
	aria_description
	aria_details
	aria_disabled
	aria_drop_effect
	aria_error_message
	aria_expanded
	aria_flow_to
	aria_grabbed
	aria_has_popup
	aria_hidden
	aria_invalid
	aria_key_shortcuts
	aria_label
	aria_labelled_by
	aria_level
	aria_live
	aria_modal
	aria_multi_line
	aria_multi_selectable
	aria_orientation
	aria_owns
	aria_placeholder
	aria_pos_in_set
	aria_pressed
	aria_read_only
	aria_relevant
	aria_required
	aria_role_description
	aria_row_count
	aria_row_index
	aria_row_index_text
	aria_row_span
	aria_selected
	aria_set_size
	aria_sort
	aria_value_max
	aria_value_min
	aria_value_now
	aria_value_text
}

pub const all_state_and_properties = [
	StateAndProperty.aria_active_descendant,
	StateAndProperty.aria_atomic,
	StateAndProperty.aria_auto_complete,
	StateAndProperty.aria_braille_label,
	StateAndProperty.aria_braille_role_description,
	StateAndProperty.aria_busy,
	StateAndProperty.aria_checked,
	StateAndProperty.aria_col_count,
	StateAndProperty.aria_col_index,
	StateAndProperty.aria_col_index_text,
	StateAndProperty.aria_col_span,
	StateAndProperty.aria_controls,
	StateAndProperty.aria_current,
	StateAndProperty.aria_described_by,
	StateAndProperty.aria_description,
	StateAndProperty.aria_details,
	StateAndProperty.aria_disabled,
	StateAndProperty.aria_drop_effect,
	StateAndProperty.aria_error_message,
	StateAndProperty.aria_expanded,
	StateAndProperty.aria_flow_to,
	StateAndProperty.aria_grabbed,
	StateAndProperty.aria_has_popup,
	StateAndProperty.aria_hidden,
	StateAndProperty.aria_invalid,
	StateAndProperty.aria_key_shortcuts,
	StateAndProperty.aria_label,
	StateAndProperty.aria_labelled_by,
	StateAndProperty.aria_level,
	StateAndProperty.aria_live,
	StateAndProperty.aria_modal,
	StateAndProperty.aria_multi_line,
	StateAndProperty.aria_multi_selectable,
	StateAndProperty.aria_orientation,
	StateAndProperty.aria_owns,
	StateAndProperty.aria_placeholder,
	StateAndProperty.aria_pos_in_set,
	StateAndProperty.aria_pressed,
	StateAndProperty.aria_read_only,
	StateAndProperty.aria_relevant,
	StateAndProperty.aria_required,
	StateAndProperty.aria_role_description,
	StateAndProperty.aria_row_count,
	StateAndProperty.aria_row_index,
	StateAndProperty.aria_row_index_text,
	StateAndProperty.aria_row_span,
	StateAndProperty.aria_selected,
	StateAndProperty.aria_set_size,
	StateAndProperty.aria_sort,
	StateAndProperty.aria_value_max,
	StateAndProperty.aria_value_min,
	StateAndProperty.aria_value_now,
	StateAndProperty.aria_value_text,
]

pub struct NoDefault {}

pub type DefaultValue = AriaHasPopup | AriaLive | AriaOrientation | NoDefault | bool | f64

pub fn state_or_property_from_string(value string) ?StateAndProperty {
	for candidate in all_state_and_properties {
		if state_or_property_to_string(candidate) == value {
			return candidate
		}
	}
	return none
}

pub fn state_or_property_to_string(value StateAndProperty) string {
	return match value {
		.aria_active_descendant { 'aria-activedescendant' }
		.aria_atomic { 'aria-atomic' }
		.aria_auto_complete { 'aria-autocomplete' }
		.aria_braille_label { 'aria-braillelabel' }
		.aria_braille_role_description { 'aria-brailleroledescription' }
		.aria_busy { 'aria-busy' }
		.aria_checked { 'aria-checked' }
		.aria_col_count { 'aria-colcount' }
		.aria_col_index { 'aria-colindex' }
		.aria_col_index_text { 'aria-colindextext' }
		.aria_col_span { 'aria-colspan' }
		.aria_controls { 'aria-controls' }
		.aria_current { 'aria-current' }
		.aria_described_by { 'aria-describedby' }
		.aria_description { 'aria-description' }
		.aria_details { 'aria-details' }
		.aria_disabled { 'aria-disabled' }
		.aria_drop_effect { 'aria-dropeffect' }
		.aria_error_message { 'aria-errormessage' }
		.aria_expanded { 'aria-expanded' }
		.aria_flow_to { 'aria-flowto' }
		.aria_grabbed { 'aria-grabbed' }
		.aria_has_popup { 'aria-haspopup' }
		.aria_hidden { 'aria-hidden' }
		.aria_invalid { 'aria-invalid' }
		.aria_key_shortcuts { 'aria-keyshortcuts' }
		.aria_label { 'aria-label' }
		.aria_labelled_by { 'aria-labelledby' }
		.aria_level { 'aria-level' }
		.aria_live { 'aria-live' }
		.aria_modal { 'aria-modal' }
		.aria_multi_line { 'aria-multiline' }
		.aria_multi_selectable { 'aria-multiselectable' }
		.aria_orientation { 'aria-orientation' }
		.aria_owns { 'aria-owns' }
		.aria_placeholder { 'aria-placeholder' }
		.aria_pos_in_set { 'aria-posinset' }
		.aria_pressed { 'aria-pressed' }
		.aria_read_only { 'aria-readonly' }
		.aria_relevant { 'aria-relevant' }
		.aria_required { 'aria-required' }
		.aria_role_description { 'aria-roledescription' }
		.aria_row_count { 'aria-rowcount' }
		.aria_row_index { 'aria-rowindex' }
		.aria_row_index_text { 'aria-rowindextext' }
		.aria_row_span { 'aria-rowspan' }
		.aria_selected { 'aria-selected' }
		.aria_set_size { 'aria-setsize' }
		.aria_sort { 'aria-sort' }
		.aria_value_max { 'aria-valuemax' }
		.aria_value_min { 'aria-valuemin' }
		.aria_value_now { 'aria-valuenow' }
		.aria_value_text { 'aria-valuetext' }
	}
}

pub fn tristate_to_string(value Tristate) string {
	return match value {
		.true_ { 'true' }
		.false_ { 'false' }
		.undefined { 'undefined' }
		.mixed { 'mixed' }
	}
}

pub fn optional_integer_to_string(value ?i32) string {
	return if integer := value { integer.str() } else { '' }
}

pub fn optional_bool_to_string(value ?bool) string {
	return if boolean := value {
		if boolean {
			'true'
		} else {
			'false'
		}
	} else {
		'undefined'
	}
}

pub fn optional_number_to_string(value ?f64) string {
	return if number := value { number.str() } else { 'undefined' }
}

pub fn id_reference_list_to_string(value []string) string {
	return value.join(' ')
}

fn aria_autocomplete_to_string(value AriaAutocomplete) string {
	return match value {
		.inline { 'inline' }
		.list { 'list' }
		.both { 'both' }
		.none_ { 'none' }
	}
}

fn aria_current_to_string(value AriaCurrent) string {
	return match value {
		.page { 'page' }
		.step { 'step' }
		.location { 'location' }
		.date { 'date' }
		.time { 'time' }
		.true_ { 'true' }
		.false_ { 'false' }
	}
}

fn aria_has_popup_to_string(value AriaHasPopup) string {
	return match value {
		.false_ { 'false' }
		.true_ { 'true' }
		.menu { 'menu' }
		.listbox { 'listbox' }
		.tree { 'tree' }
		.grid { 'grid' }
		.dialog { 'dialog' }
	}
}

fn aria_invalid_to_string(value AriaInvalid) string {
	return match value {
		.grammar { 'grammar' }
		.false_ { 'false' }
		.spelling { 'spelling' }
		.true_ { 'true' }
	}
}

fn aria_live_to_string(value AriaLive) string {
	return match value {
		.assertive { 'assertive' }
		.off { 'off' }
		.polite { 'polite' }
	}
}

fn aria_orientation_to_string(value AriaOrientation) string {
	return match value {
		.horizontal { 'horizontal' }
		.undefined { 'undefined' }
		.vertical { 'vertical' }
	}
}

fn aria_sort_to_string(value AriaSort) string {
	return match value {
		.ascending { 'ascending' }
		.descending { 'descending' }
		.none_ { 'none' }
		.other { 'other' }
	}
}

fn serialize_aria_string(value string) string {
	return value
}

pub fn state_or_property_to_string_value(value StateAndProperty, data &AriaData, default_value DefaultValue) string {
	return match value {
		.aria_active_descendant {
			serialize_aria_string(data.aria_active_descendant_or_default() or { '' })
		}
		.aria_atomic {
			data.aria_atomic_or(if default_value is bool { default_value } else { false }).str()
		}
		.aria_auto_complete {
			aria_autocomplete_to_string(data.aria_auto_complete_or_default())
		}
		.aria_braille_label {
			serialize_aria_string(data.aria_braille_label_or_default())
		}
		.aria_braille_role_description {
			serialize_aria_string(data.aria_braille_role_description_or_default())
		}
		.aria_busy {
			data.aria_busy_or_default().str()
		}
		.aria_checked {
			tristate_to_string(data.aria_checked_or_default())
		}
		.aria_col_count {
			optional_integer_to_string(data.aria_col_count_or_default())
		}
		.aria_col_index {
			optional_integer_to_string(data.aria_col_index_or_default())
		}
		.aria_col_index_text {
			serialize_aria_string(data.aria_col_index_text_or_default())
		}
		.aria_col_span {
			optional_integer_to_string(data.aria_col_span_or_default())
		}
		.aria_controls {
			id_reference_list_to_string(data.aria_controls_or_default())
		}
		.aria_current {
			aria_current_to_string(data.aria_current_or_default())
		}
		.aria_described_by {
			id_reference_list_to_string(data.aria_described_by_or_default())
		}
		.aria_description {
			serialize_aria_string(data.aria_description_or_default())
		}
		.aria_details {
			serialize_aria_string(data.aria_details_or_default() or { '' })
		}
		.aria_disabled {
			data.aria_disabled_or_default().str()
		}
		.aria_drop_effect {
			data.aria_drop_effect_or_default().map(match it {
				.copy { 'copy' }
				.execute { 'execute' }
				.link { 'link' }
				.move { 'move' }
				.none_ { 'none' }
				.popup { 'popup' }
			}).join(' ')
		}
		.aria_error_message {
			serialize_aria_string(data.aria_error_message_or_default() or { '' })
		}
		.aria_expanded {
			optional_bool_to_string(data.aria_expanded_or_default())
		}
		.aria_flow_to {
			id_reference_list_to_string(data.aria_flow_to_or_default())
		}
		.aria_grabbed {
			optional_bool_to_string(data.aria_grabbed_or_default())
		}
		.aria_has_popup {
			aria_has_popup_to_string(data.aria_has_popup_or_default())
		}
		.aria_hidden {
			optional_bool_to_string(data.aria_hidden_or_default())
		}
		.aria_invalid {
			aria_invalid_to_string(data.aria_invalid_or_default())
		}
		.aria_key_shortcuts {
			serialize_aria_string(data.aria_key_shortcuts_or_default())
		}
		.aria_label {
			serialize_aria_string(data.aria_label_or_default())
		}
		.aria_labelled_by {
			id_reference_list_to_string(data.aria_labelled_by_or_default())
		}
		.aria_level {
			optional_integer_to_string(data.aria_level_or_default())
		}
		.aria_live {
			aria_live_to_string(data.aria_live_or(if default_value is AriaLive {
				default_value
			} else {
				.off
			}))
		}
		.aria_modal {
			data.aria_modal_or_default().str()
		}
		.aria_multi_line {
			data.aria_multi_line_or_default().str()
		}
		.aria_multi_selectable {
			data.aria_multi_selectable_or_default().str()
		}
		.aria_orientation {
			aria_orientation_to_string(data.aria_orientation_or(if default_value is AriaOrientation {
				default_value
			} else {
				.undefined
			}))
		}
		.aria_owns {
			id_reference_list_to_string(data.aria_owns_or_default())
		}
		.aria_placeholder {
			serialize_aria_string(data.aria_placeholder_or_default())
		}
		.aria_pos_in_set {
			optional_integer_to_string(data.aria_pos_in_set_or_default())
		}
		.aria_pressed {
			tristate_to_string(data.aria_pressed_or_default())
		}
		.aria_read_only {
			data.aria_read_only_or_default().str()
		}
		.aria_relevant {
			data.aria_relevant_or_default().map(match it {
				.additions { 'additions' }
				.additions_text { 'additions text' }
				.all { 'all' }
				.removals { 'removals' }
				.text { 'text' }
			}).join(' ')
		}
		.aria_required {
			data.aria_required_or_default().str()
		}
		.aria_role_description {
			serialize_aria_string(data.aria_role_description_or_default())
		}
		.aria_row_count {
			optional_integer_to_string(data.aria_row_count_or_default())
		}
		.aria_row_index {
			optional_integer_to_string(data.aria_row_index_or_default())
		}
		.aria_row_index_text {
			serialize_aria_string(data.aria_row_index_text_or_default())
		}
		.aria_row_span {
			optional_integer_to_string(data.aria_row_span_or_default())
		}
		.aria_selected {
			optional_bool_to_string(data.aria_selected_or_default())
		}
		.aria_set_size {
			optional_integer_to_string(data.aria_set_size_or_default())
		}
		.aria_sort {
			aria_sort_to_string(data.aria_sort_or_default())
		}
		.aria_value_max {
			mut numeric_default := ?f64(none)
			if default_value is f64 {
				numeric_default = default_value
			}
			optional_number_to_string(data.aria_value_max_or(numeric_default))
		}
		.aria_value_min {
			mut numeric_default := ?f64(none)
			if default_value is f64 {
				numeric_default = default_value
			}
			optional_number_to_string(data.aria_value_min_or(numeric_default))
		}
		.aria_value_now {
			optional_number_to_string(data.aria_value_now_or_default())
		}
		.aria_value_text {
			serialize_aria_string(data.aria_value_text_or_default())
		}
	}
}
