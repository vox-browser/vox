// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLSelectElement.cpp and HTMLOptionsCollection.cpp. Native
// dropdown presentation terminates at a typed hook; its item/state algorithms
// remain here.
module html

import aria
import css
import dom
import infra

pub type SelectPickerHook = fn ([]SelectItem)

@[heap]
pub struct HTMLOptionsCollection {
pub:
	select_element &dom.HTMLSelectElement
}

pub fn HTMLOptionsCollection.create(select_element &dom.HTMLSelectElement) &HTMLOptionsCollection {
	return &HTMLOptionsCollection{ select_element: select_element }
}

pub fn (collection &HTMLOptionsCollection) length() u32 {
	return html_select_element_length(collection.select_element)
}

pub fn (collection &HTMLOptionsCollection) item(index u32) ?&dom.HTMLOptionElement {
	return html_select_element_item(collection.select_element, index)
}

pub fn (collection &HTMLOptionsCollection) item_value(index uint) ?&dom.HTMLOptionElement {
	if index > uint(0xffff_ffff) {
		return none
	}
	return collection.item(u32(index))
}

pub fn (collection &HTMLOptionsCollection) named_item(name string) ?&dom.HTMLOptionElement {
	return html_select_element_named_item(collection.select_element, name)
}

pub fn (collection &HTMLOptionsCollection) set_length(value u32) ! {
	set_html_select_element_length(collection.select_element, value)!
}

pub fn (collection &HTMLOptionsCollection) set_value_of_indexed_property(index u32, option ?&dom.HTMLOptionElement) ! {
	set_html_select_element_indexed_option(collection.select_element, index, option)!
}

pub fn (collection &HTMLOptionsCollection) add(element &dom.HTMLElement, before_element ?&dom.HTMLElement, before_index ?i32) ! {
	html_select_element_add_option(collection.select_element, element, before_element, before_index)!
}

pub fn (collection &HTMLOptionsCollection) remove(index i32) {
	html_select_element_remove_option(collection.select_element, index)
}

pub fn (collection &HTMLOptionsCollection) selected_index() i32 {
	return html_select_element_selected_index(collection.select_element)
}

pub fn (collection &HTMLOptionsCollection) set_selected_index(index i32) {
	set_html_select_element_selected_index(collection.select_element, index)
}

@[heap]
pub struct HTMLSelectElementModel {
pub:
	element &dom.HTMLSelectElement
	control &FormAssociatedElement
pub mut:
	cached_list_of_options_           []&dom.HTMLOptionElement
	cached_number_of_selected_options u32
	inner_text_element_               ?&dom.Element
	chevron_icon_element_             ?&dom.Element
	select_items_                     []SelectItem
	is_open_                          bool
	user_validity_                    bool
	picker_hook_                      ?SelectPickerHook
mut:
	options_ ?&HTMLOptionsCollection
}

pub fn HTMLSelectElementModel.create(element &dom.HTMLSelectElement) &HTMLSelectElementModel {
	if element.select_element_model_ != unsafe { nil } {
		return unsafe { &HTMLSelectElementModel(element.select_element_model_) }
	}
	model := &HTMLSelectElementModel{
		element: element
		control: FormAssociatedElement.create(select_dom_element(element))
	}
	mut mutable_element := unsafe { &dom.HTMLSelectElement(element) }
	mutable_element.select_element_model_ = voidptr(model)
	return model
}

pub fn (mut model HTMLSelectElementModel) set_picker_hook(hook ?SelectPickerHook) {
	model.picker_hook_ = hook
}

pub fn (mut model HTMLSelectElementModel) options() &HTMLOptionsCollection {
	if collection := model.options_ {
		return collection
	}
	collection := HTMLOptionsCollection.create(model.element)
	model.options_ = collection
	return collection
}

pub fn (mut model HTMLSelectElementModel) item_value(index uint) ?&dom.HTMLOptionElement {
	return model.options().item_value(index)
}

pub fn (mut model HTMLSelectElementModel) add(element &dom.HTMLElement, before_element ?&dom.HTMLElement, before_index ?i32) ! {
	model.options().add(element, before_element, before_index)!
	model.update_cached_list_of_options()
	html_select_element_update_selectedness(model.element)
}

pub fn (mut model HTMLSelectElementModel) set_value_of_indexed_property(index u32, option ?&dom.HTMLOptionElement) ! {
	model.options().set_value_of_indexed_property(index, option)!
	model.update_cached_list_of_options()
}

