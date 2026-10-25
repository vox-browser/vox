// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/ResourceLoader.{h,cpp}. Protocol I/O is represented by
// deterministic injected resource/network stores; dispatch, filtering, bad-port
// checks, metadata, counters, and configuration retain the upstream semantics.
@[has_globals]
module loader

import dom
import http
import os
import platform
import strconv
import time
import url as liburl

__global (
	loader_global_resource_loader          &ResourceLoader
	loader_global_content_blocker          &ContentBlocker
)

pub enum ConnectionPreparation {
	none
	resolve_only
	create_connection
}

pub struct StoredResource {
pub:
	data          []u8
	content_type  string
	last_modified ?string
	is_directory  bool
	file_url      ?dom.URL
}

pub struct NetworkResponse {
pub:
	data          []u8
	headers       []http.Header
	status_code   u16 = 200
	reason_phrase string
	error_message ?string
}

pub struct LoadResult {
pub:
	success       bool
	data          []u8
	headers       []http.Header
	status_code   ?u16
	reason_phrase ?string
	error_message ?string
	protocol      string
}

pub struct StoredResponseCookie {
pub:
	page_id u64
	url     dom.URL
	value   string
}

pub struct HSTSPolicy {
pub:
	max_age_seconds    u64
	include_sub_domains bool
	stored_at_unix     i64
}

struct StartedNetworkRequest {
	id       u64
	response NetworkResponse
}

pub struct ResourceLoader {
mut:
	request_client_                voidptr
	user_agent_                   string
	platform_                     string
	preferred_languages_          []string                   = ['en-US']
	navigator_compatibility_mode_ NavigatorCompatibilityMode = .chrome
	enable_global_privacy_control_ bool
	site_compatibility_data_       SiteCompatibilityData
	hsts_policies                  map[string]HSTSPolicy
	preloaded_hsts_policies        map[string]bool
	resources                      map[string]StoredResource
	about_pages                    map[string][]u8
	network_responses              map[string]NetworkResponse
	response_cookies_              []StoredResponseCookie
	pending_loads_                 int
	active_requests                map[u64]string
	next_request_id                u64 = 1
}

pub fn ResourceLoader.create() &ResourceLoader {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &ResourceLoader{
		user_agent_:       default_user_agent()
		platform_:         default_platform()
		hsts_policies:     map[string]HSTSPolicy{}
		preloaded_hsts_policies: map[string]bool{}
		resources:         map[string]StoredResource{}
		about_pages:       map[string][]u8{}
		network_responses: map[string]NetworkResponse{}
		active_requests:   map[u64]string{}
	}
}

fn resource_loader() &ResourceLoader {
	return loader_global_resource_loader
}

pub fn initialize() &ResourceLoader {
	loader_global_resource_loader = ResourceLoader.create()
	return loader_global_resource_loader
}

pub fn is_initialized() bool {
	return loader_global_resource_loader != unsafe { nil }
}

pub fn ResourceLoader.is_initialized() bool {
	return is_initialized()
}

pub fn the() &ResourceLoader {
	if !is_initialized() {
		panic('Web::ResourceLoader was not initialized')
	}
	return loader_global_resource_loader
}

pub fn ResourceLoader.the() &ResourceLoader {
	return the()
}

// Requests::RequestClient belongs to the embedder. Its opaque identity is
// retained here without importing the browser process into this library.
pub fn (mut resource_loader ResourceLoader) set_client(request_client voidptr) {
	resource_loader.request_client_ = request_client
}

pub fn (resource_loader &ResourceLoader) request_client() voidptr {
	return resource_loader.request_client_
}

pub fn (resource_loader &ResourceLoader) pending_loads() int {
	return resource_loader.pending_loads_
}

pub fn (resource_loader &ResourceLoader) user_agent() string {
	return resource_loader.user_agent_
}

pub fn (resource_loader &ResourceLoader) user_agent_for_url(url dom.URL) string {
	return resource_loader.site_compatibility_data_.user_agent_for_url(url,
		resource_loader.user_agent_)
}

pub fn (resource_loader &ResourceLoader) user_agent_for_websocket_url(url dom.URL) string {
	return resource_loader.site_compatibility_data_.user_agent_for_websocket_url(url,
		resource_loader.user_agent_)
}

pub fn (mut resource_loader ResourceLoader) set_user_agent(user_agent string) {
	resource_loader.user_agent_ = user_agent
}

pub fn (mut resource_loader ResourceLoader) set_site_compatibility_data(data SiteCompatibilityData) {
	resource_loader.site_compatibility_data_ = data
}

