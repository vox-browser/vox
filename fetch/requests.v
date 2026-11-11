// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Fetch/Infrastructure/HTTP/Requests.{h,cpp} — the Fetch
// `request` record (https://fetch.spec.whatwg.org/#concept-request): its enumerations, fields,
// and the url()/current_url() accessors. The header list and Body are translated types; HTML client
// environments and policy containers enter through the typed projections noted at their fields.
module fetch

import dom
import contentsecuritypolicy
import http
import time
import url as liburl

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
	text
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

// The parts of HTML's PolicyContainer that fetching reads. A new policy container has the default referrer policy.
pub struct RequestPolicyContainer {
pub:
	referrer_policy string = 'strict-origin-when-cross-origin'
	csp_list &contentsecuritypolicy.PolicyList = contentsecuritypolicy.PolicyList.create([]&contentsecuritypolicy.Policy{})
	integrity_policy contentsecuritypolicy.IntegrityPolicy
	report_only_integrity_policy contentsecuritypolicy.IntegrityPolicy
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
	kind        RequestBodyKind = .empty
	bytes       []u8
	body_object ?&Body
}

// Infrastructure::Request stores an HTML::EnvironmentSettingsObject. Fetch
// cannot import HTML (HTML itself imports Fetch), so retain the typed behavior
// through the structurally implemented client contract instead of a voidptr
// plus manually synchronized flags.
pub interface RequestClient {
	fetch_request_client_api_base_url() dom.URL
	fetch_request_client_is_window() bool
	fetch_request_client_is_top_level_window() bool
	fetch_request_client_origin() dom.Origin
	fetch_request_client_document_url() ?dom.URL
	fetch_request_client_creation_url() dom.URL
	fetch_request_client_embedder_policy_credentialless() bool
	fetch_request_client_top_level_origin() ?dom.Origin
	fetch_request_client_top_level_creation_url() ?dom.URL
	fetch_request_client_cross_origin_isolated_capability() bool
	fetch_request_client_policy_container() RequestPolicyContainer
}

// Optional client capability: decoded SVG documents have a more restrictive
// resource policy than ordinary SVG documents loaded as pages.
pub interface SVGImageRequestClient {
	fetch_request_client_is_svg_image() bool
}

// Infrastructure::Request::ReservedClientType is HTML::Environment, distinct
// from the EnvironmentSettingsObject stored in client.
pub interface RequestReservedClient {
	fetch_request_environment_blob_url_origin() liburl.Origin
	fetch_request_environment_creation_url() dom.URL
	fetch_request_environment_top_level_origin() ?dom.Origin
	fetch_request_environment_top_level_creation_url() ?dom.URL
}

// https://fetch.spec.whatwg.org/#concept-request
@[heap]
pub struct Request {

	// https://fetch.spec.whatwg.org/#concept-request-method
pub mut:
	method string = 'GET'
	// https://fetch.spec.whatwg.org/#local-urls-only-flag
	local_urls_only bool
	// https://fetch.spec.whatwg.org/#concept-request-header-list
	header_list &http.HeaderList = http.HeaderList.create()
	// https://fetch.spec.whatwg.org/#unsafe-request-flag
	unsafe_request bool
	// https://fetch.spec.whatwg.org/#concept-request-body
	body   RequestBody
	client ?RequestClient
	// Typed observable projection of the environment used by ReferrerPolicy.
	// A Window client uses document_url; other clients use creation_url.
	client_is_window               bool
	client_is_svg_image            bool
	client_is_top_level_window     bool
	client_origin_opaque           bool
	client_document_url            ?dom.URL
	client_creation_url            ?dom.URL
	client_present                 bool
	embedder_policy_credentialless bool
	reserved_client                ?RequestReservedClient
	replaces_client_id             string
	traversable_for_user_prompts   TraversableForUserPrompts = .client
	keepalive                      bool
	initiator_type                 ?InitiatorType
	service_workers_mode           ServiceWorkersMode = .all
	initiator                      ?Initiator
	destination                    ?Destination
	// Embedding metadata for content filtering: navigation's Fetch destination
	// remains document for both top-level and nested target navigables.
	target_is_nested_navigable      bool
	priority                       Priority = .auto
	// https://fetch.spec.whatwg.org/#concept-request-origin
	origin                                RequestOrigin
	top_level_navigation_initiator_origin ?dom.Origin
	// PolicyContainerType = Variant<PolicyContainer, GC::Ref<PolicyContainer>>; the container is
	// held opaquely and the sentinel captures the "client" case.
	policy_container PolicyContainerSentinel = .client
	// The policy container that populate-from-client resolves "client" to. HTML owns PolicyContainer, which Fetch
	// cannot import; fetching reads only its referrer policy.
	resolved_policy_container ?RequestPolicyContainer
	csp_global ?&contentsecuritypolicy.GlobalContext
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
	// https://fetch.spec.whatwg.org/#request-navigation-timing-allow-values-list
	navigation_timing_allow_values_list_ [][]string
	// Pending responses are represented by Fetching::PendingResponse in runtime.v.
	pending_responses []&PendingResponse
	request_time      i64
}

