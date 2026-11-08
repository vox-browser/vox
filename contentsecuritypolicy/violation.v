// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Violation.{h,cpp}. Fetching report endpoints is represented by
// CSPReportRequest records at the embedder boundary.
module contentsecuritypolicy

import dom
import url

pub enum ViolationResourceKind {
	inline
	eval
	wasm_eval
	trusted_types_policy
	trusted_types_sink
}

pub struct EmptyResource {}

pub type ViolationResource = EmptyResource | ViolationResourceKind | url.URL

pub struct ViolationReport {
pub:
	document_uri        string
	referrer            string
	blocked_uri         string
	effective_directive string
	violated_directive  string
	original_policy     string
	disposition         Disposition
	status_code         u16
	source_file         string
	line_number         u32
	column_number       u32
	sample              string
}

pub struct CSPReportRequest {
pub:
	endpoint     string
	method       string = 'POST'
	content_type string = 'application/csp-report'
	body         string
	keepalive    bool = true
}

@[heap]
pub struct Violation {
pub mut:
	global_url url.URL
mut:
	status_              u16
	resource_            ?ViolationResource
	referrer_            ?url.URL
	policy_              &Policy = unsafe { nil }
	effective_directive_ string
	source_file_         ?url.URL
	line_number_         u32
	column_number_       u32
	element_             ?ElementContext
	sample_              string
}

fn global_scope_from_global_object(global_object ?&GlobalContext) ?&GlobalContext {
	if global_scope := global_object {
		return global_scope
	}
	return none
}

pub fn create_a_violation_object_for_global_policy_and_directive(global &GlobalContext, policy &Policy, directive string) &Violation {
	global_scope := global_scope_from_global_object(global) or { panic('missing CSP global scope') }
	return &Violation{
		global_url: global_scope.url
		referrer_: global_scope.referrer
		policy_: policy
		effective_directive_: directive
	}
}

pub fn Violation.create_a_violation_object_for_global_policy_and_directive(global &GlobalContext, policy &Policy, directive string) &Violation {
	return create_a_violation_object_for_global_policy_and_directive(global, policy, directive)
}

pub fn create_a_violation_object_for_request_and_policy(global &GlobalContext, request &Request, policy &Policy) &Violation {
	directive := get_the_effective_directive_for_request(request) or { default_src }
	mut violation := create_a_violation_object_for_global_policy_and_directive(global, policy, directive)
	violation.set_resource(ViolationResource(request.url))
	return violation
}

pub fn Violation.create_a_violation_object_for_request_and_policy(global &GlobalContext, request &Request, policy &Policy) &Violation {
	return create_a_violation_object_for_request_and_policy(global, request, policy)
}

pub fn (violation &Violation) status() u16 {
	return violation.status_
}

pub fn (mut violation Violation) set_status(status u16) {
	violation.status_ = status
}

pub fn (violation &Violation) resource() ?ViolationResource {
	return violation.resource_
}

pub fn (mut violation Violation) set_resource(resource ViolationResource) {
	violation.resource_ = resource
}

pub fn (violation &Violation) referrer() ?url.URL {
	return violation.referrer_
}

pub fn (violation &Violation) policy() &Policy {
	return violation.policy_
}

pub fn (violation &Violation) disposition() Disposition {
	return violation.policy_.disposition()
}

pub fn (violation &Violation) effective_directive() string {
	return violation.effective_directive_
}

pub fn (violation &Violation) source_file() ?url.URL {
	return violation.source_file_
}

pub fn (mut violation Violation) set_source_file(source_file url.URL) {
	violation.source_file_ = source_file
}

pub fn (violation &Violation) line_number() u32 {
	return violation.line_number_
}

pub fn (mut violation Violation) set_line_number(line_number u32) {
	violation.line_number_ = line_number
}

pub fn (violation &Violation) column_number() u32 {
	return violation.column_number_
}

pub fn (mut violation Violation) set_column_number(column_number u32) {
	violation.column_number_ = column_number
}

pub fn (violation &Violation) element() ?ElementContext {
	return violation.element_
}

pub fn (mut violation Violation) set_element(element ElementContext) {
	violation.element_ = element
}

pub fn (violation &Violation) sample() string {
	return violation.sample_
}

pub fn (mut violation Violation) set_sample(sample string) {
	violation.sample_ = sample
}

pub fn (violation &Violation) url() url.URL {
	return violation.global_url
}

pub fn strip_url_for_use_in_reports(record url.URL) string {
	if !is_http_or_https_scheme(record.scheme) {
		return record.scheme
	}
	mut stripped := record
	stripped.fragment = none
	stripped.username = ''
	stripped.password = ''
	return stripped.serialize(false)
}

pub fn original_disposition_to_string(disposition Disposition) string {
	return match disposition {
		.enforce { 'enforce' }
		.report { 'report' }
	}
}