pub fn (resource_loader &ResourceLoader) site_compatibility_exposes_experimental_interface(url dom.URL, name string) bool {
	return resource_loader.site_compatibility_data_.exposes_experimental_interface(url, name)
}

pub fn (resource_loader &ResourceLoader) platform() string {
	return resource_loader.platform_
}

pub fn (mut resource_loader ResourceLoader) set_platform(platform_name string) {
	resource_loader.platform_ = platform_name
}

pub fn (resource_loader &ResourceLoader) preferred_languages() []string {
	return resource_loader.preferred_languages_.clone()
}

pub fn (mut resource_loader ResourceLoader) set_preferred_languages(languages []string) ! {
	if languages.len == 0 {
		return error('preferred languages must not be empty')
	}
	resource_loader.preferred_languages_ = languages.clone()
}

pub fn (resource_loader &ResourceLoader) navigator_compatibility_mode() NavigatorCompatibilityMode {
	return resource_loader.navigator_compatibility_mode_
}

pub fn (mut resource_loader ResourceLoader) set_navigator_compatibility_mode(mode NavigatorCompatibilityMode) {
	resource_loader.navigator_compatibility_mode_ = mode
}

pub fn (resource_loader &ResourceLoader) enable_global_privacy_control() bool {
	return resource_loader.enable_global_privacy_control_
}

pub fn (mut resource_loader ResourceLoader) set_enable_global_privacy_control(enable bool) {
	resource_loader.enable_global_privacy_control_ = enable
}

pub fn (resource_loader &ResourceLoader) response_cookies() []StoredResponseCookie {
	return resource_loader.response_cookies_.clone()
}

pub fn (mut resource_loader ResourceLoader) register_resource(url string, resource StoredResource) {
	resource_loader.resources[url] = resource
}

pub fn (mut resource_loader ResourceLoader) register_about_page(path string, contents []u8) {
	resource_loader.about_pages[path] = contents.clone()
}

pub fn (mut resource_loader ResourceLoader) register_network_response(url string, response NetworkResponse) {
	// Completed native resources can arrive during document/paint work. Own
	// both the map backing and response bytes independently of that scope.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut headers := []http.Header{cap: response.headers.len}
	for header in response.headers {
		headers << http.Header{header.name.clone(), header.value.clone()}
	}
	resource_loader.network_responses[url] = NetworkResponse{
		...response
		data: response.data.clone()
		headers: headers
		reason_phrase: response.reason_phrase.clone()
		error_message: if message := response.error_message { message.clone() } else { none }
	}
}

pub fn (resource_loader &ResourceLoader) prepare_connection(url dom.URL, source_url dom.URL, preconnect bool) ConnectionPreparation {
	if url.scheme() in ['file', 'data']
		|| ContentBlocker.the().is_filtered_for_resource(url, source_url, .other) {
		return .none
	}
	return if preconnect { .create_connection } else { .resolve_only }
}

pub fn (resource_loader &ResourceLoader) prefetch_dns(url dom.URL, source_url dom.URL) ConnectionPreparation {
	return resource_loader.prepare_connection(url, source_url, false)
}

pub fn (resource_loader &ResourceLoader) preconnect(url dom.URL, source_url dom.URL) ConnectionPreparation {
	return resource_loader.prepare_connection(url, source_url, true)
}

const blocked_loader_ports = [u16(1), 7, 9, 11, 13, 15, 17, 19, 20, 21, 22, 23, 25, 37, 42, 43,
	53, 77, 79, 87, 95, 101, 102, 103, 104, 109, 110, 111, 113, 115, 117, 119, 123, 135, 139, 143,
	179, 389, 465, 512, 513, 514, 515, 526, 530, 531, 532, 540, 556, 563, 587, 601, 636, 993, 995,
	2049, 3659, 4045, 6000, 6379, 6665, 6666, 6667, 6668, 6669]

fn port_or_default(url dom.URL) u16 {
	if port := url.port() {
		return port
	}
	return match url.scheme() {
		'http' { u16(80) }
		'https' { u16(443) }
		else { u16(0) }
	}
}

pub fn (resource_loader &ResourceLoader) should_block_request(request &LoadRequest) bool {
	url := request.url() or { return true }
	source_url := request.source_url() or { url }
	return port_or_default(url) in blocked_loader_ports
		|| ContentBlocker.the().is_filtered_with_metadata(url, source_url, request.destination(),
		request.initiator_type(), request.request_mode())
}

pub fn sanitized_url_for_logging(url dom.URL) string {
	if url.scheme() == 'data' {
		return '[data URL]'
	}
	return url.to_string()
}

