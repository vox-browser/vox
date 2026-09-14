// Copyright (c) 2026, Jelle Raaijmakers <jelle@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

module dom

// https://drafts.csswg.org/css-anchor-position-1/#typedef-anchor-name
pub struct AnchorNameMap {
mut:
	elements_by_name map[string][]&Element
}

pub type AnchorNameMapElementPredicate = fn (voidptr, &Element) bool

pub struct AnchorNameMapFilter {
pub:
	target   voidptr
	callback AnchorNameMapElementPredicate = unsafe { nil }
}

pub fn (mut anchor_names AnchorNameMap) register_name(name string, element &Element) {
	mut elements := anchor_names.elements_by_name[name] or { []&Element{} }
	for existing in elements {
		if voidptr(existing) == voidptr(element) {
			return
		}
	}
	for index, existing in elements {
		if (element.as_node().compare_document_position(existing.as_node()) & document_position_following) != 0 {
			elements.insert(index, element)
			anchor_names.elements_by_name[name] = elements
			return
		}
	}
	elements << element
	anchor_names.elements_by_name[name] = elements
}

pub fn (mut anchor_names AnchorNameMap) unregister_name(name string, element &Element) {
	elements := anchor_names.elements_by_name[name] or { return }
	remaining := elements.filter(voidptr(it) != voidptr(element))
	if remaining.len == 0 {
		anchor_names.elements_by_name.delete(name)
		return
	}
	anchor_names.elements_by_name[name] = remaining
}

pub fn (anchor_names &AnchorNameMap) has_registered_names() bool {
	return anchor_names.elements_by_name.len > 0
}

pub fn (anchor_names &AnchorNameMap) last_element_by_name_matching(name string,
	filter AnchorNameMapFilter) ?&Element {
	elements := anchor_names.elements_by_name[name] or { return none }
	for index := elements.len; index > 0; index-- {
		element := elements[index - 1]
		if filter.callback == unsafe { nil } || filter.callback(filter.target, element) {
			return element
		}
	}
	return none
}

pub fn (anchor_names &AnchorNameMap) element_by_name(name string) ?&Element {
	return anchor_names.last_element_by_name_matching(name, AnchorNameMapFilter{})
}

fn update_anchor_name_map_for_root(root &Node, old_names []string, new_names []string, element &Element) {
	if shadow_root := root.as_shadow_root() {
		mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
		for name in old_names {
			mutable_shadow_root.anchor_name_map_.unregister_name(name, element)
		}
		for name in new_names {
			mutable_shadow_root.anchor_name_map_.register_name(name, element)
		}
		return
	}
	mut document := unsafe { &Document(element.document()) }
	for name in old_names {
		document.anchor_name_map_.unregister_name(name, element)
	}
	for name in new_names {
		document.anchor_name_map_.register_name(name, element)
	}
}

pub fn (d &Document) any_anchor_names_are_registered() bool {
	if d.anchor_name_map_.has_registered_names() {
		return true
	}
	for shadow_root in d.shadow_roots {
		if shadow_root.anchor_name_map_.has_registered_names() {
			return true
		}
	}
	return false
}

pub fn (d &Document) element_by_anchor_name(name string, querying_node &Node,
	filters ...AnchorNameMapFilter) ?&Element {
	filter := if filters.len > 0 { filters[0] } else { AnchorNameMapFilter{} }
	mut node := unsafe { &Node(querying_node) }
	for {
		root := node.root()
		shadow_root := root.as_shadow_root() or {
			return d.anchor_name_map_.last_element_by_name_matching(name, filter)
		}
		if element := shadow_root.anchor_name_map_.last_element_by_name_matching(name,
			filter) {
			return element
		}
		host := shadow_root.host() or { return none }
		node = unsafe { &Node(host.as_node()) }
	}
	return none
}
