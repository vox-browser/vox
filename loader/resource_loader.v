// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/ResourceLoader.{h,cpp}. Protocol I/O is represented by
// deterministic injected resource/network stores; dispatch, filtering, bad-port
// checks, metadata, counters, and configuration retain the upstream semantics.
@[has_globals]
module loader

import dom
import http
import net.urllib
import os

__global (
	loader_global_resource_loader          &ResourceLoader
	loader_browser_process_command_line    string
	loader_browser_process_executable_path string
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
	proxy         ?ProxyData
}

pub struct ResourceLoader {
pub mut:
	user_agent                    string
	platform                      string
	preferred_languages           []string                   = ['en-US']
	navigator_compatibility_mode  NavigatorCompatibilityMode = .chrome
	enable_global_privacy_control bool
mut:
	content_filter    &ContentFilter
	proxy_mappings    &ProxyMappings
	resources         map[string]StoredResource
	about_pages       map[string][]u8
	network_responses map[string]NetworkResponse
	pending_loads_    int
	active_requests   map[u64]string
	next_request_id   u64 = 1
}

pub fn ResourceLoader.create() &ResourceLoader {
	return &ResourceLoader{
		user_agent:        default_user_agent()
		platform:          default_platform()
		content_filter:    ContentFilter.create()
		proxy_mappings:    ProxyMappings.create()
		resources:         map[string]StoredResource{}
		about_pages:       map[string][]u8{}
		network_responses: map[string]NetworkResponse{}
		active_requests:   map[u64]string{}
	}
}

pub fn initialize() &ResourceLoader {
	loader_global_resource_loader = ResourceLoader.create()
	return loader_global_resource_loader
}

pub fn is_initialized() bool {
	return loader_global_resource_loader != unsafe { nil }
}

pub fn the() &ResourceLoader {
	if !is_initialized() {
		panic('Web::ResourceLoader was not initialized')
	}
	return loader_global_resource_loader
}

pub fn (resource_loader &ResourceLoader) pending_loads() int {
	return resource_loader.pending_loads_
}

pub fn (resource_loader &ResourceLoader) content_filter() &ContentFilter {
	return resource_loader.content_filter
}

pub fn (resource_loader &ResourceLoader) proxy_mappings() &ProxyMappings {
	return resource_loader.proxy_mappings
}

pub fn (mut resource_loader ResourceLoader) set_preferred_languages(languages []string) ! {
	if languages.len == 0 {
		return error('preferred languages must not be empty')
	}
	resource_loader.preferred_languages = languages.clone()
}

pub fn (mut resource_loader ResourceLoader) register_resource(url string, resource StoredResource) {
	resource_loader.resources[url] = resource
}

pub fn (mut resource_loader ResourceLoader) register_about_page(path string, contents []u8) {
	resource_loader.about_pages[path] = contents.clone()
}

pub fn (mut resource_loader ResourceLoader) register_network_response(url string, response NetworkResponse) {
	resource_loader.network_responses[url] = response
}

pub fn (resource_loader &ResourceLoader) prepare_connection(url dom.URL, preconnect bool) ConnectionPreparation {
	if url.scheme() in ['file', 'data'] || resource_loader.content_filter.is_filtered(url) {
		return .none
	}
	return if preconnect { .create_connection } else { .resolve_only }
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
	url := request.url or { return true }
	return port_or_default(url) in blocked_loader_ports
		|| resource_loader.content_filter.is_filtered(url)
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
	url := request.url or { return failure('Request has no URL', '') }
	request.start_timer()
	if resource_loader.should_block_request(request) {
		return failure('Request was blocked', url.scheme())
	}
	match url.scheme() {
		'about' {
			serialized_path := url.serialize_path()
			encoded_path := if serialized_path != '' {
				serialized_path
			} else {
				url.serialize().all_after('about:').all_before('?').all_before('#')
			}
			// The upstream about loader percent-decodes the serialized path before
			// selecting the generated or embedded page.
			path := urllib.query_unescape(encoded_path) or { encoded_path }
			data := if path == 'version' {
				load_about_version_page().bytes()
			} else {
				resource_loader.about_pages[path] or { []u8{} }
			}
			return LoadResult{
				success:  true
				data:     data.clone()
				headers:  [http.Header{'Content-Type', 'text/html; charset=UTF-8'}]
				protocol: 'about'
			}
		}
		'resource' {
			resource := resource_loader.resources[url.serialize()] or {
				return failure('Resource not found: ${url.serialize()}', 'resource')
			}
			if resource.is_directory {
				directory_url := resource.file_url or {
					return failure('Resource directory has no file URL', 'resource')
				}

				page := load_file_directory_page(directory_url) or {
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
		'file' {
			path := file_path_from_url(url) or { return failure(err.msg(), 'file') }
			if os.is_dir(path) {
				page := load_file_directory_page(url) or { return failure(err.msg(), 'file') }
				return LoadResult{
					success:  true
					data:     page.bytes()
					headers:  [http.Header{'Content-Type', 'text/html'}]
					protocol: 'file'
				}
			}
			data := os.read_bytes(path) or { return failure(err.msg(), 'file') }
			return LoadResult{
				success:  true
				data:     data
				headers:  response_headers_for_file(path, '', none)
				protocol: 'file'
			}
		}
		'http', 'https' {
			response := resource_loader.network_responses[url.serialize()] or {
				return failure('Failed to start network request', url.scheme())
			}
			request_id := resource_loader.next_request_id
			resource_loader.next_request_id++
			resource_loader.pending_loads_++
			resource_loader.active_requests[request_id] = url.serialize()
			proxy := resource_loader.proxy_mappings.proxy_for_url(url)
			resource_loader.pending_loads_--
			resource_loader.active_requests.delete(request_id)
			if message := response.error_message {
				return LoadResult{
					error_message: 'Request finished with error: ${message}'
					protocol:      url.scheme()
					proxy:         proxy
				}
			}
			return LoadResult{
				success:       true
				data:          response.data.clone()
				headers:       response.headers.clone()
				status_code:   response.status_code
				reason_phrase: response.reason_phrase
				protocol:      url.scheme()
				proxy:         proxy
			}
		}
		else {
			return failure('Protocol not implemented: ${url.scheme()}', url.scheme())
		}
	}
}
