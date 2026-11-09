// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Typed host-facing records used by the CSP algorithms. Ladybird receives these
// values from Fetch, DOM, HTML and the JS runtime; keeping the records here makes
// the translation usable without introducing dependency cycles between those
// partially translated modules.
module contentsecuritypolicy

import dom
import http
import url

pub enum Result {
	blocked
	allowed
}

pub enum NavigationType {
	form_submission
	other
}

pub enum CheckType {
	source
	response
}

pub enum InlineType {
	navigation
	script
	script_attribute
	style
	style_attribute
}

pub enum RequestInitiator {
	none
	prefetch
	prerender
	other
}

pub enum RequestDestination {
	audio
	audio_worklet
	document
	embed
	font
	frame
	iframe
	image
	json
	manifest
	object
	paint_worklet
	report
	script
	service_worker
	shared_worker
	style
	track
	video
	web_identity
	worker
	xslt
	other
}

pub enum ParserMetadata {
	parser_inserted
	not_parser_inserted
}

pub enum RequestMode {
	no_cors
	cors
	same_origin
	navigate
}

pub struct IntegrityPolicy {
pub:
	sources              []string
	blocked_destinations []RequestDestination
}

pub fn (policy IntegrityPolicy) is_empty() bool {
	return policy.sources.len == 0 && policy.blocked_destinations.len == 0
}

@[heap]
pub struct Request {
pub mut:
	url                          url.URL
	current_url                  url.URL
	destination                  ?RequestDestination
	initiator                    RequestInitiator
	cryptographic_nonce_metadata string
	integrity_metadata           string
	redirect_count               u8
	parser_metadata              ParserMetadata
	mode                         RequestMode
	is_local                     bool
	policy_list                  &PolicyList = unsafe { nil }
	integrity_policy             IntegrityPolicy
	report_only_integrity_policy IntegrityPolicy
	global_url                   url.URL
	referrer                     ?url.URL
}

pub fn new_request(target url.URL) Request {
	return Request{
		url:         target
		current_url: target
		global_url:  target
	}
}

pub fn (request &Request) destination_is_script_like() bool {
	if destination := request.destination {
		return destination in [.script, .xslt, .audio_worklet, .paint_worklet,
			.service_worker, .shared_worker, .worker]
	}
	return false
}

pub struct Response {
pub mut:
	url         ?url.URL
	status      u16
	header_list ?&http.HeaderList
	// Standalone compatibility input; genuine Fetch projections retain header_list.
	headers     map[string][]string
	is_local    bool
}

pub struct ElementContext {
pub:
	dom_element                 ?&dom.Element
	is_html_or_svg               bool = true
	is_script                    bool
	is_style                     bool
	nonce                        string
	attributes                   map[string]string
	had_duplicate_attribute      bool
	parser_inserted              bool
	connected_to_policy_document bool = true
}

// Detached callers may provide ancestor_origins directly. In-process callers
// provide navigable so frame-ancestors can walk logical parents and remain
// independent of locally hosted container documents.
pub struct NavigableContext {
pub:
	navigable        ?&dom.Navigable
	ancestor_origins []url.Origin
}

fn opaque_context_origin() url.Origin {
	return url.Origin.opaque([16]u8{}, .standard)
}

fn context_origin_from_dom(origin dom.Origin) url.Origin {
	if origin.is_opaque() {
		return opaque_context_origin()
	}
	parsed := url.parse(origin.serialize()) or { return opaque_context_origin() }
	return parsed.origin()
}

pub fn (context NavigableContext) active_ancestor_origins() []url.Origin {
	navigable := context.navigable or { return context.ancestor_origins.clone() }
	mut origins := []url.Origin{}
	mut ancestor := navigable.parent()
	for ancestor != none {
		current := ancestor or { break }
		if origin := current.active_document_origin() {
			origins << context_origin_from_dom(origin)
		} else {
			// Missing replicated state cannot satisfy frame-ancestors.
			origins << opaque_context_origin()
		}
		ancestor = current.parent()
	}
	return origins
}

pub type ViolationEventDispatcher = fn (&SecurityPolicyViolationEvent)

pub struct GlobalContext {
pub mut:
	url             url.URL
	source_file ?url.URL
	line_number u32
	column_number u32
	referrer        ?url.URL
	policy_list     &PolicyList = unsafe { nil }
	reports         []ViolationReport
	events          []SecurityPolicyViolationEvent
	report_requests []CSPReportRequest
	dispatch_violation_event ?ViolationEventDispatcher
}

pub enum CompilationType {
	timer
	function
	eval
}

pub struct CompilationInput {
pub:
	parameter_strings          []string
	body_string                string
	code_string                string
	type_                      CompilationType
	body_arg_trusted_data      ?string
	parameter_arg_trusted_data []?string
	trusted_types_result       ?string
	trusted_types_failed       bool
}

fn origin_scheme(origin url.Origin) string {
	if origin is url.OriginTuple {
		return origin.scheme or { '' }
	}
	return ''
}

fn origin_host(origin url.Origin) ?url.Host {
	if origin is url.OriginTuple {
		return origin.host
	}
	return none
}

fn origin_port(origin url.Origin) ?u16 {
	if origin is url.OriginTuple {
		return origin.port
	}
	return none
}