pub fn original_disposition_to_bindings_disposition(disposition Disposition) Disposition {
	return disposition
}

pub fn (violation &Violation) obtain_the_blocked_uri_of_resource() string {
	resource := violation.resource_ or { return '' }
	return match resource {
		url.URL {
			strip_url_for_use_in_reports(resource)
		}
		ViolationResourceKind {
			match resource {
				.inline { 'inline' }
				.eval { 'eval' }
				.wasm_eval { 'wasm-eval' }
				.trusted_types_policy { 'trusted-types-policy' }
				.trusted_types_sink { 'trusted-types-sink' }
			}
		}
		EmptyResource {
			''
		}
	}
}

fn json_escape(value string) string {
	mut result := ''
	for code_point in value.runes() {
		result += match code_point {
			`"` { '\\"' }
			`\\` { '\\\\' }
			`\n` { '\\n' }
			`\r` { '\\r' }
			`\t` { '\\t' }
			else { code_point.str() }
		}
	}
	return result
}

pub fn (violation &Violation) obtain_the_deprecated_serialization() string {
	referrer := if value := violation.referrer_ { strip_url_for_use_in_reports(value) } else { '' }
	source_file := if value := violation.source_file_ {
		strip_url_for_use_in_reports(value)
	} else {
		''
	}
	disposition := original_disposition_to_string(violation.policy_.disposition())
	mut fields := [
		'"document-uri":"${json_escape(strip_url_for_use_in_reports(violation.url()))}"',
		'"referrer":"${json_escape(referrer)}"',
		'"blocked-uri":"${json_escape(violation.obtain_the_blocked_uri_of_resource())}"',
		'"effective-directive":"${json_escape(violation.effective_directive_)}"',
		'"violated-directive":"${json_escape(violation.effective_directive_)}"',
		'"original-policy":"${json_escape(violation.policy_.pre_parsed_policy_string())}"',
		'"disposition":"${disposition}"',
		'"status-code":${violation.status_}',
		'"script-sample":"${json_escape(violation.sample_)}"',
	]
	if source_file != '' {
		fields << '"source-file":"${json_escape(source_file)}"'
		fields << '"line-number":${violation.line_number_}'
		fields << '"column-number":${violation.column_number_}'
	}
	return '{"csp-report":{${fields.join(',')}}}'
}

fn resolve_report_endpoint(token string, base url.URL) ?string {
	if token.contains('://') {
		return token
	}
	if token.starts_with('/') {
		host := base.host or { return none }
		mut value := '${base.scheme}://${host.serialize()}'
		if port := base.port {
			value += ':${port}'
		}
		return value + token
	}
	return none
}

pub fn (violation &Violation) as_report() ViolationReport {
	return ViolationReport{
		document_uri: strip_url_for_use_in_reports(violation.url())
		referrer: if value := violation.referrer_ {
			strip_url_for_use_in_reports(value)
		} else {
			''
		}
		blocked_uri: violation.obtain_the_blocked_uri_of_resource()
		effective_directive: violation.effective_directive_
		violated_directive: violation.effective_directive_
		original_policy: violation.policy_.pre_parsed_policy_string()
		disposition: violation.policy_.disposition()
		status_code: violation.status_
		source_file: if value := violation.source_file_ {
			strip_url_for_use_in_reports(value)
		} else {
			''
		}
		line_number: violation.line_number_
		column_number: violation.column_number_
		sample: violation.sample_
	}
}

pub fn (violation &Violation) report_a_violation(mut global GlobalContext) {
	report := violation.as_report()
	global.reports << report
	init := SecurityPolicyViolationEventInit{
		EventInit: dom.EventInit{
			bubbles: true
			composed: true
		}
		document_uri: report.document_uri
		referrer: report.referrer
		blocked_uri: report.blocked_uri
		effective_directive: report.effective_directive
		violated_directive: report.violated_directive
		original_policy: report.original_policy
		disposition: report.disposition
		source_file: report.source_file
		status_code: report.status_code
		line_number: report.line_number
		column_number: report.column_number
		sample: report.sample
	}
	mut event := SecurityPolicyViolationEvent.create('securitypolicyviolation', init)
	if element := violation.element_ { event.policy_element = element.dom_element }
	event.set_is_trusted(true)
	global.events << *event
	if dispatch := global.dispatch_violation_event {
		dispatch(event)
	}
	if report_uris := violation.policy_.get_directive_by_name(report_uri) {
		if !violation.policy_.contains_directive_with_name(report_to) {
			for token in report_uris.value() {
				if endpoint := resolve_report_endpoint(token, violation.url()) {
					global.report_requests << CSPReportRequest{
						endpoint: endpoint
						body: violation.obtain_the_deprecated_serialization()
					}
				}
			}
		}
	}
}
