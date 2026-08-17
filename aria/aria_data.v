// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ARIA/AriaData.{h,cpp}.
module aria

import strconv

pub enum Tristate {
	true_
	false_
	mixed
	undefined
}

pub enum AriaAutocomplete {
	inline
	list
	both
	none_
}

pub enum AriaCurrent {
	page
	step
	location
	date
	time
	true_
	false_
}

pub enum AriaDropEffect {
	copy
	execute
	link
	move
	none_
	popup
}

pub enum AriaHasPopup {
	false_
	true_
	menu
	listbox
	tree
	grid
	dialog
}

pub enum AriaInvalid {
	grammar
	false_
	spelling
	true_
}

pub enum AriaLive {
	assertive
	off
	polite
}

pub enum AriaOrientation {
	horizontal
	undefined
	vertical
}

pub enum AriaRelevant {
	additions
	additions_text
	all
	removals
	text
}

pub enum AriaSort {
	ascending
	descending
	none_
	other
}

pub struct AriaData {
mut:
	aria_active_descendant_        ?string
	aria_atomic_                   ?bool
	aria_auto_complete_            AriaAutocomplete
	aria_braille_label_            string
	aria_braille_role_description_ string
	aria_busy_                     bool
	aria_checked_                  Tristate
	aria_col_count_                ?i32
	aria_col_index_                ?i32
	aria_col_index_text_           string
	aria_col_span_                 ?i32
	aria_controls_                 []string
	aria_current_                  AriaCurrent
	aria_described_by_             []string
	aria_description_              string
	aria_details_                  ?string
	aria_disabled_                 bool
	aria_drop_effect_              []AriaDropEffect
	aria_error_message_            ?string
	aria_expanded_                 ?bool
	aria_flow_to_                  []string
	aria_grabbed_                  ?bool
	aria_has_popup_                AriaHasPopup
	aria_hidden_                   ?bool
	aria_invalid_                  AriaInvalid
	aria_key_shortcuts_            string
	aria_label_                    string
	aria_labelled_by_              []string
	aria_level_                    ?i32
	aria_live_                     ?AriaLive
	aria_modal_                    bool
	aria_multi_line_               bool
	aria_multi_selectable_         bool
	aria_orientation_              ?AriaOrientation
	aria_owns_                     []string
	aria_placeholder_              string
	aria_pos_in_set_               ?i32
	aria_pressed_                  Tristate
	aria_read_only_                bool
	aria_relevant_                 []AriaRelevant
	aria_required_                 bool
	aria_role_description_         string
	aria_row_count_                ?i32
	aria_row_index_                ?i32
	aria_row_index_text_           string
	aria_row_span_                 ?i32
	aria_selected_                 ?bool
	aria_set_size_                 ?i32
	aria_sort_                     AriaSort
	aria_value_max_                ?f64
	aria_value_min_                ?f64
	aria_value_now_                ?f64
	aria_value_text_               string
}

