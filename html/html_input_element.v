// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLInputElement.{h,cpp}. Platform pickers and image painting
// remain host boundaries; type/value modes, sanitization, numeric/date stepping,
// checked/radio behavior, selected files, applicability predicates, validation,
// selection, reset/clear, and input/change events are implemented here.
@[has_globals]
module html

import dom
import math

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

@[heap]
pub struct HTMLInputElementModel {
pub:
	element &dom.HTMLInputElement
pub mut:
	control                  &FormAssociatedElement
	text_control             &FormAssociatedTextControlElement
	type_state_              HTMLInputTypeState
	value_                   string
	dirty_value_             bool
	checked_                 bool
	dirty_checkedness_       bool
	indeterminate_           bool
	user_validity_           bool
	has_uncommitted_changes_ bool
	selected_files_          []SelectedFile
	event_target_            &dom.EventTarget = unsafe { nil }
	event_counts_            map[string]int
	selected_x_              int
	selected_y_              int
	is_open_                 bool
}

__global html_input_models []&HTMLInputElementModel

fn input_element(model &HTMLInputElementModel) &dom.Element {
	return unsafe { &dom.Element(model.element) }
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
	dom_element := unsafe { &dom.Element(element) }
	control := FormAssociatedElement.create(dom_element)
	type_state := parse_html_input_type(dom_element.get_attribute_value('type'))
	mut model := &HTMLInputElementModel{
		element:       element
		control:       control
		text_control:  FormAssociatedTextControlElement.create(control, '')
		type_state_:   type_state
		checked_:      dom_element.has_attribute('checked')
		event_target_: dom.EventTarget.new()
	}
	model.value_ = model.sanitize_value(dom_element.get_attribute_value('value'))
	model.text_control.set_relevant_value(model.value_)
	model.update_validity()
	html_input_models << model
	return model
}

fn (mut model HTMLInputElementModel) fire_event(name string) {
	model.event_counts_[name]++
	model.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{ bubbles: true }))
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

pub fn (mut model HTMLInputElementModel) set_type(value string) {
	old_state := model.type_state_
	mut element := input_element(&model)
	element.set_attribute_value('type', value)
	model.type_state_ = parse_html_input_type(value)
	if old_state != model.type_state_ {
		model.value_ = model.sanitize_value(model.value_)
		model.text_control.set_relevant_value(model.value_)
		if !model.checked_applies() {
			model.indeterminate_ = false
		}
		if model.type_state_ != .file_upload {
			model.selected_files_.clear()
		}
		model.update_validity()
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
		if !((byte >= `0` && byte <= `9`) || (byte >= `a` && byte <= `f`)
			|| (byte >= `A` && byte <= `F`)) {
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
				if number < minimum { number = minimum }
				if maximum >= minimum && number > maximum { number = maximum }
			}
			return number.str()
		}
		.color {
			return if valid_simple_color(value) { ascii_lowercase_string(value) } else { '#000000' }
		}
		else {
			return value
		}
	}
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
			if model.selected_files_.len == 0 {
				''
			} else {
				'C:\\fakepath\\${model.selected_files_[0].name}'
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
	if model.type_state_ in [.checkbox, .radio_button] {
		return input_element(model).get_attribute('value')
	}
	return model.value()
}

pub fn (mut model HTMLInputElementModel) set_value(value string) ! {
	if model.type_state_ == .file_upload {
		if value != '' {
			return error('InvalidStateError: file input value can only be set to the empty string')
		}
		model.selected_files_.clear()
		return
	}
	if model.type_state_ in [.checkbox, .radio_button, .submit_button, .image_button, .reset_button,
		.button, .hidden] {
		mut element := input_element(&model)
		element.set_attribute_value('value', value)
		return
	}
	old := model.value_
	model.value_ = model.sanitize_value(value)
	model.dirty_value_ = true
	model.text_control.dirty_value_flag = true
	model.text_control.set_relevant_value(model.value_)
	if old != model.value_ && model.selection_or_range_applies() {
		length := u32(form_string_to_utf16(model.value_).len)
		model.text_control.set_the_selection_range(length, length, .none, .dom)
	}
	model.update_validity()
}

pub fn (model &HTMLInputElementModel) checked() bool {
	return model.checked_
}

fn same_radio_group(a &HTMLInputElementModel, b &HTMLInputElementModel) bool {
	if a == b || a.type_state_ != .radio_button || b.type_state_ != .radio_button {
		return false
	}
	a_element := input_element(a)
	b_element := input_element(b)
	return a_element.as_node().root() == b_element.as_node().root()
		&& a_element.get_attribute_value('name') == b_element.get_attribute_value('name')
		&& a_element.get_attribute_value('name') != ''
}

