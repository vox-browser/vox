// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module html

import aria
import contentsecuritypolicy
import dom
import strings
import trustedtypes
import url as liburl

// ARIAMixin is owned by Element in C++. V keeps the module dependency in the
// same direction (HTML/ARIA -> DOM) and exposes the result to DOM through a
// document callback, rather than duplicating role parsing in DOM.
pub fn html_element_role_or_default(element &dom.Element) ?aria.Role {
	default_role := html_default_role_for_element(element)
	mixin := aria.ARIAMixin.create(element, default_role, html_element_role_resolver)
	return mixin.role_or_default()
}

fn html_element_role_resolver(element &dom.Element) ?aria.Role {
	return html_element_role_or_default(element)
}

fn html_default_role_for_element(element &dom.Element) ?aria.Role {
	if !element.is_html_element() {
		return none
	}
	return match element.local_name() {
		'a' {
			html_anchor_element_default_role(unsafe { &dom.HTMLAnchorElement(element) })
		}
		'area' {
			html_area_element_default_role(unsafe { &dom.HTMLAreaElement(element) })
		}
		'body' { aria.Role.generic }
		'button' { aria.Role.button }
		'data', 'div', 'pre', 'span', 'selectedcontent' { aria.Role.generic }
		'datalist' { aria.Role.listbox }
		'details' { aria.Role.group }
		'dialog' { aria.Role.dialog }
		'fieldset' { aria.Role.group }
		'form' { aria.Role.form }
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6' { aria.Role.heading }
		'hr' { aria.Role.separator }
		'html' { aria.Role.document }
		'img' {
			html_image_element_default_role(unsafe { &dom.HTMLImageElement(element) })
		}
		'input' {
			html_input_element_default_role(unsafe { &dom.HTMLInputElement(element) })
		}
		'li' { aria.Role.listitem }
		'menu', 'ol', 'ul' { aria.Role.list }
		'meter' { aria.Role.meter }
		'optgroup' { aria.Role.group }
		'option' { aria.Role.option }
		'output' { aria.Role.status }
		'p' { aria.Role.paragraph }
		'progress' { aria.Role.progressbar }
		'select' {
			html_select_element_default_role(unsafe { &dom.HTMLSelectElement(element) })
		}
		'summary' { aria.Role.button }
		'table' { aria.Role.table }
		'caption' { aria.Role.caption }
		'tbody', 'thead', 'tfoot' { aria.Role.rowgroup }
		'td', 'th' {
			html_table_cell_element_default_role(unsafe { &dom.HTMLTableCellElement(element) })
		}
		'textarea' { aria.Role.textbox }
		'time' { aria.Role.time }
		'tr' { aria.Role.row }
		'del', 'ins' {
			html_mod_element_default_role(unsafe { &dom.HTMLModElement(element) })
		}
		'blockquote', 'q' {
			html_quote_element_default_role(unsafe { &dom.HTMLQuoteElement(element) })
		}
		else {
			html_element_default_role(unsafe { &dom.HTMLElement(element) })
		}
	}
}

fn dom_element_allows_name_from_content(_ voidptr, element &dom.Element, should_compute_role bool) bool {
	// Node::name_or_description() computes the explicit role unless ARIAMixin
	// called back with ShouldComputeRole::No to break the landmark-name cycle.
	// It then asks for the default role, except for aside/section whose default
	// role itself depends on the accessible name.
	default_role := if element.local_name() in ['aside', 'section'] {
		?aria.Role(none)
	} else {
		html_default_role_for_element(element)
	}
	mixin := aria.ARIAMixin.create(element, default_role, html_element_role_resolver)
	role := if should_compute_role {
		mixin.role_from_role_attribute_value() or { default_role or { return false } }
	} else {
		default_role or { return false }
	}
	return aria.allows_name_from_content(role)
}

