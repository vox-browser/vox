// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TrustedTypePolicyFactory, InjectionSink and
// RequireTrustedTypesForDirective.
module trustedtypes

pub const html_namespace = 'http://www.w3.org/1999/xhtml'
pub const svg_namespace = 'http://www.w3.org/2000/svg'
pub const mathml_namespace = 'http://www.w3.org/1998/Math/MathML'
pub const xlink_namespace = 'http://www.w3.org/1999/xlink'

const event_handler_attributes = [
	'onabort',
	'onanimationcancel',
	'onanimationend',
	'onanimationiteration',
	'onanimationstart',
	'onauxclick',
	'onbeforeinput',
	'onbeforematch',
	'onbeforetoggle',
	'onblur',
	'oncancel',
	'oncanplay',
	'oncanplaythrough',
	'onchange',
	'onclick',
	'onclose',
	'oncommand',
	'oncontextlost',
	'oncontextmenu',
	'oncontextrestored',
	'oncopy',
	'oncuechange',
	'oncut',
	'ondblclick',
	'ondrag',
	'ondragend',
	'ondragenter',
	'ondragleave',
	'ondragover',
	'ondragstart',
	'ondrop',
	'ondurationchange',
	'onemptied',
	'onended',
	'onerror',
	'onfocus',
	'onfocusin',
	'onfocusout',
	'onformdata',
	'ongotpointercapture',
	'oninput',
	'oninvalid',
	'onkeydown',
	'onkeypress',
	'onkeyup',
	'onload',
	'onloadeddata',
	'onloadedmetadata',
	'onloadstart',
	'onlostpointercapture',
	'onmousedown',
	'onmouseenter',
	'onmouseleave',
	'onmousemove',
	'onmouseout',
	'onmouseover',
	'onmouseup',
	'onpaste',
	'onpause',
	'onplay',
	'onplaying',
	'onpointercancel',
	'onpointerdown',
	'onpointerenter',
	'onpointerleave',
	'onpointermove',
	'onpointerout',
	'onpointerover',
	'onpointerrawupdate',
	'onpointerup',
	'onprogress',
	'onratechange',
	'onreset',
	'onresize',
	'onscroll',
	'onscrollend',
	'onsecuritypolicyviolation',
	'onseeked',
	'onseeking',
	'onselect',
	'onselectionchange',
	'onslotchange',
	'onstalled',
	'onsubmit',
	'onsuspend',
	'ontimeupdate',
	'ontoggle',
	'onvolumechange',
	'onwaiting',
	'onwebkitanimationend',
	'onwebkitanimationiteration',
	'onwebkitanimationstart',
	'onwebkittransitionend',
	'onwheel',
	'onafterprint',
	'onbeforeprint',
	'onbeforeunload',
	'ongamepadconnected',
	'ongamepaddisconnected',
	'onhashchange',
	'onlanguagechange',
	'onmessage',
	'onmessageerror',
	'onoffline',
	'ononline',
	'onpagehide',
	'onpagereveal',
	'onpageshow',
	'onpageswap',
	'onpopstate',
	'onrejectionhandled',
	'onstorage',
	'onunhandledrejection',
	'onunload',
]

pub enum InjectionSink {
	document_parse_html_unsafe
	document_write
	document_writeln
	document_exec_command
	dom_parser_parse_from_string
	element_inner_html
	element_insert_adjacent_html
	element_outer_html
	element_set_html_unsafe
	eval
	function_
	html_iframe_element_srcdoc
	html_script_element_inner_text
	html_script_element_src
	html_script_element_text
	html_script_element_text_content
	location_href
	range_create_contextual_fragment
	service_worker_container_register
	shadow_root_inner_html
	shadow_root_set_html_unsafe
	shared_worker_constructor
	svg_script_element_href
	worker_constructor
	element_event_handler
}