fn log_request_start(request &LoadRequest) string {
	url := request.url() or { return '' }
	return 'ResourceLoader: Starting load of: "${sanitized_url_for_logging(url)}"'
}

fn log_success(request &LoadRequest) string {
	url := request.url() or { return '' }
	return 'ResourceLoader: Finished load of: "${sanitized_url_for_logging(url)}", Duration: ${request.load_time().milliseconds()}ms'
}

fn log_failure(request &LoadRequest, message string) string {
	url := request.url() or { return message }
	return 'ResourceLoader: Failed load of: "${sanitized_url_for_logging(url)}", Error: ${message}, Duration: ${request.load_time().milliseconds()}ms'
}

fn log_filtered_request(request &LoadRequest) string {
	url := request.url() or { return '' }
	return 'ResourceLoader: Filtered request to: "${sanitized_url_for_logging(url)}"'
}

fn is_http_token_byte(character u8) bool {
	if (character >= `a` && character <= `z`) || (character >= `A` && character <= `Z`)
		|| (character >= `0` && character <= `9`) {
		return true
	}
	return character in [`!`, `#`, `$`, `%`, `&`, `'`, `*`, `+`, `-`, `.`, `^`, `_`, `\``, `|`, `~`]
}

fn is_http_token(value string) bool {
	if value == '' {
		return false
	}
	for character in value.bytes() {
		if !is_http_token_byte(character) {
			return false
		}
	}
	return true
}

fn split_hsts_directives(header_value string) ?[]string {
	mut directives := []string{}
	mut start := 0
	mut quoted := false
	mut escaped := false
	for index, character in header_value.bytes() {
		if escaped {
			escaped = false
			continue
		}
		if quoted && character == `\\` {
			escaped = true
			continue
		}
		if character == `"` {
			quoted = !quoted
			continue
		}
		if character == `;` && !quoted {
			directives << header_value[start..index]
			start = index + 1
		}
	}
	if quoted || escaped {
		return none
	}
	directives << header_value[start..]
	return directives
}

fn parse_hsts_directive_value(raw_value string) ?string {
	value := raw_value.trim_space()
	if value.starts_with('"') {
		if value.len < 2 || !value.ends_with('"') {
			return none
		}
		mut result := []u8{}
		mut index := 1
		for index < value.len - 1 {
			if value[index] == `\\` {
				index++
				if index >= value.len - 1 {
					return none
				}
			}
			result << value[index]
			index++
		}
		return result.bytestr()
	}
	if !is_http_token(value) {
		return none
	}
	return value
}

fn parse_hsts_policy(header_value string) ?HSTSPolicy {
	directives := split_hsts_directives(header_value) or { return none }
	mut max_age := ?u64(none)
	mut include_sub_domains := false
	for raw_directive in directives {
		directive := raw_directive.trim_space()
		if directive == '' {
			continue
		}
		separator := directive.index('=') or { -1 }
		name := if separator >= 0 {
			directive[..separator].trim_space()
		} else {
			directive
		}
		if !is_http_token(name) {
			return none
		}
		value := if separator >= 0 {
			parse_hsts_directive_value(directive[separator + 1..]) or { return none }
		} else {
			''
		}
		match name.to_lower() {
			'max-age' {
				if separator < 0 || max_age != none {
					return none
				}
				max_age = strconv.parse_uint(value, 10, 64) or { return none }
			}
			'includesubdomains' {
				if separator >= 0 || include_sub_domains {
					return none
				}
				include_sub_domains = true
			}
			else {}
		}
	}
	seconds := max_age or { return none }
	return HSTSPolicy{
		max_age_seconds: seconds
		include_sub_domains: include_sub_domains
		stored_at_unix: time.now().unix()
	}
}

pub fn (mut resource_loader ResourceLoader) try_store_hsts_policy_for_url(url dom.URL, header_value string) {
	parsed_url := liburl.parse(url.serialize()) or { return }
	host_record := parsed_url.host or { return }
	if !host_record.is_domain() {
		return
	}
	policy := parse_hsts_policy(header_value) or { return }
	host := host_record.serialize().trim_right('.').to_lower()
	if policy.max_age_seconds == 0 {
		resource_loader.hsts_policies.delete(host)
		return
	}
	resource_loader.hsts_policies[host] = policy
}

fn hsts_policy_is_active(policy HSTSPolicy) bool {
	if policy.max_age_seconds > u64(9223372036854775807) {
		return true
	}
	return time.now().unix() - policy.stored_at_unix < i64(policy.max_age_seconds)
}

