// SPDX-License-Identifier: BSD-2-Clause
// Diagnose a classic worker entry in its actual HTML/JSC worker environment.
module main

import browserjs
import dom
import highresolutiontime
import html
import json
import loader
import os
import platform
import strconv
import time

struct WorkerEntryReport {
	entry_url string
	parent_url string
	final_url string
	state string
	closing bool
	load_error string
	reported_exceptions []string
	outgoing_frames int
	outgoing_bytes u64
	outgoing_messages []string
	settle_milliseconds int
}

fn probe(entry_url dom.URL, parent_url dom.URL, settle_milliseconds int, message_json ?string) !WorkerEntryReport {
	if !loader.is_initialized() { loader.initialize() }
	mut document := html.parse_navigation_document('<!doctype html>', parent_url, parent_url.origin(), none)!
	defer { document.finalize() }
	outside := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut agent := browserjs.WorkerAgentRuntime.create(entry_url, html.WorkerOptions{}, outside.serialize(), highresolutiontime.unsafe_shared_current_time(), none)!
	defer { agent.close() }
	mut load_error := ''
	agent.load_entry() or { load_error = err.msg() }
	mut sender := browserjs.Runtime.create()
	defer { sender.close() }
	sender.bind_scripting_environment(outside)!
	bridge := browserjs.ArrayBufferTransferBridge.create(sender)!
	if message := message_json {
		value := sender.evaluate_host_value('JSON.parse(${json.encode(message)})')!
		defer { sender.release_javascript_value(value) }
		agent.queue_message(browserjs.encode_worker_message(bridge.serialize(value, [])!)!)!
	}
	deadline := time.sys_mono_now() + i64(settle_milliseconds) * time.millisecond
	for agent.state() == .ready && !agent.environment.global_scope.is_closing() && time.sys_mono_now() < deadline {
		agent.process()
		platform.pump_native_events(0.001)
		time.sleep(time.millisecond)
	}
	mut exceptions := []string{}
	for reported in agent.environment.settings.realm().reported_exceptions {
		message := reported.value.to_string_value()
		exceptions << message[..int_min(message.len, 8192)]
		if exceptions.len >= 32 { break }
	}
	frames := agent.take_outgoing()
	mut bytes := u64(0)
	for frame in frames { bytes += u64(frame.len) }
	mut messages := []string{}
	if frames.len > 0 {
		capture := sender.evaluate_host_value('(value)=>{globalThis.__workerEntryMessage=JSON.stringify(value)}')!
		defer { sender.release_javascript_value(capture) }
		for frame in frames[..int_min(frames.len, 32)] {
			value := bridge.deserialize(browserjs.decode_worker_message(frame)!)!
			sender.call_javascript_function(capture, unsafe { nil }, [value])!
			sender.release_javascript_value(value)
			message := sender.evaluate_host('globalThis.__workerEntryMessage')!
			messages << message[..int_min(message.len, 8192)]
		}
	}
	return WorkerEntryReport{
		entry_url: entry_url.serialize()
		parent_url: parent_url.serialize()
		final_url: agent.environment.global_scope.url().serialize()
		state: agent.state().str()
		closing: agent.environment.global_scope.is_closing()
		load_error: load_error
		reported_exceptions: exceptions
		outgoing_frames: frames.len
		outgoing_bytes: bytes
		outgoing_messages: messages
		settle_milliseconds: settle_milliseconds
	}
}

fn int_min(a int, b int) int { return if a < b { a } else { b } }

fn main() {
	if os.args.len < 3 || os.args.len > 5 {
		eprintln('usage: worker-entry-mini ENTRY_URL PARENT_URL [SETTLE_MILLISECONDS [MESSAGE_JSON]]')
		exit(2)
	}
	settle := if os.args.len >= 4 {
		strconv.atoi(os.args[3]) or { eprintln(err); exit(2) }
	} else { 2000 }
	if settle < 0 || settle > 30000 { eprintln('settle must be between 0 and 30000 milliseconds'); exit(2) }
	_ = platform.initialize_browser_heap_policy()
	message := if os.args.len == 5 { ?string(os.args[4]) } else { none }
	report := probe(dom.URL{value: os.args[1]}, dom.URL{value: os.args[2]}, settle, message) or {
		eprintln(err)
		exit(1)
	}
	println(json.encode(report))
	if report.state != 'ready' || report.load_error != '' || report.reported_exceptions.len != 0 { exit(1) }
}