// Node.cpp step C of name_or_description(): return the contribution from an
// HTML form control's associated labels, including the values of controls
// embedded in those labels. `none` means the step does not apply; an empty
// string is a real result when labels exist but contribute no text.
fn dom_embedded_control_label_value(_ voidptr, element &dom.Element) ?string {
	if !element.is_html_element() {
		return none
	}
	labels := html_element_labels(unsafe { &dom.HTMLElement(element) }) or { return none }
	if labels.length() == 0 {
		return none
	}

	mut builder := strings.new_builder(0)
	for label_index in 0 .. labels.length() {
		if builder.len > 0 {
			builder.write_string(' ')
		}
		label := labels.item(label_index) or { continue }
		for node in label.children_as_vector() {
			if voidptr(node) == voidptr(element.as_node()) {
				continue
			}
			if child := node.as_element() {
				role := html_element_role_or_default(child) or { continue }
				match role {
					.textbox {
						if child.local_name() == 'input' {
							if child.has_attribute('value') {
								input := HTMLInputElementModel.create(unsafe {
									&dom.HTMLInputElement(child)
								})
								builder.write_string(input.value())
							}
						} else {
							builder.write_string(node.text_content() or { '' })
						}
					}
					.combobox {
						if child.local_name() == 'input' {
							if child.has_attribute('value') {
								input := HTMLInputElementModel.create(unsafe {
									&dom.HTMLInputElement(child)
								})
								builder.write_string(input.value())
							}
						} else if child.local_name() == 'select' {
							builder.write_string(html_select_element_value(unsafe {
								&dom.HTMLSelectElement(child)
							}))
						} else {
							builder.write_string(node.text_content() or { '' })
						}
					}
					.listbox {
						if child.local_name() == 'select' {
							builder.write_string(html_select_element_value(unsafe {
								&dom.HTMLSelectElement(child)
							}))
						}
						for option_node in node.children_as_vector() {
							option := option_node.as_element() or { continue }
							option_role := html_element_role_or_default(option) or { continue }
							if option_role == aria.Role.option {
								mixin := aria.ARIAMixin.create(option, aria.Role.option, html_element_role_resolver)
								if (mixin.aria_selected() or { '' }) == 'true' {
									builder.write_string(option_node.text_content() or { '' })
								}
							}
						}
					}
					.spinbutton, .slider {
						mixin := aria.ARIAMixin.create(child, role, html_element_role_resolver)
						if value_text := mixin.aria_value_text() {
							builder.write_string(value_text)
						} else if value_now := mixin.aria_value_now() {
							builder.write_string(value_now)
						} else if child.local_name() == 'input' && child.has_attribute('value') {
							input := HTMLInputElementModel.create(unsafe {
								&dom.HTMLInputElement(child)
							})
							builder.write_string(input.value())
						}
					}
					else {}
				}
			} else if node.is_text() {
				builder.write_string(node.text_content() or { '' })
			}
		}
	}
	return builder.str()
}

pub fn install_document_accessibility_role_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_accessibility_role_hook(dom.DocumentAccessibilityRoleHook{
		target: voidptr(document)
		element_allows_name_from_content: dom_element_allows_name_from_content
		embedded_control_label_value: dom_embedded_control_label_value
	})
}

fn document_csp_policies(document &dom.Document) []&contentsecuritypolicy.Policy {
	settings_pointer := document.relevant_settings_object()
	if settings_pointer != unsafe { nil } {
		// BlockingAlgorithms.cpp:414–416. The actual settings container is the
		// sole policy owner; standalone Meta-string storage is not another list.
		settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
		return fetch_csp_policy_list(settings.policy_container().csp_list).policies
	}
	mut policies := []&contentsecuritypolicy.Policy{}
	for serialized in document.enforced_meta_csp_policies() {
		policy := contentsecuritypolicy.parse_a_serialized_csp(serialized, .meta, .enforce)
		if policy.directives().len > 0 {
			policies << policy
		}
	}
	return policies
}

