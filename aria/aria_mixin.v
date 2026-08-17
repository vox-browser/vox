// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ARIA/ARIAMixin.{h,cpp}.
module aria

import dom

pub type RoleResolver = fn (&dom.Element) ?Role

@[heap]
pub struct ARIAMixin {
pub:
	element &dom.Element
mut:
	default_role_       ?Role
	role_resolver_      ?RoleResolver
	element_references_ map[string]&dom.Element
	list_references_    map[string][]&dom.Element
	list_reference_set_ map[string]bool
	list_cache_         map[string][]&dom.Element
}

pub fn ARIAMixin.create(element &dom.Element, default_role ?Role, role_resolver ?RoleResolver) &ARIAMixin {
	return &ARIAMixin{
		element:        element
		default_role_:  default_role
		role_resolver_: role_resolver
	}
}

pub fn (mixin &ARIAMixin) attribute(name string) ?string {
	return mixin.element.get_attribute(name)
}

pub fn (mixin &ARIAMixin) set_attribute(name string, value ?string) {
	mut element := unsafe { &dom.Element(mixin.element) }
	if string_value := value {
		element.set_attribute_value(name, string_value)
	} else {
		element.remove_attribute(name)
	}
}

pub fn (mixin &ARIAMixin) default_role() ?Role {
	return mixin.default_role_
}

pub fn (mut mixin ARIAMixin) set_default_role(role ?Role) {
	mixin.default_role_ = role
}

fn first_unconditional_explicit_role(element &dom.Element) ?Role {
	role_attribute := element.get_attribute('role') or { return none }
	for token in role_attribute.fields() {
		role := role_from_string(token) or { continue }
		if is_abstract_role(role) {
			continue
		}
		return match role {
			.directory { Role.list }
			.img { Role.image }
			.presentation { Role.none_ }
			else { role }
		}
	}
	return none
}

fn (mixin &ARIAMixin) resolve_element_role(element &dom.Element) ?Role {
	if resolver := mixin.role_resolver_ {
		return resolver(element)
	}
	return first_unconditional_explicit_role(element)
}

fn (mixin &ARIAMixin) has_ancestor_with_role(roles []Role) bool {
	mut ancestor := mixin.element.as_node().parent_element()
	for ancestor != none {
		element := ancestor or { break }
		if role := mixin.resolve_element_role(element) {
			if role in roles {
				return true
			}
		}
		ancestor = element.as_node().parent_element()
	}
	return false
}

fn role_required_contexts(role Role) []Role {
	return match role {
		.columnheader, .gridcell, .rowheader { [Role.row] }
		.listitem { [Role.directory, Role.list] }
		.menuitem, .menuitemcheckbox, .menuitemradio { [Role.menu, Role.menubar] }
		.option { [Role.listbox] }
		.row, .rowgroup { [Role.table, Role.grid, Role.treegrid] }
		.tab { [Role.tablist] }
		.treeitem { [Role.tree] }
		else { []Role{} }
	}
}

// https://www.w3.org/TR/wai-aria-1.2/#introroles
pub fn (mixin &ARIAMixin) role_from_role_attribute_value() ?Role {
	role_attribute := mixin.role() or { return none }
	for token in role_attribute.fields() {
		mut role := role_from_string(token) or { continue }
		if role == .directory {
			return .list
		}
		if role == .img {
			return .image
		}
		contexts := role_required_contexts(role)
		if contexts.len > 0 && !mixin.has_ancestor_with_role(contexts) {
			continue
		}
		if role in [.form, .region] {
			name := mixin.element.as_node().accessible_name(mixin.element.document(), .no) or { '' }
			if name == '' {
				continue
			}
		}
		if role in [.none_, .presentation] {
			if mixin.element.is_focusable() || mixin.has_global_aria_attribute() {
				continue
			}
			role = .none_
		}
		if !is_abstract_role(role) {
			return role
		}
	}
	return none
}

pub fn (mixin &ARIAMixin) role_or_default() ?Role {
	if role := mixin.role_from_role_attribute_value() {
		return role
	}
	return mixin.default_role()
}

// https://www.w3.org/TR/wai-aria-1.2/#global_states
pub fn (mixin &ARIAMixin) has_global_aria_attribute() bool {
	for name in ['aria-atomic', 'aria-braillelabel', 'aria-brailleroledescription', 'aria-busy',
		'aria-controls', 'aria-current', 'aria-describedby', 'aria-description', 'aria-details',
		'aria-disabled', 'aria-dropeffect', 'aria-errormessage', 'aria-flowto', 'aria-grabbed',
		'aria-haspopup', 'aria-hidden', 'aria-invalid', 'aria-keyshortcuts', 'aria-label',
		'aria-labelledby', 'aria-live', 'aria-owns', 'aria-relevant', 'aria-roledescription'] {
		if mixin.attribute(name) != none {
			return true
		}
	}
	return false
}

pub fn (mixin &ARIAMixin) id_reference_exists(id string) bool {
	return mixin.element.id_reference_exists(id)
}

pub fn (mixin &ARIAMixin) parse_id_reference(id_reference ?string) ?string {
	value := id_reference or { return none }
	return if mixin.id_reference_exists(value) { value } else { none }
}

pub fn (mixin &ARIAMixin) parse_id_reference_list(id_list ?string) []string {
	value := id_list or { return []string{} }
	mut result := []string{}
	for id in value.fields() {
		if mixin.id_reference_exists(id) {
			result << id
		}
	}
	return result
}

pub fn (mixin &ARIAMixin) element_reference(name string) ?&dom.Element {
	return mixin.element_references_[name] or { none }
}

pub fn (mut mixin ARIAMixin) set_element_reference(name string, value ?&dom.Element) {
	if element := value {
		mixin.element_references_[name] = element
	} else {
		mixin.element_references_.delete(name)
	}
}

pub fn (mixin &ARIAMixin) element_reference_list(name string) ?[]&dom.Element {
	if !mixin.list_reference_set_[name] {
		return none
	}
	value := mixin.list_references_[name] or { return []&dom.Element{} }
	return value.clone()
}

pub fn (mut mixin ARIAMixin) set_element_reference_list(name string, value ?[]&dom.Element) {
	if elements := value {
		mixin.list_references_[name] = elements.clone()
		mixin.list_reference_set_[name] = true
	} else {
		mixin.list_references_.delete(name)
		mixin.list_reference_set_.delete(name)
	}
	mixin.list_cache_.delete(name)
}

pub fn (mixin &ARIAMixin) cached_element_reference_list(name string) ?[]&dom.Element {
	if value := mixin.list_cache_[name] {
		return value.clone()
	}
	return none
}

pub fn (mut mixin ARIAMixin) set_cached_element_reference_list(name string, value ?[]&dom.Element) {
	if elements := value {
		mixin.list_cache_[name] = elements.clone()
	} else {
		mixin.list_cache_.delete(name)
	}
}
