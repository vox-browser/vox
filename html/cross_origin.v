// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CrossOrigin/AbstractOperations.{h,cpp} and
// CrossOrigin/Reporting.{h,cpp} against the V Window/Location models.
module html

import dom

pub enum CrossOriginObjectKind {
	location
	window
}

pub struct CrossOriginProperty {
pub:
	property  string
	needs_get ?bool
	needs_set ?bool
}

pub fn cross_origin_properties(kind CrossOriginObjectKind) []CrossOriginProperty {
	if kind == .location {
		return [
			CrossOriginProperty{
				property:  'href'
				needs_get: false
				needs_set: true
			},
			CrossOriginProperty{
				property: 'replace'
			},
		]
	}
	mut properties := []CrossOriginProperty{cap: window_cross_origin_property_names.len}
	for name in window_cross_origin_property_names {
		properties << match name {
			'window', 'self', 'closed', 'frames', 'length', 'top', 'opener', 'parent' {
				CrossOriginProperty{
					property:  name
					needs_get: true
					needs_set: false
				}
			}
			'location' {
				CrossOriginProperty{
					property:  name
					needs_get: true
					needs_set: true
				}
			}
			else {
				CrossOriginProperty{
					property: name
				}
			}
		}
	}
	return properties
}

pub fn is_cross_origin_accessible_window_property_name(property string) bool {
	return property in window_cross_origin_property_names
		|| window_property_array_index(property) != none
}

pub fn cross_origin_property_fallback(property string) !WindowProxyProperty {
	if property in ['then', '@@toStringTag', '@@hasInstance', '@@isConcatSpreadable'] {
		return WindowProxyProperty{
			value:        dom.js_undefined()
			configurable: true
		}
	}
	return error("SecurityError: cannot access property '${property}' on cross-origin object")
}

pub fn is_platform_object_same_origin(current_origin dom.Origin, relevant_origin dom.Origin) bool {
	return current_origin.is_same_origin(relevant_origin)
}

pub fn cross_origin_get(proxy &WindowProxyModel, current_origin dom.Origin, property string) !dom.JSValue {
	result := proxy.get_own_property(current_origin, property)!
	if !result.found {
		fallback := cross_origin_property_fallback(property)!
		return fallback.value
	}
	return result.descriptor.value
}

pub fn cross_origin_set(mut proxy WindowProxyModel, current_origin dom.Origin, property string, value dom.JSValue) !bool {
	return proxy.set(current_origin, property, value)
}

pub fn cross_origin_own_property_keys(proxy &WindowProxyModel, current_origin dom.Origin) []string {
	return proxy.own_property_keys(current_origin)
}

pub enum AccessorAccessedRelationship {
	none
	accessor_is_opener
	accessor_is_openee
}

pub struct CrossOriginAccessReport {
pub:
	property     string
	relationship AccessorAccessedRelationship
	accessor_url dom.URL
	accessed_url dom.URL
}

fn context_inclusive_ancestor_origins(context &BrowsingContextModel) []dom.Origin {
	mut origins := []dom.Origin{}
	mut current := ?&BrowsingContextModel(context)
	for current != none {
		candidate := current or { break }
		if document := candidate.active_document() {
			origins << document.origin()
		}
		current = candidate.parent()
	}
	return origins
}

fn all_origins_match(origins []dom.Origin, expected dom.Origin) bool {
	for origin in origins {
		if !origin.is_same_origin(expected) {
			return false
		}
	}
	return true
}

pub fn check_if_access_between_two_browsing_contexts_should_be_reported(accessor ?&BrowsingContextModel, accessed ?&BrowsingContextModel, property string) ?CrossOriginAccessReport {
	accessor_context := accessor or { return none }
	accessed_context := accessed or { return none }
	if !is_cross_origin_accessible_window_property_name(property)
		|| !accessor_context.is_fully_active() || !accessed_context.is_fully_active() {
		return none
	}
	accessor_top := accessor_context.top_level_browsing_context() or { return none }
	accessed_top := accessed_context.top_level_browsing_context() or { return none }
	accessor_document := accessor_context.active_document() or { return none }
	accessed_document := accessed_context.active_document() or { return none }
	accessor_top_document := accessor_top.active_document() or { return none }
	accessed_top_document := accessed_top.active_document() or { return none }
	if !all_origins_match(context_inclusive_ancestor_origins(accessor_context), accessor_top_document.origin())
		|| !all_origins_match(context_inclusive_ancestor_origins(accessed_context), accessed_top_document.origin()) {
		return none
	}
	accessor_group := accessor_top.group() or { return none }
	accessed_group := accessed_top.group() or { return none }
	if accessor_group == accessed_group {
		return none
	}
	mut relationship := AccessorAccessedRelationship.none
	if opener := accessed_top.opener() {
		if opener == accessor_context || opener.is_ancestor_of(accessor_context) {
			relationship = .accessor_is_opener
		}
	}
	if opener := accessor_top.opener() {
		if opener == accessed_context || opener.is_ancestor_of(accessed_context) {
			relationship = .accessor_is_openee
		}
	}
	return CrossOriginAccessReport{
		property:     property
		relationship: relationship
		accessor_url: accessor_document.url
		accessed_url: accessed_document.url
	}
}