fn dom_inline_csp_check(_ voidptr, element &dom.Element, inline_type string, source string) bool {
	policies := document_csp_policies(element.document())
	mut policy_list := contentsecuritypolicy.PolicyList.create(policies)
	mut global := &contentsecuritypolicy.GlobalContext{
		policy_list: policy_list
	}
	settings_pointer := element.document().relevant_settings_object()
	if settings_pointer != unsafe { nil } {
		settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
		global = settings.fetch_request_client_csp_global()
	}
	mut attributes := map[string]string{}
	for name in element.get_attribute_names() {
		attributes[name] = element.get_attribute_value(name)
	}
	element_context := contentsecuritypolicy.ElementContext{
		dom_element: element
		is_html_or_svg: element.is_html_element() || element.is_svg_element()
		is_script: element.local_name() == 'script'
		is_style: element.local_name() == 'style'
		nonce: element.cryptographic_nonce()
		had_duplicate_attribute: element.had_duplicate_attribute_during_tokenization
		attributes: attributes
		connected_to_policy_document: element.as_node().is_connected()
	}
	type_ := match inline_type {
		'script' { contentsecuritypolicy.InlineType.script }
		'script-attribute' { contentsecuritypolicy.InlineType.script_attribute }
		'navigation' { contentsecuritypolicy.InlineType.navigation }
		'style-attribute' { contentsecuritypolicy.InlineType.style_attribute }
		else { contentsecuritypolicy.InlineType.style }
	}
	return contentsecuritypolicy.should_elements_inline_type_behavior_be_blocked_by_content_security_policy(mut
		global, if type_ == .navigation { contentsecuritypolicy.ElementContext{} } else { element_context }, type_, source) == .blocked
}

fn dom_base_csp_check(document &dom.Document, base dom.URL) bool {
	settings_pointer := document.relevant_settings_object()
	if settings_pointer == unsafe { nil } {
		// Standalone DOM construction has no actual HTML settings owner.
		return true
	}
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	mut global := settings.fetch_request_client_csp_global()
	base_url := liburl.parse(base.serialize()) or { panic('Invalid parsed Base URL') }
	return contentsecuritypolicy.is_base_allowed_for_document(mut global, base_url) == .allowed
}

// HTMLMetaElement.cpp:209–223 and PolicyList.cpp:105–109. Parse and filter
// with the actual translated CSP engine, then append to the same settings
// container consumed by Fetch, Base and inline checks.
fn dom_meta_csp_enforce(document &dom.Document, input string) string {
	mut policy := contentsecuritypolicy.parse_a_serialized_csp(input, .meta, .enforce)
	policy.remove_directive(contentsecuritypolicy.report_uri)
	policy.remove_directive(contentsecuritypolicy.frame_ancestors)
	policy.remove_directive(contentsecuritypolicy.sandbox)
	policy.set_self_origin(document.origin().liburl_origin() or {
		panic('Meta CSP requires the actual Document origin')
	})
	serialized := policy.serialize() or { panic(err) }
	mut directives := []SerializedCSPDirective{}
	for directive in serialized.directives {
		directives << SerializedCSPDirective{ name: directive.name, value: directive.value.clone() }
	}
	settings_pointer := document.relevant_settings_object()
	if settings_pointer != unsafe { nil } {
		settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
		mut container := unsafe { &PolicyContainer(settings.policy_container()) }
		container.csp_list << SerializedCSPPolicy{
			directives: directives
			disposition: .enforce
			source: .meta
			self_origin: document.origin()
			pre_parsed_policy_string: serialized.pre_parsed_policy_string
		}
	}
	// This string is only the standalone adapter. Genuine settings owners read
	// the parsed list above, retaining its original unfiltered input separately.
	return directives.map('${it.name} ${it.value.join(' ')}'.trim_space()).join('; ')
}

fn document_csp_initialization_policies(document &dom.Document) []&contentsecuritypolicy.Policy {
	// Document.cpp:10720 reads the Document's own list. Inline/global checks
	// use relevant settings instead, which may currently name another Document.
	return fetch_csp_policy_list(document.policy_container().csp_list).policies
}

fn dom_csp_initialize_document(_ voidptr, document &dom.Document) {
	for policy in document_csp_initialization_policies(document) {
		for directive in policy.directives() {
			// Source VERIFY remains active in production builds.
			if directive.initialization(false, policy) != .allowed {
				panic('CSP Document initialization must return Allowed')
			}
		}
	}
}

