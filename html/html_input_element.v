// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLInputElement.{h,cpp}. Platform pickers and image painting
// remain host boundaries; type/value modes, sanitization, numeric/date stepping,
// checked/radio behavior, selected files, applicability predicates, validation,
// selection, reset/clear, and input/change events are implemented here.
@[has_globals]
module html

import aria
import css
import dom
import fileapi
import math
import strconv
import mimesniff
import libregex
import libjs

const max_ecmascript_time_value = 8.64e15

pub enum HTMLInputTypeState {
	hidden
	text
	search
	telephone
	url
	email
	password
	date
	month
	week
	time
	local_date_and_time
	number
	range
	color
	checkbox
	radio_button
	file_upload
	submit_button
	image_button
	reset_button
	button
}

pub enum MultipleFileHandling {
	replace
	append
}

pub enum HTMLInputValueAttributeMode {
	value
	default_
	default_on
	filename
}

pub enum InputPickerKind {
	file
	color
}

pub struct InputPickerRequest {
pub:
	element        &dom.HTMLInputElement
	kind           InputPickerKind
	file_filter    FileFilter
	allow_multiple bool
	initial_color  string
}

pub type InputPickerRequestCallback = fn (voidptr, InputPickerRequest)

pub struct InputPickerHook {
pub:
	target  voidptr                    = unsafe { nil }
	request InputPickerRequestCallback = unsafe { nil }
}

pub struct InputSelectedCoordinate {
pub:
	x int
	y int
}

pub enum InputFormAction {
	submit
	reset
	implicit_submit
}

pub type InputFormActionCallback = fn (voidptr, &FormAssociatedElement, InputFormAction) !

pub struct InputFormActionHook {
pub:
	target voidptr                 = unsafe { nil }
	run    InputFormActionCallback = unsafe { nil }
}

// Hosts receive the model so adopted image inputs use their current owner.
pub type InputImageModelFetchHook = fn (&HTMLInputElementModel, dom.URL) !DecodedImageData

@[heap]
pub struct HTMLInputElementModel {
pub:
	element &dom.HTMLInputElement
pub mut:
	control                          &FormAssociatedElement
	text_control                     &FormAssociatedTextControlElement
	type_state_                      HTMLInputTypeState
	value_                           string
	dirty_value_                     bool
	// Whether the value was last changed by a user edit rather than by
	// script; only such values can be too long or too short.
	value_last_changed_by_user_edit_ bool
	user_validity_                   bool
	has_uncommitted_changes_         bool
	selected_files_                  ?&fileapi.FileList
	event_target_                    &dom.EventTarget = unsafe { nil }
	event_counts_                    map[string]int
	selected_x_                      int
	selected_y_                      int
	is_open_                         bool
	picker_hook_                     ?InputPickerHook
	inner_text_element_              ?&dom.Element
	text_node_                       ?&dom.Text
	image_button_alt_text_node_      ?&dom.Text
	placeholder_element_             ?&dom.Element
	placeholder_text_node_           ?&dom.Text
	up_button_element_               ?&dom.Element
	down_button_element_             ?&dom.Element
	color_well_element_              ?&dom.Element
	file_button_                     ?&dom.Element
	file_label_                      ?&dom.Element
	slider_progress_element_         ?&dom.Element
	slider_thumb_                    ?&dom.Element
	before_activation_checked_       bool
	before_activation_indeterminate_ bool
	previously_checked_radio_        ?&HTMLInputElementModel
	last_src_value_                  string
	resource_request_                ?&SharedResourceRequest
	load_event_delayer_              ?dom.DocumentLoadEventDelayer
	image_fetch_hook_                ?HTMLImageFetchHook
	image_model_fetch_hook_          ?InputImageModelFetchHook
	visible_in_viewport_             bool = true
	form_action_hook_                ?InputFormActionHook
}

$if test {
	fn is_integral_multiple(value f64, step f64) bool {
		assert step > 0
		if math.abs(value) / math.ldexp(1.0, 53) > step {
			return true
		}
		remainder := math.abs(value - math.round(value / step) * step)
		acceptable_error := if math.round(step) == step { 0.0 } else { step / f64(1 << 24) }
		return remainder <= acceptable_error || remainder >= step - acceptable_error
	}
}

fn stepper_button_style_when_visible() string {
	return 'padding:0;cursor:default;'
}

$if test {
	fn stepper_button_style_when_hidden() string {
		return 'display:none;'
	}
}

fn placeholder_style_when_visible() string {
	return 'display:block;width:100%;height:1lh;overflow:hidden;text-overflow:clip;white-space:nowrap;margin-inline-start:-100%;pointer-events:none;user-select:none;'
}

fn placeholder_style_when_hidden() string {
	return 'display:none;'
}

$if test {
	fn is_applicable_for_maxlength_attribute(state HTMLInputTypeState) bool {
		return state in [.text, .search, .telephone, .url, .email, .password]
	}
}

$if test {
	fn is_allowed_to_have_placeholder(state HTMLInputTypeState) bool {
		return state in [.text, .search, .url, .telephone, .email, .password, .number]
	}
}

fn input_element(model &HTMLInputElementModel) &dom.Element {
	return unsafe { &dom.Element(model.element) }
}

fn html_input_element_adopted_from_callback(target voidptr, old_document &dom.Document) {
	mut model := unsafe { &HTMLInputElementModel(target) }
	model.adopted_from(old_document)
}

fn attach_html_input_element_model(element &dom.HTMLInputElement, model &HTMLInputElementModel) {
	mut mutable_element := unsafe { &dom.HTMLInputElement(element) }
	mutable_element.input_element_model_ = voidptr(model)
	mut node := unsafe { &dom.Element(element) }.as_node()
	node.set_adopted_from_hook(dom.NodeAdoptedFromHook{
		target:   voidptr(model)
		callback: html_input_element_adopted_from_callback
	})
}

pub fn parse_html_input_type(value string) HTMLInputTypeState {
	return match ascii_lowercase_string(value) {
		'hidden' { .hidden }
		'search' { .search }
		'tel' { .telephone }
		'url' { .url }
		'email' { .email }
		'password' { .password }
		'date' { .date }
		'month' { .month }
		'week' { .week }
		'time' { .time }
		'datetime-local' { .local_date_and_time }
		'number' { .number }
		'range' { .range }
		'color' { .color }
		'checkbox' { .checkbox }
		'radio' { .radio_button }
		'file' { .file_upload }
		'submit' { .submit_button }
		'image' { .image_button }
		'reset' { .reset_button }
		'button' { .button }
		else { .text }
	}
}

fn html_input_type_name(state HTMLInputTypeState) string {
	return match state {
		.hidden { 'hidden' }
		.text { 'text' }
		.search { 'search' }
		.telephone { 'tel' }
		.url { 'url' }
		.email { 'email' }
		.password { 'password' }
		.date { 'date' }
		.month { 'month' }
		.week { 'week' }
		.time { 'time' }
		.local_date_and_time { 'datetime-local' }
		.number { 'number' }
		.range { 'range' }
		.color { 'color' }
		.checkbox { 'checkbox' }
		.radio_button { 'radio' }
		.file_upload { 'file' }
		.submit_button { 'submit' }
		.image_button { 'image' }
		.reset_button { 'reset' }
		.button { 'button' }
	}
}

pub fn HTMLInputElementModel.create(element &dom.HTMLInputElement) &HTMLInputElementModel {
	if element.input_element_model_ != unsafe { nil } {
		model := unsafe { &HTMLInputElementModel(element.input_element_model_) }
		attach_html_input_element_model(element, model)
		return model
	}
	dom_element := unsafe { &dom.Element(element) }
	mut mutable_input := unsafe { &dom.HTMLInputElement(element) }
	initial_checkedness := mutable_input.checked()
	initial_dirty_checkedness := mutable_input.dirty_checkedness_
	mutable_input.set_checkedness(initial_checkedness, initial_dirty_checkedness)
	control := FormAssociatedElement.create(dom_element)
	type_state := parse_html_input_type(dom_element.get_attribute_value('type'))
	mut model := &HTMLInputElementModel{
		element:       element
		control:       control
		text_control:  FormAssociatedTextControlElement.create(control, '')
		type_state_:   type_state
		event_target_: dom.EventTarget.new()
	}
	// Install the model identity before initialization below. Radio-group
	// algorithms walk the live DOM tree, and creating a sibling model may query
	// this element again while that sibling is initialized.
	attach_html_input_element_model(element, model)
	model.control.reset_form_owner()
	model.value_ = model.sanitize_value(dom_element.get_attribute_value('value'))
	model.text_control.did_edit_target_ = voidptr(model)
	model.text_control.did_edit_callback_ = html_input_element_did_edit_callback
	model.text_control.set_relevant_value(model.value_)
	model.update_validity()
	model.create_shadow_tree_if_needed()
	install_form_control_selected_text_callback(dom_element.document())
	return model
}

fn html_input_element_did_edit_callback(target voidptr, input_type string, data ?string) {
	mut model := unsafe { &HTMLInputElementModel(target) }
	model.did_edit_text_node(input_type, data)
}

// Input.cpp fires these at the element itself: page listeners and inline
// handlers observe a checkbox's change, a picker's input or a committed edit.
fn (mut model HTMLInputElementModel) fire_event(name string) {
	model.event_counts_[name]++
	mut event := dom.Event.create(name, dom.EventInit{
		bubbles: name !in ['load', 'error']
		composed: name == 'input'
	})
	event.set_is_trusted(true)
	unsafe { &dom.EventTarget(input_element(&model).as_node()) }.dispatch_event(event)
}

pub fn (model &HTMLInputElementModel) event_target() &dom.EventTarget {
	return model.event_target_
}

pub fn (model &HTMLInputElementModel) event_count(name string) int {
	return model.event_counts_[name]
}

pub fn (model &HTMLInputElementModel) type_() string {
	return html_input_type_name(model.type_state_)
}

pub fn (model &HTMLInputElementModel) default_value() string {
	return input_element(model).get_attribute_value('value')
}

pub fn (model &HTMLInputElementModel) type_state() HTMLInputTypeState {
	return model.type_state_
}

pub fn (model &HTMLInputElementModel) placeholder_element() ?&dom.Element {
	return model.placeholder_element_
}

pub fn (model &HTMLInputElementModel) is_html_input_element() bool {
	_ = model
	return true
}

pub fn (model &HTMLInputElementModel) to_html_element() &dom.Element {
	return input_element(model)
}

pub fn (model &HTMLInputElementModel) current_frame_index() uint {
	_ = model
	return 0
}

pub fn (model &HTMLInputElementModel) decoded_image_data() ?DecodedImageData {
	return model.image_data()
}

pub fn (model &HTMLInputElementModel) relevant_value() string {
	return model.value()
}

pub fn (mut model HTMLInputElementModel) set_relevant_value(value string) ! {
	model.set_value(value)!
}

pub fn (model &HTMLInputElementModel) selected_text_for_stringifier() ?string {
	return model.text_control.selected_text_for_stringifier()
}

pub fn (mut model HTMLInputElementModel) set_dirty_value_flag(flag bool) {
	model.dirty_value_ = flag
	model.text_control.dirty_value_flag = flag
}

pub fn (model &HTMLInputElementModel) user_validity() bool {
	return model.user_validity_
}

pub fn (mut model HTMLInputElementModel) set_user_validity(flag bool) {
	model.user_validity_ = flag
}

pub fn (model &HTMLInputElementModel) has_uncommitted_changes() bool {
	return model.has_uncommitted_changes_
}

pub fn (model &HTMLInputElementModel) checked_binding() bool {
	return model.checked()
}

pub fn (mut model HTMLInputElementModel) set_being_activated(activated bool) {
	mut element := input_element(&model)
	element.set_being_activated(activated)
	if model.type_state_ in [.checkbox, .radio_button] {
		mut node := element.as_node()
		node.set_needs_repaint(.paint_commands)
	}
}

pub fn (mut model HTMLInputElementModel) set_type(value string) {
	old_state := model.type_state_
	mut element := input_element(&model)
	element.set_attribute_value('type', value)
	new_state := parse_html_input_type(value)
	if old_state != new_state {
		model.type_attribute_changed(old_state, new_state)
	}
}