pub fn injection_sink_string(sink InjectionSink) string {
	return match sink {
		.document_parse_html_unsafe { 'Document parseHTMLUnsafe' }
		.document_write { 'Document write' }
		.document_writeln { 'Document writeln' }
		.document_exec_command { 'Document execCommand' }
		.dom_parser_parse_from_string { 'DOMParser parseFromString' }
		.element_inner_html { 'Element innerHTML' }
		.element_insert_adjacent_html { 'Element insertAdjacentHTML' }
		.element_outer_html { 'Element outerHTML' }
		.element_set_html_unsafe { 'Element setHTMLUnsafe' }
		.eval { 'eval' }
		.function_ { 'Function' }
		.html_iframe_element_srcdoc { 'HTMLIFrameElement srcdoc' }
		.html_script_element_inner_text { 'HTMLScriptElement innerText' }
		.html_script_element_src { 'HTMLScriptElement src' }
		.html_script_element_text { 'HTMLScriptElement text' }
		.html_script_element_text_content { 'HTMLScriptElement textContent' }
		.location_href { 'Location href' }
		.range_create_contextual_fragment { 'Range createContextualFragment' }
		.service_worker_container_register { 'ServiceWorkerContainer register' }
		.shadow_root_inner_html { 'ShadowRoot innerHTML' }
		.shadow_root_set_html_unsafe { 'ShadowRoot setHTMLUnsafe' }
		.shared_worker_constructor { 'SharedWorker constructor' }
		.svg_script_element_href { 'SVGScriptElement href' }
		.worker_constructor { 'Worker constructor' }
		.element_event_handler { 'Element event handler' }
	}
}

pub enum CSPDisposition {
	enforce
	report_only
}

pub struct TrustedTypesCSPPolicy {
pub:
	disposition               CSPDisposition
	trusted_types             ?[]string
	require_trusted_types_for []string
}

pub struct TrustedTypesViolation {
pub:
	resource string
	sample   string
}

// The V embedding passes the request global's policy factory and serialized
// request URL explicitly instead of retaining JS/Fetch graph objects here.
pub struct RequireTrustedTypesForDirective {}

pub fn (directive &RequireTrustedTypesForDirective) pre_navigation_check(mut factory TrustedTypePolicyFactory, url string) !string {
	return factory.pre_navigation_check(url)
}

// A small, cycle-free representation of the Window/WorkerGlobalScope owner
// retained by the upstream factory. Embedders can associate their concrete
// global and realm objects through the opaque handles.
pub struct TrustedTypesGlobalContext {
pub:
	global voidptr
	realm  voidptr
	current_csp_policies ?fn () []TrustedTypesCSPPolicy
}

@[heap]
pub struct TrustedTypePolicyFactory {
pub mut:
	csp_policies []TrustedTypesCSPPolicy
	violations   []TrustedTypesViolation
mut:
	created_policy_names []string
	default_policy_      ?&TrustedTypePolicy
	empty_html_          ?TrustedHTML
	empty_script_        ?TrustedScript
	global_context_      ?&TrustedTypesGlobalContext
}

pub fn TrustedTypePolicyFactory.create() &TrustedTypePolicyFactory {
	return &TrustedTypePolicyFactory{}
}

pub fn TrustedTypePolicyFactory.create_for_global(context &TrustedTypesGlobalContext) &TrustedTypePolicyFactory {
	return &TrustedTypePolicyFactory{
		global_context_: context
	}
}

pub fn (factory &TrustedTypePolicyFactory) relevant_global_impl() voidptr {
	context := factory.global_context_ or { return unsafe { nil } }
	return context.global
}

pub fn (factory &TrustedTypePolicyFactory) relevant_realm() voidptr {
	context := factory.global_context_ or { return unsafe { nil } }
	return context.realm
}

fn (factory &TrustedTypePolicyFactory) current_csp_policies() []TrustedTypesCSPPolicy {
	if context := factory.global_context_ {
		if current := context.current_csp_policies { return current() }
	}
	return factory.csp_policies.clone()
}

pub fn TrustedTypePolicyFactory.default_policy_offset() uint {
	return uint(__offsetof(TrustedTypePolicyFactory, default_policy_))
}

pub fn (factory &TrustedTypePolicyFactory) default_policy() ?&TrustedTypePolicy {
	return factory.default_policy_
}

pub fn (mut factory TrustedTypePolicyFactory) create_policy(name string, options TrustedTypePolicyOptions) !&TrustedTypePolicy {
	return factory.create_a_trusted_type_policy(name, options)
}

// https://w3c.github.io/trusted-types/dist/spec/#create-trusted-type-policy-algorithm
pub fn (mut factory TrustedTypePolicyFactory) create_a_trusted_type_policy(name string, options TrustedTypePolicyOptions) !&TrustedTypePolicy {
	if factory.should_trusted_type_policy_be_blocked_by_content_security_policy(name, factory.created_policy_names.clone()) {
		return error('TypeError: Content Security Policy blocked the creation of the policy ${name}')
	}
	if name == 'default' && factory.default_policy_ != none {
		return error('TypeError: Policy Factory already has a default value defined')
	}
	policy := TrustedTypePolicy.create(name, options)
	if name == 'default' {
		factory.default_policy_ = policy
	}
	factory.created_policy_names << name
	return policy
}

