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
$if test {
	fn convert_value_to_callback_function(value dom.JSValue) !&dom.CallbackType {
		if !value.is_object() || value.object_data == unsafe { nil } {
			return error('TypeError: value is not a function')
		}
		return unsafe { &dom.CallbackType(value.object_data) }
	}
}

// The standalone port represents an already-iterated JS sequence as a V array.
$if test {
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
	is_scoped_                    bool
	scoped_documents_             []&dom.Document
	definitions_                  []&CustomElementRegistration
	when_defined_promise_map_     map[string]&dom.Promise
	element_definition_is_running bool
}

fn custom_element_definition_lookup(registry_handle voidptr, namespace_ ?string, local_name string, is_ ?string) ?&dom.CustomElementDefinition {
	registry := unsafe { &CustomElementRegistry(registry_handle) }
	if namespace_ or { return none } != 'http://www.w3.org/1999/xhtml' {
		return none
	}
	if definition := registry.get_definition_with_name_and_local_name(local_name, local_name) {
		return definition
	}
	is_value := is_ or { return none }
	return registry.get_definition_with_name_and_local_name(is_value, local_name)
}

fn custom_element_registry_is_scoped(registry_handle voidptr) bool {
	return unsafe { &CustomElementRegistry(registry_handle) }.is_scoped_
}

fn custom_element_registry_append_document(registry_handle voidptr, document &dom.Document) {
	mut registry := unsafe { &CustomElementRegistry(registry_handle) }
	registry.append_scoped_document(document)
}

fn install_custom_element_registry_dom_hooks() {
	dom.install_custom_element_definition_lookup(custom_element_definition_lookup)
	dom.install_custom_element_registry_hooks(custom_element_registry_is_scoped, custom_element_registry_append_document)
	dom.install_global_custom_element_registry_factory(create_global_custom_element_registry_for_dom)
}

fn create_global_custom_element_registry_for_dom(document &dom.Document) voidptr {
	return voidptr(CustomElementRegistry.create(document))
}