// The C++ overloads are represented by an optional index. `none` invokes the
// ChildNode overload and an index invokes HTMLOptionsCollection.remove().
pub fn (mut model HTMLSelectElementModel) remove(index ?i32) {
	if option_index := index {
		model.options().remove(option_index)
	} else {
		remove_table_node(select_node(model.element))
	}
	model.update_cached_list_of_options()
}

pub fn (mut model HTMLSelectElementModel) update_cached_list_of_options() {
	model.cached_list_of_options_ = html_select_element_list_of_options(model.element)
	mut selected_count := u32(0)
	for option in model.cached_list_of_options_ {
		if html_option_element_selected(option) {
			selected_count++
		}
	}
	model.cached_number_of_selected_options = selected_count
}

pub fn (mut model HTMLSelectElementModel) reset_algorithm() {
	model.user_validity_ = false
	html_select_element_reset(model.element)
	model.update_cached_list_of_options()
	model.clone_selected_option_into_select_button()
}

pub fn (model &HTMLSelectElementModel) is_html_select_element() bool {
	_ = model
	return true
}

pub fn (model &HTMLSelectElementModel) is_listed() bool {
	return true
}

pub fn (model &HTMLSelectElementModel) is_submittable() bool {
	return true
}

pub fn (model &HTMLSelectElementModel) is_resettable() bool {
	return true
}

pub fn (model &HTMLSelectElementModel) is_autocapitalize_and_autocorrect_inheriting() bool {
	return true
}

pub fn (model &HTMLSelectElementModel) is_labelable() bool {
	return true
}

pub fn (model &HTMLSelectElementModel) user_validity() bool {
	return model.user_validity_
}

pub fn (mut model HTMLSelectElementModel) set_user_validity(value bool) {
	model.user_validity_ = value
}

pub fn (model &HTMLSelectElementModel) default_tab_index_value() i32 {
	return 0
}

pub fn (mut model HTMLSelectElementModel) can_skip_selectedness_update_for_inserted_option(option &dom.HTMLOptionElement) bool {
	model.update_cached_list_of_options()
	if html_option_element_selected(option) || model.cached_number_of_selected_options >= 2 {
		return false
	}
	if html_select_element_display_size(model.element) == 1 && model.cached_number_of_selected_options == 0 {
		return false
	}
	return true
}

pub fn (mut model HTMLSelectElementModel) can_skip_children_changed_selectedness_update(metadata dom.ChildrenChangedMetadata) bool {
	if metadata.type_ != .inserted || metadata.node == unsafe { nil } {
		return false
	}
	element := metadata.node.as_element() or { return false }
	if element.local_name() != 'option' {
		return false
	}
	return model.can_skip_selectedness_update_for_inserted_option(unsafe {
		&dom.HTMLOptionElement(element)
	})
}

pub fn (mut model HTMLSelectElementModel) children_changed(metadata dom.ChildrenChangedMetadata) {
	if model.can_skip_children_changed_selectedness_update(metadata) {
		return
	}
	model.update_cached_list_of_options()
	html_select_element_update_selectedness(model.element)
	model.clone_selected_option_into_select_button()
}

pub fn html_select_element_default_role(select_element &dom.HTMLSelectElement) aria.Role {
	element := select_dom_element(select_element)
	if element.has_attribute('multiple') {
		return .listbox
	}
	if value := element.get_attribute('size') {
		if value.int() > 1 {
			return .listbox
		}
	}
	return .combobox
}

pub fn (model &HTMLSelectElementModel) default_role() aria.Role {
	return html_select_element_default_role(model.element)
}

pub fn (mut model HTMLSelectElementModel) send_select_update_notifications() {
	model_pointer := voidptr(&model)
	document := select_dom_element(model.element).document()
	queue_a_task(.user_interaction, main_thread_event_loop(), document, fn [model_pointer] () {
		mut mutable_model := unsafe { &HTMLSelectElementModel(model_pointer) }
		mutable_model.user_validity_ = true
		html_select_element_update_selectedcontent(mutable_model.element) or {}
		mutable_model.clone_selected_option_into_select_button()
		mut input_event := dom.Event.create('input', dom.EventInit{ bubbles: true })
		input_event.set_composed(true)
		unsafe { &dom.EventTarget(select_node(mutable_model.element)) }
		.dispatch_event(input_event)
		change_event := dom.Event.create('change', dom.EventInit{ bubbles: true })
		unsafe { &dom.EventTarget(select_node(mutable_model.element)) }
		.dispatch_event(change_event)
	})
}

pub fn (mut model HTMLSelectElementModel) set_is_open(open bool) {
	if model.is_open_ == open {
		return
	}
	model.is_open_ = open
	mut element := unsafe { &dom.HTMLSelectElement(model.element) }
	element.set_is_open(open)
}