pub fn (mut resource_loader ResourceLoader) add_preloaded_hsts_host(host string, include_sub_domains bool) {
	resource_loader.preloaded_hsts_policies[host.trim_right('.').to_lower()] = include_sub_domains
}

pub fn (resource_loader &ResourceLoader) hsts_policy_for_host(host string) ?HSTSPolicy {
	policy := resource_loader.hsts_policies[host.trim_right('.').to_lower()] or { return none }
	return if hsts_policy_is_active(policy) { policy } else { none }
}

pub fn (resource_loader &ResourceLoader) is_known_hsts_host(host string) bool {
	mut candidate := host.trim_right('.').to_lower()
	mut exact := true
	for candidate != '' {
		if include_subdomains := resource_loader.preloaded_hsts_policies[candidate] {
			if exact || include_subdomains {
				return true
			}
		}
		if policy := resource_loader.hsts_policies[candidate] {
			if hsts_policy_is_active(policy) && (exact || policy.include_sub_domains) {
				return true
			}
		}
		dot := candidate.index('.') or { break }
		candidate = candidate[dot + 1..]
		exact = false
	}
	return false
}

fn store_response_cookies(mut resource_loader ResourceLoader, request &LoadRequest, set_cookie_entry string) {
	page_id := request.page() or { return }
	url := request.url() or { return }
	// Cookie::parse_cookie rejects entries without a name/value pair. The full
	// cookie jar is an embedder boundary; retain each accepted HTTP cookie so
	// the page client can consume the same response-side effect.
	if !set_cookie_entry.contains('=') {
		return
	}
	resource_loader.response_cookies_ << StoredResponseCookie{
		page_id: page_id
		url:     url
		value:   set_cookie_entry
	}
}

fn response_headers_for_file(path string, content_type string, modified ?string) []http.Header {
	mut headers := [http.Header{'Access-Control-Allow-Origin', 'null'}]
	mime_type := if content_type != '' { content_type } else { guess_mime_type(path) }
	headers << http.Header{'Content-Type', mime_type}
	if value := modified {
		headers << http.Header{'Last-Modified', value}
	}
	return headers
}

fn guess_mime_type(path string) string {
	return match os.file_ext(path).to_lower() {
		'.html', '.htm' { 'text/html' }
		'.css' { 'text/css' }
		'.js', '.mjs' { 'text/javascript' }
		'.json' { 'application/json' }
		'.svg' { 'image/svg+xml' }
		'.png' { 'image/png' }
		'.jpg', '.jpeg' { 'image/jpeg' }
		'.txt' { 'text/plain' }
		else { 'application/octet-stream' }
	}
}

fn failure(message string, protocol string) LoadResult {
	return LoadResult{
		error_message: message
		protocol:      protocol
	}
}

pub fn (mut resource_loader ResourceLoader) load(mut request LoadRequest) LoadResult {
	url := request.url() or { return failure('Request has no URL', '') }
	_ := log_request_start(request)
	request.start_timer()
	if resource_loader.should_block_request(request) {
		_ := log_filtered_request(request)
		return failure('Request was blocked', url.scheme())
	}
	match url.scheme() {
		'about' {
			return resource_loader.handle_about_load_request(request)
		}
		'resource' {
			return resource_loader.handle_resource_load_request(request)
		}
		'file' {
			return resource_loader.handle_file_load_request(mut request)
		}
		'http', 'https' {
			protocol_request := resource_loader.start_network_request(request) or {
				return failure('Failed to start network request', url.scheme())
			}
			resource_loader.handle_network_response_headers(request, protocol_request.response.headers)
			resource_loader.finish_network_request(protocol_request)
			if message := protocol_request.response.error_message {
				_ := log_failure(request, message)
		return LoadResult{
				error_message: 'Request finished with error: ${message}'
				protocol:      url.scheme()
			}
			}
			_ := log_success(request)
			return LoadResult{
				success:       true
				data:          protocol_request.response.data.clone()
				headers:       protocol_request.response.headers.clone()
				status_code:   protocol_request.response.status_code
			reason_phrase: protocol_request.response.reason_phrase
			protocol:      url.scheme()
		}
		}
		else {
			message := 'Protocol not implemented: ${url.scheme()}'
			_ := log_failure(request, message)
			return failure(message, url.scheme())
		}
	}
}