pub fn CustomElementRegistry.create(document &dom.Document) &CustomElementRegistry {
	install_custom_element_registry_dom_hooks()
	registry := &CustomElementRegistry{
		document_: document
	}
	if document.custom_element_registry() == unsafe { nil } {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.set_custom_element_registry(voidptr(registry))
		registry.initialize_global_document(document)
	}
	return registry
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry
pub fn CustomElementRegistry.construct(document &dom.Document) &CustomElementRegistry {
	install_custom_element_registry_dom_hooks()
	return &CustomElementRegistry{
		document_: document
		is_scoped_: true
	}
}

pub fn (registry &CustomElementRegistry) is_scoped() bool {
	return registry.is_scoped_
}

pub fn (mut registry CustomElementRegistry) append_scoped_document(document &dom.Document) {
	if !registry.is_scoped_ {
		return
	}
	for existing in registry.scoped_documents_ {
		if existing == document {
			return
		}
	}
	registry.scoped_documents_ << document
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

fn enqueue_upgrade_candidates(node &dom.Node, registry &CustomElementRegistry, registration &CustomElementRegistration) {
	if element := node.as_element() {
		if element.custom_element_registry() == voidptr(registry)
			&& candidate_matches_custom_definition(element, registration) {
			mut candidate := unsafe { element }
			candidate.enqueue_a_custom_element_upgrade_reaction(registration.definition)
		}
		if shadow_root := element.shadow_root() {
			enqueue_upgrade_candidates(unsafe { &dom.Node(shadow_root) }, registry, registration)
		}
	}
	for child in node.children_as_vector() {
		enqueue_upgrade_candidates(child, registry, registration)
	}
}

fn (registry &CustomElementRegistry) initialize_global_document(document &dom.Document) {
	document.as_node().visit_shadow_including_inclusive_descendants(fn [registry] (node &dom.Node) dom.TraversalDecision {
		if element := node.as_element() {
			if element.custom_element_registry() == unsafe { nil } {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_custom_element_registry(voidptr(registry))
			}
		} else if shadow_root := node.as_shadow_root() {
			if shadow_root.custom_element_registry() == unsafe { nil }
				&& !shadow_root.keep_custom_element_registry_null() {
				mut mutable_shadow_root := unsafe { &dom.ShadowRoot(shadow_root) }
				mutable_shadow_root.set_custom_element_registry(voidptr(registry))
			}
		}
		return .@continue
	})
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-define
pub fn (mut registry CustomElementRegistry) define(name string, constructor CustomElementConstructor, options ElementDefinitionOptions) ! {
	registry.define_with_metadata(name, constructor, options, fn (identity CustomElementConstructor) !CustomElementConstructor {
		return identity
	})!
}

// The engine must read author-controlled constructor metadata after the name,
// constructor identity and extends checks, while the reentrancy guard is held.
// Standalone callers keep the declarative define() interface above.
pub type CustomElementMetadataReader = fn (CustomElementConstructor) !CustomElementConstructor

pub fn (mut registry CustomElementRegistry) define_with_metadata(name string, identity CustomElementConstructor, options ElementDefinitionOptions, read_metadata CustomElementMetadataReader) ! {
	if !identity.is_constructor {
		return error('TypeError: custom element callback is not a constructor')
	}
	if !is_valid_custom_element_name(name) {
		return error("SyntaxError: '${name}' is not a valid custom element name")
	}
	if registry.registration_with_name(name) != none {
		return error("NotSupportedError: a custom element with name '${name}' is already defined")
	}
	if registry.registration_with_constructor(identity.id) != none {
		return error('NotSupportedError: constructor is already in use')
	}
	mut local_name := name
	if extends := options.extends {
		if registry.is_scoped_ {
			return error('NotSupportedError: scoped registries cannot define customized built-in elements')
		}
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
	constructor := read_metadata(identity)!
	mut lifecycle_callbacks := []string{}
	for callback in custom_element_reaction_names() {
		if callback in constructor.lifecycle_callbacks && callback !in lifecycle_callbacks {
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
		constructor_id_: identity.id
		lifecycle_callbacks_: lifecycle_callbacks.clone()
		exception_reporter_: constructor.exception_reporter
	}
	registration := &CustomElementRegistration{
		definition: definition
		constructor_id: identity.id
		lifecycle_callbacks: lifecycle_callbacks
	}
	registry.definitions_ << registration
	if registry.is_scoped_ {
		for document in registry.scoped_documents_ {
			enqueue_upgrade_candidates(unsafe { &dom.Node(document) }, registry, registration)
		}
	} else {
		enqueue_upgrade_candidates(unsafe { &dom.Node(registry.document_) }, registry, registration)
	}
	if promise := registry.when_defined_promise_map_[name] {
		mut pending := unsafe { promise }
		pending.resolve(dom.js_number(f64(identity.id)))
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
		if element.custom_element_registry() == voidptr(registry) {
			for registration in registry.definitions_ {
				if candidate_matches_custom_definition(element, registration) {
					mut candidate := unsafe { element }
					candidate.enqueue_a_custom_element_upgrade_reaction(registration.definition)
					break
				}
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

// https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-initialize
pub fn (mut registry CustomElementRegistry) initialize(root &dom.Node) ! {
	if !registry.is_scoped_
		&& (root.is_document() || root.document().custom_element_registry() != voidptr(registry)) {
		return error("NotSupportedError: registry must be scoped or the document's registry")
	}
	if document := root.as_document() {
		if document.custom_element_registry() == unsafe { nil } {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.set_custom_element_registry(voidptr(registry))
		}
	} else if shadow_root := root.as_shadow_root() {
		if shadow_root.custom_element_registry() == unsafe { nil } {
			mut mutable_shadow_root := unsafe { &dom.ShadowRoot(shadow_root) }
			mutable_shadow_root.set_custom_element_registry(voidptr(registry))
		}
	}
	registry_handle := voidptr(&registry)
	registry_is_scoped := registry.is_scoped_
	root.visit_inclusive_subtree(fn [registry_handle, registry_is_scoped] (node &dom.Node) dom.TraversalDecision {
		if element := node.as_element() {
			mut mutable_element := unsafe { &dom.Element(element) }
			if element.custom_element_registry() == unsafe { nil } {
				mutable_element.set_custom_element_registry(registry_handle)
				if registry_is_scoped {
					dom.custom_element_registry_append_document(registry_handle, element.document())
				}
			}
			if element.custom_element_registry() == registry_handle {
				mutable_element.try_to_upgrade()
			}
		}
		return .@continue
	})
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