pub fn AriaData.from_mixin(source &ARIAMixin) AriaData {
	return AriaData{
		aria_active_descendant_:        source.aria_active_descendant()
		aria_atomic_:                   parse_optional_true_false(source.aria_atomic())
		aria_auto_complete_:            parse_aria_autocomplete(source.aria_auto_complete())
		aria_braille_label_:            source.aria_braille_label() or { '' }
		aria_braille_role_description_: source.aria_braille_role_description() or { '' }
		aria_busy_:                     parse_true_false(source.aria_busy())
		aria_checked_:                  parse_tristate(source.aria_checked())
		aria_col_count_:                parse_aria_integer(source.aria_col_count())
		aria_col_index_:                parse_aria_integer(source.aria_col_index())
		aria_col_index_text_:           source.aria_col_index_text() or { '' }
		aria_col_span_:                 parse_aria_integer(source.aria_col_span())
		aria_controls_:                 source.parse_id_reference_list(source.aria_controls())
		aria_current_:                  parse_aria_current(source.aria_current())
		aria_described_by_:             source.parse_id_reference_list(source.aria_described_by())
		aria_description_:              source.aria_description() or { '' }
		aria_details_:                  source.parse_id_reference(source.aria_details())
		aria_disabled_:                 parse_true_false(source.aria_disabled())
		aria_drop_effect_:              parse_aria_drop_effect(source.aria_drop_effect())
		aria_error_message_:            source.parse_id_reference(source.aria_error_message())
		aria_expanded_:                 parse_true_false_undefined(source.aria_expanded())
		aria_flow_to_:                  source.parse_id_reference_list(source.aria_flow_to())
		aria_grabbed_:                  parse_true_false_undefined(source.aria_grabbed())
		aria_has_popup_:                parse_aria_has_popup(source.aria_has_popup())
		aria_hidden_:                   parse_true_false_undefined(source.aria_hidden())
		aria_invalid_:                  parse_aria_invalid(source.aria_invalid())
		aria_key_shortcuts_:            source.aria_key_shortcuts() or { '' }
		aria_label_:                    source.aria_label() or { '' }
		aria_labelled_by_:              source.parse_id_reference_list(source.aria_labelled_by())
		aria_level_:                    parse_aria_integer(source.aria_level())
		aria_live_:                     parse_aria_live(source.aria_live())
		aria_modal_:                    parse_true_false(source.aria_modal())
		aria_multi_line_:               parse_true_false(source.aria_multi_line())
		aria_multi_selectable_:         parse_true_false(source.aria_multi_selectable())
		aria_orientation_:              parse_aria_orientation(source.aria_orientation())
		aria_owns_:                     source.parse_id_reference_list(source.aria_owns())
		aria_placeholder_:              source.aria_placeholder() or { '' }
		aria_pos_in_set_:               parse_aria_integer(source.aria_pos_in_set())
		aria_pressed_:                  parse_tristate(source.aria_pressed())
		aria_read_only_:                parse_true_false(source.aria_read_only())
		aria_relevant_:                 parse_aria_relevant(source.aria_relevant())
		aria_required_:                 parse_true_false(source.aria_required())
		aria_role_description_:         source.aria_role_description() or { '' }
		aria_row_count_:                parse_aria_integer(source.aria_row_count())
		aria_row_index_:                parse_aria_integer(source.aria_row_index())
		aria_row_index_text_:           source.aria_row_index_text() or { '' }
		aria_row_span_:                 parse_aria_integer(source.aria_row_span())
		aria_selected_:                 parse_true_false_undefined(source.aria_selected())
		aria_set_size_:                 parse_aria_integer(source.aria_set_size())
		aria_sort_:                     parse_aria_sort(source.aria_sort())
		aria_value_max_:                parse_aria_number(source.aria_value_max())
		aria_value_min_:                parse_aria_number(source.aria_value_min())
		aria_value_now_:                parse_aria_number(source.aria_value_now())
		aria_value_text_:               source.aria_value_text() or { '' }
	}
}

fn parse_true_false(value ?string) bool {
	string_value := value or { return false }
	return string_value == 'true'
}

fn parse_tristate(value ?string) Tristate {
	return match value {
		'true' { .true_ }
		'false' { .false_ }
		'mixed' { .mixed }
		else { .undefined }
	} or { return .undefined }
}

fn parse_true_false_undefined(value ?string) ?bool {
	return match value {
		'true' { true }
		'false' { false }
		else { none }
	} or { return none }
}

fn parse_optional_true_false(value ?string) ?bool {
	return parse_true_false_undefined(value)
}

fn parse_aria_integer(value ?string) ?i32 {
	string_value := value or { return none }
	parsed := strconv.parse_int(string_value, 10, 32) or { return none }
	return i32(parsed)
}

fn parse_aria_number(value ?string) ?f64 {
	string_value := value or { return none }
	return strconv.atof64(string_value.trim_space()) or { none }
}

fn parse_aria_autocomplete(value ?string) AriaAutocomplete {
	return match value {
		'inline' { .inline }
		'list' { .list }
		'both' { .both }
		else { .none_ }
	} or { return .none_ }
}

fn parse_aria_current(value ?string) AriaCurrent {
	return match value {
		'page' { .page }
		'step' { .step }
		'location' { .location }
		'date' { .date }
		'time' { .time }
		'true' { .true_ }
		else { .false_ }
	} or { return .false_ }
}

fn parse_aria_drop_effect(value ?string) []AriaDropEffect {
	string_value := value or { return []AriaDropEffect{} }
	mut result := []AriaDropEffect{}
	for token in string_value.fields() {
		match token {
			'copy' { result << .copy }
			'execute' { result << .execute }
			'link' { result << .link }
			'move' { result << .move }
			'popup' { result << .popup }
			else {}
		}
	}
	if result.len == 0 {
		result << .none_
	}
	return result
}