pub fn (mut resource_loader ResourceLoader) handle_about_load_request(request &LoadRequest) LoadResult {
	url := request.url() or { return failure('Request has no URL', 'about') }
	serialized_path := url.serialize_path()
	encoded_path := if serialized_path != '' {
		serialized_path
	} else {
		url.serialize().all_after('about:').all_before('?').all_before('#')
	}
	path := liburl.percent_decode(encoded_path).bytestr()
	target_file := '${path}.html'
	data := resource_loader.about_pages[target_file] or {
		message := 'No such about page: ${path}'
		_ := log_failure(request, message)
		return failure(message, 'about')
	}
	_ := log_success(request)
	return LoadResult{
		success:  true
		data:     data.clone()
		headers:  [http.Header{'Content-Type', 'text/html; charset=UTF-8'}]
		protocol: 'about'
	}
}

pub fn (mut resource_loader ResourceLoader) handle_resource_load_request(request &LoadRequest) LoadResult {
	url := request.url() or { return failure('Request has no URL', 'resource') }
	resource := resource_loader.resources[url.serialize()] or {
		message := 'Resource not found: ${url.serialize()}'
		_ := log_failure(request, message)
		return failure(message, 'resource')
	}
	if resource.is_directory {
		directory_url := resource.file_url or {
			return failure('Resource directory has no file URL', 'resource')
		}
		page := load_file_directory_page(directory_url) or {
			_ := log_failure(request, err.msg())
			return failure(err.msg(), 'resource')
		}
		return LoadResult{
			success:  true
			data:     page.bytes()
			headers:  [http.Header{'Content-Type', 'text/html'}]
			protocol: 'resource'
		}
	}
	return LoadResult{
		success:  true
		data:     resource.data.clone()
		headers:  response_headers_for_file(url.serialize_path(), resource.content_type,
			resource.last_modified)
		protocol: 'resource'
	}
}

pub fn (mut resource_loader ResourceLoader) handle_file_load_request(mut request LoadRequest) LoadResult {
	url := request.url() or { return failure('Request has no URL', 'file') }
	if request.page() == none {
		// Host-backed tests do not have a Page object. File access itself remains
		// the explicit stand-in for PageClient::request_file.
	}
	path := file_path_from_url(url) or {
		_ := log_failure(request, err.msg())
		return failure(err.msg(), 'file')
	}
	resource_loader.pending_loads_++
	defer {
		resource_loader.pending_loads_--
	}
	if os.is_dir(path) {
		page := load_file_directory_page(url) or {
			_ := log_failure(request, err.msg())
			return failure(err.msg(), 'file')
		}
		_ := log_success(request)
		return LoadResult{
			success:  true
			data:     page.bytes()
			headers:  [http.Header{'Content-Type', 'text/html'}]
			protocol: 'file'
		}
	}
	data := os.read_bytes(path) or {
		_ := log_failure(request, err.msg())
		return failure(err.msg(), 'file')
	}
	_ := log_success(request)
	return LoadResult{
		success:  true
		data:     data
		headers:  response_headers_for_file(path, '', none)
		protocol: 'file'
	}
}

fn (mut resource_loader ResourceLoader) start_network_request(request &LoadRequest) ?StartedNetworkRequest {
	url := request.url() or { return none }
	response := resource_loader.network_responses[url.serialize()] or {
		_ := log_failure(request, 'Failed to initiate load')
		return none
	}
	// Empty V maps allocate on first insertion. SVG loads can begin while
	// building a temporary paint tree, but request tracking belongs to the
	// loader and must remain valid after that tree is retired.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	request_id := resource_loader.next_request_id
	resource_loader.next_request_id++
	resource_loader.pending_loads_++
	resource_loader.active_requests[request_id] = url.serialize()
	return StartedNetworkRequest{
		id:       request_id
		response: response
	}
}

fn (mut resource_loader ResourceLoader) handle_network_response_headers(request &LoadRequest, response_headers []http.Header) {
	if request.page() == none {
		return
	}
	if url := request.url() {
		if url.scheme() == 'https' {
			for header in response_headers {
				if header.name.to_lower() == 'strict-transport-security' {
					resource_loader.try_store_hsts_policy_for_url(url, header.value)
					break
				}
			}
		}
	}
	if !request.include_credentials() {
		return
	}
	for header in response_headers {
		if header.name.to_lower() == 'set-cookie' {
			store_response_cookies(mut resource_loader, request, header.value)
		}
	}
}

fn (mut resource_loader ResourceLoader) finish_network_request(protocol_request StartedNetworkRequest) {
	// Deletion may allocate tombstone storage or compact the map as well.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	resource_loader.pending_loads_--
	resource_loader.active_requests.delete(protocol_request.id)
}