pub fn HTMLInputElementModel.parse_type_attribute(value string) HTMLInputTypeState {
	return parse_html_input_type(value)
}

pub fn html_input_element_parse_type_attribute(value string) HTMLInputTypeState {
	return parse_html_input_type(value)
}

pub fn html_input_value_attribute_mode_for_type_state(state HTMLInputTypeState) HTMLInputValueAttributeMode {
	return match state {
		.text, .search, .telephone, .url, .email, .password, .date, .month, .week, .time,
		.local_date_and_time, .number, .range, .color {
			.value
		}
		.hidden, .submit_button, .image_button, .reset_button, .button { .default_ }
		.checkbox, .radio_button { .default_on }
		.file_upload { .filename }
	}
}

pub fn html_input_element_value_attribute_mode_for_type_state(state HTMLInputTypeState) HTMLInputValueAttributeMode {
	return html_input_value_attribute_mode_for_type_state(state)
}

pub fn (model &HTMLInputElementModel) value_attribute_mode() HTMLInputValueAttributeMode {
	return html_input_value_attribute_mode_for_type_state(model.type_state_)
}

pub fn (mut model HTMLInputElementModel) type_attribute_changed(old_state HTMLInputTypeState, new_state HTMLInputTypeState) {
	old_mode := html_input_value_attribute_mode_for_type_state(old_state)
	new_mode := html_input_value_attribute_mode_for_type_state(new_state)
	mut element := input_element(&model)
	// Input states select different concrete layout-node classes (for example,
	// TextInputBox versus ImageBox). The shadow-root transition below dirties a
	// subtree when either state materializes one, but states without a shadow
	// root still require the host node itself to be replaced.
	mut document := unsafe { &dom.Document(element.document()) }
	document.set_needs_full_layout_tree_update(true)
	if old_mode == .value && model.value_ != '' && new_mode in [.default_, .default_on] {
		element.set_attribute_value('value', model.value_)
	} else if old_mode != .value && new_mode == .value {
		model.value_ = element.get_attribute_value('value')
		model.dirty_value_ = false
	} else if old_mode != .filename && new_mode == .filename {
		model.value_ = ''
		model.selected_files_ = none
	}
	previously_selectable := html_input_selection_or_range_applies_for_type_state(old_state)
	model.type_state_ = new_state
	element.set_shadow_root(none)
	model.clear_shadow_tree_handles()
	model.create_shadow_tree_if_needed()
	model.signal_a_type_change()
	model.value_ = model.value_sanitization_algorithm(model.value_)
	model.text_control.set_relevant_value(model.value_)
	if new_state != .file_upload {
		model.selected_files_ = none
	}
	if !previously_selectable && model.selection_or_range_applies() {
		model.text_control.set_the_selection_range(0, 0, .none, .dom)
	}
	model.update_validity()
	model.update_shadow_tree()
}

pub fn (mut model HTMLInputElementModel) signal_a_type_change() {
	if model.type_state_ == .radio_button && model.checked() {
		for mut other in input_models_in_same_tree(&model) {
			if same_radio_group(&model, other) {
				other.set_checked(false)
			}
		}
	}
}

fn strip_input_newlines(value string) string {
	return value.replace('\r', '').replace('\n', '')
}

fn valid_simple_color(value string) bool {
	if value.len != 7 || value[0] != `#` {
		return false
	}
	for byte in value[1..].bytes() {
		if !((byte >= `0` && byte <= `9`) || (byte >= `a` && byte <= `f`) || (byte >= `A` && byte <= `F`)) {
			return false
		}
	}
	return true
}

fn (model &HTMLInputElementModel) sanitize_value(value string) string {
	match model.type_state_ {
		.text, .search, .telephone, .password {
			return strip_input_newlines(value)
		}
		.url {
			return strip_input_newlines(value).trim_space()
		}
		.email {
			without_newlines := strip_input_newlines(value)
			if input_element(model).has_attribute('multiple') {
				return without_newlines.split(',').map(it.trim_space()).join(',')
			}
			return without_newlines.trim_space()
		}
		.number {
			number := parse_floating_point_number(value) or { return '' }
			return if math.is_nan(number) || math.is_inf(number, 0) { '' } else { value }
		}
		.date {
			return if is_valid_date_string(value) { value } else { '' }
		}
		.month {
			return if is_valid_month_string(value) { value } else { '' }
		}
		.week {
			return if is_valid_week_string(value) { value } else { '' }
		}
		.time {
			return if is_valid_time_string(value) { value } else { '' }
		}
		.local_date_and_time {
			return if is_valid_local_date_and_time_string(value) {
				value.replace(' ', 'T')
			} else {
				''
			}
		}
		.range {
			minimum := model.minimum() or { 0.0 }
			maximum := model.maximum() or { 100.0 }
			mut number := parse_floating_point_number(value) or {
				if maximum < minimum { minimum } else { minimum + (maximum - minimum) / 2.0 }
			}
			if number < minimum {
				number = minimum
			}
			if maximum >= minimum && number > maximum {
				number = maximum
			}
			if step := model.allowed_value_step() {
				base := model.step_base()
				number = base + math.round((number - base) / step) * step
				if number < minimum {
					number = minimum
				}
				if maximum >= minimum && number > maximum {
					number = maximum
				}
			}
			return best_representation_of_number(number)
		}
		.color {
			return if valid_simple_color(value) { ascii_lowercase_string(value) } else { '#000000' }
		}
		else {
			return value
		}
	}
}

pub fn (model &HTMLInputElementModel) value_sanitization_algorithm(value string) string {
	return model.sanitize_value(value)
}

pub fn (model &HTMLInputElementModel) value() string {
	return match model.type_state_ {
		.checkbox, .radio_button {
			value := input_element(model).get_attribute_value('value')
			if value == '' {
				'on'
			} else {
				value
			}
		}
		.file_upload {
			if files := model.selected_files_ {
				if file := files.item(0) {
					'C:\\fakepath\\${file.name()}'
				} else {
					''
				}
			} else {
				''
			}
		}
		.submit_button, .image_button, .reset_button, .button, .hidden {
			input_element(model).get_attribute_value('value')
		}
		else {
			if model.selection_or_range_applies() {
				model.text_control.relevant_value()
			} else {
				model.value_
			}
		}
	}
}

pub fn (model &HTMLInputElementModel) optional_value() ?string {
	if model.type_state_ == .submit_button {
		return input_element(model).get_attribute('value')
	}
	return none
}

pub fn (mut model HTMLInputElementModel) set_value(value string) ! {
	if model.type_state_ == .file_upload {
		if value != '' {
			return error('InvalidStateError: file input value can only be set to the empty string')
		}
		model.selected_files_ = none
		model.update_file_input_shadow_tree()
		return
	}
	if model.type_state_ in [.checkbox, .radio_button, .submit_button, .image_button, .reset_button,
		.button, .hidden] {
		mut element := input_element(&model)
		element.set_attribute_value('value', value)
		model.update_shadow_tree()
		return
	}
	old := model.value_
	model.value_ = model.sanitize_value(value)
	model.dirty_value_ = true
	model.value_last_changed_by_user_edit_ = false
	model.text_control.dirty_value_flag = true
	model.text_control.set_relevant_value(model.value_)
	if old != model.value_ && model.selection_or_range_applies() {
		length := u32(form_string_to_utf16(model.value_).len)
		model.text_control.set_the_selection_range(length, length, .none, .value_change)
	}
	model.update_validity()
	model.update_shadow_tree()
}

pub fn (model &HTMLInputElementModel) checked() bool {
	return unsafe { &dom.HTMLInputElement(model.element) }.checked()
}

fn same_radio_group(a &HTMLInputElementModel, b &HTMLInputElementModel) bool {
	if a == b || a.type_state_ != .radio_button || b.type_state_ != .radio_button {
		return false
	}
	a_element := input_element(a)
	b_element := input_element(b)
	if a_element.as_node().root() != b_element.as_node().root() {
		return false
	}
	a_form := a.control.form()
	b_form := b.control.form()
	if a_form == none {
		if b_form != none {
			return false
		}
	} else {
		actual_a_form := a_form
		actual_b_form := b_form or { return false }
		if voidptr(actual_a_form) != voidptr(actual_b_form) {
			return false
		}
	}
	a_name := a_element.get_attribute('name') or { return false }
	b_name := b_element.get_attribute('name') or { return false }
	return a_name != '' && a_name == b_name
}

fn collect_input_models_in_subtree(node &dom.Node, mut models []&HTMLInputElementModel) {
	if element := node.as_element() {
		if element.is_html_element() && element.local_name() == 'input' {
			models << HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		}
	}
	for child in node.children {
		collect_input_models_in_subtree(child, mut models)
	}
}

// HTMLInputElement's radio algorithms use root().for_each_in_inclusive_subtree
// in C++. Keep the same live-tree boundary rather than retaining a global list
// of every model ever created.
fn input_models_in_same_tree(model &HTMLInputElementModel) []&HTMLInputElementModel {
	mut models := []&HTMLInputElementModel{}
	collect_input_models_in_subtree(input_element(model).as_node().root(), mut models)
	return models
}

pub fn (mut model HTMLInputElementModel) set_checked(value bool) {
	mut input := unsafe { &dom.HTMLInputElement(model.element) }
	old_value := input.checked()
	input.set_checkedness(value, true)
	if old_value == value {
		return
	}
	mut node := input_element(&model).as_node()
	node.invalidate_style(.html_input_element_set_checked)
	node.set_needs_repaint(.paint_commands)
	model.update_validity()
}

pub fn (mut model HTMLInputElementModel) set_checked_within_group() {
	if model.checked() {
		return
	}
	model.set_checked(true)
	if input_element(&model).get_attribute_value('name') == '' {
		return
	}
	for mut other in input_models_in_same_tree(&model) {
		if other.checked() && same_radio_group(&model, other) {
			other.set_checked(false)
		}
	}
}

pub fn (mut model HTMLInputElementModel) set_checked_binding(value bool) {
	if model.type_state_ == .radio_button && value {
		model.set_checked_within_group()
	} else {
		model.set_checked(value)
	}
}

pub fn (mut model HTMLInputElementModel) set_indeterminate(value bool) {
	mut input := unsafe { &dom.HTMLInputElement(model.element) }
	input.set_indeterminate(value)
}

pub fn (model &HTMLInputElementModel) indeterminate() bool {
	return unsafe { &dom.HTMLInputElement(model.element) }.indeterminate()
}

fn find_input_suggestions_source(node &dom.Node, id string, mut found ?&dom.Element) bool {
	if element := node.as_element() {
		if element.id() or { '' } == id {
			found = element
			return true
		}
	}
	for child in node.children_as_vector() {
		if find_input_suggestions_source(child, id, mut found) {
			return true
		}
	}
	return false
}

// https://html.spec.whatwg.org/multipage/input.html#concept-input-list
pub fn (model &HTMLInputElementModel) suggestions_source_element() ?&dom.HTMLDataListElement {
	list_id := input_element(model).get_attribute('list') or { return none }
	mut found := ?&dom.Element(none)
	find_input_suggestions_source(input_element(model).as_node().root(), list_id, mut found)
	element := found or { return none }
	if !element.is_html_element() || element.local_name() != 'datalist' {
		return none
	}
	return unsafe { &dom.HTMLDataListElement(element) }
}

pub fn (model &HTMLInputElementModel) list() ?&dom.HTMLDataListElement {
	return model.suggestions_source_element()
}

// https://html.spec.whatwg.org/multipage/input.html#compiled-pattern-regular-expression
pub fn (model &HTMLInputElementModel) compiled_pattern_regular_expression() ?&libregex.ECMAScriptRegex {
	pattern := input_element(model).get_attribute('pattern') or { return none }
	flags := libregex.ECMAScriptCompileFlags{ unicode_sets: true }
	// HTMLInputElement.cpp:303–335 validates the original pattern before
	// adding a noncapturing anchor. A capturing wrapper changes backreferences.
	mut original := libregex.ECMAScriptRegex.compile(libjs.utf16_string(pattern), flags) or { return none }
	defer { original.destroy() }
	return libregex.ECMAScriptRegex.compile(libjs.utf16_string('^(?:' + pattern + ')$'), flags) or { return none }
}

