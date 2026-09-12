// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/LoadRequest.h and Loader/FileRequest.{h,cpp}.
module loader

import dom
import fetch
import http
import referrerpolicy
import time

pub enum NavigatorCompatibilityMode {
	chrome
	gecko
	webkit
}

pub struct LoadRequest {
mut:
	url_                 ?dom.URL
	method_              string           = 'GET'
	headers_             &http.HeaderList = http.HeaderList.create()
	body_                []u8
	cache_mode_          fetch.CacheMode
	include_credentials_ bool = true
	initiator_type_      ?fetch.InitiatorType
	destination_         ?fetch.Destination
	request_mode_        fetch.Mode = .no_cors
	referrer_policy_     referrerpolicy.ReferrerPolicy = referrerpolicy.default_referrer_policy
	is_navigation_request_ bool
	priority_              fetch.Priority = .auto
	source_url_            ?dom.URL
	page_id_             ?u64
	started_at           ?time.Time
}

pub fn LoadRequest.create(headers &http.HeaderList) &LoadRequest {
	return &LoadRequest{
		headers_: headers
	}
}

pub fn (request &LoadRequest) url() ?dom.URL {
	return request.url_
}

pub fn (mut request LoadRequest) set_url(url ?dom.URL) {
	request.url_ = url
}

pub fn (request &LoadRequest) method() string {
	return request.method_
}

pub fn (mut request LoadRequest) set_method(method string) {
	request.method_ = method
}

pub fn (request &LoadRequest) body() []u8 {
	return request.body_
}

pub fn (mut request LoadRequest) set_body(body []u8) {
	request.body_ = body
}

pub fn (request &LoadRequest) cache_mode() fetch.CacheMode {
	return request.cache_mode_
}

pub fn (mut request LoadRequest) set_cache_mode(cache_mode fetch.CacheMode) {
	request.cache_mode_ = cache_mode
}

pub fn (request &LoadRequest) include_credentials() bool {
	return request.include_credentials_
}

pub fn (mut request LoadRequest) set_include_credentials(include_credentials bool) {
	request.include_credentials_ = include_credentials
}

pub fn (request &LoadRequest) initiator_type() ?fetch.InitiatorType {
	return request.initiator_type_
}

pub fn (mut request LoadRequest) set_initiator_type(initiator_type ?fetch.InitiatorType) {
	request.initiator_type_ = initiator_type
}

pub fn (request &LoadRequest) destination() ?fetch.Destination {
	return request.destination_
}

pub fn (mut request LoadRequest) set_destination(destination ?fetch.Destination) {
	request.destination_ = destination
}

pub fn (request &LoadRequest) request_mode() fetch.Mode {
	return request.request_mode_
}

pub fn (mut request LoadRequest) set_request_mode(request_mode fetch.Mode) {
	request.request_mode_ = request_mode
}

pub fn (request &LoadRequest) referrer_policy() referrerpolicy.ReferrerPolicy {
	return request.referrer_policy_
}

pub fn (mut request LoadRequest) set_referrer_policy(referrer_policy referrerpolicy.ReferrerPolicy) {
	request.referrer_policy_ = referrer_policy
}

pub fn (request &LoadRequest) is_navigation_request() bool {
	return request.is_navigation_request_
}

pub fn (mut request LoadRequest) set_is_navigation_request(is_navigation_request bool) {
	request.is_navigation_request_ = is_navigation_request
}

pub fn (request &LoadRequest) priority() fetch.Priority {
	return request.priority_
}

pub fn (mut request LoadRequest) set_priority(priority fetch.Priority) {
	request.priority_ = priority
}

pub fn (request &LoadRequest) source_url() ?dom.URL {
	return request.source_url_
}

pub fn (mut request LoadRequest) set_source_url(source_url dom.URL) {
	request.source_url_ = source_url
}

// Page is an embedder-owned GC object upstream. The standalone translation
// keeps its stable identifier at this boundary.
pub fn (request &LoadRequest) page() ?u64 {
	return request.page_id_
}

pub fn (mut request LoadRequest) set_page(page_id u64) {
	request.page_id_ = page_id
}

pub fn (request &LoadRequest) headers() &http.HeaderList {
	return request.headers_
}

pub fn (mut request LoadRequest) start_timer() {
	request.started_at = time.now()
}

pub fn (request &LoadRequest) load_time() time.Duration {
	started := request.started_at or { return time.Duration(0) }
	return time.since(started)
}

pub type FileRequestCallback = fn (FileDescriptorResult)

pub struct FileDescriptorResult {
pub:
	file_descriptor ?int
	error_message   ?string
}

pub struct FileRequest {
pub:
	on_file_request_finish FileRequestCallback @[required]
mut:
	path_ string
}

pub fn FileRequest.create(path string, callback FileRequestCallback) FileRequest {
	return FileRequest{
		path_:                  path
		on_file_request_finish: callback
	}
}

pub fn (request &FileRequest) path() string {
	return request.path_
}
