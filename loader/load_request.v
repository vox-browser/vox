// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/LoadRequest.h and Loader/FileRequest.{h,cpp}.
module loader

import dom
import fetch
import http
import time

pub enum NavigatorCompatibilityMode {
	chrome
	gecko
	webkit
}

pub struct LoadRequest {
pub mut:
	url                 ?dom.URL
	method              string           = 'GET'
	headers             &http.HeaderList = http.HeaderList.create()
	body                []u8
	cache_mode          fetch.CacheMode
	include_credentials bool = true
	initiator_type      ?fetch.InitiatorType
	page_id             ?u64
mut:
	started_at ?time.Time
}

pub fn LoadRequest.create(headers &http.HeaderList) &LoadRequest {
	return &LoadRequest{
		headers: headers
	}
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
	path                   string
	on_file_request_finish FileRequestCallback @[required]
}

pub fn FileRequest.create(path string, callback FileRequestCallback) FileRequest {
	return FileRequest{
		path:                   path
		on_file_request_finish: callback
	}
}
