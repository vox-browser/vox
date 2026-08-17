// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Worker/WebWorkerClient.{h,cpp}. IPC transport is an explicit
// embedding boundary; endpoint response and callback semantics live here.
module worker

pub enum CookieSource {
	http
	non_http
}

pub enum AgentType {
	dedicated_worker
	shared_worker
	service_worker
}

pub struct VersionedCookie {
pub:
	name    string
	value   string
	version u64
}

pub struct TransportHandle {
pub:
	id int
}

pub struct WorkerAgentResponse {
pub:
	client   TransportHandle
	server   TransportHandle
	reserved TransportHandle
}

pub type CloseCallback = fn ()

pub type CookieCallback = fn (string, CookieSource) VersionedCookie

pub type WorkerAgentCallback = fn (AgentType) WorkerAgentResponse

@[heap]
pub struct WebWorkerClient {
pub mut:
	on_worker_close               ?CloseCallback
	on_worker_script_load_failure ?CloseCallback
	on_request_cookie             ?CookieCallback
	on_request_worker_agent       ?WorkerAgentCallback
}

pub fn (_ &WebWorkerClient) die() {
	// Upstream intentionally has no WorkerAgent notification yet.
}

pub fn (client &WebWorkerClient) did_close_worker() {
	if callback := client.on_worker_close {
		callback()
	}
}

pub fn (client &WebWorkerClient) did_fail_loading_worker_script() {
	if callback := client.on_worker_script_load_failure {
		callback()
	}
}

pub fn (client &WebWorkerClient) did_request_cookie(url string, source CookieSource) VersionedCookie {
	if callback := client.on_request_cookie {
		return callback(url, source)
	}
	return VersionedCookie{}
}

pub fn (client &WebWorkerClient) request_worker_agent(kind AgentType) WorkerAgentResponse {
	if callback := client.on_request_worker_agent {
		return callback(kind)
	}
	return WorkerAgentResponse{}
}