fn parse_aria_has_popup(value ?string) AriaHasPopup {
	return match value {
		'true' { .true_ }
		'menu' { .menu }
		'listbox' { .listbox }
		'tree' { .tree }
		'grid' { .grid }
		'dialog' { .dialog }
		else { .false_ }
	} or { return .false_ }
}

fn parse_aria_invalid(value ?string) AriaInvalid {
	return match value {
		'grammar' { .grammar }
		'spelling' { .spelling }
		'true' { .true_ }
		else { .false_ }
	} or { return .false_ }
}

fn parse_aria_live(value ?string) ?AriaLive {
	return match value {
		'assertive' { .assertive }
		'off' { .off }
		'polite' { .polite }
		else { none }
	} or { return none }
}

fn parse_aria_orientation(value ?string) ?AriaOrientation {
	return match value {
		'horizontal' { .horizontal }
		'undefined' { .undefined }
		'vertical' { .vertical }
		else { none }
	} or { return none }
}

fn parse_aria_relevant(value ?string) []AriaRelevant {
	string_value := value or { return []AriaRelevant{} }
	tokens := string_value.fields()
	mut result := []AriaRelevant{}
	mut index := 0
	for index < tokens.len {
		if tokens[index] == 'additions' {
			if index + 1 < tokens.len && tokens[index + 1] == 'text' {
				result << .additions_text
				index += 2
				continue
			}
			if index + 2 < tokens.len && tokens[index + 1] == 'removals'
				&& tokens[index + 2] == 'text' {
				result << .all
				index += 3
				continue
			}
			result << .additions
		} else if tokens[index] == 'all' {
			result << .all
		} else if tokens[index] == 'removals' {
			result << .removals
		} else if tokens[index] == 'text' {
			result << .text
		}
		index++
	}
	if result.len == 0 {
		result << .additions_text
	}
	return result
}

fn parse_aria_sort(value ?string) AriaSort {
	return match value {
		'ascending' { .ascending }
		'descending' { .descending }
		'other' { .other }
		else { .none_ }
	} or { return .none_ }
}

pub fn (data &AriaData) aria_active_descendant_or_default() ?string {
	return data.aria_active_descendant_
}

pub fn (data &AriaData) aria_atomic_or_default() bool {
	return data.aria_atomic_ or { false }
}

pub fn (data &AriaData) aria_atomic_or(default_value bool) bool {
	return data.aria_atomic_ or { default_value }
}

pub fn (data &AriaData) aria_auto_complete_or_default() AriaAutocomplete {
	return data.aria_auto_complete_
}

pub fn (data &AriaData) aria_braille_label_or_default() string {
	return data.aria_braille_label_
}

pub fn (data &AriaData) aria_braille_role_description_or_default() string {
	return data.aria_braille_role_description_
}

pub fn (data &AriaData) aria_busy_or_default() bool {
	return data.aria_busy_
}

pub fn (data &AriaData) aria_checked_or_default() Tristate {
	return data.aria_checked_
}

pub fn (data &AriaData) aria_col_count_or_default() ?i32 {
	return data.aria_col_count_
}

pub fn (data &AriaData) aria_col_index_or_default() ?i32 {
	return data.aria_col_index_
}

pub fn (data &AriaData) aria_col_index_text_or_default() string {
	return data.aria_col_index_text_
}

pub fn (data &AriaData) aria_col_span_or_default() ?i32 {
	return data.aria_col_span_
}

pub fn (data &AriaData) aria_controls_or_default() []string {
	return data.aria_controls_.clone()
}

pub fn (data &AriaData) aria_current_or_default() AriaCurrent {
	return data.aria_current_
}

pub fn (data &AriaData) aria_described_by_or_default() []string {
	return data.aria_described_by_.clone()
}

pub fn (data &AriaData) aria_description_or_default() string {
	return data.aria_description_
}

pub fn (data &AriaData) aria_details_or_default() ?string {
	return data.aria_details_
}

pub fn (data &AriaData) aria_disabled_or_default() bool {
	return data.aria_disabled_
}

pub fn (data &AriaData) aria_drop_effect_or_default() []AriaDropEffect {
	return data.aria_drop_effect_.clone()
}

pub fn (data &AriaData) aria_error_message_or_default() ?string {
	return data.aria_error_message_
}