// https://www.w3.org/TR/trusted-types/#should-block-create-policy
pub fn (mut factory TrustedTypePolicyFactory) should_trusted_type_policy_be_blocked_by_content_security_policy(name string, created_policy_names []string) bool {
	mut blocked := false
	for policy in factory.current_csp_policies() {
		values := policy.trusted_types or { continue }
		lower := values.map(it.to_lower())
		mut violation := lower == ["'none'"]
		if name in created_policy_names && "'allow-duplicates'" !in lower {
			violation = true
		}
		if name !in values && '*' !in values {
			violation = true
		}
		if violation {
			runes := name.runes()
			trimmed := runes[..if runes.len < 40 { runes.len } else { 40 }].string()
			factory.violations << TrustedTypesViolation{
				resource: 'trusted-types-policy'
				sample: trimmed
			}
			if policy.disposition == .enforce {
				blocked = true
			}
		}
	}
	return blocked
}

pub fn (factory &TrustedTypePolicyFactory) is_html(value TrustedTypeOrString) bool {
	return is_trusted_html_value(value)
}

pub fn (factory &TrustedTypePolicyFactory) is_script(value TrustedTypeOrString) bool {
	return is_trusted_script_value(value)
}

pub fn (factory &TrustedTypePolicyFactory) is_script_url(value TrustedTypeOrString) bool {
	return is_trusted_script_url_value(value)
}

pub fn (mut factory TrustedTypePolicyFactory) empty_html() TrustedHTML {
	if value := factory.empty_html_ {
		return value
	}
	value := TrustedHTML{
		data: ''
	}
	factory.empty_html_ = value
	return value
}

pub fn (mut factory TrustedTypePolicyFactory) empty_script() TrustedScript {
	if value := factory.empty_script_ {
		return value
	}
	value := TrustedScript{
		data: ''
	}
	factory.empty_script_ = value
	return value
}

fn strip_sink_group_quotes(value string) string {
	if value.len >= 2 && ((value[0] == `'` && value[value.len - 1] == `'`)
		|| (value[0] == `"` && value[value.len - 1] == `"`)) {
		return value[1..value.len - 1]
	}
	return value
}

pub fn sink_group_matches(directive_value string, sink_group string) bool {
	return strip_sink_group_quotes(directive_value).to_lower() == strip_sink_group_quotes(sink_group).to_lower()
}

pub fn (factory &TrustedTypePolicyFactory) does_sink_require_trusted_types(sink_group string, include_report_only bool) bool {
	for policy in factory.current_csp_policies() {
		if !policy.require_trusted_types_for.any(sink_group_matches(it, sink_group)) {
			continue
		}
		if policy.disposition == .enforce || include_report_only {
			return true
		}
	}
	return false
}

pub fn (mut factory TrustedTypePolicyFactory) should_sink_type_mismatch_violation_be_blocked(sink InjectionSink, sink_group string, source string) bool {
	return should_sink_type_mismatch_violation_be_blocked_by_content_security_policy(mut factory, sink, sink_group, source)
}

// https://w3c.github.io/trusted-types/dist/spec/#should-block-sink-type-mismatch
pub fn should_sink_type_mismatch_violation_be_blocked_by_content_security_policy(mut factory TrustedTypePolicyFactory, sink InjectionSink, sink_group string, source string) bool {
	return should_sink_type_mismatch_violation_be_blocked_named(mut factory, sink, injection_sink_string(sink), sink_group, source)
}

fn should_sink_type_mismatch_violation_be_blocked_named(mut factory TrustedTypePolicyFactory, sink InjectionSink, sink_name string, sink_group string, source string) bool {
	mut sample := source
	if sink == .function_ {
		for prefix in ['function anonymous', 'async function anonymous', 'function* anonymous',
			'async function* anonymous'] {
			if sample.starts_with(prefix) {
				sample = sample[prefix.len..]
				break
			}
		}
	}
	mut blocked := false
	for policy in factory.current_csp_policies() {
		if !policy.require_trusted_types_for.any(sink_group_matches(it, sink_group)) {
			continue
		}
		trimmed :=
			sample.runes()[..if sample.runes().len < 40 { sample.runes().len } else { 40 }].string()
		factory.violations << TrustedTypesViolation{
			resource: 'trusted-types-sink'
			sample: '${sink_name}|${trimmed}'
		}
		if policy.disposition == .enforce {
			blocked = true
		}
	}
	return blocked
}

pub fn (factory &TrustedTypePolicyFactory) sink_type_mismatch_would_be_blocked(sink_group string) bool {
	for policy in factory.current_csp_policies() {
		if policy.disposition == .enforce
			&& policy.require_trusted_types_for.any(sink_group_matches(it, sink_group)) {
			return true
		}
	}
	return false
}

