// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the DOM/state algorithms in HTMLOptionElement.cpp,
// HTMLSelectElement.cpp, and HTMLOptionsCollection.cpp.
module html

import aria
import dom
import infra

fn select_dom_element(select_element &dom.HTMLSelectElement) &dom.Element {
	return unsafe { &dom.Element(select_element) }
}

fn option_dom_element(option &dom.HTMLOptionElement) &dom.Element {
	return unsafe { &dom.Element(option) }
}

fn option_html_element(option &dom.HTMLOptionElement) &dom.HTMLElement {
	return unsafe { &dom.HTMLElement(option) }
}

fn select_node(select_element &dom.HTMLSelectElement) &dom.Node {
	return select_dom_element(select_element).as_node()
}

fn option_node(option &dom.HTMLOptionElement) &dom.Node {
	return option_dom_element(option).as_node()
}

fn initialize_option_selectedness(option &dom.HTMLOptionElement) {
	mut mutable_option := unsafe { &dom.HTMLOptionElement(option) }
	mutable_option.label_changed_hook_ = html_option_element_update_selection_label
	if option.selectedness_initialized_ {
		return
	}
	mut option_node_ := option_node(option)
	option_node_.set_lifecycle_hook(dom.NodeLifecycleHook{
		target: option
		removed_from: html_option_node_removed_from
		moved_from: html_option_node_moved_from
	})
	mutable_option.selectedness_initialized_ = true
	if option_dom_element(option).has_attribute('selected') {
		html_option_element_set_selected_internal(option, true)
	}
}

fn html_option_node_removed_from(target voidptr, _ dom.NodeIsSubtreeRoot, _ ?&dom.Node, _ &dom.Node) {
	option := unsafe { &dom.HTMLOptionElement(target) }
	html_option_element_update_nearest_select_element(option)
}

fn html_option_node_moved_from(target voidptr, _ dom.NodeIsSubtreeRoot, _ ?&dom.Node) {
	option := unsafe { &dom.HTMLOptionElement(target) }
	html_option_element_update_nearest_select_element(option)
}

pub fn html_option_element_selected(option &dom.HTMLOptionElement) bool {
	initialize_option_selectedness(option)
	return option.selected_
}

pub fn html_option_element_selectedness_update_index(option &dom.HTMLOptionElement) u64 {
	initialize_option_selectedness(option)
	return option.selectedness_update_index_
}