pub fn (model &HTMLInputElementModel) placeholder() string {
	return strip_input_newlines(input_element(model).get_attribute_value('placeholder'))
}

pub fn (model &HTMLInputElementModel) placeholder_value() ?string {
	if model.value() != '' || model.type_state_ !in [.text, .search, .url, .telephone, .email,
		.password, .number] || !input_element(model).has_attribute('placeholder') {
		return none
	}
	return model.placeholder()
}

pub fn (model &HTMLInputElementModel) button_label() string {
	if label := input_element(model).get_attribute('value') {
		return label
	}
	return match model.type_state_ {
		.reset_button { 'Reset' }
		.submit_button { 'Submit' }
		else { model.value() }
	}
}

fn replace_element_text(element &dom.Element, text string) {
	mut node := element.as_node()
	node.string_replace_all(text)
}

fn append_input_shadow_child(mut parent dom.Node, child &dom.Node) {
	parent.append_child(child) or {}
}

fn (mut model HTMLInputElementModel) clear_shadow_tree_handles() {
	model.inner_text_element_ = none
	model.text_node_ = none
	model.text_control.text_node_ = none
	model.image_button_alt_text_node_ = none
	model.placeholder_element_ = none
	model.placeholder_text_node_ = none
	model.up_button_element_ = none
	model.down_button_element_ = none
	model.color_well_element_ = none
	model.file_button_ = none
	model.file_label_ = none
	model.slider_progress_element_ = none
	model.slider_thumb_ = none
}

pub fn (mut model HTMLInputElementModel) create_shadow_tree_if_needed() {
	if input_element(&model).shadow_root() != none {
		return
	}
	match model.type_state_ {
		.hidden, .radio_button, .checkbox {}
		.button, .submit_button, .reset_button { model.create_button_input_shadow_tree() }
		.image_button {
			if model.renders_as_alt_text() && input_element(&model).get_attribute_value('alt') != '' {
				model.create_image_button_alt_text_shadow_tree()
			}
		}
		.color { model.create_color_input_shadow_tree() }
		.file_upload { model.create_file_input_shadow_tree() }
		.range { model.create_range_input_shadow_tree() }
		else { model.create_text_input_shadow_tree() }
	}
}

pub fn (mut model HTMLInputElementModel) update_shadow_tree() {
	match model.type_state_ {
		.color { model.update_color_well_element() }
		.file_upload { model.update_file_input_shadow_tree() }
		.range { model.update_slider_shadow_tree_elements() }
		.button, .reset_button, .submit_button { model.update_button_input_shadow_tree() }
		.image_button { model.update_image_button_alt_text_shadow_tree() }
		else { model.update_text_input_shadow_tree() }
	}
}

pub fn (mut model HTMLInputElementModel) create_button_input_shadow_tree() {
	mut element := input_element(&model)
	shadow := element.attach_a_user_agent_shadow_root(.named)
	mut container := dom.create_element(element.document(), 'span', ns_html, none, none, false) or { return }
	container.set_attribute_value('style', 'display: inline-block; pointer-events: none;')
	text := element.document().create_text_node(model.button_label())
	mut container_node := container.as_node()
	append_input_shadow_child(mut container_node, text.as_node())
	mut shadow_node := unsafe { &dom.Node(shadow) }
	append_input_shadow_child(mut shadow_node, container.as_node())
	model.text_node_ = text
	model.text_control.text_node_ = text
}

pub fn (mut model HTMLInputElementModel) update_button_input_shadow_tree() {
	if text := model.text_node_ {
		mut mutable_text := unsafe { text }
		mutable_text.set_data(model.button_label())
	}
	model.update_placeholder_visibility()
}

fn (mut model HTMLInputElementModel) create_image_button_alt_text_shadow_tree() {
	mut element := input_element(&model)
	if element.shadow_root() != none {
		return
	}
	shadow := element.attach_a_user_agent_shadow_root(.named)
	mut wrapper := dom.create_element(element.document(), 'div', ns_html, none, none, false) or {
		return
	}
	wrapper.set_attribute_value('style', 'display: inline; unicode-bidi: normal;')
	text := element.document().create_text_node(element.get_attribute_value('alt'))
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(text.as_node()) or { return }
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_node.append_child(wrapper.as_node()) or { return }
	model.image_button_alt_text_node_ = text
	mut document := unsafe { &dom.Document(element.document()) }
	document.set_needs_full_layout_tree_update(true)
}

fn (mut model HTMLInputElementModel) remove_image_button_alt_text_shadow_tree() {
	if model.image_button_alt_text_node_ == none {
		return
	}
	mut element := input_element(&model)
	element.set_shadow_root(none)
	model.image_button_alt_text_node_ = none
	mut document := unsafe { &dom.Document(element.document()) }
	document.set_needs_full_layout_tree_update(true)
}

pub fn (mut model HTMLInputElementModel) update_image_button_alt_text_shadow_tree() {
	alt_text := input_element(&model).get_attribute_value('alt')
	if model.type_state_ != .image_button || !model.renders_as_alt_text() || alt_text == '' {
		model.remove_image_button_alt_text_shadow_tree()
		return
	}
	if model.image_button_alt_text_node_ == none {
		model.create_image_button_alt_text_shadow_tree()
		return
	}
	if text := model.image_button_alt_text_node_ {
		if text.data() == alt_text {
			return
		}
		mut mutable_text := unsafe { text }
		mutable_text.set_data(alt_text)
		mut node := input_element(&model).as_node()
		node.set_needs_layout_tree_update(true, .html_input_element_src_attribute)
		mut document := unsafe { &dom.Document(input_element(&model).document()) }
		document.set_needs_full_layout_tree_update(true)
	}
}

pub fn (mut model HTMLInputElementModel) create_text_input_shadow_tree() {
	mut element := input_element(&model)
	shadow := element.attach_a_user_agent_shadow_root(.named)
	mut container := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	container.set_attribute_value('style', 'display:flex;height:100%;align-items:center;white-space:pre;border:none;')
	mut text_container := container
	if model.type_state_ == .number {
		text_container = dom.create_element(element.document(), 'div', ns_html, none, none,
			false) or { return }
		text_container.set_attribute_value('style', 'display:flex;align-items:center;flex:1;min-width:0;')
		mut container_node := container.as_node()
		append_input_shadow_child(mut container_node, text_container.as_node())
	}
	mut inner := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	inner.set_attribute_value('style', 'width:100%;height:1lh;overflow:auto;scrollbar-width:none;text-overflow:clip;white-space:pre;')
	mut text := element.document().create_text_node(model.value_)
	if model.type_state_ == .password {
		text.set_is_password_input(true)
	}
	mut inner_node := inner.as_node()
	append_input_shadow_child(mut inner_node, text.as_node())
	placeholder := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	placeholder_text := element.document().create_text_node(model.placeholder())
	mut placeholder_node := placeholder.as_node()
	append_input_shadow_child(mut placeholder_node, placeholder_text.as_node())
	mut text_container_node := text_container.as_node()
	append_input_shadow_child(mut text_container_node, inner.as_node())
	append_input_shadow_child(mut text_container_node, placeholder.as_node())
	if model.type_state_ == .number {
		mut container_node := container.as_node()
		mut up := dom.create_element(element.document(), 'button', ns_html, none, none, false) or { return }
		mut down := dom.create_element(element.document(), 'button', ns_html, none, none, false) or { return }
		up.set_attribute_value('style', stepper_button_style_when_visible())
		down.set_attribute_value('style', stepper_button_style_when_visible())
		replace_element_text(up, '▲')
		replace_element_text(down, '▼')
		append_input_shadow_child(mut container_node, up.as_node())
		append_input_shadow_child(mut container_node, down.as_node())
		model.up_button_element_ = up
		model.down_button_element_ = down
		model.install_number_input_ua_event_handlers(up, down)
	}
	mut shadow_node := unsafe { &dom.Node(shadow) }
	append_input_shadow_child(mut shadow_node, container.as_node())
	mut mutable_placeholder := unsafe { &dom.Element(placeholder) }
	mutable_placeholder.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.placeholder))
	model.inner_text_element_ = inner
	model.text_node_ = text
	model.text_control.text_node_ = text
	model.placeholder_element_ = placeholder
	model.placeholder_text_node_ = placeholder_text
	model.handle_maxlength_attribute()
	model.update_text_input_shadow_tree()
}

pub fn (mut model HTMLInputElementModel) create_color_input_shadow_tree() {
	mut element := input_element(&model)
	shadow := element.attach_a_user_agent_shadow_root(.named)
	// Keep geometry in the UA stylesheet so author rules for the swatch
	// pseudo-elements can override it (Ladybird a468d7109e4d).
	mut wrapper := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	mut shadow_node := unsafe { &dom.Node(shadow) }
	append_input_shadow_child(mut shadow_node, wrapper.as_node())
	wrapper.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.webkit_color_swatch_wrapper))
	mut well := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	mut wrapper_node := wrapper.as_node()
	append_input_shadow_child(mut wrapper_node, well.as_node())
	well.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.color_swatch))
	model.color_well_element_ = well
	model.update_color_well_element()
}

pub fn (mut model HTMLInputElementModel) update_color_well_element() {
	if well := model.color_well_element_ {
		mut mutable_well := unsafe { well }
		mutable_well.set_attribute_value('style', 'background-color:${model.value_};')
	}
}

pub fn (mut model HTMLInputElementModel) create_file_input_shadow_tree() {
	mut element := input_element(&model)
	shadow := element.attach_a_user_agent_shadow_root(.named)
	button := dom.create_element(element.document(), 'button', ns_html, none, none, false) or { return }
	mut label := dom.create_element(element.document(), 'label', ns_html, none, none, false) or { return }
	label.set_attribute_value('style', 'padding-left: 4px;')
	mut shadow_node := unsafe { &dom.Node(shadow) }
	append_input_shadow_child(mut shadow_node, button.as_node())
	mut mutable_button := unsafe { &dom.Element(button) }
	mutable_button.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.file_selector_button))
	append_input_shadow_child(mut shadow_node, label.as_node())
	model.file_button_ = button
	model.file_label_ = label
	model.update_file_input_shadow_tree()
}

pub fn (mut model HTMLInputElementModel) update_file_input_shadow_tree() {
	mut button := model.file_button_ or { return }
	mut label := model.file_label_ or { return }
	files_label := if input_element(&model).has_attribute('multiple') { 'files' } else { 'file' }
	replace_element_text(button, 'Select ${files_label}...')
	files := model.selected_files_ or { fileapi.FileList.create() }
	label_text := if files.length() == 1 {
		files.item(0) or { panic('missing selected file') }.name()
	} else if files.length() > 1 {
		'${files.length()} files selected.'
	} else {
		'No ${files_label} selected.'
	}
	replace_element_text(label, label_text)
}

fn html_input_event_client_x(event &dom.Event) ?f64 {
	client_x := match event.interface_ {
		.mouse_event, .wheel_event { unsafe { &dom.MouseEvent(event) }.client_x() }
		.pointer_event { unsafe { &dom.PointerEvent(event) }.client_x() }
		else {
			return none
		}
	}
	if math.is_nan(client_x) || math.is_inf(client_x, 0) {
		return none
	}
	return client_x
}

fn (mut model HTMLInputElementModel) handle_number_step_button(down bool) {
	if model.type_state_ != .number || !model.is_mutable()
		|| model.allowed_value_step() == none {
		return
	}
	if down {
		model.step_down(1) or { return }
	} else {
		model.step_up(1) or { return }
	}
	model.user_interaction_did_change_input_value('', none)
}

fn (mut model HTMLInputElementModel) handle_range_keydown_event(event &dom.Event) {
	if model.type_state_ != .range || model.allowed_value_step() == none
		|| event.interface_ != .keyboard_event {
		return
	}
	key := unsafe { &dom.KeyboardEvent(event) }.key()
	if key in ['ArrowLeft', 'ArrowDown'] {
		model.step_down(1) or { return }
	}
	if key == 'PageDown' {
		model.step_down(10) or { return }
	}
	if key in ['ArrowRight', 'ArrowUp'] {
		model.step_up(1) or { return }
	}
	if key == 'PageUp' {
		model.step_up(10) or { return }
	}
	model.user_interaction_did_change_input_value('', none)
}

