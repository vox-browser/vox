// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module main

import browserjs
import dom
import encoding.base64
import html
import os
import platform
import time

fn read_frame(process &browserjs.WorkerProcess) !browserjs.WorkerProcessFrame {
	deadline := time.sys_mono_now() + 10 * time.second
	for time.sys_mono_now() < deadline {
		process.flush()!
		read := process.receive()!
		if frame := read.frame { return frame }
		if read.ended { return error('Worker ended before the expected frame') }
		process.wait(5)!
	}
	return error('Worker frame deadline')
}

fn wait_for_end(process &browserjs.WorkerProcess) ! {
	deadline := time.sys_mono_now() + 10 * time.second
	for time.sys_mono_now() < deadline {
		process.flush()!
		read := process.receive()!
		if read.frame != none { return error('Unexpected worker frame after completion') }
		if read.ended { return }
		process.wait(5)!
	}
	return error('Worker shutdown deadline')
}

fn start(source string) !&browserjs.WorkerProcess {
	mut process := browserjs.WorkerProcess.spawn(os.executable())!
	mut started := false
	defer { if !started { process.close() } }
	parent := dom.URL{value: 'https://worker-process.test/maps/current#private'}
	bytes := browserjs.encode_worker_startup(browserjs.WorkerStartup{
		url: dom.URL{value: 'data:text/javascript;base64,' + base64.encode_str(source)}
		options: html.WorkerOptions{name: 'Санкт-Петербург 😀'}
		creation_time: 12
		outside: html.SerializedEnvironmentSettingsObject{
			creation_url: parent
			api_base_url: parent
			origin: parent.origin()
			global: html.SerializedWindow{associated_document: html.SerializedDocument{
				url: parent
				relevant_settings_object_is_secure_context: true
			}}
		}
	})!
	process.queue(u32(browserjs.WorkerAgentFrameKind.start), bytes)!
	started = true
	return process
}

fn test_round_trip() ! {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	bridge := browserjs.ArrayBufferTransferBridge.create(runtime)!
	mut process := start(r'
importScripts("data:text/javascript,globalThis.imported%3D40");
if(!(self instanceof DedicatedWorkerGlobalScope)||typeof document!=="undefined"||imported!==40)throw Error("worker realm");
onmessage=event=>{
 const value=event.data;
 if(!event.isTrusted||value.self!==value||value.view.buffer!==value.buffer||value.label!=="Санкт-Петербург 😀")throw Error("worker clone");
 value.view[0]+=2;value.name=name;
 close();postMessage(value,[value.buffer]);
 if(value.buffer.byteLength!==0)throw Error("worker detach");
};
postMessage("entry");')!
	defer { process.close() }
	assert read_frame(process)!.kind == u32(browserjs.WorkerAgentFrameKind.ready)
	entry := read_frame(process)!
	assert entry.kind == u32(browserjs.WorkerAgentFrameKind.message)
	check_entry := runtime.evaluate_host_value('(value)=>{if(value!=="entry")throw Error("entry message")}')!
	runtime.call_javascript_function(check_entry, unsafe { nil }, [bridge.deserialize(browserjs.decode_worker_message(entry.bytes)!)!])!
	payload := runtime.evaluate_host_value(r'globalThis.payload=(()=>{const buffer=new ArrayBuffer(4),view=new Uint8Array(buffer);view[0]=40;const value={buffer,view,label:"Санкт-Петербург 😀"};value.self=value;return value})()')!
	buffer := runtime.evaluate_host_value('payload.buffer')!
	process.queue(u32(browserjs.WorkerAgentFrameKind.message), browserjs.encode_worker_message(bridge.serialize(payload, [buffer])!)!)!
	assert runtime.evaluate_host('payload.buffer.byteLength')! == '0'
	response := read_frame(process)!
	assert response.kind == u32(browserjs.WorkerAgentFrameKind.message)
	value := bridge.deserialize(browserjs.decode_worker_message(response.bytes)!)!
	check := runtime.evaluate_host_value(r'(value)=>{if(value.self!==value||value.view.buffer!==value.buffer||value.view[0]!==42||value.buffer.byteLength!==4||value.name!=="Санкт-Петербург 😀")throw Error("parent clone")}')!
	runtime.call_javascript_function(check, unsafe { nil }, [value])!
	wait_for_end(process)!
	println('PASS isolated worker entry, importScripts, trusted messages, cycles, views and ArrayBuffer transfer')
}

fn test_load_failure() ! {
	mut process := start('postMessage("unreachable");const = ;')!
	defer { process.close() }
	frame := read_frame(process)!
	assert frame.kind == u32(browserjs.WorkerAgentFrameKind.load_failure)
	assert frame.bytes.len == 0
	wait_for_end(process)!
	println('PASS isolated worker syntax failure and process exit')
}

fn test_shutdown() ! {
	mut process := start('setInterval(()=>{},1);postMessage("running");')!
	defer { process.close() }
	assert read_frame(process)!.kind == u32(browserjs.WorkerAgentFrameKind.ready)
	assert read_frame(process)!.kind == u32(browserjs.WorkerAgentFrameKind.message)
	process.queue(u32(browserjs.WorkerAgentFrameKind.shutdown), [])!
	wait_for_end(process)!
	process.close()
	println('PASS isolated worker timer cleanup and parent shutdown')
}

fn main() {
	if status := browserjs.run_worker_process_role(os.args) { exit(status) }
	_ = platform.initialize_browser_heap_policy()
	test_round_trip() or { eprintln(err); exit(1) }
	test_load_failure() or { eprintln(err); exit(1) }
	test_shutdown() or { eprintln(err); exit(1) }
}