pub fn (model &HTMLSelectElementModel) is_open() bool {
	return unsafe { &dom.HTMLSelectElement(model.element) }.is_open()
}

pub fn (model &HTMLSelectElementModel) has_activation_behavior() bool {
	return true
}

fn html_select_element_visible_picker_items(select_element &dom.HTMLSelectElement) []SelectItem {
	mut items := []SelectItem{}
	mut id_counter := u32(1)
	for child in select_node(select_element).children_as_vector() {
		element := child.as_element() or { continue }
		if element.has_attribute('hidden') {
			continue
		}
		if element.local_name() == 'optgroup' {
			mut group_options := []SelectItemOption{}
			for group_child in child.children_as_vector() {
				option_element := group_child.as_element() or { continue }
				if option_element.local_name() != 'option' || option_element.has_attribute('hidden') {
					continue
				}
				option := unsafe { &dom.HTMLOptionElement(option_element) }
				group_options << SelectItemOption{
					id: id_counter
					selected: html_option_element_selected(option)
					disabled: html_option_element_disabled(option)
					option_element: option
					label: infra.strip_and_collapse_whitespace(html_option_element_label(option))
					value: html_option_element_value(option)
				}
				id_counter++
			}
			items << SelectItemOptionGroup{
				label: element.get_attribute('label') or { '' }
				items: group_options
			}
		} else if element.local_name() == 'option' {
			option := unsafe { &dom.HTMLOptionElement(element) }
			items << SelectItemOption{
				id: id_counter
				selected: html_option_element_selected(option)
				disabled: html_option_element_disabled(option)
				option_element: option
				label: infra.strip_and_collapse_whitespace(html_option_element_label(option))
				value: html_option_element_value(option)
			}
			id_counter++
		} else if element.local_name() == 'hr' {
			items << SelectItemSeparator{}
		}
	}
	return items
}

pub fn (mut model HTMLSelectElementModel) show_the_picker_if_applicable() {
	window := picker_relevant_window(select_dom_element(model.element)) or {
		panic('Source select picker requires a Window global')
	}
	if !window.has_transient_activation() || !model.is_mutable() {
		return
	}
	window.consume_user_activation()
	model.select_items_ = html_select_element_visible_picker_items(model.element)
	if hook := model.picker_hook_ {
		hook(model.select_items_.clone())
	}
	model.set_is_open(true)
}

pub fn (mut model HTMLSelectElementModel) show_picker() ! {
	if !model.is_mutable() {
		return error('InvalidStateError: element is not mutable')
	}
	element := select_dom_element(model.element)
	if !picker_origin_is_same_as_top_level(element) {
		return error('SecurityError: cross-origin pickers are not allowed')
	}
	window := picker_relevant_window(element) or {
		return error('NotAllowedError: too long since user activation to show picker')
	}
	if !window.has_transient_activation() {
		return error('NotAllowedError: too long since user activation to show picker')
	}
	if !element.meets_focusable_area_rendering_requirements() {
		return error('NotSupportedError: element is not being rendered')
	}
	model.show_the_picker_if_applicable()
}

pub fn (mut model HTMLSelectElementModel) activation_behavior(event &dom.Event) {
	if event.is_trusted() {
		model.show_the_picker_if_applicable()
	}
}

pub fn (mut model HTMLSelectElementModel) did_select_item(id ?u32) {
	model.set_is_open(false)
	selected_id := id or { return }
	model.update_cached_list_of_options()
	for option in model.cached_list_of_options_ {
		html_option_element_set_selected(option, false)
	}
	for item in model.select_items_ {
		match item {
			SelectItemOption {
				if item.id == selected_id {
					if option := item.option_element {
						html_option_element_set_selected(option, true)
					}
				}
			}
			SelectItemOptionGroup {
				for group_option in item.items {
					if group_option.id == selected_id {
						if option := group_option.option_element {
							html_option_element_set_selected(option, true)
						}
					}
				}
			}
			SelectItemSeparator {}
		}
	}
	model.clone_selected_option_into_select_button()
	model.send_select_update_notifications()
}

pub fn (mut model HTMLSelectElementModel) form_associated_element_was_inserted() {
	model.create_shadow_tree_if_needed()
}

pub fn (mut model HTMLSelectElementModel) form_associated_element_attribute_changed(name string, value ?string) {
	if name == 'multiple' && value == none {
		html_select_element_update_selectedness(model.element)
		model.clone_selected_option_into_select_button()
	}
}

