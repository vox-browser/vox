// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Fetch/Infrastructure/HTTP/Requests.{h,cpp} — the Fetch
// `request` record (https://fetch.spec.whatwg.org/#concept-request): its enumerations, fields,
// and the url()/current_url() accessors. The header list is a real http.HeaderList; the remaining
// untranslated Fetch/HTML dependencies (the Body object, the client environment settings object,
// policy containers, pending responses) are held opaquely and noted at each field.
module fetch

import dom
import http

// https://fetch.spec.whatwg.org/#concept-request-credentials-mode
pub enum CredentialsMode {
	omit
	same_origin
	include
}

// https://fetch.spec.whatwg.org/#concept-request-destination
pub enum Destination {
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
}

pub enum Initiator {
	download
	image_set
	manifest
	prefetch
	prerender
	xslt
}

pub enum InitiatorType {
	audio
	beacon
	body
	css
	early_hint
	embed
	fetch
	font
	frame
	iframe
	image
	img
	input
	link
	object
	ping
	script
	track
	video
	xml_http_request
	other
}

// https://fetch.spec.whatwg.org/#concept-request-mode
pub enum Mode {
	same_origin
	cors
	no_cors
	navigate
	websocket
}

// https://fetch.spec.whatwg.org/#concept-request-origin (the "client" sentinel).
pub enum OriginSentinel {
	client
}

pub enum ParserMetadata {
	parser_inserted
	not_parser_inserted
}

pub enum PolicyContainerSentinel {
	client
}

// https://fetch.spec.whatwg.org/#concept-request-redirect-mode
pub enum RedirectMode {
	follow
	error
	manual
}

pub enum ReferrerSentinel {
	no_referrer
	client
}

// https://fetch.spec.whatwg.org/#concept-request-response-tainting
pub enum ResponseTainting {
	basic
	cors
	opaque
}

pub enum ServiceWorkersMode {
	all
	none
}

pub enum TraversableForUserPrompts {
	no_traversable
	client
}

pub enum Priority {
	high
	low
	auto
}

// HTTP::CacheMode (Fetch/Infrastructure/HTTP.h).
pub enum CacheMode {
	default
	no_store
	reload
	no_cache
	force_cache
	only_if_cached
}

// https://fetch.spec.whatwg.org/#concept-request-referrer (the request's referrer: "no-referrer",
// "client", or a URL). Modelled as a sentinel plus an optional explicit referrer URL.
pub struct Referrer {
pub mut:
	sentinel ReferrerSentinel = .client
	url      ?dom.URL
}

// https://fetch.spec.whatwg.org/#concept-request-origin: "client" or an origin.
pub struct RequestOrigin {
pub mut:
	is_client bool = true
	origin    ?dom.Origin
}

// https://fetch.spec.whatwg.org/#concept-request-body: null (Empty), a byte sequence, or a Body.
pub enum RequestBodyKind {
	empty
	bytes
	body_object
}

pub struct RequestBody {
pub mut:
	kind  RequestBodyKind = .empty
	bytes []u8
	// The GC::Ref<Body> alternative is opaque (Body is not translated).
}

// https://fetch.spec.whatwg.org/#concept-request
@[heap]
pub struct Request {
pub mut:
	// https://fetch.spec.whatwg.org/#concept-request-method
	method string = 'GET'
	// https://fetch.spec.whatwg.org/#local-urls-only-flag
	local_urls_only bool
	// https://fetch.spec.whatwg.org/#concept-request-header-list
	header_list &http.HeaderList = http.HeaderList.create()
	// https://fetch.spec.whatwg.org/#unsafe-request-flag
	unsafe_request bool
	// https://fetch.spec.whatwg.org/#concept-request-body
	body RequestBody
	// The client is an EnvironmentSettingsObject (not translated) — held opaquely.
	client                       voidptr = unsafe { nil }
	replaces_client_id           string
	traversable_for_user_prompts TraversableForUserPrompts = .client
	keepalive                    bool
	initiator_type               ?InitiatorType
	service_workers_mode         ServiceWorkersMode = .all
	initiator                    ?Initiator
	destination                  ?Destination
	priority                     Priority = .auto
	// https://fetch.spec.whatwg.org/#concept-request-origin
	origin                                RequestOrigin
	top_level_navigation_initiator_origin ?dom.Origin
	// PolicyContainerType = Variant<PolicyContainer, GC::Ref<PolicyContainer>>; the container is
	// held opaquely and the sentinel captures the "client" case.
	policy_container PolicyContainerSentinel = .client
	// https://fetch.spec.whatwg.org/#concept-request-referrer
	referrer Referrer
	// https://fetch.spec.whatwg.org/#concept-request-referrer-policy
	// The referrer policy is a ReferrerPolicy (default the empty string) — kept as its string form.
	referrer_policy string
	// https://fetch.spec.whatwg.org/#concept-request-mode
	mode               Mode = .no_cors
	use_cors_preflight bool
	// https://fetch.spec.whatwg.org/#concept-request-credentials-mode
	credentials_mode    CredentialsMode = .same_origin
	use_url_credentials bool
	// https://fetch.spec.whatwg.org/#concept-request-cache-mode
	cache_mode CacheMode = .default
	// https://fetch.spec.whatwg.org/#concept-request-redirect-mode
	redirect_mode                RedirectMode = .follow
	integrity_metadata           string
	cryptographic_nonce_metadata string
	parser_metadata              ?ParserMetadata
	reload_navigation            bool
	history_navigation           bool
	user_activation              bool
	render_blocking              bool
	// https://fetch.spec.whatwg.org/#concept-request-url-list
	url_list []dom.URL
	// https://fetch.spec.whatwg.org/#concept-request-redirect-count
	redirect_count u8
	// https://fetch.spec.whatwg.org/#concept-request-response-tainting
	response_tainting                                  ResponseTainting = .basic
	prevent_no_cache_cache_control_header_modification bool
	done                                               bool
	timing_allow_failed                                bool
	// Pending responses (Fetching::PendingResponse) are not translated — held opaquely.
	request_time i64
}

pub fn Request.create() &Request {
	return &Request{}
}

// https://fetch.spec.whatwg.org/#concept-request-url
// A request's URL is the first URL in its URL list.
pub fn (request &Request) url() dom.URL {
	// VERIFY(!m_url_list.is_empty()).
	return request.url_list.first()
}

// https://fetch.spec.whatwg.org/#concept-request-current-url
// A request's current URL is the last URL in its URL list.
pub fn (request &Request) current_url() dom.URL {
	// VERIFY(!m_url_list.is_empty()).
	return request.url_list.last()
}

// https://fetch.spec.whatwg.org/#request-destination-script-like
pub fn destination_is_script_like(destination Destination) bool {
	// "audioworklet", "paintworklet", "script", "serviceworker", "sharedworker", or "worker".
	return destination in [Destination.audio_worklet, .paint_worklet, .script, .service_worker,
		.shared_worker, .worker]
}

pub fn (request &Request) destination_is_script_like() bool {
	destination := request.destination or { return false }
	return destination_is_script_like(destination)
}