pub fn Request.create() &Request {
	return &Request{
		request_time: i64(time.now().unix_milli())
	}
}

pub fn (mut request Request) set_client(client RequestClient) {
	request.client = client
	request.client_present = true
	request.client_is_window = client.fetch_request_client_is_window()
	request.client_is_svg_image = if client is SVGImageRequestClient {
		client.fetch_request_client_is_svg_image()
	} else { false }
	request.client_is_top_level_window = client.fetch_request_client_is_top_level_window()
	request.client_origin_opaque = client.fetch_request_client_origin().value == 'opaque'
	request.client_document_url = client.fetch_request_client_document_url()
	request.client_creation_url = client.fetch_request_client_creation_url()
	request.embedder_policy_credentialless = client.fetch_request_client_embedder_policy_credentialless()
}

pub fn (mut request Request) clear_client() {
	request.client = none
	request.client_present = false
	request.client_is_window = false
	request.client_is_svg_image = false
	request.client_is_top_level_window = false
	request.client_origin_opaque = false
	request.client_document_url = none
	request.client_creation_url = none
	request.embedder_policy_credentialless = false
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

pub fn (mut request Request) set_url(url dom.URL) {
	request.url_list = [url]
}

pub fn (request &Request) is_subresource_request() bool {
	destination := request.destination or { return true }
	return destination in [Destination.audio, .audio_worklet, .font, .image, .json, .manifest,
		.paint_worklet, .script, .style, .text, .track, .video, .xslt]
}

pub fn (request &Request) is_non_subresource_request() bool {
	destination := request.destination or { return false }
	return destination in [Destination.document, .embed, .frame, .iframe, .object, .report,
		.service_worker, .shared_worker, .worker]
}

pub fn (request &Request) is_navigation_request() bool {
	destination := request.destination or { return false }
	return destination in [Destination.document, .embed, .frame, .iframe, .object]
}

pub fn (request &Request) navigation_timing_allow_values_list() [][]string {
	return clone_navigation_timing_allow_values_list(request.navigation_timing_allow_values_list_)
}

// https://fetch.spec.whatwg.org/#append-to-a-requests-navigation-timing-allow-values-list
pub fn (mut request Request) append_to_navigation_timing_allow_values_list(response &Response) {
	assert request.is_navigation_request()
	tao_values := response.fetch_response_header_list().get_decode_and_split('Timing-Allow-Origin') or {
		[]string{}
	}
	request.navigation_timing_allow_values_list_ << tao_values
}

fn request_same_site(a dom.URL, b dom.URL) bool {
	return a.origin().is_same_site(b.origin())
}

pub fn (request &Request) redirect_taint() RedirectTaint {
	mut last := ?dom.URL(none)
	mut taint := RedirectTaint.same_origin
	for current in request.url_list {
		previous := last or {
			last = current
			continue
		}

		origin_is_same_site_as_previous := if origin := request.origin.origin {
			origin.is_same_site(previous.origin())
		} else {
			false
		}
		origin_is_same_origin_as_previous := if origin := request.origin.origin {
			origin.is_same_origin(previous.origin())
		} else {
			false
		}
		if !request_same_site(current, previous) && !origin_is_same_site_as_previous {
			return .cross_site
		}
		if !current.origin().is_same_origin(previous.origin()) && !origin_is_same_origin_as_previous {
			taint = .same_site
		}
		last = current
	}
	return taint
}

pub fn (request &Request) serialize_origin() string {
	if request.redirect_taint() != .same_origin {
		return 'null'
	}
	origin := request.origin.origin or { return 'null' }
	return origin.serialize()
}

pub fn (request &Request) clone() &Request {
	mut headers := http.HeaderList.create()
	for header in request.header_list.headers() {
		headers.append(header)
	}
	return &Request{
		method: request.method
		local_urls_only: request.local_urls_only
		header_list: headers
		unsafe_request: request.unsafe_request
		body: RequestBody{
			kind: request.body.kind
			bytes: request.body.bytes.clone()
			body_object: clone_body(request.body.body_object)
		}
		client: request.client
		client_is_window: request.client_is_window
		client_is_svg_image: request.client_is_svg_image
		client_is_top_level_window: request.client_is_top_level_window
		client_origin_opaque: request.client_origin_opaque
		client_document_url: request.client_document_url
		client_creation_url: request.client_creation_url
		client_present: request.client_present
		embedder_policy_credentialless: request.embedder_policy_credentialless
		reserved_client: request.reserved_client
		replaces_client_id: request.replaces_client_id
		traversable_for_user_prompts: request.traversable_for_user_prompts
		keepalive: request.keepalive
		initiator_type: request.initiator_type
		service_workers_mode: request.service_workers_mode
		initiator: request.initiator
		destination: request.destination
		target_is_nested_navigable: request.target_is_nested_navigable
		priority: request.priority
		origin: request.origin
		policy_container: request.policy_container
		resolved_policy_container: request.resolved_policy_container
		referrer: request.referrer
		referrer_policy: request.referrer_policy
		mode: request.mode
		use_cors_preflight: request.use_cors_preflight
		credentials_mode: request.credentials_mode
		use_url_credentials: request.use_url_credentials
		cache_mode: request.cache_mode
		redirect_mode: request.redirect_mode
		integrity_metadata: request.integrity_metadata
		cryptographic_nonce_metadata: request.cryptographic_nonce_metadata
		parser_metadata: request.parser_metadata
		reload_navigation: request.reload_navigation
		history_navigation: request.history_navigation
		user_activation: request.user_activation
		render_blocking: request.render_blocking
		url_list: request.url_list.clone()
		redirect_count: request.redirect_count
		response_tainting: request.response_tainting
		prevent_no_cache_cache_control_header_modification: request.prevent_no_cache_cache_control_header_modification
		done: request.done
		timing_allow_failed: request.timing_allow_failed
		navigation_timing_allow_values_list_: clone_navigation_timing_allow_values_list(request.navigation_timing_allow_values_list_)
		request_time: i64(time.now().unix_milli())
	}
}

pub fn (mut request Request) add_range_header(first u64, last ?u64) {
	if end := last {
		assert first <= end
		request.header_list.append(http.Header{ name: 'Range', value: 'bytes=${first}-${end}' })
	} else {
		request.header_list.append(http.Header{ name: 'Range', value: 'bytes=${first}-' })
	}
}

pub fn (mut request Request) add_origin_header() {
	mut serialized := request.serialize_origin()
	if request.response_tainting == .cors || request.mode == .websocket {
		request.header_list.append(http.Header{ name: 'Origin', value: serialized })
		return
	}
	if request.method in ['GET', 'HEAD'] {
		return
	}
	if request.mode != .cors {
		if request.referrer_policy == 'no-referrer' {
			serialized = 'null'
		} else if request.referrer_policy in ['no-referrer-when-downgrade', 'strict-origin',
			'strict-origin-when-cross-origin'] {
			if origin := request.origin.origin {
				if origin.serialize().starts_with('https://') && request.current_url().scheme() != 'https' {
					serialized = 'null'
				}
			}
		} else if request.referrer_policy == 'same-origin' {
			if origin := request.origin.origin {
				if !origin.is_same_origin(request.current_url().origin()) {
					serialized = 'null'
				}
			}
		}
	}
	request.header_list.append(http.Header{ name: 'Origin', value: serialized })
}

// HTTP-network-or-cache fetch and the native transport must use the same
// credentials flag, including after a redirect changes response tainting.
pub fn (request &Request) includes_credentials() bool {
	return (request.credentials_mode == .include || (request.credentials_mode == .same_origin && request.response_tainting == .basic))
		&& request.cross_origin_embedder_policy_allows_credentials()
}

pub fn (request &Request) cross_origin_embedder_policy_allows_credentials() bool {
	if request.mode != .no_cors || !request.client_present || !request.embedder_policy_credentialless {
		return true
	}
	origin := request.origin.origin or { return false }
	return origin.is_same_origin(request.current_url().origin()) && request.redirect_taint() != .same_origin
}

pub fn request_destination_to_string(destination Destination) string {
	return match destination {
		.audio { 'audio' }
		.audio_worklet { 'audioworklet' }
		.document { 'document' }
		.embed { 'embed' }
		.font { 'font' }
		.frame { 'frame' }
		.iframe { 'iframe' }
		.image { 'image' }
		.json { 'json' }
		.manifest { 'manifest' }
		.object { 'object' }
		.paint_worklet { 'paintworklet' }
		.report { 'report' }
		.script { 'script' }
		.service_worker { 'serviceworker' }
		.shared_worker { 'sharedworker' }
		.style { 'style' }
		.text { 'text' }
		.track { 'track' }
		.video { 'video' }
		.web_identity { 'webidentity' }
		.worker { 'worker' }
		.xslt { 'xslt' }
	}
}

fn translate_potential_destination_impl(value string) ?Destination {
	if value == 'fetch' {
		return none
	}
	return match value {
		'audio' { Destination.audio }
		'audioworklet' { Destination.audio_worklet }
		'document' { Destination.document }
		'embed' { Destination.embed }
		'font' { Destination.font }
		'frame' { Destination.frame }
		'iframe' { Destination.iframe }
		'image' { Destination.image }
		'json' { Destination.json }
		'manifest' { Destination.manifest }
		'object' { Destination.object }
		'paintworklet' { Destination.paint_worklet }
		'report' { Destination.report }
		'script' { Destination.script }
		'serviceworker' { Destination.service_worker }
		'sharedworker' { Destination.shared_worker }
		'style' { Destination.style }
		'text' { Destination.text }
		'track' { Destination.track }
		'video' { Destination.video }
		'webidentity' { Destination.web_identity }
		'worker' { Destination.worker }
		'xslt' { Destination.xslt }
		else { none }
	}
}

pub fn translate_potential_destination(value string) ?Destination {
	return translate_potential_destination_impl(value)
}

pub fn request_mode_to_string(mode Mode) string {
	return match mode {
		.same_origin { 'same-origin' }
		.cors { 'cors' }
		.no_cors { 'no-cors' }
		.navigate { 'navigate' }
		.websocket { 'websocket' }
	}
}

pub fn request_priority_from_string(value string) ?Priority {
	return match ascii_lowercase(value) {
		'high' { Priority.high }
		'low' { Priority.low }
		'auto' { Priority.auto }
		else { none }
	}
}

// ReferrerPolicy/AbstractOperations.cpp, determine request's referrer steps
// 2-3: explicit URL, no-referrer, or the Window/Worker client source.
pub fn (request &Request) referrer_source() ?dom.URL {
	if explicit := request.referrer.url {
		return explicit
	}
	if request.referrer.sentinel == .no_referrer || request.client_origin_opaque {
		return none
	}
	if request.client_is_window {
		return request.client_document_url
	}
	return request.client_creation_url
}
