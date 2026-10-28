// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Literal translation of the non-binding algorithms in
// LibWeb/HTML/HTMLTextAreaElement.cpp. CSS and Layout entry points live in
// those lower-level modules to preserve the V module dependency graph.
module html

import css
import dom

fn html_text_area_element_did_edit_callback(target voidptr, input_type string, data ?string) {
	mut model := unsafe { &HTMLTextAreaElementModel(target) }
	model.did_edit_text_node(input_type, data)
}

pub fn (mut model HTMLTextAreaElementModel) set_raw_value(value string) {
	old_raw_value := model.text.relevant_value()
	model.text.relevant_value_ = value
	mut control := model.control
	control.value_ = value
	if value != old_raw_value {
		model.text.relevant_value_was_changed()
	}
}

pub fn (model &HTMLTextAreaElementModel) api_value() string {
	return normalize_textarea_api_newlines(model.text.relevant_value())
}

pub fn (mut model HTMLTextAreaElementModel) set_dirty_value_flag(value bool) {
	model.dirty_value = value
	model.text.dirty_value_flag = value
}

pub fn (model &HTMLTextAreaElementModel) user_validity() bool {
	return model.user_validity
}

pub fn (mut model HTMLTextAreaElementModel) set_user_validity(value bool) {
	model.user_validity = value
}

pub fn (model &HTMLTextAreaElementModel) form_associated_element_to_text_node() ?&dom.Text {
	return model.text_node_
}

pub fn (model &HTMLTextAreaElementModel) text_control_scroll_container() &dom.Element {
	return textarea_element(model)
}

pub fn (model &HTMLTextAreaElementModel) placeholder_element() ?&dom.Element {
	return model.placeholder_element_
}

pub fn (model &HTMLTextAreaElementModel) is_html_textarea_element() bool {
	_ = model
	return true
}

pub fn (mut model HTMLTextAreaElementModel) set_relevant_value(value string) ! {
	model.set_value(value)
}

fn (mut model HTMLTextAreaElementModel) sync_text_node_to_raw_value() {
	if text_node := model.text_node_ {
		mut mutable_text_node := unsafe { text_node }
		mutable_text_node.set_data(model.text.relevant_value())
	}
}

pub fn (model &HTMLTextAreaElementModel) selection_start_binding() u32 {
	return model.text.selection_start_binding() or { 0 }
}

pub fn (mut model HTMLTextAreaElementModel) set_selection_start_binding(value u32) ! {
	model.text.set_selection_start_binding(value)!
}

pub fn (model &HTMLTextAreaElementModel) selection_end_binding() u32 {
	return model.text.selection_end_binding() or { 0 }
}

pub fn (mut model HTMLTextAreaElementModel) set_selection_end_binding(value u32) ! {
	model.text.set_selection_end_binding(value)!
}

pub fn (model &HTMLTextAreaElementModel) selection_direction_binding() string {
	return model.text.selection_direction() or { 'none' }
}

pub fn (mut model HTMLTextAreaElementModel) set_selection_direction_binding(direction string) {
	model.text.set_selection_direction_binding(direction) or {}
}

pub fn (mut model HTMLTextAreaElementModel) did_receive_focus() {
	if text_node := model.text_node_ {
		mut node := text_node.as_node()
		node.set_needs_repaint(.paint_commands)
	}
	if placeholder_text_node := model.placeholder_text_node_ {
		mut node := placeholder_text_node.as_node()
		node.set_needs_repaint(.paint_commands)
	}
	if selection := textarea_element(&model).document().get_selection() {
		mut mutable_selection := unsafe { selection }
		mutable_selection.remove_all_ranges()
	}
}

pub fn (mut model HTMLTextAreaElementModel) did_lose_focus() {
	if text_node := model.text_node_ {
		mut node := text_node.as_node()
		node.set_needs_repaint(.paint_commands)
	}
	if placeholder_text_node := model.placeholder_text_node_ {
		mut node := placeholder_text_node.as_node()
		node.set_needs_repaint(.paint_commands)
	}
	model_pointer := voidptr(&model)
	document := textarea_element(&model).document()
	queue_a_task(.user_interaction, main_thread_event_loop(), document, fn [model_pointer] () {
		mutable_model := unsafe { &HTMLTextAreaElementModel(model_pointer) }
		change_event := dom.Event.create('change', dom.EventInit{ bubbles: true })
		unsafe { &dom.EventTarget(textarea_element(mutable_model).as_node()) }
		.dispatch_event(change_event)
	})
}

pub fn (model &HTMLTextAreaElementModel) default_tab_index_value() i32 {
	return 0
}

pub fn (mut model HTMLTextAreaElementModel) reset_algorithm() {
	model.user_validity = false
	model.dirty_value = false
	model.text.dirty_value_flag = false
	model.set_raw_value(model.default_value())
	model.sync_text_node_to_raw_value()
	model.update_placeholder_visibility()
	model.update_validity()
}

pub fn (mut model HTMLTextAreaElementModel) clear_algorithm() {
	model.dirty_value = false
	model.text.dirty_value_flag = false
	model.set_raw_value('')
	model.sync_text_node_to_raw_value()
	model.update_placeholder_visibility()
	model.update_validity()
	model.dispatch_input_event('', none)
}

pub fn (model &HTMLTextAreaElementModel) cloned(mut copy HTMLTextAreaElementModel, _ bool) {
	copy.set_raw_value(model.text.relevant_value())
	copy.dirty_value = model.dirty_value
	copy.text.dirty_value_flag = model.text.dirty_value_flag
}