pub fn html_option_element_set_selected_internal(option &dom.HTMLOptionElement, selected bool) {
	mut mutable_option := unsafe { &dom.HTMLOptionElement(option) }
	mutable_option.selectedness_initialized_ = true
	if mutable_option.selected_ != selected {
		mut node := option_node(option)
		node.invalidate_style(.html_option_element_selected_change)
	}
	mutable_option.selected_ = selected
	if selected {
		mut document := unsafe { &dom.Document(option_dom_element(option).document()) }
		mutable_option.selectedness_update_index_ = document.next_option_selectedness_update_index()
	}
	mut document := unsafe { &dom.Document(option_dom_element(option).document()) }
	document.bump_dom_tree_version()
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-option-selected
pub fn html_option_element_set_selected(option &dom.HTMLOptionElement, selected bool) {
	html_option_element_set_selected_internal(option, selected)
	mut mutable_option := unsafe { &dom.HTMLOptionElement(option) }
	mutable_option.dirty_ = true
	if select_element := html_option_element_nearest_select(option) {
		html_select_element_update_selectedness(select_element)
	}
}

// This is the selected-attribute branch of HTMLOptionElement::attribute_changed().
pub fn html_option_element_selected_attribute_changed(option &dom.HTMLOptionElement, value ?string) {
	initialize_option_selectedness(option)
	if option.dirty_ {
		return
	}
	html_option_element_set_selected_internal(option, value != none)
}

pub fn html_option_element_update_selection_label(option &dom.HTMLOptionElement) {
	// A menu's intrinsic width includes unselected options as well. Such an
	// option has no rendered box of its own, so invalidate its owning select.
	if select_element := html_option_element_nearest_select(option) {
		mut node := select_dom_element(select_element).as_node()
		node.set_needs_layout_update(.style_change)
	}
	if !html_option_element_selected(option) {
		return
	}
	select_element := html_option_element_nearest_select(option) or { return }
	html_select_element_update_selectedcontent(select_element) or {}
	if select_element.select_element_model_ != unsafe { nil } {
		mut model := unsafe { &HTMLSelectElementModel(select_element.select_element_model_) }
		model.clone_selected_option_into_select_button()
		return
	}
	shadow_root := select_dom_element(select_element).shadow_root() or { return }
	shadow_children := unsafe { &dom.Node(shadow_root) }.children_as_vector()
	if shadow_children.len == 0 {
		return
	}
	border_children := shadow_children[0].children_as_vector()
	if border_children.len == 0 {
		return
	}
	mut inner := border_children[0]
	inner.string_replace_all(html_option_element_label(option))
}

pub fn html_option_element_attribute_changed(option &dom.HTMLOptionElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := option_dom_element(option)
	element.attribute_changed(name, old_value, value, namespace_)
	if name == 'selected' {
		html_option_element_selected_attribute_changed(option, value)
	} else if name == 'label' {
		html_option_element_update_selection_label(option)
	}
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-option-value
pub fn html_option_element_value(option &dom.HTMLOptionElement) string {
	return option_dom_element(option).get_attribute('value') or { html_option_element_text(option) }
}

pub fn set_html_option_element_value(option &dom.HTMLOptionElement, value string) {
	mut element := unsafe { &dom.Element(option) }
	element.set_attribute_value('value', value)
}

fn append_option_descendant_text(node &dom.Node, mut output []u8) {
	if node.is_text() {
		text := unsafe { &dom.Text(node) }
		output << text.data().bytes()
		return
	}
	if element := node.as_element() {
		if element.local_name() == 'script' {
			return
		}
	}
	for child in node.children_as_vector() {
		append_option_descendant_text(child, mut output)
	}
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-option-text
pub fn html_option_element_text(option &dom.HTMLOptionElement) string {
	mut output := []u8{}
	for child in option_node(option).children_as_vector() {
		append_option_descendant_text(child, mut output)
	}
	return infra.strip_and_collapse_whitespace(output.bytestr())
}

pub fn set_html_option_element_text(option &dom.HTMLOptionElement, text string) {
	mut node := unsafe { &dom.Node(option_node(option)) }
	node.string_replace_all(text)
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-option-label
pub fn html_option_element_label(option &dom.HTMLOptionElement) string {
	return option_dom_element(option).get_attribute('label') or { html_option_element_text(option) }
}

pub fn set_html_option_element_label(option &dom.HTMLOptionElement, label string) {
	mut element := unsafe { &dom.Element(option) }
	element.set_attribute_value('label', label)
}

// https://html.spec.whatwg.org/multipage/form-elements.html#option-element-nearest-ancestor-select
pub fn html_option_element_nearest_select(option &dom.HTMLOptionElement) ?&dom.HTMLSelectElement {
	if cached := option.cached_nearest_select_element_ {
		return cached
	}
	return html_option_element_compute_nearest_select_element(option)
}

pub fn html_option_element_compute_nearest_select_element(option &dom.HTMLOptionElement) ?&dom.HTMLSelectElement {
	mut ancestor_optgroup := false
	mut ancestor := option_node(option).parent_node()
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			name := element.local_name()
			if name in ['datalist', 'hr', 'option'] {
				return none
			}
			if name == 'optgroup' {
				if ancestor_optgroup {
					return none
				}
				ancestor_optgroup = true
			}
			if name == 'select' {
				return unsafe { &dom.HTMLSelectElement(element) }
			}
		}
		ancestor = current.parent_node()
	}
	return none
}

pub fn html_option_element_update_nearest_select_element(option &dom.HTMLOptionElement) {
	old_select := option.cached_nearest_select_element_
	new_select := html_option_element_compute_nearest_select_element(option)
	mut changed := old_select == none || new_select == none
	if old := old_select {
		if new := new_select {
			changed = voidptr(old) != voidptr(new)
		}
	}
	if changed {
		if old := old_select {
			html_select_element_update_selectedness(old)
		}
		if new := new_select {
			html_select_element_update_selectedness(new)
		}
	}
	mut mutable_option := unsafe { &dom.HTMLOptionElement(option) }
	mutable_option.cached_nearest_select_element_ = new_select
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-option-index
pub fn html_option_element_index(option &dom.HTMLOptionElement) i32 {
	select_element := html_option_element_nearest_select(option) or { return 0 }
	for index, candidate in html_select_element_list_of_options(select_element) {
		if option_node(candidate).is_same_node(option_node(option)) {
			return i32(index)
		}
	}
	return 0
}

pub fn html_option_element_nearest_select_element(option &dom.HTMLOptionElement) ?&dom.HTMLSelectElement {
	return html_option_element_nearest_select(option)
}

pub fn html_selected_content_element_disabled(element &dom.HTMLSelectedContentElement) bool {
	return element.disabled_
}

pub fn html_selected_content_element_set_disabled(element &dom.HTMLSelectedContentElement, value bool) {
	mut mutable_element := unsafe { &dom.HTMLSelectedContentElement(element) }
	mutable_element.disabled_ = value
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-option-disabled
pub fn html_option_element_disabled(option &dom.HTMLOptionElement) bool {
	element := option_dom_element(option)
	if element.has_attribute('disabled') {
		return true
	}
	parent := option_node(option).parent_element() or { return false }
	return parent.local_name() == 'optgroup' && parent.has_attribute('disabled')
}

pub fn html_option_element_ask_for_a_reset(option &dom.HTMLOptionElement) {
	if select_element := html_option_element_nearest_select(option) {
		html_select_element_update_selectedness(select_element)
	}
}

pub fn html_option_element_form(option &dom.HTMLOptionElement) ?&dom.HTMLFormElement {
	select_element := html_option_element_nearest_select(option) or { return none }
	select_dom := select_dom_element(select_element)
	if form_id := select_dom.get_attribute('form') {
		return form_element_find_form_by_id(select_dom.as_node().root(), form_id)
	}
	ancestor := form_element_nearest_ancestor(select_dom, 'form') or { return none }
	return unsafe { &dom.HTMLFormElement(ancestor) }
}

pub fn html_option_element_default_role(_ &dom.HTMLOptionElement) aria.Role {
	return .option
}

pub fn html_option_element_clone_into_selectedcontent(option &dom.HTMLOptionElement, selectedcontent &dom.HTMLSelectedContentElement) ! {
	clone_html_option_into_selectedcontent(option, selectedcontent)!
}

pub fn html_option_element_inserted(option &dom.HTMLOptionElement) {
	initialize_option_selectedness(option)
	html_option_element_set_selected_internal(option, html_option_element_selected(option))
	html_option_element_update_nearest_select_element(option)
}

pub fn html_option_element_removed_from(option &dom.HTMLOptionElement, _ ?&dom.Node, _ &dom.Node) {
	html_option_element_update_nearest_select_element(option)
}

// https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element:html-element-moving-steps
pub fn html_option_element_moved_from(option &dom.HTMLOptionElement, _ dom.NodeIsSubtreeRoot, _ ?&dom.Node) {
	html_option_element_update_nearest_select_element(option)
}

pub fn html_option_element_children_changed(option &dom.HTMLOptionElement, metadata dom.ChildrenChangedMetadata) {
	mut element := option_dom_element(option)
	element.children_changed(metadata)
	html_option_element_update_selection_label(option)
}

fn html_opt_group_element_has_option_child(optgroup &dom.HTMLOptGroupElement) bool {
	for child in unsafe { &dom.Element(optgroup) }.as_node().children_as_vector() {
		if element := child.as_element() {
			if element.local_name() == 'option' {
				return true
			}
		}
	}
	return false
}

pub fn html_opt_group_element_inserted(optgroup &dom.HTMLOptGroupElement) {
	parent := unsafe { &dom.Element(optgroup) }.as_node().parent_element() or { return }
	if parent.local_name() == 'select' && html_opt_group_element_has_option_child(optgroup) {
		html_select_element_update_selectedness(unsafe { &dom.HTMLSelectElement(parent) })
	}
}

pub fn html_opt_group_element_removed_from(optgroup &dom.HTMLOptGroupElement, old_parent ?&dom.Node, _ &dom.Node) {
	parent := old_parent or { return }
	element := parent.as_element() or { return }
	if element.local_name() == 'select' && html_opt_group_element_has_option_child(optgroup) {
		html_select_element_update_selectedness(unsafe { &dom.HTMLSelectElement(element) })
	}
}

pub fn html_data_list_element_options(datalist &dom.HTMLDataListElement) &dom.HTMLCollection {
	if options := datalist.options_ {
		return options
	}
	element := unsafe { &dom.Element(datalist) }
	options := dom.HTMLCollection.create(unsafe { &dom.ParentNode(element) }, .descendants, fn (candidate &dom.Element) bool {
		return candidate.local_name() == 'option'
	}, fn (_ &dom.Element, _ &dom.Element) bool {
		return false
	})
	mut mutable_datalist := unsafe { &dom.HTMLDataListElement(datalist) }
	mutable_datalist.options_ = options
	return options
}

fn option_is_nested_optgroup(node &dom.Node, select_element &dom.HTMLSelectElement) bool {
	element := node.as_element() or { return false }
	if element.local_name() != 'optgroup' {
		return false
	}
	mut ancestor := node.parent_node()
	for ancestor != none {
		current := ancestor or { break }
		if current.is_same_node(select_node(select_element)) {
			return false
		}
		if ancestor_element := current.as_element() {
			if ancestor_element.local_name() == 'optgroup' {
				return true
			}
		}
		ancestor = current.parent_node()
	}
	return false
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-select-option-list
fn collect_select_options(node &dom.Node, select_element &dom.HTMLSelectElement, mut options []&dom.HTMLOptionElement) {
	for child in node.children_as_vector() {
		element := child.as_element() or {
			collect_select_options(child, select_element, mut options)
			continue
		}
		name := element.local_name()
		if name == 'option' {
			option := unsafe { &dom.HTMLOptionElement(element) }
			initialize_option_selectedness(option)
			options << option
		}
		if name in ['select', 'hr', 'option', 'datalist']
			|| option_is_nested_optgroup(child, select_element) {
			continue
		}
		collect_select_options(child, select_element, mut options)
	}
}

pub fn html_select_element_list_of_options(select_element &dom.HTMLSelectElement) []&dom.HTMLOptionElement {
	mut options := []&dom.HTMLOptionElement{}
	collect_select_options(select_node(select_element), select_element, mut options)
	return options
}

pub fn html_select_element_selected_options(select_element &dom.HTMLSelectElement) []&dom.HTMLOptionElement {
	return html_select_element_list_of_options(select_element).filter(html_option_element_selected(it))
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-select-size
pub fn html_select_element_display_size(select_element &dom.HTMLSelectElement) u32 {
	element := select_dom_element(select_element)
	if size_string := element.get_attribute('size') {
		if size := parse_non_negative_integer(size_string) {
			return size
		}
	}
	return if element.has_attribute('multiple') { u32(4) } else { u32(1) }
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-size
pub fn html_select_element_size(select_element &dom.HTMLSelectElement) u32 {
	if size_string := select_dom_element(select_element).get_attribute('size') {
		if size := parse_non_negative_integer(size_string) {
			if size <= 0x7fff_ffff {
				return size
			}
		}
	}
	return 0
}

pub fn set_html_select_element_size(select_element &dom.HTMLSelectElement, size u32) {
	mut element := unsafe { &dom.Element(select_element) }
	element.set_attribute_value('size', (if size > 0x7fff_ffff { u32(0) } else { size }).str())
}

pub fn html_select_element_length(select_element &dom.HTMLSelectElement) u32 {
	return u32(html_select_element_list_of_options(select_element).len)
}

pub fn html_select_element_item(select_element &dom.HTMLSelectElement, index u32) ?&dom.HTMLOptionElement {
	options := html_select_element_list_of_options(select_element)
	if index >= u32(options.len) {
		return none
	}
	return options[index]
}

pub fn html_select_element_named_item(select_element &dom.HTMLSelectElement, name string) ?&dom.HTMLOptionElement {
	for option in html_select_element_list_of_options(select_element) {
		element := option_dom_element(option)
		if element.get_attribute_value('id') == name || element.get_attribute_value('name') == name {
			return option
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-type
pub fn html_select_element_type(select_element &dom.HTMLSelectElement) string {
	return if select_dom_element(select_element).has_attribute('multiple') {
		'select-multiple'
	} else {
		'select-one'
	}
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-selectedindex
pub fn html_select_element_selected_index(select_element &dom.HTMLSelectElement) i32 {
	for index, option in html_select_element_list_of_options(select_element) {
		if html_option_element_selected(option) {
			return i32(index)
		}
	}
	return -1
}

pub fn set_html_select_element_selected_index(select_element &dom.HTMLSelectElement, selected_index i32) {
	// In C++, the form-associated insertion steps have already materialized the
	// built-in shadow tree before an IDL setter can run. Ensure the split V model
	// has reached the same state, then preserve the setter's ScopeGuard update of
	// the built-in label below.
	mut model := HTMLSelectElementModel.create(select_element)
	model.create_shadow_tree_if_needed()
	mut first_matching_option := ?&dom.HTMLOptionElement(none)
	for index, option in html_select_element_list_of_options(select_element) {
		html_option_element_set_selected_internal(option, false)
		if first_matching_option == none && i32(index) == selected_index {
			first_matching_option = option
		}
	}
	if option := first_matching_option {
		html_option_element_set_selected_internal(option, true)
		mut mutable_option := unsafe { &dom.HTMLOptionElement(option) }
		mutable_option.dirty_ = true
	}
	html_select_element_update_selectedcontent(select_element) or {}
	model.clone_selected_option_into_select_button()
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-value
pub fn html_select_element_value(select_element &dom.HTMLSelectElement) string {
	for option in html_select_element_list_of_options(select_element) {
		if html_option_element_selected(option) {
			return html_option_element_value(option)
		}
	}
	return ''
}

pub fn set_html_select_element_value(select_element &dom.HTMLSelectElement, value string) {
	mut first_matching_option := ?&dom.HTMLOptionElement(none)
	for option in html_select_element_list_of_options(select_element) {
		html_option_element_set_selected_internal(option, false)
		if first_matching_option == none && html_option_element_value(option) == value {
			first_matching_option = option
		}
	}
	if option := first_matching_option {
		html_option_element_set_selected_internal(option, true)
		mut mutable_option := unsafe { &dom.HTMLOptionElement(option) }
		mutable_option.dirty_ = true
	}
	html_select_element_update_selectedcontent(select_element) or {}
	if select_element.select_element_model_ != unsafe { nil } {
		mut model := unsafe { &HTMLSelectElementModel(select_element.select_element_model_) }
		model.clone_selected_option_into_select_button()
	}
}

// https://html.spec.whatwg.org/multipage/form-elements.html#selectedness-setting-algorithm
pub fn html_select_element_update_selectedness(select_element &dom.HTMLSelectElement) {
	options := html_select_element_list_of_options(select_element)
	mut number_selected := 0
	for option in options {
		if html_option_element_selected(option) {
			number_selected++
		}
	}
	element := select_dom_element(select_element)
	if !element.has_attribute('multiple') && html_select_element_display_size(select_element) == 1
		&& number_selected == 0 {
		for option in options {
			if !html_option_element_disabled(option) {
				html_option_element_set_selected_internal(option, true)
				break
			}
		}
	} else if !element.has_attribute('multiple') && number_selected >= 2 {
		mut last_selected_option := ?&dom.HTMLOptionElement(none)
		mut last_selected_update_index := u64(0)
		for option in options {
			if html_option_element_selected(option) && (last_selected_option == none
				|| html_option_element_selectedness_update_index(option) > last_selected_update_index) {
				last_selected_option = option
				last_selected_update_index = html_option_element_selectedness_update_index(option)
			}
		}
		for option in options {
			last := last_selected_option or { continue }
			if !option_node(option).is_same_node(option_node(last)) {
				html_option_element_set_selected_internal(option, false)
			}
		}
	}
	html_select_element_update_selectedcontent(select_element) or {}
	if select_element.select_element_model_ != unsafe { nil } {
		mut model := unsafe { &HTMLSelectElementModel(select_element.select_element_model_) }
		model.clone_selected_option_into_select_button()
	}
}

// https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element:concept-form-reset-control
pub fn html_select_element_reset(select_element &dom.HTMLSelectElement) {
	for option in html_select_element_list_of_options(select_element) {
		html_option_element_set_selected_internal(option, option_dom_element(option).has_attribute('selected'))
		mut mutable_option := unsafe { &dom.HTMLOptionElement(option) }
		mutable_option.dirty_ = false
	}
	html_select_element_update_selectedness(select_element)
}

// https://html.spec.whatwg.org/multipage/form-elements.html#placeholder-label-option
pub fn html_select_element_placeholder_label_option(select_element &dom.HTMLSelectElement) ?&dom.HTMLOptionElement {
	element := select_dom_element(select_element)
	if !element.has_attribute('required') || element.has_attribute('multiple')
		|| html_select_element_display_size(select_element) != 1 {
		return none
	}
	options := html_select_element_list_of_options(select_element)
	if options.len == 0 {
		return none
	}
	first := options[0]
	parent := option_node(first).parent_node() or { return none }
	if html_option_element_value(first) == '' && parent.is_same_node(select_node(select_element)) {
		return first
	}
	return none
}

pub fn html_select_element_suffering_from_being_missing(select_element &dom.HTMLSelectElement) bool {
	if !select_dom_element(select_element).has_attribute('required') {
		return false
	}
	selected := html_select_element_selected_options(select_element)
	if selected.len == 0 {
		return true
	}
	if selected.len == 1 {
		placeholder := html_select_element_placeholder_label_option(select_element) or {
			return false
		}
		return option_node(selected[0]).is_same_node(option_node(placeholder))
	}
	return false
}

// https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#dom-htmloptionscollection-length
pub fn set_html_select_element_length(select_element &dom.HTMLSelectElement, value u32) ! {
	current := html_select_element_list_of_options(select_element).len
	if value > u32(current) {
		if value > 100_000 {
			return
		}
		mut root := select_node(select_element)
		for _ in 0 .. int(value) - current {
			option := dom.create_element(select_dom_element(select_element).document(), 'option', ns_html, none, none, false)!
			root.append_child(option.as_node())!
		}
	} else if value < u32(current) {
		for _ in 0 .. current - int(value) {
			options := html_select_element_list_of_options(select_element)
			remove_table_node(option_node(options.last()))
		}
	}
	html_select_element_update_selectedness(select_element)
}

// Translation of HTMLOptionsCollection's indexed setter. `option == none` is the JS null case.
pub fn set_html_select_element_indexed_option(select_element &dom.HTMLSelectElement, index u32, option ?&dom.HTMLOptionElement) ! {
	if index >= 100_000 {
		return
	}
	if value := option {
		length := html_select_element_list_of_options(select_element).len
		delta := i64(index) - i64(length)
		mut root := select_node(select_element)
		if delta > 0 {
			for _ in 0 .. int(delta) {
				placeholder := dom.create_element(select_dom_element(select_element).document(), 'option', ns_html, none, none, false)!
				root.append_child(placeholder.as_node())!
			}
		}
		if delta >= 0 {
			root.append_child(option_node(value))!
		} else {
			old_option := html_select_element_list_of_options(select_element)[index]
			root.replace_child(option_node(value), option_node(old_option))!
		}
	} else {
		html_select_element_remove_option(select_element, i32(index))
	}
	html_select_element_update_selectedness(select_element)
}

pub fn html_select_element_remove_option(select_element &dom.HTMLSelectElement, index i32) {
	options := html_select_element_list_of_options(select_element)
	if index < 0 || index >= options.len {
		return
	}
	remove_table_node(option_node(options[index]))
	html_select_element_update_selectedness(select_element)
}

// Translation of HTMLOptionsCollection::add with the WebIDL union already resolved by the caller.
pub fn html_select_element_add_option(select_element &dom.HTMLSelectElement, element &dom.HTMLElement, before_element ?&dom.HTMLElement, before_index ?i32) ! {
	element_node := unsafe { &dom.Element(element) }.as_node()
	if element_node.is_ancestor_of(select_node(select_element)) {
		return error('HierarchyRequestError: The provided element is an ancestor of the root select element.')
	}
	mut reference := ?&dom.Node(none)
	if before := before_element {
		before_node := unsafe { &dom.Element(before) }.as_node()
		if !before_node.is_descendant_of(select_node(select_element)) {
			return error("NotFoundError: The 'before' element is not a descendant of the root select element.")
		}
		if element_node.is_same_node(before_node) {
			return
		}
		reference = before_node
	} else if index := before_index {
		if index >= 0 {
			if option := html_select_element_item(select_element, u32(index)) {
				reference = option_node(option)
			}
		}
	}
	mut parent := if reference_node := reference {
		reference_node.parent_node() or { select_node(select_element) }
	} else {
		select_node(select_element)
	}
	parent.pre_insert(element_node, reference)!
	html_select_element_update_selectedness(select_element)
}

fn collect_selectedcontent_descendants(node &dom.Node, mut result []&dom.HTMLSelectedContentElement) {
	for child in node.children_as_vector() {
		if element := child.as_element() {
			if element.local_name() == 'selectedcontent' {
				result << unsafe { &dom.HTMLSelectedContentElement(element) }
			}
		}
		collect_selectedcontent_descendants(child, mut result)
	}
}

fn html_select_element_selectedcontent_descendants(select_element &dom.HTMLSelectElement) []&dom.HTMLSelectedContentElement {
	mut result := []&dom.HTMLSelectedContentElement{}
	collect_selectedcontent_descendants(select_node(select_element), mut result)
	return result
}

pub fn html_selectedcontent_element_disabled(selectedcontent &dom.HTMLSelectedContentElement) bool {
	return selectedcontent.disabled_
}

fn set_html_selectedcontent_element_disabled(selectedcontent &dom.HTMLSelectedContentElement, disabled bool) {
	mut mutable_selectedcontent := unsafe { &dom.HTMLSelectedContentElement(selectedcontent) }
	mutable_selectedcontent.disabled_ = disabled
}

// https://html.spec.whatwg.org/multipage/form-elements.html#clear-a-selectedcontent
pub fn clear_html_selectedcontent_element(selectedcontent &dom.HTMLSelectedContentElement) {
	mut node := unsafe { &dom.Element(selectedcontent) }.as_node()
	node.replace_all(none)
}

// https://html.spec.whatwg.org/multipage/form-elements.html#select-enabled-selectedcontent
pub fn html_select_element_enabled_selectedcontent(select_element &dom.HTMLSelectElement) ?&dom.HTMLSelectedContentElement {
	if select_dom_element(select_element).has_attribute('multiple') {
		return none
	}
	selectedcontents := html_select_element_selectedcontent_descendants(select_element)
	if selectedcontents.len == 0 || html_selectedcontent_element_disabled(selectedcontents[0]) {
		return none
	}
	return selectedcontents[0]
}

// https://html.spec.whatwg.org/multipage/form-elements.html#clone-an-option-into-a-selectedcontent
pub fn clone_html_option_into_selectedcontent(option &dom.HTMLOptionElement, selectedcontent &dom.HTMLSelectedContentElement) ! {
	document := option_dom_element(option).document()
	mut fragment := dom.DocumentFragment.new(document)
	mut fragment_node := fragment.as_node()
	for child in option_node(option).children_as_vector() {
		clone := child.clone_node(document, true, none)!
		fragment_node.append_child(clone)!
	}
	mut selectedcontent_node := unsafe { &dom.Element(selectedcontent) }.as_node()
	selectedcontent_node.replace_all(fragment.as_node())
}

// https://html.spec.whatwg.org/multipage/form-elements.html#update-a-select%27s-selectedcontent
pub fn html_select_element_update_selectedcontent(select_element &dom.HTMLSelectElement) ! {
	selectedcontent := html_select_element_enabled_selectedcontent(select_element) or { return }
	for option in html_select_element_list_of_options(select_element) {
		if html_option_element_selected(option) {
			clone_html_option_into_selectedcontent(option, selectedcontent)!
			return
		}
	}
	clear_html_selectedcontent_element(selectedcontent)
}

// https://html.spec.whatwg.org/multipage/form-elements.html#clear-a-select%27s-non-primary-selectedcontent-elements
pub fn html_select_element_clear_non_primary_selectedcontent(select_element &dom.HTMLSelectElement) {
	selectedcontents := html_select_element_selectedcontent_descendants(select_element)
	for index in 1 .. selectedcontents.len {
		clear_html_selectedcontent_element(selectedcontents[index])
	}
}

pub fn html_option_element_maybe_clone_into_selectedcontent(option &dom.HTMLOptionElement) ! {
	if !html_option_element_selected(option) {
		return
	}
	select_element := html_option_element_nearest_select(option) or { return }
	selectedcontent := html_select_element_enabled_selectedcontent(select_element) or { return }
	clone_html_option_into_selectedcontent(option, selectedcontent)!
}

// https://html.spec.whatwg.org/multipage/form-elements.html#the-selectedcontent-element:html-element-post-connection-steps
pub fn html_selectedcontent_element_post_connection(selectedcontent &dom.HTMLSelectedContentElement) ! {
	set_html_selectedcontent_element_disabled(selectedcontent, false)
	selectedcontent_node := unsafe { &dom.Element(selectedcontent) }.as_node()
	mut nearest_select := ?&dom.HTMLSelectElement(none)
	mut ancestor := selectedcontent_node.parent_node()
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.local_name() == 'select' {
				if nearest_select == none {
					nearest_select = unsafe { &dom.HTMLSelectElement(element) }
				} else {
					set_html_selectedcontent_element_disabled(selectedcontent, true)
				}
			}
			if element.local_name() in ['option', 'selectedcontent'] {
				set_html_selectedcontent_element_disabled(selectedcontent, true)
			}
		}
		ancestor = current.parent_node()
	}
	select_element := nearest_select or { return }
	if select_dom_element(select_element).has_attribute('multiple') {
		return
	}
	html_select_element_update_selectedcontent(select_element)!
	html_select_element_clear_non_primary_selectedcontent(select_element)
}

pub fn html_selected_content_element_clear_selectedcontent(selectedcontent &dom.HTMLSelectedContentElement) {
	clear_html_selectedcontent_element(selectedcontent)
}

pub fn html_selected_content_element_post_connection(selectedcontent &dom.HTMLSelectedContentElement) ! {
	html_selectedcontent_element_post_connection(selectedcontent)!
}

// The caller supplies old_parent after it removes selectedcontent from the tree.
pub fn html_selectedcontent_element_removed(selectedcontent &dom.HTMLSelectedContentElement, old_parent ?&dom.Node) ! {
	selectedcontent_node := unsafe { &dom.Element(selectedcontent) }.as_node()
	mut ancestor := selectedcontent_node.parent_node()
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.local_name() == 'select' {
				return
			}
		}
		ancestor = current.parent_node()
	}
	mut old_ancestor := old_parent
	for old_ancestor != none {
		current := old_ancestor or { break }
		if element := current.as_element() {
			if element.local_name() == 'select' {
				html_select_element_update_selectedcontent(unsafe { &dom.HTMLSelectElement(element) })!
				return
			}
		}
		old_ancestor = current.parent_node()
	}
}

pub fn html_selected_content_element_removed_from(selectedcontent &dom.HTMLSelectedContentElement, old_parent ?&dom.Node, _ &dom.Node) ! {
	html_selectedcontent_element_removed(selectedcontent, old_parent)!
}