pub fn (mut model HTMLSelectElementModel) computed_properties_changed(appearance_is_none bool) {
	chromium_theme := !appearance_is_none
		&& html_select_element_uses_chromium_menu_list(select_dom_element(model.element))
	if chevron := model.chevron_icon_element_ {
		mut element := unsafe { &dom.Element(chevron) }
		style := if appearance_is_none || chromium_theme {
			'display:none;position:absolute;inset-inline-end:0;top:calc(50% - 8px);width:16px;height:16px;'
		} else {
			'display:block;position:absolute;inset-inline-end:0;top:calc(50% - 8px);width:16px;height:16px;'
		}
		if element.get_attribute_value('style') != style { element.set_attribute_value('style', style) }
	}
	if inner_text := model.inner_text_element_ {
		mut element := unsafe { &dom.Element(inner_text) }
		style := if chromium_theme {
			chromium_select_label_style()
		} else if appearance_is_none {
			'flex:1;min-width:0;overflow:clip;text-overflow:inherit;margin-inline-end:0;'
		} else {
			'flex:1;min-width:0;overflow:clip;text-overflow:inherit;margin-inline-end:20px;'
		}
		if element.get_attribute_value('style') != style { element.set_attribute_value('style', style) }
	}
}

pub fn (mut model HTMLSelectElementModel) create_shadow_tree_if_needed() {
	mut element := unsafe { &dom.Element(select_dom_element(model.element)) }
	if element.shadow_root() != none {
		return
	}
	appearance_is_none := if style := css.computed_properties_for_element(element) {
		style.appearance() == .none_
	} else {
		false
	}
	shadow := element.attach_a_user_agent_shadow_root(.named)
	mut border := dom.create_element(element.document(), 'div', ns_html, none, none, false) or {
		return
	}
	border.set_attribute_value('style', 'display:flex;align-items:center;height:100%;position:relative;')
	mut inner_text := dom.create_element(element.document(), 'div', ns_html, none, none, false) or {
		return
	}
	inner_text.set_attribute_value('style', 'flex:1;min-width:0;overflow:clip;text-overflow:inherit;margin-inline-end:20px;')
	mut chevron := dom.create_element(element.document(), 'div', ns_html, none, none, false) or {
		return
	}
	chevron.set_attribute_value('style', 'position:absolute;inset-inline-end:0;top:calc(50% - 8px);width:16px;height:16px;')
	mut svg := dom.create_element(element.document(), 'svg', ns_svg, none, none, false) or {
		return
	}
	svg.set_attribute_value('xmlns', ns_svg)
	svg.set_attribute_value('viewBox', '0 0 24 24')
	mut path := dom.create_element(element.document(), 'path', ns_svg, none, none, false) or {
		return
	}
	path.set_attribute_value('fill', 'currentcolor')
	path.set_attribute_value('d', 'M7.41,8.58L12,13.17L16.59,8.58L18,10L12,16L6,10L7.41,8.58Z')
	mut svg_node := svg.as_node()
	svg_node.append_child(path.as_node()) or { return }
	mut chevron_node := chevron.as_node()
	chevron_node.append_child(svg.as_node()) or { return }
	mut border_node := border.as_node()
	border_node.append_child(inner_text.as_node()) or { return }
	border_node.append_child(chevron.as_node()) or { return }
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_node.append_child(border.as_node()) or { return }
	model.inner_text_element_ = inner_text
	model.chevron_icon_element_ = chevron
	model.computed_properties_changed(appearance_is_none)
	model.clone_selected_option_into_select_button()
}

// https://html.spec.whatwg.org/multipage/form-elements.html#clone-selected-option-into-select-button
pub fn (mut model HTMLSelectElementModel) clone_selected_option_into_select_button() {
	inner := model.inner_text_element_ or { return }
	model.update_cached_list_of_options()
	mut text := ''
	for option in model.cached_list_of_options_ {
		if html_option_element_selected(option) {
			text = html_option_element_label(option)
			break
		}
	}
	mut inner_node := inner.as_node()
	inner_node.string_replace_all(text)
}

// Compatibility entry point for callers translated before the algorithm was
// named in the HTML specification.
pub fn (mut model HTMLSelectElementModel) update_inner_text_element() {
	model.clone_selected_option_into_select_button()
}

// HTMLSelectElement::is_focusable(), which DOM's Element::is_focusable() dispatch translates.
pub fn (model &HTMLSelectElementModel) is_focusable() bool {
	return select_dom_element(model.element).is_focusable()
}

pub fn (model &HTMLSelectElementModel) is_mutable() bool {
	return model.control.enabled()
}