pub fn (mut model HTMLTextAreaElementModel) form_associated_element_was_inserted() {
	model.control.form_node_was_inserted()
	model.create_shadow_tree_if_needed()
}

pub fn (mut model HTMLTextAreaElementModel) create_shadow_tree_if_needed() {
	mut element := textarea_element(&model)
	if element.shadow_root() != none {
		return
	}
	shadow_root := element.attach_a_user_agent_shadow_root(.named)
	mut container := dom.create_element(element.document(), 'div', ns_html, none, none, false) or {
		return
	}
	container.set_attribute_value('style', 'display:flex;')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(container.as_node()) or { return }

	mut inner_text_element := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	inner_text_element.set_attribute_value('style', 'width:100%;')
	mut container_node := container.as_node()
	container_node.append_child(inner_text_element.as_node()) or { return }

	mut text_node := dom.Text.new(element.document(), model.text.relevant_value())
	mut inner_text_node := inner_text_element.as_node()
	inner_text_node.append_child(text_node.as_node()) or { return }

	mut placeholder_element := dom.create_element(element.document(), 'div', ns_html, none, none, false) or { return }
	container_node.append_child(placeholder_element.as_node()) or { return }
	placeholder_element.set_associated_shadow_host_pseudo_element(int(css.PseudoElement.placeholder))

	mut placeholder_text_node := dom.Text.new(element.document(), element.get_attribute_value('placeholder'))
	mut placeholder_node := placeholder_element.as_node()
	placeholder_node.append_child(placeholder_text_node.as_node()) or { return }

	model.inner_text_element_ = inner_text_element
	model.text_node_ = text_node
	model.text.text_node_ = text_node
	model.placeholder_element_ = placeholder_element
	model.placeholder_text_node_ = placeholder_text_node
	model.handle_maxlength_attribute()
	model.update_placeholder_visibility()
}

pub fn (mut model HTMLTextAreaElementModel) handle_maxlength_attribute() {
	mut text_node := model.text_node_ or { return }
	max_length := model.max_length()
	if max_length >= 0 {
		text_node.set_max_length(int(max_length))
	} else {
		text_node.set_max_length(none)
	}
	model.update_validity()
}

fn textarea_placeholder_style_when_visible() string {
	return 'width:100%;overflow:hidden;margin-inline-start:-100%;pointer-events:none;user-select:none;'
}

fn textarea_placeholder_style_when_hidden() string {
	return 'display:none;'
}

pub fn (mut model HTMLTextAreaElementModel) update_placeholder_visibility() {
	mut placeholder_element := model.placeholder_element_ or { return }
	text_node := model.text_node_ or { return }
	if textarea_element(&model).has_attribute('placeholder') && text_node.data() == '' {
		placeholder_element.set_attribute_value('style', textarea_placeholder_style_when_visible())
	} else {
		placeholder_element.set_attribute_value('style', textarea_placeholder_style_when_hidden())
	}
}

pub fn (mut model HTMLTextAreaElementModel) children_changed(metadata dom.ChildrenChangedMetadata) {
	mut element := textarea_element(&model)
	element.children_changed(metadata)
	if !model.dirty_value {
		model.set_raw_value(model.default_value())
		model.sync_text_node_to_raw_value()
		model.update_placeholder_visibility()
		model.update_validity()
	}
}

pub fn (mut model HTMLTextAreaElementModel) form_associated_element_attribute_changed(name string, _ ?string, value ?string, namespace_ ?string) {
	if namespace_ != none {
		return
	}
	model.control.form_node_attribute_changed(name)
	if name == 'placeholder' {
		if placeholder_text_node := model.placeholder_text_node_ {
			mut mutable_placeholder_text_node := unsafe { placeholder_text_node }
			mutable_placeholder_text_node.set_data(value or { '' })
		}
		model.update_placeholder_visibility()
	} else if name == 'maxlength' {
		model.handle_maxlength_attribute()
	}
}

pub fn (mut model HTMLTextAreaElementModel) did_edit_text_node(input_type string, data ?string) {
	text_node := model.text_node_ or { return }
	model.set_raw_value(text_node.data())
	model.dispatch_input_event(input_type, data)
	model.dirty_value = true
	model.text.dirty_value_flag = true
	model.user_validity = true
	model.update_placeholder_visibility()
	model.update_validity()
}

pub fn (mut model HTMLTextAreaElementModel) handle_return_key(input_type string) ! {
	model.text.handle_insert(input_type, '\n')!
}

fn (mut model HTMLTextAreaElementModel) dispatch_input_event(input_type string, data ?string) {
	document := textarea_element(&model).document()
	input_event := dom.InputEvent.create_from_platform_event('input', dom.InputEventInit{
		data:         data
		input_type:   input_type
		is_composing: document.is_input_method_composing()
	}, [], dom.current_event_timestamp())
	base_event := unsafe { &dom.Event(input_event) }
	unsafe { &dom.EventTarget(textarea_element(&model).as_node()) }.dispatch_event(base_event)
}

// HTMLTextAreaElement::is_focusable(), which DOM's Element::is_focusable() dispatch translates.
pub fn (model &HTMLTextAreaElementModel) is_focusable() bool {
	return unsafe { &dom.Element(model.element) }.is_focusable()
}

pub fn (model &HTMLTextAreaElementModel) suffering_from_being_missing() bool {
	return textarea_element(model).has_attribute('required') && model.is_mutable() && model.value() == ''
}

pub fn (model &HTMLTextAreaElementModel) is_mutable() bool {
	return model.control.enabled() && !textarea_element(model).has_attribute('readonly')
}
