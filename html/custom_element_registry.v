// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CustomElements/CustomElementRegistry.{h,cpp} and
// CustomElements/CustomElementDefinition.{h,cpp}. JavaScript constructors are
// represented by stable host-supplied IDs and declarative constructor metadata.
module html

import dom

// WebIDL callback conversion at the compact JS-value boundary. Object values
// used here carry a CallbackType pointer in object_data.
fn convert_value_to_callback_function(value dom.JSValue) !&dom.CallbackType {
	if !value.is_object() || value.object_data == unsafe { nil } {
		return error('TypeError: value is not a function')
	}
	return unsafe { &dom.CallbackType(value.object_data) }
}

// The standalone port represents an already-iterated JS sequence as a V array.
fn convert_value_to_sequence_of_strings(values []dom.JSValue) ![]string {
	mut result := []string{cap: values.len}
	for value in values {
		if value.is_object() {
			return error('TypeError: object string conversion requires a JavaScript host')
		}
		result << value.to_string_value()
	}
	return result
}

pub struct ElementDefinitionOptions {
pub:
	extends ?string
}

pub struct CustomElementConstructor {
pub:
	id                  u64
	is_constructor      bool = true
	observed_attributes []string
	lifecycle_callbacks []string
	disabled_features   []string
	form_associated     bool
	exception_reporter  ?dom.CustomElementExceptionReporter
}

@[heap]
pub struct CustomElementRegistration {
pub:
	definition          &dom.CustomElementDefinition
	constructor_id      u64
	lifecycle_callbacks []string
}

@[heap]
pub struct CustomElementRegistry {
mut:
	document_                     &dom.Document = unsafe { nil }
	definitions_                  []&CustomElementRegistration
	when_defined_promise_map_     map[string]&dom.Promise
	element_definition_is_running bool
}

pub fn CustomElementRegistry.create(document &dom.Document) &CustomElementRegistry {
	return &CustomElementRegistry{
		document_: document
	}
}

fn (registry &CustomElementRegistry) registration_with_name(name string) ?&CustomElementRegistration {
	for registration in registry.definitions_ {
		if registration.definition.name() == name {
			return registration
		}
	}
	return none
}

fn (registry &CustomElementRegistry) registration_with_constructor(constructor_id u64) ?&CustomElementRegistration {
	for registration in registry.definitions_ {
		if registration.constructor_id == constructor_id {
			return registration
		}
	}
	return none
}

fn candidate_matches_custom_definition(element &dom.Element, registration &CustomElementRegistration) bool {
	if element.namespace_uri() or { '' } != 'http://www.w3.org/1999/xhtml' {
		return false
	}
	definition := registration.definition
	if element.local_name() != definition.local_name() {
		return false
	}
	if definition.local_name() != definition.name() {
		return element.get_attribute_value('is') == definition.name()
	}
	return true
}