pub struct ElementInterface {
pub:
	element_name string
	element_ns   string
}

pub struct TrustedTypeData {
pub:
	element              string
	attribute_ns         ?string
	attribute_local_name string
	trusted_type         TrustedTypeName
	sink                 InjectionSink
}

pub fn element_interface(local_name string, namespace string) ElementInterface {
	if namespace == html_namespace && local_name == 'iframe' {
		return ElementInterface{
			element_name: 'HTMLIFrameElement'
			element_ns: namespace
		}
	}
	if namespace == html_namespace && local_name == 'script' {
		return ElementInterface{
			element_name: 'HTMLScriptElement'
			element_ns: namespace
		}
	}
	if namespace == svg_namespace && local_name == 'script' {
		return ElementInterface{
			element_name: 'SVGScriptElement'
			element_ns: namespace
		}
	}
	return ElementInterface{
		element_name: 'Element'
		element_ns: namespace
	}
}

pub fn get_trusted_type_data_for_attribute(element ElementInterface, attribute string, attribute_ns ?string) ?TrustedTypeData {
	actual_attribute := attribute.to_lower()
	valid_svg_href_namespace := if namespace := attribute_ns {
		namespace == xlink_namespace
	} else {
		true
	}
	if attribute_ns == none
		&& element.element_ns in [html_namespace, svg_namespace, mathml_namespace]
		&& actual_attribute in event_handler_attributes {
		return TrustedTypeData{
			element: 'Element'
			attribute_local_name: actual_attribute
			trusted_type: .trusted_script
			sink: .element_event_handler
		}
	}
	mut name := TrustedTypeName.trusted_html
	mut sink := InjectionSink.html_iframe_element_srcdoc
	if attribute_ns == none && element.element_name == 'HTMLIFrameElement'
		&& actual_attribute == 'srcdoc' {
		name = .trusted_html
		sink = .html_iframe_element_srcdoc
	} else if attribute_ns == none && element.element_name == 'HTMLScriptElement'
		&& actual_attribute == 'src' {
		name = .trusted_script_url
		sink = .html_script_element_src
	} else if element.element_name == 'SVGScriptElement' && actual_attribute == 'href'
		&& valid_svg_href_namespace {
		name = .trusted_script_url
		sink = .svg_script_element_href
	} else {
		return none
	}
	return TrustedTypeData{
		element: element.element_name
		attribute_ns: attribute_ns
		attribute_local_name: actual_attribute
		trusted_type: name
		sink: sink
	}
}

pub fn (factory &TrustedTypePolicyFactory) get_attribute_type(tag_name string, attribute string, element_ns ?string, attribute_ns ?string) ?string {
	namespace := element_ns or { html_namespace }
	actual_namespace := if namespace == '' { html_namespace } else { namespace }
	actual_attribute_ns := if value := attribute_ns {
		if value == '' { none } else { value }
	} else {
		none
	}
	data := get_trusted_type_data_for_attribute(element_interface(tag_name.to_lower(), actual_namespace), attribute.to_lower(), actual_attribute_ns) or { return none }
	return trusted_type_name_string(data.trusted_type)
}

pub fn (factory &TrustedTypePolicyFactory) get_property_type(tag_name string, property string, element_ns ?string) ?string {
	namespace := element_ns or { html_namespace }
	interface_name := element_interface(tag_name.to_lower(), if namespace == '' {
		html_namespace
	} else {
		namespace
	}).element_name
	name := match '${interface_name}|${property}' {
		'HTMLIFrameElement|srcdoc' {
			TrustedTypeName.trusted_html
		}
		'HTMLScriptElement|innerText', 'HTMLScriptElement|text', 'HTMLScriptElement|textContent' {
			TrustedTypeName.trusted_script
		}
		'HTMLScriptElement|src' {
			TrustedTypeName.trusted_script_url
		}
		else {
			if property in ['innerHTML', 'outerHTML'] {
				TrustedTypeName.trusted_html
			} else {
				return none
			}
		}
	}
	return trusted_type_name_string(name)
}

pub fn (mut factory TrustedTypePolicyFactory) pre_navigation_check(url string) !string {
	if !url.starts_with('javascript:') {
		return url
	}
	converted := process_value_with_a_default_policy(factory, .trusted_script, url['javascript:'.len..], .location_href)!
	trusted := converted.value or { return error('Blocked') }
	if trusted is TrustedScript {
		return 'javascript:${trusted.data}'
	}
	return error('Blocked')
}
