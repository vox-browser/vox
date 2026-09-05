// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct entry points for the Fetch request record. V exposes the record's
// fields to other translated modules, but the upstream implementation also
// provides this accessor surface. Keeping both preserves the upstream API and
// gives callers a mutation boundary that can be tested independently.
module fetch

import dom
import http
import mimesniff

pub fn (request &Request) fetch_request_method() string {
	return request.method
}

pub fn (mut request Request) set_method(method string) {
	request.method = method
}

pub fn (request &Request) fetch_request_local_urls_only() bool {
	return request.local_urls_only
}

pub fn (mut request Request) set_local_urls_only(local_urls_only bool) {
	request.local_urls_only = local_urls_only
}

pub fn (request &Request) fetch_request_header_list() &http.HeaderList {
	return request.header_list
}

pub fn (mut request Request) set_header_list(header_list &http.HeaderList) {
	request.header_list = header_list
}

pub fn (request &Request) fetch_request_unsafe_request() bool {
	return request.unsafe_request
}

pub fn (mut request Request) set_unsafe_request(unsafe_request bool) {
	request.unsafe_request = unsafe_request
}

pub fn (request &Request) fetch_request_body() RequestBody {
	return RequestBody{
		kind: request.body.kind
		bytes: request.body.bytes.clone()
		body_object: request.body.body_object
	}
}

pub fn (mut request Request) set_body(body RequestBody) {
	request.body = RequestBody{
		kind: body.kind
		bytes: body.bytes.clone()
		body_object: body.body_object
	}
}

pub fn (request &Request) fetch_request_reserved_client() ?RequestReservedClient {
	return request.reserved_client
}

pub fn (mut request Request) set_reserved_client(reserved_client ?RequestReservedClient) {
	request.reserved_client = reserved_client
}

pub fn (request &Request) fetch_request_replaces_client_id() string {
	return request.replaces_client_id
}

pub fn (mut request Request) set_replaces_client_id(replaces_client_id string) {
	request.replaces_client_id = replaces_client_id
}

pub fn (request &Request) fetch_request_traversable_for_user_prompts() TraversableForUserPrompts {
	return request.traversable_for_user_prompts
}

pub fn (mut request Request) set_traversable_for_user_prompts(value TraversableForUserPrompts) {
	request.traversable_for_user_prompts = value
}

pub fn (request &Request) fetch_request_keepalive() bool {
	return request.keepalive
}

pub fn (mut request Request) set_keepalive(keepalive bool) {
	request.keepalive = keepalive
}

pub fn (request &Request) fetch_request_initiator_type() ?InitiatorType {
	return request.initiator_type
}

pub fn (mut request Request) set_initiator_type(initiator_type ?InitiatorType) {
	request.initiator_type = initiator_type
}

pub fn (request &Request) fetch_request_service_workers_mode() ServiceWorkersMode {
	return request.service_workers_mode
}

pub fn (mut request Request) set_service_workers_mode(mode ServiceWorkersMode) {
	request.service_workers_mode = mode
}

pub fn (request &Request) fetch_request_initiator() ?Initiator {
	return request.initiator
}

pub fn (mut request Request) set_initiator(initiator ?Initiator) {
	request.initiator = initiator
}

pub fn (request &Request) fetch_request_destination() ?Destination {
	return request.destination
}

pub fn (mut request Request) set_destination(destination ?Destination) {
	request.destination = destination
}

pub fn (request &Request) fetch_request_priority() Priority {
	return request.priority
}

pub fn (mut request Request) set_priority(priority Priority) {
	request.priority = priority
}

pub fn (mut request Request) set_origin(origin RequestOrigin) {
	request.origin = origin
}

pub fn (request &Request) fetch_request_top_level_navigation_initiator_origin() ?dom.Origin {
	return request.top_level_navigation_initiator_origin
}

pub fn (mut request Request) set_top_level_navigation_initiator_origin(origin ?dom.Origin) {
	request.top_level_navigation_initiator_origin = origin
}

pub fn (request &Request) fetch_request_policy_container() PolicyContainerSentinel {
	return request.policy_container
}

pub fn (mut request Request) set_policy_container(container PolicyContainerSentinel) {
	request.policy_container = container
}

pub fn (request &Request) fetch_request_mode() Mode {
	return request.mode
}

pub fn (mut request Request) set_mode(mode Mode) {
	request.mode = mode
}

pub fn (request &Request) fetch_request_use_cors_preflight() bool {
	return request.use_cors_preflight
}

pub fn (mut request Request) set_use_cors_preflight(use_cors_preflight bool) {
	request.use_cors_preflight = use_cors_preflight
}

pub fn (request &Request) fetch_request_credentials_mode() CredentialsMode {
	return request.credentials_mode
}

pub fn (mut request Request) set_credentials_mode(mode CredentialsMode) {
	request.credentials_mode = mode
}