fn (mut model HTMLInputElementModel) handle_range_wheel_event(event &dom.Event) {
	if model.type_state_ != .range || model.allowed_value_step() == none
		|| event.interface_ != .wheel_event {
		return
	}
	delta_y := unsafe { &dom.WheelEvent(event) }.delta_y()
	if math.is_nan(delta_y) || math.is_inf(delta_y, 0) {
		return
	}
	if delta_y > 0 {
		model.step_down(1) or { return }
	} else {
		model.step_up(1) or { return }
	}
	model.user_interaction_did_change_input_value('', none)
}

fn (mut model HTMLInputElementModel) handle_range_mouse_event(event &dom.Event) {
	if model.type_state_ != .range {
		return
	}
	client_x := html_input_event_client_x(event) or { return }
	rect := input_element(&model).get_bounding_client_rect()
	if rect.width <= 0 {
		return
	}
	minimum := model.min() or { return }
	maximum := model.max() or { return }
	if minimum > maximum {
		return
	}
	position := math.round(((client_x - rect.x) / rect.width) * (maximum - minimum) + minimum)
	value := math.max(minimum, math.min(position, maximum))
	model.set_value_as_number(value) or { return }
	model.user_interaction_did_change_input_value('', none)
}

fn (mut model HTMLInputElementModel) install_number_input_ua_event_handlers(up &dom.Element, down &dom.Element) {
	model_target := voidptr(&model)
	up_callback := &dom.CallbackType{
		handle_event: fn [model_target] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_model := unsafe { &HTMLInputElementModel(model_target) }
			mutable_model.handle_number_step_button(false)
			return dom.js_undefined()
		}
	}
	down_callback := &dom.CallbackType{
		handle_event: fn [model_target] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_model := unsafe { &HTMLInputElementModel(model_target) }
			mutable_model.handle_number_step_button(true)
			return dom.js_undefined()
		}
	}
	mouseup_callback := &dom.CallbackType{
		handle_event: fn [model_target] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_model := unsafe { &HTMLInputElementModel(model_target) }
			mutable_model.commit_pending_changes()
			return dom.js_undefined()
		}
	}
	up_target := unsafe { &dom.EventTarget(up.as_node()) }
	down_target := unsafe { &dom.EventTarget(down.as_node()) }
	up_target.add_event_listener_without_options('mousedown', dom.IDLEventListener.create(up_callback))
	down_target.add_event_listener_without_options('mousedown', dom.IDLEventListener.create(down_callback))
	up_target.add_event_listener_without_options('mouseup', dom.IDLEventListener.create(mouseup_callback))
	down_target.add_event_listener_without_options('mouseup', dom.IDLEventListener.create(mouseup_callback))
}

fn (mut model HTMLInputElementModel) install_range_input_ua_event_handlers() {
	model_target := voidptr(&model)
	target := unsafe { &dom.EventTarget(input_element(&model).as_node()) }
	keydown_callback := &dom.CallbackType{
		handle_event: fn [model_target] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_model := unsafe { &HTMLInputElementModel(model_target) }
			mutable_model.handle_range_keydown_event(event)
			return dom.js_undefined()
		}
	}
	wheel_callback := &dom.CallbackType{
		handle_event: fn [model_target] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_model := unsafe { &HTMLInputElementModel(model_target) }
			mutable_model.handle_range_wheel_event(event)
			return dom.js_undefined()
		}
	}
	mousedown_callback := &dom.CallbackType{
		handle_event: fn [model_target] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_model := unsafe { &HTMLInputElementModel(model_target) }
			mutable_model.handle_range_mouse_event(event)
			return dom.js_undefined()
		}
	}
	target.add_event_listener_without_options('keydown', dom.IDLEventListener.create(keydown_callback))
	target.add_event_listener_without_options('wheel', dom.IDLEventListener.create(wheel_callback))
	target.add_event_listener_without_options('mousedown', dom.IDLEventListener.create(mousedown_callback))
}

pub fn (mut model HTMLInputElementModel) create_range_input_shadow_tree() {
	mut element := input_element(&model)
	shadow := element.attach_a_user_agent_shadow_root(.named)
	// Keep track alignment independent of author changes to the input's display.
	mut slider_container := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	slider_container.set_attribute_value('style', 'display:flex;align-items:center;width:100%;height:100%;')
	track := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	progress := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	thumb := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	mut track_node := track.as_node()
	append_input_shadow_child(mut track_node, progress.as_node())
	append_input_shadow_child(mut track_node, thumb.as_node())
	mut slider_container_node := slider_container.as_node()
	append_input_shadow_child(mut slider_container_node, track.as_node())
	mut shadow_node := unsafe { &dom.Node(shadow) }
	append_input_shadow_child(mut shadow_node, slider_container.as_node())
	mut mutable_track := unsafe { &dom.Element(track) }
	mutable_track.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.slider_track))
	mut mutable_progress := unsafe { &dom.Element(progress) }
	mutable_progress.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.slider_fill))
	mut mutable_thumb := unsafe { &dom.Element(thumb) }
	mutable_thumb.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.slider_thumb))
	model.slider_progress_element_ = progress
	model.slider_thumb_ = thumb
	model.update_slider_shadow_tree_elements()
	model.install_range_input_ua_event_handlers()
}

pub fn (mut model HTMLInputElementModel) update_slider_shadow_tree_elements() {
	minimum := model.minimum() or { 0.0 }
	maximum := model.maximum() or { 100.0 }
	value := model.convert_string_to_number(model.value_sanitization_algorithm(model.value_)) or {
		minimum
	}
	position := if maximum == minimum {
		0.0
	} else {
		(value - minimum) / (maximum - minimum) * 100.0
	}
	if progress := model.slider_progress_element_ {
		mut mutable_progress := unsafe { progress }
		mutable_progress.set_attribute_value('style', 'width:${position}%;')
	}
	if thumb := model.slider_thumb_ {
		mut mutable_thumb := unsafe { thumb }
		mutable_thumb.set_attribute_value('style', 'margin-left:${position}%;')
	}
}

pub fn (mut model HTMLInputElementModel) update_text_input_shadow_tree() {
	if text := model.text_node_ {
		mut mutable_text := unsafe { text }
		mutable_text.set_data(model.value_)
	}
	model.update_placeholder_visibility()
}

pub fn (mut model HTMLInputElementModel) update_placeholder_visibility() {
	mut placeholder := model.placeholder_element_ or { return }
	style := if model.placeholder_value() != none {
		placeholder_style_when_visible()
	} else {
		placeholder_style_when_hidden()
	}
	if placeholder.get_attribute_value('style') == style { return }
	placeholder.set_attribute_value('style', style)
}

pub fn (mut model HTMLInputElementModel) handle_maxlength_attribute() {
	model.update_validity()
}

pub fn (mut model HTMLInputElementModel) user_interaction_did_change_input_value(input_type string, data ?string) {
	model.has_uncommitted_changes_ = true
	model.user_validity_ = true
	model.event_counts_['input']++
	document := input_element(&model).document()
	event_init := dom.InputEventInit{
		data:         data
		input_type:   input_type
		is_composing: document.is_input_method_composing()
	}
	model_event := dom.InputEvent.create_from_platform_event('input', event_init, [],
		dom.current_event_timestamp())
	model.event_target_.dispatch_event(unsafe { &dom.Event(model_event) })
	element_event := dom.InputEvent.create_from_platform_event('input', event_init, [],
		dom.current_event_timestamp())
	element_event_target := unsafe { &dom.EventTarget(input_element(&model).as_node()) }
	element_base_event := unsafe { &dom.Event(element_event) }
	element_event_target.dispatch_event(element_base_event)
	model.update_validity()
}

pub fn (mut model HTMLInputElementModel) did_edit_text_node(input_type string, data ?string) {
	old_value := model.value_
	if text := model.text_node_ {
		model.value_ = model.value_sanitization_algorithm(text.data())
	}
	model.dirty_value_ = true
	model.value_last_changed_by_user_edit_ = true
	model.text_control.dirty_value_flag = true
	model.text_control.set_relevant_value(model.value_)
	if model.value_ != old_value {
		model.update_placeholder_visibility()
	}
	model.user_interaction_did_change_input_value(input_type, data)
}

pub fn (mut model HTMLInputElementModel) did_receive_focus() {
	if model.has_selectable_text() {
		model.text_control.select()
	}
}

pub fn (mut model HTMLInputElementModel) did_lose_focus() {
	model.commit_pending_changes()
}

pub fn (model &HTMLInputElementModel) has_activation_behavior() bool {
	// https://html.spec.whatwg.org/multipage/input.html#the-input-element:activation-behaviour
	// Input activation runs this element's input activation behavior, if any,
	// and then popover target activation.
	// https://html.spec.whatwg.org/multipage/input.html#button-state-(type=button)
	// Button-state inputs have no input activation behavior.
	//
	// NB: Per spec, input elements have activation behavior even when those
	//     steps are a no-op. However, making a no-op input button the
	//     activation target prevents activation behavior on ancestor anchors.
	//     For compatibility with other browsers, let plain input buttons yield
	//     to ancestors.
	if model.type_state_ == .button
		&& PopoverTargetAttributes.get_the_popover_target_element(input_element(model).as_node()) == none {
		return false
	}
	return true
}

pub fn (mut model HTMLInputElementModel) set_form_action_hook(hook ?InputFormActionHook) {
	model.form_action_hook_ = hook
}

fn (mut model HTMLInputElementModel) run_form_action(action InputFormAction) ! {
	owner := model.control.form() or { return }
	if !input_element(&model).document().is_fully_active() {
		return
	}
	if hook := model.form_action_hook_ {
		if hook.run != unsafe { nil } {
			hook.run(hook.target, model.control, action)!
		}
		return
	}
	mut form := HTMLFormElementModel.create(owner)
	match action {
		.submit {
			form.submit_form(model.control, SubmitFormOptions{ user_involvement: .activation })!
		}
		.reset { form.reset_form() }
		.implicit_submit { form.implicitly_submit_form()! }
	}
}

// Image submitter coordinates are relative to the image's content edge. Use
// native geometry for constructed MouseEvents too, without changing trust or
// granting user activation. Reuse the paint transform for scaled/rotated boxes.
fn (mut model HTMLInputElementModel) select_image_coordinate(event &dom.MouseEvent) {
	element := input_element(&model)
	rect := element.get_bounding_client_rect()
	layout_node := element.as_node().unsafe_layout_node() or { return }
	if !layout_node.has_geometry_ { return }
	document := element.document()
	scale := document.layout_coordinate_scale()
	mut x := event.client_x() - rect.x
	mut y := event.client_y() - rect.y
	if paintable := element.as_node().unsafe_paintable() {
		viewport := document.viewport_rect()
		local := paintable.inverse_transform_point(dom.CSSPixelPoint_{
			x_: event.client_x() + viewport.x
			y_: event.client_y() + viewport.y
		})
		origin := paintable.box_type_agnostic_position()
		x = (local.x() - origin.x()) / scale
		y = (local.y() - origin.y()) / scale
	} else {
		box := layout_node.box_model()
		x -= (box.border_left + box.padding_left) / scale
		y -= (box.border_top + box.padding_top) / scale
	}
	if math.is_nan(x) || math.is_nan(y) || math.is_inf(x, 0) || math.is_inf(y, 0) { return }
	model.selected_x_ = int(x)
	model.selected_y_ = int(y)
}

