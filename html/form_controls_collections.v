// Copyright (c) 2023, Shannon Booth <shannon@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of RadioNodeList.{h,cpp} and HTMLFormControlsCollection.{h,cpp}.
module html

import dom

fn form_collection_never_sort(_ &dom.Element, _ &dom.Element) bool {
	return false
}

fn radio_node_list_radio_element(node &dom.Node) ?&dom.Element {
	element := node.as_element() or { return none }
	if !element.is_html_element() || element.local_name() != 'input' {
		return none
	}
	type_ := ascii_lowercase_string(element.get_attribute('type') or { 'text' })
	if type_ != 'radio' {
		return none
	}
	return element
}

$if test {
	fn radio_button(node &dom.Node) ?&dom.HTMLInputElement {
		element := radio_node_list_radio_element(node) or { return none }
		return unsafe { &dom.HTMLInputElement(element) }
	}
}

pub fn html_input_element_checked(element &dom.HTMLInputElement) bool {
	return element.checked()
}

pub fn html_input_element_set_checked(mut element dom.HTMLInputElement, checked bool) {
	mut model := HTMLInputElementModel.create(&element)
	model.set_checked(checked)
}

fn radio_node_list_element_checked(element &dom.Element) bool {
	input := unsafe { &dom.HTMLInputElement(element) }
	return html_input_element_checked(input)
}

fn radio_node_list_set_element_checked(element &dom.Element, checked bool) {
	mut input := unsafe { &dom.HTMLInputElement(element) }
	html_input_element_set_checked(mut input, checked)
}

@[heap]
pub struct RadioNodeList {
mut:
	list &dom.NodeList
}

pub fn RadioNodeList.create(root &dom.Node, scope dom.LiveNodeListScope, filter fn (&dom.Node) bool) &RadioNodeList {
	return &RadioNodeList{
		list: dom.LiveNodeList.create(root, scope, filter)
	}
}

pub fn (list &RadioNodeList) collection() []&dom.Node {
	return list.list.collection()
}

pub fn (list &RadioNodeList) length() int {
	return list.list.length()
}

pub fn (list &RadioNodeList) item(index int) ?&dom.Node {
	return list.list.item(index)
}

pub fn (list &RadioNodeList) value() string {
	for node in list.list.collection() {
		element := radio_node_list_radio_element(node) or { continue }
		if radio_node_list_element_checked(element) {
			return element.get_attribute('value') or { 'on' }
		}
	}
	return ''
}

pub fn (mut list RadioNodeList) set_value(value string) {
	mut matching := ?&dom.Element(none)
	for node in list.list.collection() {
		element := radio_node_list_radio_element(node) or { continue }
		attribute_value := element.get_attribute('value')
		matches := if actual_value := attribute_value {
			actual_value == value
		} else {
			value == 'on'
		}
		if matching == none && matches {
			matching = element
		}
	}
	target := matching or { return }
	// RadioNodeList's value setter explicitly updates the named group. This uses
	// HTMLInputElement::set_checked(), whose C++ counterpart only changes one
	// element; radio-group exclusivity belongs to the caller here.
	for node in list.list.collection() {
		element := radio_node_list_radio_element(node) or { continue }
		radio_node_list_set_element_checked(element, voidptr(element) == voidptr(target))
	}
}

pub struct HTMLFormControlsCollectionEmpty {}

pub struct HTMLFormControlsCollectionElement {
pub:
	element &dom.Element
}

pub struct HTMLFormControlsCollectionRadioNodeList {
pub:
	list &RadioNodeList
}

pub type HTMLFormControlsNamedItem = HTMLFormControlsCollectionElement
	| HTMLFormControlsCollectionEmpty
	| HTMLFormControlsCollectionRadioNodeList

@[heap]
pub struct HTMLFormControlsCollection {
mut:
	collection &dom.HTMLCollection
}

pub fn HTMLFormControlsCollection.create(root &dom.ParentNode, scope dom.HTMLCollectionScope, filter fn (&dom.Element) bool) &HTMLFormControlsCollection {
	return &HTMLFormControlsCollection{
		collection: dom.HTMLCollection.create(root, scope, filter, form_collection_never_sort)
	}
}

pub fn (collection &HTMLFormControlsCollection) length() int {
	return collection.collection.length()
}

pub fn (collection &HTMLFormControlsCollection) item(index int) ?&dom.Element {
	return collection.collection.item(index)
}

pub fn (collection &HTMLFormControlsCollection) named_item_or_radio_node_list(name string) HTMLFormControlsNamedItem {
	if name == '' {
		return HTMLFormControlsCollectionEmpty{}
	}
	mut matches := []&dom.Element{}
	for element in collection.collection.collect_matching_elements() {
		if element.id() or { '' } == name || element.get_attribute('name') or { '' } == name {
			matches << element
		}
	}
	if matches.len == 0 {
		return HTMLFormControlsCollectionEmpty{}
	}
	if matches.len == 1 {
		return HTMLFormControlsCollectionElement{
			element: matches[0]
		}
	}
	root := collection.collection.root.as_node()
	scope := if collection.collection.scope == .descendants {
		dom.LiveNodeListScope.descendants
	} else {
		dom.LiveNodeListScope.children
	}
	base_filter := collection.collection.filter
	return HTMLFormControlsCollectionRadioNodeList{
		list: RadioNodeList.create(root, scope, fn [name, base_filter] (node &dom.Node) bool {
			element := node.as_element() or { return false }
			return base_filter(element) && (element.id() or { '' } == name || element.get_attribute('name') or {
				''
			} == name)
		})
	}
}

pub fn (collection &HTMLFormControlsCollection) named_item_value(name string) HTMLFormControlsNamedItem {
	return collection.named_item_or_radio_node_list(name)
}
