// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Worker-agent, worker diagnostic, BroadcastChannel, JavaScript source, and
// batched DOM-mutation browser-process boundaries.
module page

pub struct WorkerException {
pub:
	message  string
	filename string
	line     u32
	column   u32
}

pub struct JavaScriptSource {
pub:
	document_id u64
	description string
}

pub struct WorkerAgentStartRequest {
pub:
	owner_token string
	script_url  string
}

pub struct WorkerAgentState {
pub:
	id          u64
	owner_token string
	script_url  string
}

pub fn (mut client PageClient) page_did_report_worker_exception(message string, filename string, line u32, column u32) {
	client.worker_exceptions_ << WorkerException{
		message: message
		filename: filename
		line: line
		column: column
	}
	client.record('report-worker-exception', '${filename}:${line}:${column}:${message}')
}

pub fn (client &PageClient) worker_exceptions() []WorkerException {
	return client.worker_exceptions_.clone()
}

pub fn (mut client PageClient) page_did_register_javascript_source(document_id u64, description string) {
	if !client.has_active_devtools_client() {
		return
	}
	client.javascript_sources_ << JavaScriptSource{
		document_id: document_id
		description: description
	}
	client.record('register-javascript-source', '${document_id}:${description}')
}

pub fn (client &PageClient) javascript_sources() []JavaScriptSource {
	return client.javascript_sources_.clone()
}

pub fn (mut client PageClient) page_did_post_broadcast_channel_message(message string) {
	client.broadcast_channel_messages_ << message
	client.record('post-broadcast-channel-message', message)
}

pub fn (client &PageClient) broadcast_channel_messages() []string {
	return client.broadcast_channel_messages_.clone()
}

pub fn (mut client PageClient) start_worker_agent(request WorkerAgentStartRequest) u64 {
	agent_id := client.next_worker_agent_id_
	client.next_worker_agent_id_++
	client.worker_agents_[agent_id] = WorkerAgentState{
		id: agent_id
		owner_token: request.owner_token
		script_url: request.script_url
	}
	client.record('start-worker-agent', '${agent_id}:${request.script_url}')
	return agent_id
}

pub fn (mut client PageClient) close_worker_agent(agent_id u64, owner_token string) {
	agent := client.worker_agents_[agent_id] or { return }
	if agent.owner_token != owner_token {
		return
	}
	client.worker_agents_.delete(agent_id)
	client.record('close-worker-agent', agent_id.str())
}

pub fn (client &PageClient) worker_agent(agent_id u64) ?WorkerAgentState {
	agent := client.worker_agents_[agent_id] or { return none }
	return agent
}

pub fn (mut client PageClient) set_listen_for_dom_mutations(value bool) {
	client.listen_for_dom_mutations_ = value
	if !value {
		client.pending_dom_mutations_.clear()
	}
}

pub fn (mut client PageClient) flush_pending_dom_mutations() {
	if !client.listen_for_dom_mutations_ {
		client.pending_dom_mutations_.clear()
		return
	}
	if client.record_events_ {
		client.events << client.pending_dom_mutations_
	}
	client.pending_dom_mutations_.clear()
}

pub fn (client &PageClient) pending_dom_mutation_count() int {
	return client.pending_dom_mutations_.len
}