// https://html.spec.whatwg.org/multipage/input.html#input-activation-behavior
pub fn (mut model HTMLInputElementModel) run_input_activation_behavior(event &dom.Event) ! {
	match model.type_state_ {
		.checkbox, .radio_button {
			if !input_element(&model).is_connected() {
				return
			}
			if model.type_state_ == .radio_button && model.before_activation_checked_ {
				return
			}
			model.fire_event('input')
			model.fire_event('change')
		}
		.submit_button {
			if !input_element(&model).is_actually_disabled() {
				model.run_form_action(.submit)!
			}
		}
		.file_upload, .color {
			model.show_the_picker_if_applicable()
		}
		.image_button {
			if event.interface_ in [.mouse_event, .pointer_event] {
				mouse_event := unsafe { &dom.MouseEvent(event) }
				if !mouse_event.is_synthetic_activation_ {
					model.select_image_coordinate(mouse_event)
				}
			}
			model.run_form_action(.submit)!
		}
		.reset_button {
			if !input_element(&model).is_actually_disabled() {
				model.run_form_action(.reset)!
			}
		}
		else {}
	}
}

pub fn (mut model HTMLInputElementModel) activation_behavior(event &dom.Event) ! {
	if !model.is_mutable() && model.type_state_ !in [.checkbox, .radio_button] {
		return
	}
	model.run_input_activation_behavior(event)!
}

pub fn (mut model HTMLInputElementModel) legacy_pre_activation_behavior() {
	model.before_activation_checked_ = model.checked()
	model.before_activation_indeterminate_ = model.indeterminate()
	if model.type_state_ == .checkbox {
		model.set_checked(!model.checked())
		model.set_indeterminate(false)
	} else if model.type_state_ == .radio_button {
		model.previously_checked_radio_ = none
		for other in input_models_in_same_tree(&model) {
			if other.checked() && same_radio_group(&model, other) {
				model.previously_checked_radio_ = other
				break
			}
		}
		model.set_checked_within_group()
	}
}

pub fn (mut model HTMLInputElementModel) legacy_cancelled_activation_behavior() {
	if model.type_state_ == .checkbox {
		model.set_checked(model.before_activation_checked_)
		model.set_indeterminate(model.before_activation_indeterminate_)
	} else if model.type_state_ == .radio_button {
		mut did_reselect := false
		if previous := model.previously_checked_radio_ {
			if same_radio_group(&model, previous) {
				mut mutable_previous := unsafe { previous }
				mutable_previous.set_checked_within_group()
				did_reselect = true
			}
		}
		model.previously_checked_radio_ = none
		if !did_reselect {
			model.set_checked(false)
		}
	}
}

pub fn (mut model HTMLInputElementModel) legacy_cancelled_activation_behavior_was_not_called() {
	model.previously_checked_radio_ = none
}

pub fn (mut model HTMLInputElementModel) activate() {
	if !model.is_mutable() && model.type_state_ !in [.checkbox, .radio_button] {
		return
	}
	model.legacy_pre_activation_behavior()
	event := dom.Event.create('click', dom.EventInit{})
	model.run_input_activation_behavior(event) or {
		model.legacy_cancelled_activation_behavior()
		return
	}
	model.legacy_cancelled_activation_behavior_was_not_called()
}

pub fn (mut model HTMLInputElementModel) did_select_files(files []SelectedFile, handling MultipleFileHandling) {
	model.set_is_open(false)
	if model.type_state_ != .file_upload {
		return
	}
	if files.len == 0 {
		model.fire_event('cancel')
		return
	}
	selected := input_file_list_from_picker(files)
	if old_files := model.selected_files_ {
		if handling == .append && input_element(&model).has_attribute('multiple') {
			mut list := unsafe { &fileapi.FileList(old_files) }
			for file in selected.files() {
				list.add_file(file)
			}
		} else {
			model.selected_files_ = selected
		}
	} else {
		model.selected_files_ = selected
	}
	model.fire_event('input')
	model.fire_event('change')
	model.update_validity()
	model.update_file_input_shadow_tree()
}

pub fn (mut model HTMLInputElementModel) set_files(files ?[]SelectedFile) {
	if model.type_state_ != .file_upload {
		return
	}
	if replacement := files {
		model.set_file_list(input_file_list_from_picker(replacement))
	}
}

pub fn (mut model HTMLInputElementModel) update_the_file_selection(files []SelectedFile) {
	model.set_files(files)
	model.fire_event('input')
	model.fire_event('change')
	model.update_validity()
}

pub fn (model &HTMLInputElementModel) files() ?[]SelectedFile {
	if model.type_state_ != .file_upload {
		return none
	}
	mut result := []SelectedFile{}
	if files := model.selected_files_ {
		for file in files.files() {
			result << SelectedFile.from_contents(file.name(), file.raw_bytes().clone())
		}
	}
	return result
}

// HTMLInputElement::did_select_files(), the picker/IPC boundary. SelectedFile
// descriptors have already been materialized by IPC upstream; the V in-process
// boundary also accepts them and uses the existing IPC byte snapshot helper.
fn input_file_list_from_picker(selected_files []SelectedFile) &fileapi.FileList {
	mut files := fileapi.FileList.create()
	for selected_file in selected_files {
		contents, _ := selected_file_contents(&selected_file) or { panic(err) }
		mime_type := mimesniff.Resource.sniff(contents, mimesniff.SniffingConfiguration{})
		files.add_file(fileapi.File.construct([fileapi.BlobPart.from_bytes(contents)], selected_file.name,
			fileapi.FilePropertyBag{
				type_: mime_type.essence()
			}))
	}
	return files
}

// HTMLInputElement::files()/set_files(). Unlike the legacy SelectedFile array
// adapter, these expose the source FileList and preserve File object identity.
pub fn (mut model HTMLInputElementModel) file_list() ?&fileapi.FileList {
	if model.type_state_ != .file_upload {
		return none
	}
	if files := model.selected_files_ {
		return files
	}
	files := fileapi.FileList.create()
	model.selected_files_ = files
	return files
}

pub fn (mut model HTMLInputElementModel) set_file_list(files ?&fileapi.FileList) {
	if model.type_state_ != .file_upload {
		return
	}
	if selected := files {
		model.selected_files_ = selected
	}
}

pub fn (model &HTMLInputElementModel) max_length() i32 {
	return limited_nonnegative_attribute(input_element(model), 'maxlength')
}

pub fn (mut model HTMLInputElementModel) set_max_length(value i32) ! {
	if value < 0 {
		return error('IndexSizeError: maxLength must be non-negative')
	}
	mut element := input_element(&model)
	element.set_attribute_value('maxlength', value.str())
	model.handle_maxlength_attribute()
}

pub fn (model &HTMLInputElementModel) min_length() i32 {
	return limited_nonnegative_attribute(input_element(model), 'minlength')
}

pub fn (mut model HTMLInputElementModel) set_min_length(value i32) ! {
	if value < 0 {
		return error('IndexSizeError: minLength must be non-negative')
	}
	mut element := input_element(&model)
	element.set_attribute_value('minlength', value.str())
	model.update_validity()
}

pub fn (model &HTMLInputElementModel) size() u32 {
	value := limited_nonnegative_attribute(input_element(model), 'size')
	return if value > 0 { u32(value) } else { u32(20) }
}

pub fn (mut model HTMLInputElementModel) set_size(value u64) ! {
	if value == 0 {
		return error('IndexSizeError: size must be greater than zero')
	}
	actual := if value > 2147483647 { u64(20) } else { value }
	mut element := input_element(&model)
	element.set_attribute_value('size', actual.str())
}

pub fn (model &HTMLInputElementModel) height() u32 {
	mut document := unsafe { &dom.Document(input_element(model).document()) }
	document.update_layout(.html_input_element_height)
	if model.type_state_ != .image_button {
		return 0
	}
	if node := input_element(model).as_node().layout_node() {
		if node.has_geometry_ { return u32(node.content_height_ / document.layout_coordinate_scale()) }
	}
	if attribute := input_element(model).get_attribute('height') {
		if parsed := parse_non_negative_integer(attribute) {
			if parsed <= 2147483647 {
				return parsed
			}
		}
	}
	value := model.intrinsic_height() or { return 0 }
	return if value > 0 { u32(value) } else { 0 }
}

pub fn (mut model HTMLInputElementModel) set_height(value u64) {
	actual := if value > 2147483647 { u64(0) } else { value }
	mut element := input_element(&model)
	element.set_attribute_value('height', actual.str())
}

pub fn (model &HTMLInputElementModel) width() u32 {
	mut document := unsafe { &dom.Document(input_element(model).document()) }
	document.update_layout(.html_input_element_width)
	if model.type_state_ != .image_button {
		return 0
	}
	if node := input_element(model).as_node().layout_node() {
		if node.has_geometry_ { return u32(node.content_width_ / document.layout_coordinate_scale()) }
	}
	if attribute := input_element(model).get_attribute('width') {
		if parsed := parse_non_negative_integer(attribute) {
			if parsed <= 2147483647 {
				return parsed
			}
		}
	}
	value := model.intrinsic_width() or { return 0 }
	return if value > 0 { u32(value) } else { 0 }
}

pub fn (mut model HTMLInputElementModel) set_width(value u64) {
	actual := if value > 2147483647 { u64(0) } else { value }
	mut element := input_element(&model)
	element.set_attribute_value('width', actual.str())
}

pub fn (model &HTMLInputElementModel) selected_coordinate() InputSelectedCoordinate {
	return InputSelectedCoordinate{
		x: model.selected_x_
		y: model.selected_y_
	}
}

pub fn (model &HTMLInputElementModel) parse_accept_attribute() FileFilter {
	mut filter := FileFilter{}
	if !model.multiple_applies() {
		return filter
	}
	for raw in input_element(model).get_attribute_value('accept').split(',') {
		token := ascii_lowercase_string(raw.trim_space())
		if token == 'audio/*' {
			filter.add_filter(FileFilterFileType.audio)
		} else if token == 'image/*' {
			filter.add_filter(FileFilterFileType.image)
		} else if token == 'video/*' {
			filter.add_filter(FileFilterFileType.video)
		} else if token.starts_with('.') && token.len > 1 {
			filter.add_filter(FileFilterExtension{token})
		} else if token.contains('/') {
			filter.add_filter(FileFilterMimeType{token})
		}
	}
	return filter
}

pub fn (mut model HTMLInputElementModel) set_picker_hook(hook ?InputPickerHook) {
	model.picker_hook_ = hook
}

pub fn (mut model HTMLInputElementModel) set_image_fetch_hook(hook ?HTMLImageFetchHook) {
	model.image_fetch_hook_ = hook
}

pub fn (mut model HTMLInputElementModel) set_image_model_fetch_hook(hook ?InputImageModelFetchHook) {
	model.image_model_fetch_hook_ = hook
}

fn (mut model HTMLInputElementModel) begin_delaying_document_load_event() {
	if mut delayer := model.load_event_delayer_ {
		delayer.finish()
	}
	mut document := unsafe { &dom.Document(input_element(&model).document()) }
	model.load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut document)
}

fn (mut model HTMLInputElementModel) stop_delaying_document_load_event() {
	if mut delayer := model.load_event_delayer_ {
		delayer.finish()
	}
	model.load_event_delayer_ = none
}

pub fn (mut model HTMLInputElementModel) adopted_from(_ &dom.Document) {
	new_document := input_element(&model).document()
	mut was_delaying := false
	if mut delayer := model.load_event_delayer_ {
		delayer.finish()
		was_delaying = true
	}
	if was_delaying {
		mut mutable_new_document := unsafe { &dom.Document(new_document) }
		model.load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut mutable_new_document)
	}
}

// https://html.spec.whatwg.org/multipage/input.html#attr-input-src
pub fn (mut model HTMLInputElementModel) handle_src_attribute(value string) ! {
	if model.type_state_ != .image_button {
		return
	}
	model.last_src_value_ = value
	url := input_element(&model).document().encoding_parse_url(value) or { return }
	mut request := SharedResourceRequest.get_or_create(input_element(&model).document(), url)
	model.resource_request_ = request
	model.update_image_button_alt_text_shadow_tree()
	mut node := input_element(&model).as_node()
	node.set_needs_layout_tree_update(true, .html_input_element_src_attribute)
	if request.state() == .finished {
		model.fire_event('load')
		model.update_image_button_alt_text_shadow_tree()
		return
	}
	if request.state() == .failed {
		model.fire_event('error')
		model.update_image_button_alt_text_shadow_tree()
		return
	}
	if model.image_model_fetch_hook_ == none && model.image_fetch_hook_ == none { return }
	model.begin_delaying_document_load_event()
	decoded := model.fetch_image(url) or {
		request.handle_failed_fetch()
		model.fire_event('error')
		model.stop_delaying_document_load_event()
		model.update_image_button_alt_text_shadow_tree()
		return
	}
	request.handle_successful_resource_load(decoded)
	model.fire_event('load')
	model.stop_delaying_document_load_event()
	model.update_image_button_alt_text_shadow_tree()
}