pub fn (data &AriaData) aria_expanded_or_default() ?bool {
	return data.aria_expanded_
}

pub fn (data &AriaData) aria_flow_to_or_default() []string {
	return data.aria_flow_to_.clone()
}

pub fn (data &AriaData) aria_grabbed_or_default() ?bool {
	return data.aria_grabbed_
}

pub fn (data &AriaData) aria_has_popup_or_default() AriaHasPopup {
	return data.aria_has_popup_
}

pub fn (data &AriaData) aria_hidden_or_default() ?bool {
	return data.aria_hidden_
}

pub fn (data &AriaData) aria_invalid_or_default() AriaInvalid {
	return data.aria_invalid_
}

pub fn (data &AriaData) aria_key_shortcuts_or_default() string {
	return data.aria_key_shortcuts_
}

pub fn (data &AriaData) aria_label_or_default() string {
	return data.aria_label_
}

pub fn (data &AriaData) aria_labelled_by_or_default() []string {
	return data.aria_labelled_by_.clone()
}

pub fn (data &AriaData) aria_level_or_default() ?i32 {
	return data.aria_level_
}

pub fn (data &AriaData) aria_live_or_default() AriaLive {
	return data.aria_live_ or { AriaLive.off }
}

pub fn (data &AriaData) aria_live_or(default_value AriaLive) AriaLive {
	return data.aria_live_ or { default_value }
}

pub fn (data &AriaData) aria_modal_or_default() bool {
	return data.aria_modal_
}

pub fn (data &AriaData) aria_multi_line_or_default() bool {
	return data.aria_multi_line_
}

pub fn (data &AriaData) aria_multi_selectable_or_default() bool {
	return data.aria_multi_selectable_
}

pub fn (data &AriaData) aria_orientation_or_default() AriaOrientation {
	return data.aria_orientation_ or { AriaOrientation.undefined }
}

pub fn (data &AriaData) aria_orientation_or(default_value AriaOrientation) AriaOrientation {
	return data.aria_orientation_ or { default_value }
}

pub fn (data &AriaData) aria_owns_or_default() []string {
	return data.aria_owns_.clone()
}

pub fn (data &AriaData) aria_placeholder_or_default() string {
	return data.aria_placeholder_
}

pub fn (data &AriaData) aria_pos_in_set_or_default() ?i32 {
	return data.aria_pos_in_set_
}

pub fn (data &AriaData) aria_pressed_or_default() Tristate {
	return data.aria_pressed_
}

pub fn (data &AriaData) aria_read_only_or_default() bool {
	return data.aria_read_only_
}

pub fn (data &AriaData) aria_relevant_or_default() []AriaRelevant {
	return data.aria_relevant_.clone()
}

pub fn (data &AriaData) aria_required_or_default() bool {
	return data.aria_required_
}

pub fn (data &AriaData) aria_role_description_or_default() string {
	return data.aria_role_description_
}

pub fn (data &AriaData) aria_row_count_or_default() ?i32 {
	return data.aria_row_count_
}

pub fn (data &AriaData) aria_row_index_or_default() ?i32 {
	return data.aria_row_index_
}

pub fn (data &AriaData) aria_row_index_text_or_default() string {
	return data.aria_row_index_text_
}

pub fn (data &AriaData) aria_row_span_or_default() ?i32 {
	return data.aria_row_span_
}

pub fn (data &AriaData) aria_selected_or_default() ?bool {
	return data.aria_selected_
}

pub fn (data &AriaData) aria_set_size_or_default() ?i32 {
	return data.aria_set_size_
}

pub fn (data &AriaData) aria_sort_or_default() AriaSort {
	return data.aria_sort_
}

pub fn (data &AriaData) aria_value_max_or_default() ?f64 {
	return data.aria_value_max_
}

pub fn (data &AriaData) aria_value_max_or(default_value ?f64) ?f64 {
	if value := data.aria_value_max_ { return value }
	return default_value
}

pub fn (data &AriaData) aria_value_min_or_default() ?f64 {
	return data.aria_value_min_
}

pub fn (data &AriaData) aria_value_min_or(default_value ?f64) ?f64 {
	if value := data.aria_value_min_ { return value }
	return default_value
}

pub fn (data &AriaData) aria_value_now_or_default() ?f64 {
	return data.aria_value_now_
}

pub fn (data &AriaData) aria_value_text_or_default() string {
	return data.aria_value_text_
}
