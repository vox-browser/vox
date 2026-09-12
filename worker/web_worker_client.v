// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Worker/WebWorkerClient.{h,cpp}. IPC transport is an explicit
// embedding boundary; endpoint response and callback semantics live here.
@[has_globals]
module worker

import html

__global all_web_worker_clients = []&WebWorkerClient{}

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

pub type BroadcastChannelMessageCallback = fn (html.BroadcastChannelMessage)

@[heap]
pub struct WebWorkerClient {
pub mut:
	on_worker_close               ?CloseCallback
	on_worker_script_load_failure ?CloseCallback
	on_request_cookie             ?CookieCallback
	on_request_worker_agent       ?WorkerAgentCallback
	on_post_broadcast_message     ?BroadcastChannelMessageCallback
	on_broadcast_message          ?BroadcastChannelMessageCallback
mut:
	pid_ int = -1
}

pub fn WebWorkerClient.create() &WebWorkerClient {
	client := &WebWorkerClient{}
	all_web_worker_clients << client
	return client
}

pub fn (client &WebWorkerClient) close() {
	for index, candidate in all_web_worker_clients {
		if voidptr(candidate) == voidptr(client) {
			all_web_worker_clients.delete(index)
			return
		}
	}
}

pub fn WebWorkerClient.for_each_client(callback fn (&WebWorkerClient) bool) {
	for client in all_web_worker_clients {
		if !callback(client) {
			return
		}
	}
}

pub fn (client &WebWorkerClient) pid() int {
	return client.pid_
}

pub fn (mut client WebWorkerClient) set_pid(pid int) {
	client.pid_ = pid
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

pub fn (client &WebWorkerClient) did_post_broadcast_channel_message(message html.BroadcastChannelMessage) {
	if callback := client.on_post_broadcast_message {
		callback(message)
	}
}

pub fn (client &WebWorkerClient) broadcast_channel_message(message html.BroadcastChannelMessage) {
	if callback := client.on_broadcast_message {
		callback(message)
	}
}

pub fn forward_broadcast_channel_message_to_workers(message html.BroadcastChannelMessage) {
	WebWorkerClient.for_each_client(fn [message] (client &WebWorkerClient) bool {
		client.broadcast_channel_message(message)
		return true
	})
}

pub fn (client &WebWorkerClient) request_worker_agent(kind AgentType) WorkerAgentResponse {
	if callback := client.on_request_worker_agent {
		return callback(kind)
	}
	return WorkerAgentResponse{}
}