fn (model &HTMLInputElementModel) fetch_image(url dom.URL) !DecodedImageData {
	if fetch := model.image_model_fetch_hook_ { return fetch(model, url) }
	fetch := model.image_fetch_hook_ or { return error('No input image fetch hook') }
	return fetch(url)
}

pub fn (model &HTMLInputElementModel) image_data() ?DecodedImageData {
	request := model.resource_request_ or { return none }
	data := request.image_data() or { return none }
	return data.data
}

pub fn (model &HTMLInputElementModel) is_image_available() bool {
	return model.image_data() != none
}

pub fn (model &HTMLInputElementModel) renders_as_alt_text() bool {
	return !model.is_image_available() && !model.is_image_pending()
}

// A newly created shared request has not started its host fetch yet but is
// still potentially available, just like an in-flight request.
pub fn (model &HTMLInputElementModel) is_image_pending() bool {
	request := model.resource_request_ or {
		return model.type_state_ == .image_button
			&& input_element(model).get_attribute_value('src') != ''
	}
	return request.needs_fetching() || request.is_fetching()
}

pub fn (model &HTMLInputElementModel) intrinsic_width() ?f64 {
	data := model.image_data() or { return none }
	return data.intrinsic_width()
}

pub fn (model &HTMLInputElementModel) intrinsic_height() ?f64 {
	data := model.image_data() or { return none }
	return data.intrinsic_height()
}

pub fn (model &HTMLInputElementModel) intrinsic_aspect_ratio() ?f64 {
	data := model.image_data() or { return none }
	return data.intrinsic_aspect_ratio()
}

pub fn (model &HTMLInputElementModel) current_image_frame_sized(_ int, _ int) ?&dom.DecodedImageFrame_ {
	data := model.image_data() or { return none }
	return data.frame(0)
}

pub fn (mut model HTMLInputElementModel) set_visible_in_viewport(visible bool) {
	model.visible_in_viewport_ = visible
}

pub fn (model &HTMLInputElementModel) supports_a_picker() bool {
	return model.type_state_ in [.file_upload, .color]
}

pub fn (mut model HTMLInputElementModel) set_is_open(is_open bool) {
	model.is_open_ = is_open
	mut element := unsafe { &dom.HTMLInputElement(model.element) }
	element.set_is_open(is_open)
}

pub fn (model &HTMLInputElementModel) is_open() bool {
	return unsafe { &dom.HTMLInputElement(model.element) }.is_open()
}

fn (mut model HTMLInputElementModel) show_the_picker_if_applicable() {
	element := input_element(&model)
	window := picker_relevant_window(element) or { return }
	if !window.has_transient_activation() || !model.is_mutable() {
		return
	}
	window.consume_user_activation()
	if !model.supports_a_picker() {
		return
	}
	model.set_is_open(true)
	document := element.document()
	if document.has_page() {
		input_target := element.as_node().unique_id().value().str()
		if model.type_state_ == .file_upload {
			document.page().did_request_file_picker(input_target,
				element.get_attribute_value('accept'), element.has_attribute('multiple'))
		} else {
			document.page().did_request_color_picker(input_target, model.value())
		}
		return
	}
	hook := model.picker_hook_ or { return }
	if hook.request == unsafe { nil } {
		return
	}
	hook.request(hook.target, InputPickerRequest{
		element:        model.element
		kind:           if model.type_state_ == .file_upload { .file } else { .color }
		file_filter:    model.parse_accept_attribute()
		allow_multiple: element.has_attribute('multiple')
		initial_color:  model.value()
	})
}

// https://html.spec.whatwg.org/multipage/input.html#dom-input-showpicker
pub fn (mut model HTMLInputElementModel) show_picker() ! {
	if !model.is_mutable() {
		return error('InvalidStateError: element is not mutable')
	}
	element := input_element(&model)
	if !picker_origin_is_same_as_top_level(element) && model.type_state_ !in [.file_upload, .color] {
		return error('SecurityError: cross-origin pickers are not allowed')
	}
	window := picker_relevant_window(element) or {
		return error('NotAllowedError: no transient user activation')
	}
	if !window.has_transient_activation() {
		return error('NotAllowedError: no transient user activation')
	}
	model.show_the_picker_if_applicable()
}

pub fn (mut model HTMLInputElementModel) did_pick_color(picked_color ?string, closed bool) {
	if model.type_state_ != .color {
		return
	}
	if color := picked_color {
		model.value_ = model.value_sanitization_algorithm(color)
		model.dirty_value_ = true
		model.update_color_well_element()
		model.user_interaction_did_change_input_value('', none)
	}
	if closed {
		model.set_is_open(false)
		model.user_validity_ = true
		model.fire_event('change')
	}
}

fn (model &HTMLInputElementModel) convert_string_to_number(value string) ?f64 {
	match model.type_state_ {
		.number, .range {
			return parse_floating_point_number(value)
		}
		.month {
			month := parse_a_month_string(value) or { return none }
			return f64(number_of_months_since_unix_epoch(month))
		}
		.week {
			week := parse_a_week_string(value) or { return none }
			return f64(iso_week_monday_days(i64(week.week_year), i64(week.week))) * 86400000.0
		}
		.time {
			time := parse_time_string(value) or { return none }
			return f64(time.hour * 3600000 + time.minute * 60000) + f64(time.second) * 1000
		}
		.date {
			date := parse_a_date_string(value) or { return none }
			return f64(days_from_civil(i64(date.year), i64(date.month), i64(date.day))) * 86400000.0
		}
		.local_date_and_time {
			value_ := parse_a_local_date_and_time_string(value) or { return none }
			days := days_from_civil(i64(value_.date.year), i64(value_.date.month), i64(value_.date.day))
			return f64(days) * 86400000.0 + f64(value_.time.hour * 3600000 + value_.time.minute * 60000) + f64(value_.time.second) * 1000
		}
		else {
			return none
		}
	}
}

pub fn (model &HTMLInputElementModel) convert_time_string_to_number(value string) ?f64 {
	if model.type_state_ != .time {
		return none
	}
	return model.convert_string_to_number(value)
}

fn days_from_civil(year i64, month i64, day i64) i64 {
	y := year - if month <= 2 { i64(1) } else { i64(0) }
	era := if y >= 0 { y } else { y - 399 } / 400
	yoe := y - era * 400
	month_prime := month + if month > 2 { i64(-3) } else { i64(9) }
	doy := (153 * month_prime + 2) / 5 + day - 1
	doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
}

fn civil_from_days(days i64) (i64, i64, i64) {
	z := days + 719468
	era := if z >= 0 { z } else { z - 146096 } / 146097
	doe := z - era * 146097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	mut year := yoe + era * 400
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	day := doy - (153 * mp + 2) / 5 + 1
	month := mp + if mp < 10 { i64(3) } else { i64(-9) }
	year += if month <= 2 { i64(1) } else { i64(0) }
	return year, month, day
}

fn positive_mod(value i64, modulus i64) i64 {
	result := value % modulus
	return if result < 0 { result + modulus } else { result }
}

fn iso_weekday_from_days(days i64) i64 {
	// 1970-01-01 was Thursday (ISO weekday 4).
	return positive_mod(days + 3, 7) + 1
}

fn iso_week_monday_days(year i64, week i64) i64 {
	jan_fourth := days_from_civil(year, 1, 4)
	week_one_monday := jan_fourth - (iso_weekday_from_days(jan_fourth) - 1)
	return week_one_monday + (week - 1) * 7
}