pub fn (mut model HTMLInputElementModel) set_checked(value bool) {
	model.checked_ = value
	model.dirty_checkedness_ = true
	if value && model.type_state_ == .radio_button {
		for mut other in html_input_models {
			if same_radio_group(&model, other) {
				other.checked_ = false
			}
		}
	}
	model.update_validity()
}

pub fn (mut model HTMLInputElementModel) set_indeterminate(value bool) {
	model.indeterminate_ = value
}

pub fn (model &HTMLInputElementModel) indeterminate() bool {
	return model.indeterminate_
}

pub fn (mut model HTMLInputElementModel) activate() {
	if !model.is_mutable() && model.type_state_ !in [.checkbox, .radio_button] {
		return
	}
	match model.type_state_ {
		.checkbox {
			model.set_checked(!model.checked_)
			model.indeterminate_ = false
			model.fire_event('input')
			model.fire_event('change')
		}
		.radio_button {
			if !model.checked_ {
				model.set_checked(true)
				model.fire_event('input')
				model.fire_event('change')
			}
		}
		else {}
	}
}

pub fn (mut model HTMLInputElementModel) did_select_files(files []SelectedFile, handling MultipleFileHandling) {
	if model.type_state_ != .file_upload {
		return
	}
	if handling == .replace || !input_element(&model).has_attribute('multiple') {
		model.selected_files_ = files.clone()
	} else {
		model.selected_files_ << files
	}
	model.fire_event('input')
	model.fire_event('change')
	model.update_validity()
}

