// SPDX-License-Identifier: BSD-2-Clause
// Execute the actual JavaScript Worker constructor across the process boundary.
module main

import browserjs
import dom
import encoding.base64
import html
import json2
import loader
import os
import platform
import time

fn parent() !(&browserjs.Runtime, &browserjs.WorkerHost, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://worker-process.test/maps/current'}
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.WorkerHost.create(settings, os.executable())!
	host.install(mut runtime)!
	return runtime, host, document
}

fn start(runtime &browserjs.Runtime, source string) ! {
	url := 'data:text/javascript;base64,' + base64.encode_str(source)
	runtime.evaluate_host('globalThis.worker=new Worker(${json2.encode(url)},{name:"Санкт-Петербург 😀"})')!
}

fn until(runtime &browserjs.Runtime, document &dom.Document, expression string) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 10 * time.second
	loop.spin_until(fn [runtime, expression, deadline] () bool {
		return time.sys_mono_now() >= deadline || runtime.evaluate_host(expression) or { 'false' } == 'true'
	})
	if runtime.evaluate_host(expression)! != 'true' { return error('Worker deadline: ${expression}') }
}

fn test_constructor_round_trip() ! {
	mut runtime, _, mut document := parent()!
	defer { runtime.close(); document.finalize() }
	start(runtime, r'
 importScripts("data:text/javascript,globalThis.imported%3D40");
 onmessage=event=>{
  const value=event.data;
  if(!event.isTrusted||value.self!==value||value.view.buffer!==value.buffer||value.label!=="Санкт-Петербург 😀"||typeof document!=="undefined")throw Error("worker clone");
  value.view[0]+=2;value.name=name;value.imported=imported;
  close();postMessage(value,{transfer:[value.buffer]});
  if(value.buffer.byteLength!==0)throw Error("worker detach");
 };')!
	assert runtime.evaluate_host(r'
 globalThis.received=null;globalThis.failure=false;
 worker.onerror=()=>failure=true;
 worker.onmessage=function(event){received={event,receiver:this,current:event.currentTarget}};
 const buffer=new ArrayBuffer(4),view=new Uint8Array(buffer);view[0]=40;
 const value={buffer,view,label:"Санкт-Петербург 😀"};value.self=value;
 worker.postMessage(value,[buffer]);buffer.byteLength===0&&received===null;
 ')! == 'true'
	until(runtime, document, 'received!==null||failure')!
	assert runtime.evaluate_host(r'
 !failure&&received.event instanceof MessageEvent&&received.event.isTrusted&&received.event.target===worker&&received.receiver===worker&&received.current===worker&&received.event.currentTarget===null&&received.event.data.self===received.event.data&&received.event.data.view.buffer===received.event.data.buffer&&received.event.data.view[0]===42&&received.event.data.name==="Санкт-Петербург 😀"&&received.event.data.imported===40;
 ')! == 'true'
	println('PASS JavaScript Worker constructor, pre-ready message, importScripts and transferred clone round trip')
}

fn test_constructor_failure() ! {
	mut runtime, _, mut document := parent()!
	defer { runtime.close(); document.finalize() }
	start(runtime, 'postMessage("unreachable");const = ;')!
	assert runtime.evaluate_host(r'
 globalThis.errors=0;globalThis.messages=0;
 worker.onmessage=()=>messages++;
 worker.onerror=function(event){if(event.type!=="error"||!event.isTrusted||event.target!==worker||this!==worker)throw Error("error target");event.preventDefault();errors++};
 errors===0&&messages===0;
 ')! == 'true'
	until(runtime, document, 'errors===1')!
	assert runtime.evaluate_host('messages===0')! == 'true'
	println('PASS JavaScript Worker syntax failure dispatches asynchronously on its actual parent target')
}

fn test_constructor_terminate_and_close() ! {
	mut runtime, mut host, mut document := parent()!
	defer { runtime.close(); document.finalize() }
	start(runtime, 'onmessage=event=>postMessage(event.data);setInterval(()=>{},1);postMessage("boot");')!
	runtime.evaluate_host('globalThis.messages=[];worker.onmessage=event=>messages.push(event.data);globalThis.failure=false;worker.onerror=()=>failure=true')!
	until(runtime, document, 'messages.length===1||failure')!
	assert runtime.evaluate_host('!failure&&messages[0]==="boot"')! == 'true'
	runtime.evaluate_host('worker.postMessage("discard");worker.terminate();worker.terminate()')!
	for _ in 0 .. 20 { host.poll(); platform.pump_native_events(0.001) }
	assert runtime.evaluate_host('messages.length===1')! == 'true'
	start(runtime, 'setInterval(()=>postMessage("tick"),1);')!
	runtime.evaluate_host('worker.onmessage=()=>{throw Error("closed parent callback")}')!
	runtime.close()
	host.poll()
	println('PASS JavaScript Worker terminate and parent-runtime shutdown reap child agents and discard deliveries')
}

fn main() {
	if status := browserjs.run_worker_process_role(os.args) { exit(status) }
	_ = platform.initialize_browser_heap_policy()
	test_constructor_round_trip() or { eprintln(err); exit(1) }
	test_constructor_failure() or { eprintln(err); exit(1) }
	test_constructor_terminate_and_close() or { eprintln(err); exit(1) }
}
