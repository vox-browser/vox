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
	global_url          url.URL
	status              u16
	resource            ?ViolationResource
	referrer            ?url.URL
	policy              &Policy = unsafe { nil }
	effective_directive string
	source_file         ?url.URL
	line_number         u32
	column_number       u32
	element             ?ElementContext
	sample              string
}

pub fn create_a_violation_object_for_global_policy_and_directive(global &GlobalContext, policy &Policy, directive string) &Violation {
	return &Violation{
		global_url:          global.url
		referrer:            global.referrer
		policy:              policy
		effective_directive: directive
	}
}

pub fn create_a_violation_object_for_request_and_policy(global &GlobalContext, request &Request, policy &Policy) &Violation {
	directive := get_the_effective_directive_for_request(request) or { default_src }
	mut violation := create_a_violation_object_for_global_policy_and_directive(global, policy,
		directive)
	violation.resource = ViolationResource(request.url)
	return violation
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

pub fn (violation &Violation) obtain_the_blocked_uri_of_resource() string {
	resource := violation.resource or { return '' }
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
	referrer := if value := violation.referrer { strip_url_for_use_in_reports(value) } else { '' }
	source_file := if value := violation.source_file {
		strip_url_for_use_in_reports(value)
	} else {
		''
	}
	disposition := if violation.policy.disposition == .enforce { 'enforce' } else { 'report' }
	mut fields := [
		'"document-uri":"${json_escape(strip_url_for_use_in_reports(violation.url()))}"',
		'"referrer":"${json_escape(referrer)}"',
		'"blocked-uri":"${json_escape(violation.obtain_the_blocked_uri_of_resource())}"',
		'"effective-directive":"${json_escape(violation.effective_directive)}"',
		'"violated-directive":"${json_escape(violation.effective_directive)}"',
		'"original-policy":"${json_escape(violation.policy.pre_parsed_policy_string)}"',
		'"disposition":"${disposition}"',
		'"status-code":${violation.status}',
		'"script-sample":"${json_escape(violation.sample)}"',
	]
	if source_file != '' {
		fields << '"source-file":"${json_escape(source_file)}"'
		fields << '"line-number":${violation.line_number}'
		fields << '"column-number":${violation.column_number}'
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
		document_uri:        strip_url_for_use_in_reports(violation.url())
		referrer:            if value := violation.referrer {
			strip_url_for_use_in_reports(value)
		} else {
			''
		}
		blocked_uri:         violation.obtain_the_blocked_uri_of_resource()
		effective_directive: violation.effective_directive
		violated_directive:  violation.effective_directive
		original_policy:     violation.policy.pre_parsed_policy_string
		disposition:         violation.policy.disposition
		status_code:         violation.status
		source_file:         if value := violation.source_file {
			strip_url_for_use_in_reports(value)
		} else {
			''
		}
		line_number:         violation.line_number
		column_number:       violation.column_number
		sample:              violation.sample
	}
}

pub fn (violation &Violation) report_a_violation(mut global GlobalContext) {
	report := violation.as_report()
	global.reports << report
	init := SecurityPolicyViolationEventInit{
		EventInit:           dom.EventInit{
			bubbles:  true
			composed: true
		}
		document_uri:        report.document_uri
		referrer:            report.referrer
		blocked_uri:         report.blocked_uri
		effective_directive: report.effective_directive
		violated_directive:  report.violated_directive
		original_policy:     report.original_policy
		disposition:         report.disposition
		source_file:         report.source_file
		status_code:         report.status_code
		line_number:         report.line_number
		column_number:       report.column_number
		sample:              report.sample
	}
	mut event := SecurityPolicyViolationEvent.create('securitypolicyviolation', init)
	event.set_is_trusted(true)
	global.events << *event
	if report_uris := violation.policy.get_directive_by_name(report_uri) {
		if !violation.policy.contains_directive_with_name(report_to) {
			for token in report_uris.value {
				if endpoint := resolve_report_endpoint(token, violation.url()) {
					global.report_requests << CSPReportRequest{
						endpoint: endpoint
						body:     violation.obtain_the_deprecated_serialization()
					}
				}
			}
		}
	}
}
