// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module fetch

import contentsecuritypolicy as csp
import mixedcontentcore
import url

// EnvironmentSettingsObject implements this independently of the general
// RequestClient projection, allowing clients without a global object (browser
// UI, cache records) to retain the upstream null-client behavior.
pub interface RequestSecurityClient {
	fetch_request_client_mixed_security_context() mixedcontentcore.EnvironmentSettings
	fetch_request_client_csp_global() &csp.GlobalContext
}

fn request_security_context(request &Request) mixedcontentcore.EnvironmentSettings {
	if client := request.client {
		if client is RequestSecurityClient {
			return client.fetch_request_client_mixed_security_context()
		}
	}
	return mixedcontentcore.EnvironmentSettings{}
}

fn csp_request(request &Request) csp.Request {
	container := request.resolved_policy_container or { RequestPolicyContainer{} }
	initial := url.parse(request.url().serialize()) or { panic('invalid Fetch request URL') }
	current := url.parse(request.current_url().serialize()) or {
		panic('invalid Fetch request URL')
	}
	mut destination := ?csp.RequestDestination(none)
	if value := request.destination {
		destination = match value {
			.audio { csp.RequestDestination.audio }
			.audio_worklet { csp.RequestDestination.audio_worklet }
			.document {
				if request.target_is_nested_navigable { csp.RequestDestination.iframe }
				else { csp.RequestDestination.document }
			}
			.embed { csp.RequestDestination.embed }
			.font { csp.RequestDestination.font }
			.frame { csp.RequestDestination.frame }
			.iframe { csp.RequestDestination.iframe }
			.image { csp.RequestDestination.image }
			.json { csp.RequestDestination.json }
			.manifest { csp.RequestDestination.manifest }
			.object { csp.RequestDestination.object }
			.paint_worklet { csp.RequestDestination.paint_worklet }
			.report { csp.RequestDestination.report }
			.script { csp.RequestDestination.script }
			.service_worker { csp.RequestDestination.service_worker }
			.shared_worker { csp.RequestDestination.shared_worker }
			.style { csp.RequestDestination.style }
			.track { csp.RequestDestination.track }
			.video { csp.RequestDestination.video }
			.web_identity { csp.RequestDestination.web_identity }
			.worker { csp.RequestDestination.worker }
			.xslt { csp.RequestDestination.xslt }
			.text { csp.RequestDestination.other }
		}
	}
	return csp.Request{
		url:                          initial
		current_url:                  current
		destination:                  destination
		initiator:                    if (request.initiator or { Initiator.download }) == .prefetch {
			.prefetch
		} else {
			.other
		}
		cryptographic_nonce_metadata: request.cryptographic_nonce_metadata
		integrity_metadata:           request.integrity_metadata
		redirect_count:               request.redirect_count
		parser_metadata:              if (request.parser_metadata or {
			ParserMetadata.not_parser_inserted
		}) == .parser_inserted {
			.parser_inserted
		} else {
			.not_parser_inserted
		}
		mode:                         match request.mode {
			.cors { .cors }
			.same_origin { .same_origin }
			.navigate { .navigate }
			else { .no_cors }
		}
		is_local:                     is_local_url(request.url())
		policy_list:                  container.csp_list
		integrity_policy:             container.integrity_policy
		report_only_integrity_policy: container.report_only_integrity_policy
	}
}

pub fn csp_response(response &Response) csp.Response {
	return csp.Response{
		url:         if value := response.url() { value.parsed() } else { none }
		status:      response.status
		header_list: response.header_list
	}
}

fn request_csp_global(mut request Request) &csp.GlobalContext {
	if global := request.csp_global { return global }
	if client := request.client {
		if client is RequestSecurityClient {
			global := client.fetch_request_client_csp_global()
			request.csp_global = global
			return global
		}
	}
	global := &csp.GlobalContext{
		url:         url.parse((request.client_creation_url or { request.url() }).serialize()) or {
			panic('invalid global URL')
		}
		policy_list: (request.resolved_policy_container or { RequestPolicyContainer{} }).csp_list
	}
	request.csp_global = global
	return global
}

// Fetching.cpp main-fetch steps 4, 6 and 7, retaining the required order:
// report-only CSP observes the original URL, then eligible mixed content is
// upgraded, then bad-port, mixed-content, enforced CSP and integrity checks run.
fn apply_request_security_policies(mut request Request) bool {
	// SVG images are self-contained; block before preload/cache/transport and
	// reapply this check after filtering rewrites or HTTP redirects.
	if request.client_is_svg_image && request.current_url().scheme() != 'data' {
		return true
	}
	mut global := request_csp_global(mut request)
	before_upgrade := csp_request(request)
	csp.report_content_security_policy_violations_for_request(mut global, before_upgrade)
	context := request_security_context(request)
	destination := if value := request.destination {
		?string(request_destination_to_string(value))
	} else {
		none
	}
	request.url_list[request.url_list.len - 1] = mixedcontentcore.upgraded_request_url(request.current_url(), destination, (request.initiator or {
		Initiator.download
	}) == .image_set, context)
	policy_request := csp_request(request)
	return block_bad_port(request) == .blocked
		|| mixedcontentcore.should_request_be_blocked(request.current_url(), destination, context)
		|| csp.should_request_be_blocked_by_content_security_policy(mut global, policy_request) == .blocked
		|| csp.should_request_be_blocked_by_integrity_policy(policy_request) == .blocked
}

// Fetching.cpp main-fetch step 20. This uses the internal response URL and
// headers before exposing a filtered response to callers.
fn response_blocked_by_security_policy(mut request Request, response &Response) bool {
	context := request_security_context(request)
	destination := if value := request.destination {
		?string(request_destination_to_string(value))
	} else {
		none
	}
	if mixedcontentcore.should_response_be_blocked(response.url(), destination, context) {
		return true
	}
	mut global := request_csp_global(mut request)
	return csp.should_response_to_request_be_blocked_by_content_security_policy(mut global,
		csp_response(response), csp_request(request)) == .blocked
}