fn enqueue_upgrade_candidates(node &dom.Node, registration &CustomElementRegistration) {
	if element := node.as_element() {
		if candidate_matches_custom_definition(element, registration) {
			mut candidate := element
			candidate.enqueue_a_custom_element_upgrade_reaction(registration.definition)
		}
		if shadow_root := element.shadow_root() {
			enqueue_upgrade_candidates(unsafe { &dom.Node(shadow_root) }, registration)
		}
	}
	for child in node.children_as_vector() {
		enqueue_upgrade_candidates(child, registration)
	}
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-define
pub fn (mut registry CustomElementRegistry) define(name string, constructor CustomElementConstructor, options ElementDefinitionOptions) ! {
	if !constructor.is_constructor {
		return error('TypeError: custom element callback is not a constructor')
	}
	if !is_valid_custom_element_name(name) {
		return error("SyntaxError: '${name}' is not a valid custom element name")
	}
	if registry.registration_with_name(name) != none {
		return error("NotSupportedError: a custom element with name '${name}' is already defined")
	}
	if registry.registration_with_constructor(constructor.id) != none {
		return error('NotSupportedError: constructor is already in use')
	}
	mut local_name := name
	if extends := options.extends {
		if is_valid_custom_element_name(extends) {
			return error('NotSupportedError: custom element names cannot be extended')
		}
		if dom.is_unknown_html_element(extends) {
			return error("NotSupportedError: '${extends}' is an unknown HTML element")
		}
		local_name = extends
	}
	if registry.element_definition_is_running {
		return error('NotSupportedError: cannot recursively define custom elements')
	}
	registry.element_definition_is_running = true
	defer {
		registry.element_definition_is_running = false
	}
	mut lifecycle_callbacks := []string{}
	for callback in constructor.lifecycle_callbacks {
		if callback in custom_element_reaction_names() && callback !in lifecycle_callbacks {
			lifecycle_callbacks << callback
		}
	}
	observed_attributes := if 'attributeChangedCallback' in lifecycle_callbacks {
		constructor.observed_attributes.clone()
	} else {
		[]string{}
	}
	definition := &dom.CustomElementDefinition{
		name_: name
		local_name_: local_name
		observed_attributes: observed_attributes
		form_associated_: constructor.form_associated
		disable_internals_: 'internals' in constructor.disabled_features
		disable_shadow_: 'shadow' in constructor.disabled_features
		constructor_id_: constructor.id
		lifecycle_callbacks_: lifecycle_callbacks.clone()
		exception_reporter_: constructor.exception_reporter
	}
	registration := &CustomElementRegistration{
		definition: definition
		constructor_id: constructor.id
		lifecycle_callbacks: lifecycle_callbacks
	}
	registry.definitions_ << registration
	mut document := registry.document_
	document.register_custom_element_definition(definition)
	enqueue_upgrade_candidates(unsafe { &dom.Node(registry.document_) }, registration)
	if promise := registry.when_defined_promise_map_[name] {
		mut pending := promise
		pending.resolve(dom.js_number(f64(constructor.id)))
		registry.when_defined_promise_map_.delete(name)
	}
}

pub fn (registry &CustomElementRegistry) get(name string) ?u64 {
	registration := registry.registration_with_name(name) or { return none }
	return registration.constructor_id
}

pub fn (registry &CustomElementRegistry) get_name(constructor_id u64) ?string {
	registration := registry.registration_with_constructor(constructor_id) or { return none }
	return registration.definition.name()
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-whendefined
pub fn (mut registry CustomElementRegistry) when_defined(name string) &dom.Promise {
	if !is_valid_custom_element_name(name) {
		return dom.Promise.rejected(dom.js_string("SyntaxError: '${name}' is not a valid custom element name"))
	}
	if registration := registry.registration_with_name(name) {
		return dom.Promise.resolved(dom.js_number(f64(registration.constructor_id)))
	}
	if promise := registry.when_defined_promise_map_[name] {
		return promise
	}
	promise := dom.Promise.create()
	registry.when_defined_promise_map_[name] = promise
	return promise
}

fn registry_upgrade_node(node &dom.Node, registry &CustomElementRegistry) {
	if element := node.as_element() {
		for registration in registry.definitions_ {
			if candidate_matches_custom_definition(element, registration) {
				mut candidate := element
				candidate.enqueue_a_custom_element_upgrade_reaction(registration.definition)
				break
			}
		}
		if shadow_root := element.shadow_root() {
			registry_upgrade_node(unsafe { &dom.Node(shadow_root) }, registry)
		}
	}
	for child in node.children_as_vector() {
		registry_upgrade_node(child, registry)
	}
}

pub fn (registry &CustomElementRegistry) upgrade(root &dom.Node) {
	registry_upgrade_node(root, registry)
}

pub fn (registry &CustomElementRegistry) get_definition_with_name_and_local_name(name string, local_name string) ?&dom.CustomElementDefinition {
	for registration in registry.definitions_ {
		if registration.definition.name() == name && registration.definition.local_name() == local_name {
			return registration.definition
		}
	}
	return none
}

pub fn (registry &CustomElementRegistry) get_definition_from_new_target(new_target u64) ?&dom.CustomElementDefinition {
	registration := registry.registration_with_constructor(new_target) or { return none }
	return registration.definition
}

pub fn (registry &CustomElementRegistry) definition_count() int {
	return registry.definitions_.len
}