fn iso_week_from_days(days i64) (i64, i64) {
	weekday := iso_weekday_from_days(days)
	thursday := days + (4 - weekday)
	week_year, _, _ := civil_from_days(thursday)
	week_one_monday := iso_week_monday_days(week_year, 1)
	return week_year, (days - week_one_monday) / 7 + 1
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#best-representation-of-the-number-as-a-floating-point-number
// That is ECMAScript Number::toString: V's shortest round-tripping digits
// placed by its decimal/exponent thresholds (V would print 7 as "7.0").
fn best_representation_of_number(value f64) string {
	if math.is_nan(value) { return 'NaN' }
	if math.is_inf(value, 0) { return if value > 0 { 'Infinity' } else { '-Infinity' } }
	if value == 0 { return '0' }
	sign := if value < 0 { '-' } else { '' }
	scientific := strconv.ftoa_64(math.abs(value))
	digits := scientific.all_before('e').replace('.', '').trim_right('0')
	exponent := scientific.all_after('e').int()
	point := exponent + 1
	if point > 0 && point <= 21 {
		if point >= digits.len { return sign + digits + '0'.repeat(point - digits.len) }
		return sign + digits[..point] + '.' + digits[point..]
	}
	if point > -6 && point <= 0 { return sign + '0.' + '0'.repeat(-point) + digits }
	mantissa := if digits.len == 1 { digits } else { digits[..1] + '.' + digits[1..] }
	exponent_sign := if exponent >= 0 { '+' } else { '' }
	return '${sign}${mantissa}e${exponent_sign}${exponent}'
}

fn numeric_input_string(model &HTMLInputElementModel, value f64) string {
	match model.type_state_ {
		.number, .range {
			return best_representation_of_number(value)
		}
		.month {
			months := i64(math.floor(value))
			year := 1970 + (months - positive_mod(months, 12)) / 12
			month := positive_mod(months, 12) + 1
			return '${year:04d}-${month:02d}'
		}
		.week {
			if math.is_nan(value) || math.is_inf(value, 0)
				|| math.abs(value) > max_ecmascript_time_value {
				return ''
			}
			days := i64(math.floor(value / 86400000.0))
			year, week := iso_week_from_days(days)
			return '${year:04d}-W${week:02d}'
		}
		.time {
			mut time_of_day := math.fmod(value, 86400000.0)
			if time_of_day < 0 {
				time_of_day += 86400000.0
			}
			hour := int(time_of_day / 3600000.0)
			minute := int(math.fmod(time_of_day, 3600000.0) / 60000.0)
			second := int(math.fmod(time_of_day, 60000.0) / 1000.0)
			millisecond := int(math.fmod(time_of_day, 1000.0))
			if millisecond != 0 {
				return '${hour:02d}:${minute:02d}:${second:02d}.${millisecond:03d}'
			}
			if second != 0 {
				return '${hour:02d}:${minute:02d}:${second:02d}'
			}
			return '${hour:02d}:${minute:02d}'
		}
		.date {
			year, month, day := civil_from_days(i64(math.floor(value / 86400000.0)))
			return '${year:04d}-${month:02d}-${day:02d}'
		}
		.local_date_and_time {
			if math.is_nan(value) || math.is_inf(value, 0)
				|| math.abs(value) > max_ecmascript_time_value {
				return ''
			}
			days := i64(math.floor(value / 86400000.0))
			year, month, day := civil_from_days(days)
			remaining := i64(value) - days * 86400000
			hour := remaining / 3600000
			minute := (remaining / 60000) % 60
			return '${year:04d}-${month:02d}-${day:02d}T${hour:02d}:${minute:02d}'
		}
		else {
			return ''
		}
	}
}

pub fn (model &HTMLInputElementModel) convert_number_to_string(value f64) string {
	return numeric_input_string(model, value)
}

pub fn (model &HTMLInputElementModel) convert_string_to_date(value string) ?f64 {
	if model.type_state_ in [.date, .week, .time] {
		return model.convert_string_to_number(value)
	}
	if model.type_state_ == .month {
		month := parse_a_month_string(value) or { return none }
		return f64(days_from_civil(i64(month.year), i64(month.month), 1)) * 86400000.0
	}
	return none
}

pub fn (model &HTMLInputElementModel) convert_date_to_string(milliseconds f64) string {
	return match model.type_state_ {
		.date, .week, .time { numeric_input_string(model, milliseconds) }
		.month {
			year, month, _ := civil_from_days(i64(math.floor(milliseconds / 86400000.0)))
			'${year:04d}-${month:02d}'
		}
		else { '' }
	}
}

pub fn (model &HTMLInputElementModel) value_as_date() ?f64 {
	if !model.value_as_date_applies() {
		return none
	}
	return model.convert_string_to_date(model.value())
}

pub fn (mut model HTMLInputElementModel) set_value_as_date(value ?f64) ! {
	if !model.value_as_date_applies() {
		return error('InvalidStateError: valueAsDate does not apply')
	}
	milliseconds := value or {
		model.set_value('')!
		return
	}
	if math.is_nan(milliseconds) || math.is_inf(milliseconds, 0) {
		model.set_value('')!
		return
	}
	model.set_value(model.convert_date_to_string(milliseconds))!
}

pub fn (model &HTMLInputElementModel) value_as_number() f64 {
	if !model.value_as_number_applies() {
		return math.nan()
	}
	return model.convert_string_to_number(model.value_) or { math.nan() }
}

pub fn (mut model HTMLInputElementModel) set_value_as_number(value f64) ! {
	if math.is_inf(value, 0) {
		return error('TypeError: valueAsNumber cannot be infinite')
	}
	if !model.value_as_number_applies() {
		return error('InvalidStateError: valueAsNumber does not apply')
	}
	model.set_value(if math.is_nan(value) { '' } else { numeric_input_string(&model, value) })!
}

pub fn (model &HTMLInputElementModel) minimum() ?f64 {
	if value := input_element(model).get_attribute('min') {
		if number := model.convert_string_to_number(value) {
			return number
		}
	}
	if model.type_state_ == .range {
		return 0.0
	}
	return none
}

pub fn (model &HTMLInputElementModel) min() ?f64 {
	return model.minimum()
}

pub fn (model &HTMLInputElementModel) maximum() ?f64 {
	if value := input_element(model).get_attribute('max') {
		if number := model.convert_string_to_number(value) {
			return number
		}
	}
	if model.type_state_ == .range {
		return 100.0
	}
	return none
}

pub fn (model &HTMLInputElementModel) max() ?f64 {
	return model.maximum()
}

fn (model &HTMLInputElementModel) default_step() f64 {
	return match model.type_state_ {
		.time, .local_date_and_time { 60.0 }
		else { 1.0 }
	}
}

fn (model &HTMLInputElementModel) step_scale_factor() f64 {
	return match model.type_state_ {
		.date { 86400000.0 }
		.week { 604800000.0 }
		.time, .local_date_and_time { 1000.0 }
		else { 1.0 }
	}
}

pub fn (model &HTMLInputElementModel) allowed_value_step() ?f64 {
	if !model.step_applies() {
		return none
	}
	value := input_element(model).get_attribute('step') or {
		return model.default_step() * model.step_scale_factor()
	}
	if ascii_lowercase_string(value) == 'any' {
		return none
	}
	parsed := parse_floating_point_number(value) or {
		return model.default_step() * model.step_scale_factor()
	}
	if parsed <= 0 {
		return model.default_step() * model.step_scale_factor()
	}
	return parsed * model.step_scale_factor()
}

pub fn (model &HTMLInputElementModel) step_base() f64 {
	if minimum := model.minimum() {
		return minimum
	}
	if value := input_element(model).get_attribute('value') {
		if number := model.convert_string_to_number(value) {
			return number
		}
	}
	if model.type_state_ == .week {
		return -259200000.0
	}
	return 0.0
}

fn (mut model HTMLInputElementModel) step_up_or_down(down bool, n i32) ! {
	if !model.step_up_or_down_applies() {
		return error('InvalidStateError: stepping does not apply')
	}
	step := model.allowed_value_step() or { return error('InvalidStateError: step is any') }
	minimum := model.minimum()
	maximum := model.maximum()
	if min := minimum {
		if max := maximum {
			if min > max {
				return
			}
		}
	}
	mut value := model.convert_string_to_number(model.value_) or { 0.0 }
	base := model.step_base()
	ratio := (value - base) / step
	if math.abs(ratio - math.round(ratio)) > 1e-9 {
		value = base + (if down { math.floor(ratio) } else { math.ceil(ratio) }) * step
	} else {
		value += step * f64(if down { -n } else { n })
	}
	if min := minimum {
		if value < min {
			value = base + math.ceil((min - base) / step) * step
		}
	}
	if max := maximum {
		if value > max {
			value = base + math.floor((max - base) / step) * step
		}
	}
	model.set_value(numeric_input_string(&model, value))!
}

pub fn (mut model HTMLInputElementModel) step_up(n i32) ! {
	model.step_up_or_down(false, n)!
}

pub fn (mut model HTMLInputElementModel) step_down(n i32) ! {
	model.step_up_or_down(true, n)!
}

pub fn (model &HTMLInputElementModel) select_applies() bool {
	return model.type_state_ !in [.button, .checkbox, .hidden, .image_button, .radio_button, .range,
		.reset_button, .submit_button]
}

pub fn (model &HTMLInputElementModel) selection_or_range_applies() bool {
	return html_input_selection_or_range_applies_for_type_state(model.type_state_)
}

pub fn html_input_selection_or_range_applies_for_type_state(state HTMLInputTypeState) bool {
	return state in [.text, .search, .telephone, .url, .password]
}

pub fn html_input_element_selection_or_range_applies_for_type_state(state HTMLInputTypeState) bool {
	return html_input_selection_or_range_applies_for_type_state(state)
}

pub fn (model &HTMLInputElementModel) selection_direction_applies() bool {
	return html_input_selection_or_range_applies_for_type_state(model.type_state_)
}

pub fn (model &HTMLInputElementModel) selection_direction_binding() ?string {
	return model.text_control.selection_direction()
}

pub fn (model &HTMLInputElementModel) pattern_applies() bool {
	return model.type_state_ in [.text, .search, .telephone, .url, .email, .password]
}

pub fn (model &HTMLInputElementModel) multiple_applies() bool {
	return model.type_state_ in [.email, .file_upload]
}

pub fn (model &HTMLInputElementModel) required_applies() bool {
	return model.type_state_ in [.text, .search, .telephone, .url, .email, .password, .date, .month,
		.week, .time, .local_date_and_time, .number, .checkbox, .radio_button, .file_upload]
}

pub fn (model &HTMLInputElementModel) checked_applies() bool {
	return model.type_state_ in [.checkbox, .radio_button]
}

pub fn (model &HTMLInputElementModel) has_selectable_text() bool {
	return model.type_state_ in [.text, .search, .telephone, .url, .password, .date, .month, .week,
		.time, .local_date_and_time, .number, .email]
}

pub fn (model &HTMLInputElementModel) change_event_applies() bool {
	return model.type_state_ in [.checkbox, .color, .date, .email, .file_upload, .local_date_and_time,
		.month, .number, .password, .radio_button, .range, .search, .telephone, .text, .time, .url,
		.week]
}

pub fn (model &HTMLInputElementModel) value_as_date_applies() bool {
	return model.type_state_ in [.date, .month, .week, .time]
}

pub fn (model &HTMLInputElementModel) value_as_number_applies() bool {
	return model.type_state_ in [.date, .month, .week, .time, .local_date_and_time, .number, .range]
}

pub fn (model &HTMLInputElementModel) step_applies() bool {
	return model.value_as_number_applies()
}

pub fn (model &HTMLInputElementModel) step_up_or_down_applies() bool {
	return model.value_as_number_applies()
}

pub fn (model &HTMLInputElementModel) has_input_activation_behavior() bool {
	return model.type_state_ in [.checkbox, .color, .file_upload, .image_button, .radio_button,
		.reset_button, .submit_button]
}

pub fn (model &HTMLInputElementModel) is_button() bool {
	return model.type_state_ in [.submit_button, .image_button, .reset_button, .button]
}

pub fn (model &HTMLInputElementModel) is_listed() bool {
	return true
}

pub fn (model &HTMLInputElementModel) is_submittable() bool {
	return true
}

pub fn (model &HTMLInputElementModel) is_resettable() bool {
	return true
}

pub fn (model &HTMLInputElementModel) is_autocapitalize_and_autocorrect_inheriting() bool {
	return true
}

pub fn (model &HTMLInputElementModel) is_submit_button() bool {
	return model.type_state_ in [.submit_button, .image_button]
}

pub fn (model &HTMLInputElementModel) is_single_line() bool {
	return model.type_state_ in [.text, .search, .password, .email, .telephone, .number]
}

pub fn (model &HTMLInputElementModel) is_labelable() bool {
	return model.type_state_ != .hidden
}

pub fn (model &HTMLInputElementModel) has_periodic_domain() bool {
	return model.type_state_ == .time
}

pub fn (model &HTMLInputElementModel) supports_dimension_attributes() bool {
	return model.type_state_ == .image_button
}

pub fn (model &HTMLInputElementModel) default_tab_index_value() i32 {
	return 0
}

pub fn (model &HTMLInputElementModel) form_associated_element_to_text_node() ?&dom.Text {
	return model.text_node_
}

pub fn (model &HTMLInputElementModel) text_control_scroll_container() ?&dom.Element {
	return model.inner_text_element_
}

pub fn (model &HTMLInputElementModel) can_have_text_editing_cursor() bool {
	return model.type_state_ !in [.submit_button, .reset_button, .button]
}

pub fn (model &HTMLInputElementModel) uses_button_layout() bool {
	return model.type_state_ in [.submit_button, .reset_button, .button, .color, .file_upload]
}

// HTMLInputElement::is_focusable(), which DOM's Element::is_focusable() dispatch translates.
pub fn (model &HTMLInputElementModel) is_focusable() bool {
	return input_element(model).is_focusable()
}

pub fn html_input_element_default_role(input &dom.HTMLInputElement) ?aria.Role {
	element := unsafe { &dom.Element(input) }
	if !element.is_connected() {
		return none
	}
	return match parse_html_input_type(element.get_attribute_value('type')) {
		.button, .image_button, .reset_button, .submit_button { aria.Role.button }
		.checkbox {
			if element.has_attribute('switch') { aria.Role.switch_ } else { aria.Role.checkbox }
		}
		.email {
			if element.has_attribute('list') { aria.Role.combobox } else { aria.Role.textbox }
		}
		.number { aria.Role.spinbutton }
		.radio_button { aria.Role.radio }
		.range { aria.Role.slider }
		.search {
			if element.has_attribute('list') { aria.Role.combobox } else { aria.Role.searchbox }
		}
		.telephone, .url { aria.Role.textbox }
		.text {
			if element.has_attribute('list') { aria.Role.combobox } else { aria.Role.textbox }
		}
		else { none }
	}
}

pub fn (model &HTMLInputElementModel) default_role() ?aria.Role {
	return html_input_element_default_role(model.element)
}

pub fn (model &HTMLInputElementModel) is_mutable() bool {
	return !input_element(model).is_actually_disabled() && (!input_element(model).has_attribute('readonly') || !model.is_allowed_to_be_readonly())
}

pub fn (model &HTMLInputElementModel) is_allowed_to_be_readonly() bool {
	return model.type_state_ in [.text, .search, .telephone, .url, .email, .password, .date, .month,
		.week, .time, .local_date_and_time, .number]
}

pub fn (model &HTMLInputElementModel) is_presentational_hint(name string) bool {
	return model.type_state_ == .image_button && ascii_lowercase_string(name) in [
		'align',
		'border',
		'height',
		'hspace',
		'vspace',
		'width',
	]
}

pub fn (model &HTMLInputElementModel) apply_presentational_hints() EmbeddedPresentationalHints {
	if model.type_state_ != .image_button {
		return EmbeddedPresentationalHints{}
	}
	element := input_element(model)
	return embedded_presentational_hints({
		'align':  element.get_attribute_value('align')
		'border': element.get_attribute_value('border')
		'height': element.get_attribute_value('height')
		'hspace': element.get_attribute_value('hspace')
		'vspace': element.get_attribute_value('vspace')
		'width':  element.get_attribute_value('width')
	}, true)
}

fn valid_email_address(value string) bool {
	parts := value.split('@')
	if parts.len != 2 || parts[0] == '' || parts[1] == '' {
		return false
	}
	for byte in parts[0].bytes() {
		if !byte.is_alnum() && byte !in [`.`, `!`, `#`, `$`, `%`, `&`, `'`, `*`, `+`, `/`, `=`,
			`?`, `^`, `_`, `{`, `|`, `}`, `~`, `-`] && byte != 0x60 {
			return false
		}
	}
	for label in parts[1].split('.') {
		if label.len == 0 || label.len > 63 || !label[0].is_alnum() || !label[label.len - 1].is_alnum() {
			return false
		}
		for byte in label.bytes() {
			if !byte.is_alnum() && byte != `-` {
				return false
			}
		}
	}
	return true
}

pub fn (model &HTMLInputElementModel) has_reversed_range() bool {
	minimum := model.minimum() or { return false }
	maximum := model.maximum() or { return false }
	return model.type_state_ == .time && maximum < minimum
}

pub fn (model &HTMLInputElementModel) is_number_underflowing(number f64) bool {
	minimum := model.minimum() or { return false }
	if !model.has_reversed_range() {
		return number < minimum
	}
	maximum := model.maximum() or { return false }
	return number > maximum && number < minimum
}

pub fn (model &HTMLInputElementModel) is_number_overflowing(number f64) bool {
	maximum := model.maximum() or { return false }
	if !model.has_reversed_range() {
		return number > maximum
	}
	minimum := model.minimum() or { return false }
	return number > maximum && number < minimum
}

pub fn (model &HTMLInputElementModel) is_number_mismatching_step(number f64) bool {
	step := model.allowed_value_step() or { return false }
	ratio := (model.step_base() - number) / step
	return math.abs(ratio - math.round(ratio)) > 1e-7
}

pub fn (model &HTMLInputElementModel) suffering_from_being_missing() bool {
	return model.control.suffering_from_being_missing()
}

pub fn (model &HTMLInputElementModel) suffering_from_a_type_mismatch() bool {
	return model.control.suffering_from_a_type_mismatch()
}

pub fn (model &HTMLInputElementModel) suffering_from_a_pattern_mismatch() bool {
	if !model.pattern_applies() { return false }
	value := model.value()
	if value == '' { return false }
	mut expression := model.compiled_pattern_regular_expression() or { return false }
	defer { expression.destroy() }
	if input_element(model).has_attribute('multiple') && model.multiple_applies() {
		assert model.type_state_ == .email
		// AK::Utf16View::for_each_split_view(..., SplitBehavior::Nothing)
		// excludes empty views, preserving the pinned email-list behavior.
		for part in value.split(',') {
			if part == '' { continue }
			if expression.exec(libjs.utf16_string(part), 0) != .match_ { return true }
		}
		return false
	}
	return expression.exec(libjs.utf16_string(value), 0) != .match_
}

pub fn (model &HTMLInputElementModel) suffering_from_an_underflow() bool {
	return model.control.suffering_from_an_underflow()
}

pub fn (model &HTMLInputElementModel) suffering_from_an_overflow() bool {
	return model.control.suffering_from_an_overflow()
}

pub fn (model &HTMLInputElementModel) suffering_from_a_step_mismatch() bool {
	return model.control.suffering_from_a_step_mismatch()
}

pub fn (model &HTMLInputElementModel) suffering_from_bad_input() bool {
	return model.control.suffering_from_bad_input()
}

pub fn (mut model HTMLInputElementModel) computed_properties_changed() {
	model.create_shadow_tree_if_needed()
	model.update_shadow_tree()
}

pub fn (mut model HTMLInputElementModel) form_associated_element_was_inserted() {
	model.control.form_node_was_inserted()
	model.create_shadow_tree_if_needed()
	if input_element(&model).is_connected() && model.type_state_ == .radio_button && model.checked() {
		model.signal_a_type_change()
	}
}

pub fn (mut model HTMLInputElementModel) form_associated_element_attribute_changed(name string, old_value ?string, value ?string, namespace_ ?string) {
	if namespace_ != none {
		return
	}
	model.control.form_node_attribute_changed(name)
	match ascii_lowercase_string(name) {
		'checked' {
			mut input := unsafe { &dom.HTMLInputElement(model.element) }
			if !input.dirty_checkedness_ {
				model.set_checked(value != none)
				input.set_checkedness(model.checked(), false)
			}
		}
		'type' {
			new_state := parse_html_input_type(value or { '' })
			if new_state != model.type_state_ {
				model.type_attribute_changed(model.type_state_, new_state)
			}
			if model.type_state_ == .image_button {
				if src := input_element(&model).get_attribute('src') {
					if src != model.last_src_value_ {
						model.handle_src_attribute(src) or {}
					}
				}
			}
		}
		'value' {
			if !model.dirty_value_ {
				model.value_ = model.value_sanitization_algorithm(value or { '' })
				model.text_control.set_relevant_value(model.value_)
				model.update_shadow_tree()
				model.update_validity()
			}
		}
		'placeholder' {
			if text := model.placeholder_text_node_ {
				mut mutable_text := unsafe { text }
				mutable_text.set_data(model.placeholder())
				model.update_placeholder_visibility()
			}
		}
		'src' { model.handle_src_attribute(value or { '' }) or {} }
		'alt' {
			if model.type_state_ == .image_button {
				model.update_image_button_alt_text_shadow_tree()
			}
		}
		'maxlength' { model.handle_maxlength_attribute() }
		'multiple' {
			if model.type_state_ == .email && (old_value == none) != (value == none) {
				model.value_ = model.value_sanitization_algorithm(model.value_)
				model.text_control.set_relevant_value(model.value_)
			}
			model.update_shadow_tree()
			model.update_validity()
		}
		'min', 'max', 'step' {
			if model.type_state_ == .range {
				model.value_ = model.value_sanitization_algorithm(model.value_)
				model.text_control.set_relevant_value(model.value_)
				model.update_shadow_tree()
			}
			model.update_validity()
		}
		else {}
	}
}

pub fn (mut model HTMLInputElementModel) handle_return_key(_ string) ! {
	if model.control.form() != none {
		model.run_form_action(.implicit_submit)!
	} else {
		model.commit_pending_changes()
	}
}

// The cloning steps of the HTML elements whose state lives in their models.
fn html_element_cloning_steps(source &dom.Element, copy &dom.Node, subtree bool) ! {
	if source.local_name() == 'script' {
		copy_element := copy.as_element() or { return }
		if source.is_svg_element() && copy_element.is_svg_element() {
			model := svg_script_element_model_for_dom_element(unsafe { &dom.SVGScriptElement(source) })
			mut copy_model := svg_script_element_model_for_dom_element(unsafe { &dom.SVGScriptElement(copy_element) })
			copy_model.set_already_processed(model.already_processed())
		} else if source.is_html_element() && copy_element.is_html_element() {
			model := html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(source) })
			mut copy_model := html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(copy_element) })
			copy_model.set_already_started(model.has_already_started())
		}
		return
	}
	if !source.is_html_element() { return }

	if source.local_name() != 'input' {
		return
	}
	copy_element := copy.as_element() or { return }
	if !copy_element.is_html_element() || copy_element.local_name() != 'input' {
		return
	}
	// Only inputs with a model carry state beyond their attributes.
	source_input := unsafe { &dom.HTMLInputElement(source) }
	if source_input.input_element_model_ == unsafe { nil } && !source_input.indeterminate()
		&& !source_input.dirty_checkedness_ {
		return
	}
	model := HTMLInputElementModel.create(source_input)
	mut copy_model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(copy_element) })
	model.cloned(mut copy_model, subtree)
}