pub fn (model &HTMLInputElementModel) files() ?[]SelectedFile {
	if model.type_state_ != .file_upload {
		return none
	}
	return model.selected_files_.clone()
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

fn (model &HTMLInputElementModel) convert_string_to_number(value string) ?f64 {
	match model.type_state_ {
		.number, .range {
			return parse_floating_point_number(value)
		}
		.month {
			month := parse_a_month_string(value) or { return none }
			return f64(number_of_months_since_unix_epoch(month))
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
			days := days_from_civil(i64(value_.date.year), i64(value_.date.month),
				i64(value_.date.day))
			return f64(days) * 86400000.0 + f64(value_.time.hour * 3600000 +
				value_.time.minute * 60000) + f64(value_.time.second) * 1000
		}
		else {
			return none
		}
	}
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

fn numeric_input_string(model &HTMLInputElementModel, value f64) string {
	match model.type_state_ {
		.number, .range {
			return value.str()
		}
		.month {
			months := i64(math.floor(value))
			year := 1970 + months / 12
			month := months % 12 + 1
			return '${year:04d}-${month:02d}'
		}
		.time {
			milliseconds := i64(math.floor(value))
			hour := (milliseconds / 3600000) % 24
			minute := (milliseconds / 60000) % 60
			second := (milliseconds / 1000) % 60
			millisecond := milliseconds % 1000
			if millisecond != 0 {
				return '${hour:02d}:${minute:02d}:${second:02d}.${millisecond:03d}'
			}
			if second != 0 { return '${hour:02d}:${minute:02d}:${second:02d}' }
			return '${hour:02d}:${minute:02d}'
		}
		.date {
			year, month, day := civil_from_days(i64(math.floor(value / 86400000.0)))
			return '${year:04d}-${month:02d}-${day:02d}'
		}
		.local_date_and_time {
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
		if number := model.convert_string_to_number(value) { return number }
	}
	if model.type_state_ == .range { return 0.0 }
	return none
}

pub fn (model &HTMLInputElementModel) maximum() ?f64 {
	if value := input_element(model).get_attribute('max') {
		if number := model.convert_string_to_number(value) { return number }
	}
	if model.type_state_ == .range { return 100.0 }
	return none
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
	if !model.step_applies() { return none }
	value := input_element(model).get_attribute('step') or {
		return model.default_step() * model.step_scale_factor()
	}
	if ascii_lowercase_string(value) == 'any' { return none }
	parsed := parse_floating_point_number(value) or {
		return model.default_step() * model.step_scale_factor()
	}
	if parsed <= 0 { return model.default_step() * model.step_scale_factor() }
	return parsed * model.step_scale_factor()
}

pub fn (model &HTMLInputElementModel) step_base() f64 {
	if minimum := model.minimum() { return minimum }
	if value := input_element(model).get_attribute('value') {
		if number := model.convert_string_to_number(value) { return number }
	}
	if model.type_state_ == .week { return -259200000.0 }
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
			if min > max { return }
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
		if value < min { value = base + math.ceil((min - base) / step) * step }
	}
	if max := maximum {
		if value > max { value = base + math.floor((max - base) / step) * step }
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
	return model.type_state_ in [.text, .search, .telephone, .url, .password]
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

pub fn (model &HTMLInputElementModel) value_as_number_applies() bool {
	return model.type_state_ in [.date, .month, .time, .local_date_and_time, .number, .range]
}

pub fn (model &HTMLInputElementModel) step_applies() bool {
	return model.value_as_number_applies()
}

pub fn (model &HTMLInputElementModel) step_up_or_down_applies() bool {
	return model.value_as_number_applies()
}

pub fn (model &HTMLInputElementModel) is_button() bool {
	return model.type_state_ in [.submit_button, .image_button, .reset_button, .button]
}

pub fn (model &HTMLInputElementModel) is_submit_button() bool {
	return model.type_state_ in [.submit_button, .image_button]
}

pub fn (model &HTMLInputElementModel) is_single_line() bool {
	return model.type_state_ in [.text, .search, .password, .email, .telephone, .number]
}

pub fn (model &HTMLInputElementModel) is_mutable() bool {
	return !input_element(model).is_actually_disabled()
		&& (!input_element(model).has_attribute('readonly') || !model.is_allowed_to_be_readonly())
}

pub fn (model &HTMLInputElementModel) is_allowed_to_be_readonly() bool {
	return model.type_state_ in [.text, .search, .telephone, .url, .email, .password, .date, .month,
		.week, .time, .local_date_and_time, .number]
}

fn valid_email_address(value string) bool {
	parts := value.split('@')
	return parts.len == 2 && parts[0] != '' && parts[1].contains('.') && !value.contains(' ')
}

pub fn (mut model HTMLInputElementModel) update_validity() {
	element := input_element(&model)
	model.control.value_ = model.value()
	model.control.missing_ = false
	if element.has_attribute('required') && model.required_applies() {
		model.control.missing_ = match model.type_state_ {
			.checkbox, .radio_button { !model.checked_ }
			.file_upload { model.selected_files_.len == 0 }
			else { model.value() == '' }
		}
	}
	model.control.type_mismatch_ = false
	if model.value() != '' && model.type_state_ == .email {
		values := if element.has_attribute('multiple') { model.value().split(',') } else { [
				model.value(),
			] }
		model.control.type_mismatch_ = values.any(!valid_email_address(it.trim_space()))
	} else if model.value() != '' && model.type_state_ == .url {
		model.control.type_mismatch_ = !model.value().contains(':')
	}
	number := model.convert_string_to_number(model.value())
	model.control.underflow_ = false
	model.control.overflow_ = false
	model.control.step_mismatch_ = false
	if actual := number {
		if min := model.minimum() { model.control.underflow_ = actual < min }
		if max := model.maximum() { model.control.overflow_ = actual > max }
		if step := model.allowed_value_step() {
			ratio := (actual - model.step_base()) / step
			model.control.step_mismatch_ = math.abs(ratio - math.round(ratio)) > 1e-7
		}
	}
	max_length := limited_nonnegative_attribute(element, 'maxlength')
	min_length := limited_nonnegative_attribute(element, 'minlength')
	length := i32(form_string_to_utf16(model.value()).len)
	model.control.too_long_ = model.dirty_value_ && max_length >= 0 && length > max_length
	model.control.too_short_ = model.dirty_value_ && model.value() != '' && min_length >= 0
		&& length < min_length
}

pub fn (mut model HTMLInputElementModel) commit_pending_changes() {
	if !model.has_uncommitted_changes_ { return }
	model.has_uncommitted_changes_ = false
	model.fire_event('change')
}

pub fn (mut model HTMLInputElementModel) reset() {
	model.user_validity_ = false
	model.dirty_value_ = false
	model.dirty_checkedness_ = false
	model.value_ = model.sanitize_value(input_element(&model).get_attribute_value('value'))
	model.checked_ = input_element(&model).has_attribute('checked')
	model.selected_files_.clear()
	model.text_control.set_relevant_value(model.value_)
	model.update_validity()
}

pub fn (mut model HTMLInputElementModel) clear() {
	model.dirty_value_ = false
	model.dirty_checkedness_ = false
	model.value_ = model.sanitize_value('')
	model.checked_ = input_element(&model).has_attribute('checked')
	model.selected_files_.clear()
	model.text_control.set_relevant_value(model.value_)
	model.fire_event('input')
	model.update_validity()
}