pub fn trusted_types_factory_for_document(document &dom.Document) &trustedtypes.TrustedTypePolicyFactory {
	settings_pointer := document.relevant_settings_object()
	if settings_pointer != unsafe { nil } {
		settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
		if window := settings.window_ {
			mut services := window.window_or_worker_global_scope()
			return unsafe { &trustedtypes.TrustedTypePolicyFactory(services.trusted_types()) }
		}
	}
	mut factory := trustedtypes.TrustedTypePolicyFactory.create()
	factory.csp_policies = trusted_types_meta_policies(document)
	return factory
}

fn trusted_types_meta_policies(document &dom.Document) []trustedtypes.TrustedTypesCSPPolicy {
	mut policies := []trustedtypes.TrustedTypesCSPPolicy{}
	for policy in document_csp_policies(document) {
		mut names := ?[]string(none)
		if directive := policy.get_directive_by_name(contentsecuritypolicy.trusted_types) {
			names = directive.value()
		}
		mut sinks := []string{}
		if directive := policy.get_directive_by_name(contentsecuritypolicy.require_trusted_types_for) {
			sinks = directive.value()
		}
		policies << trustedtypes.TrustedTypesCSPPolicy{
			disposition:               if policy.disposition() == .enforce {
				trustedtypes.CSPDisposition.enforce
			} else {
				trustedtypes.CSPDisposition.report_only
			}
			trusted_types:             names
			require_trusted_types_for: sinks
		}
	}
	return policies
}

fn trusted_types_injection_sink(sink string) !trustedtypes.InjectionSink {
	return match sink {
		'document-exec-command' { trustedtypes.InjectionSink.document_exec_command }
		'document-parse-html-unsafe' { trustedtypes.InjectionSink.document_parse_html_unsafe }
		'document-write' { trustedtypes.InjectionSink.document_write }
		'document-writeln' { trustedtypes.InjectionSink.document_writeln }
		'dom-parser-parse-from-string' { trustedtypes.InjectionSink.dom_parser_parse_from_string }
		'element-inner-html' { trustedtypes.InjectionSink.element_inner_html }
		'element-insert-adjacent-html' { trustedtypes.InjectionSink.element_insert_adjacent_html }
		'element-outer-html' { trustedtypes.InjectionSink.element_outer_html }
		'element-set-html-unsafe' { trustedtypes.InjectionSink.element_set_html_unsafe }
		'range-create-contextual-fragment' { trustedtypes.InjectionSink.range_create_contextual_fragment }
		'shadow-root-inner-html' { trustedtypes.InjectionSink.shadow_root_inner_html }
		'shadow-root-set-html-unsafe' { trustedtypes.InjectionSink.shadow_root_set_html_unsafe }
		else { return error('Unknown Trusted Types injection sink: ${sink}') }
	}
}

fn dom_trusted_types_compliant_html(_ voidptr, document &dom.Document, input string, sink string) !string {
	mut factory := trusted_types_factory_for_document(document)
	injection_sink := trusted_types_injection_sink(sink)!
	return trustedtypes.get_trusted_type_compliant_string(mut factory, .trusted_html, input,
		injection_sink, "'script'", true)!
}

fn dom_trusted_types_compliant_attribute(_ voidptr, element &dom.Element, local_name string, namespace_uri ?string, input trustedtypes.TrustedTypeOrString) !string {
	mut factory := trusted_types_factory_for_document(element.document())
	element_interface := trustedtypes.element_interface(element.local_name(), element.namespace_uri() or {
		''
	})
	return trustedtypes.get_trusted_types_compliant_attribute_value(mut factory, local_name,
		namespace_uri, element_interface, input)!
}

pub fn install_document_csp_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_csp_hook(dom.DocumentCSPHook{
		target:       voidptr(document)
		inline_check: dom_inline_csp_check
		initialize:   dom_csp_initialize_document
		base_check:   dom_base_csp_check
		meta_enforce: dom_meta_csp_enforce
	})
	mutable_document.set_meta_element_metadata_callback(html_meta_element_update_metadata)
	mutable_document.set_trusted_types_hook(dom.DocumentTrustedTypesHook{
		target:              voidptr(document)
		compliant_html:      dom_trusted_types_compliant_html
		compliant_attribute: dom_trusted_types_compliant_attribute
	})
}