pub fn (request &Request) fetch_request_use_url_credentials() bool {
	return request.use_url_credentials
}

pub fn (mut request Request) set_use_url_credentials(use_url_credentials bool) {
	request.use_url_credentials = use_url_credentials
}

pub fn (request &Request) fetch_request_cache_mode() CacheMode {
	return request.cache_mode
}

pub fn (mut request Request) set_cache_mode(mode CacheMode) {
	request.cache_mode = mode
}

pub fn (request &Request) fetch_request_redirect_mode() RedirectMode {
	return request.redirect_mode
}

pub fn (mut request Request) set_redirect_mode(mode RedirectMode) {
	request.redirect_mode = mode
}

pub fn (request &Request) fetch_request_integrity_metadata() string {
	return request.integrity_metadata
}

pub fn (mut request Request) set_integrity_metadata(metadata string) {
	request.integrity_metadata = metadata
}

pub fn (request &Request) fetch_request_cryptographic_nonce_metadata() string {
	return request.cryptographic_nonce_metadata
}

pub fn (mut request Request) set_cryptographic_nonce_metadata(metadata string) {
	request.cryptographic_nonce_metadata = metadata
}

pub fn (request &Request) fetch_request_parser_metadata() ?ParserMetadata {
	return request.parser_metadata
}

pub fn (mut request Request) set_parser_metadata(metadata ?ParserMetadata) {
	request.parser_metadata = metadata
}

pub fn (request &Request) fetch_request_reload_navigation() bool {
	return request.reload_navigation
}

pub fn (mut request Request) set_reload_navigation(reload_navigation bool) {
	request.reload_navigation = reload_navigation
}

pub fn (request &Request) fetch_request_history_navigation() bool {
	return request.history_navigation
}

pub fn (mut request Request) set_history_navigation(history_navigation bool) {
	request.history_navigation = history_navigation
}

pub fn (request &Request) fetch_request_user_activation() bool {
	return request.user_activation
}

pub fn (mut request Request) set_user_activation(user_activation bool) {
	request.user_activation = user_activation
}

pub fn (request &Request) fetch_request_render_blocking() bool {
	return request.render_blocking
}

pub fn (mut request Request) set_render_blocking(render_blocking bool) {
	request.render_blocking = render_blocking
}

pub fn (request &Request) fetch_request_url_list() []dom.URL {
	return request.url_list.clone()
}

pub fn (mut request Request) set_url_list(url_list []dom.URL) {
	request.url_list = url_list.clone()
}

pub fn (request &Request) fetch_request_redirect_count() u8 {
	return request.redirect_count
}

pub fn (mut request Request) set_redirect_count(redirect_count u8) {
	request.redirect_count = redirect_count
}

pub fn (request &Request) fetch_request_response_tainting() ResponseTainting {
	return request.response_tainting
}

pub fn (mut request Request) set_response_tainting(tainting ResponseTainting) {
	request.response_tainting = tainting
}

pub fn (request &Request) fetch_request_prevent_no_cache_cache_control_header_modification() bool {
	return request.prevent_no_cache_cache_control_header_modification
}

pub fn (mut request Request) set_prevent_no_cache_cache_control_header_modification(value bool) {
	request.prevent_no_cache_cache_control_header_modification = value
}

pub fn (request &Request) fetch_request_done() bool {
	return request.done
}

pub fn (mut request Request) set_done(done bool) {
	request.done = done
}

pub fn (request &Request) fetch_request_timing_allow_failed() bool {
	return request.timing_allow_failed
}

pub fn (mut request Request) set_timing_allow_failed(failed bool) {
	request.timing_allow_failed = failed
}

pub fn (request &Request) fetch_request_request_time() i64 {
	return request.request_time
}

pub fn (request &Request) byte_serialize_origin() []u8 {
	return request.serialize_origin().bytes()
}

pub fn (mut request Request) add_pending_response(pending &PendingResponse) {
	if pending !in request.pending_responses {
		request.pending_responses << pending
	}
}

pub fn (mut request Request) remove_pending_response(pending &PendingResponse) {
	request.pending_responses = request.pending_responses.filter(it != pending)
}

// Web-exposed Request object adapters. These are explicitly mapped by the
// translation audit because upstream uses the same class name for this object
// and for the infrastructure record above.
pub fn RequestObject.construct_impl(input RequestInput, init RequestInit) !&RequestObject {
	return RequestObject.construct(input, init)
}

pub fn (object &RequestObject) mime_type_impl() ?mimesniff.MimeType {
	return extract_mime_type(object.request_.header_list)
}

pub fn (object &RequestObject) body_impl() ?&Body {
	return object.request_.body.body_object
}

pub fn (object &RequestObject) as_platform_object() &RequestObject {
	return object
}

pub fn (object &RequestObject) redirect() RedirectMode {
	return object.redirect_mode()
}