pub fn (model &HTMLInputElementModel) cloned(mut copy HTMLInputElementModel, _ bool) {
	copy.value_ = model.value_
	copy.dirty_value_ = model.dirty_value_
	copy.text_control.set_relevant_value(model.text_control.relevant_value())
	source_input := unsafe { &dom.HTMLInputElement(model.element) }
	mut copy_input := unsafe { &dom.HTMLInputElement(copy.element) }
	copy_input.set_checkedness(source_input.checked(), source_input.dirty_checkedness_)
	copy_input.set_indeterminate(source_input.indeterminate())
}

pub fn (mut model HTMLInputElementModel) update_validity() {
	element := input_element(&model)
	model.control.value_ = model.value()
	model.control.missing_ = false
	if model.type_state_ == .radio_button {
		mut group_has_checked := model.checked()
		mut group_has_required := element.has_attribute('required')
		for other in input_models_in_same_tree(&model) {
			if same_radio_group(&model, other) {
				group_has_checked = group_has_checked || other.checked()
				group_has_required = group_has_required || input_element(other).has_attribute('required')
			}
		}
		model.control.missing_ = group_has_required && !group_has_checked
	} else if element.has_attribute('required') && model.required_applies() {
		model.control.missing_ = match model.type_state_ {
			.checkbox { !model.checked() }
			.file_upload { (model.selected_files_ or { fileapi.FileList.create() }).length() == 0 }
			else { model.value() == '' }
		}
	}
	model.control.type_mismatch_ = false
	if model.value() != '' && model.type_state_ == .email {
		values := if element.has_attribute('multiple') {
			model.value().split(',')
		} else {
			[
				model.value(),
			]
		}
		model.control.type_mismatch_ = values.any(!valid_email_address(it.trim_space()))
	} else if model.value() != '' && model.type_state_ == .url {
		model.control.type_mismatch_ = !model.value().contains(':')
	}
	model.control.pattern_mismatch_ = model.suffering_from_a_pattern_mismatch()
	number := model.convert_string_to_number(model.value())
	model.control.underflow_ = false
	model.control.overflow_ = false
	model.control.step_mismatch_ = false
	if actual := number {
		model.control.underflow_ = model.is_number_underflowing(actual)
		model.control.overflow_ = model.is_number_overflowing(actual)
		model.control.step_mismatch_ = model.is_number_mismatching_step(actual)
	}
	max_length := limited_nonnegative_attribute(element, 'maxlength')
	min_length := limited_nonnegative_attribute(element, 'minlength')
	length := i32(form_string_to_utf16(model.value()).len)
	// https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#setting-maximum-input-length-requirements:-the-maxlength-attribute
	user_edited := model.dirty_value_ && model.value_last_changed_by_user_edit_
	model.control.too_long_ = user_edited && max_length >= 0 && length > max_length
	model.control.too_short_ = user_edited && model.value() != '' && min_length >= 0 && length < min_length
}

pub fn (mut model HTMLInputElementModel) commit_pending_changes() {
	if !model.has_uncommitted_changes_ {
		return
	}
	model.has_uncommitted_changes_ = false
	model.fire_event('change')
}

pub fn (mut model HTMLInputElementModel) reset() {
	model.user_validity_ = false
	model.dirty_value_ = false
	model.value_ = model.sanitize_value(input_element(&model).get_attribute_value('value'))
	mut input := unsafe { &dom.HTMLInputElement(model.element) }
	input.set_checkedness(input_element(&model).has_attribute('checked'), false)
	if model.selected_files_ != none {
		model.selected_files_ = fileapi.FileList.create()
	}
	model.text_control.set_relevant_value(model.value_)
	model.update_validity()
	model.update_shadow_tree()
}

pub fn (mut model HTMLInputElementModel) reset_algorithm() {
	model.reset()
}

pub fn (mut model HTMLInputElementModel) clear() {
	model.dirty_value_ = false
	model.value_ = model.sanitize_value('')
	mut input := unsafe { &dom.HTMLInputElement(model.element) }
	input.set_checkedness(input_element(&model).has_attribute('checked'), false)
	if model.selected_files_ != none {
		model.selected_files_ = fileapi.FileList.create()
	}
	model.text_control.set_relevant_value(model.value_)
	model.fire_event('input')
	model.update_validity()
	model.update_shadow_tree()
}

pub fn (mut model HTMLInputElementModel) clear_algorithm() {
	model.clear()
}
