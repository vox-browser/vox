module browserjs

import dom
import html
import json2
import os
import page as page_module
import time

struct WebSocketHostFixturePorts {
	http_port int
}

// The binding captures EventTarget, Event and MessageEvent at install time.
// A bare runtime has none, so the test supplies minimal implementations.
const websocket_host_test_events = r'
 globalThis.EventTarget=class EventTarget{constructor(){this.listeners={}}addEventListener(type,callback){(this.listeners[type]=this.listeners[type]||[]).push(callback)}removeEventListener(){}dispatchEvent(event){for(const callback of this.listeners[event.type]||[])callback.call(this,event);return true}};
 globalThis.Event=class Event{constructor(type){this.type=type}};
 globalThis.MessageEvent=class MessageEvent extends Event{constructor(type,init){super(type);this.data=init.data;this.origin=init.origin}};
'

fn test_websocket_binding_opens_exchanges_and_closes() {
	$if !darwin { return }
	node := os.find_abs_path_of_executable('node') or { return }
	openssl := os.find_abs_path_of_executable('openssl') or { return }
	directory := os.join_path(os.temp_dir(), 'vox-websocket-host-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	mut process := os.new_process(node)
	process.set_args([os.join_path(os.dir(@FILE), '..', 'browsernet', 'fixtures', 'http2_server.mjs'), directory, openssl])
	process.set_redirect_stdio()
	process.run()
	defer {
		process.signal_kill()
		process.wait()
		process.close()
		os.rmdir_all(directory) or {}
	}
	ready := os.join_path(directory, 'ready.json')
	for _ in 0 .. 1000 {
		if os.exists(ready) { break }
		time.sleep(10 * time.millisecond)
	}
	port := json2.decode[WebSocketHostFixturePorts](os.read_file(ready)!)!.http_port
	os.setenv('VOX_PROXY', '', true)
	defer { os.unsetenv('VOX_PROXY') }
	page := 'http://127.0.0.1:${port}/page'
	mut runtime := Runtime.create()
	mut document := html.parse_navigation_document('<!doctype html><body></body>', dom.URL{ value: page },
		dom.URL{ value: page }.origin(), none)!
	mut owner := page_module.Page.create(1)!
	document.set_page(unsafe { &dom.Page(owner) })
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') })!
	document.update_the_visibility_state(.visible)
	defer {
		runtime.close()
		document.finalize()
	}
	mut query := URLSearchParamsHost.create(document)!
	query.install(mut runtime)!
	mut urls := URLHost.create(document)!
	urls.install(mut runtime)!
	runtime.evaluate_host(websocket_host_test_events + 'globalThis.location={href:"${page}"};')!
	mut host := WebSocketHost.create(document, '', none)!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 let errors=0;for(const make of [()=>new WebSocket(),()=>new WebSocket("ftp://example.com/"),()=>new WebSocket("ws://example.com/#fragment"),()=>new WebSocket("ws://example.com/",["a","a"]),()=>new WebSocket("ws://example.com/","bad protocol")]){try{make()}catch(error){errors++}}
 errors===5&&WebSocket.OPEN===1&&WebSocket.prototype.CLOSED===3&&WebSocket.length===1;
 ')! == 'true'
	runtime.evaluate_host('globalThis.log=[];const socket=new WebSocket("/ws/echo",["chat"]);socket.binaryType="arraybuffer";globalThis.socket=socket;' +
		r'log.push("state:"+socket.readyState+":"+socket.url);
 try{socket.send("too early")}catch(error){log.push("early")}
 socket.onopen=()=>{log.push("open:"+socket.protocol+":"+socket.readyState);socket.send("hi");socket.send(new Uint8Array([9,1,2,3]).subarray(1));};
 socket.onmessage=event=>{log.push(typeof event.data==="string"?"text:"+event.data:"binary:"+new Uint8Array(event.data).join("."));if(log.length===6){try{socket.close(1001)}catch(error){log.push("invalid-code")}socket.close(1000,"done")}};
 socket.onclose=event=>{log.push("close:"+event.code+":"+event.wasClean+":"+(event instanceof CloseEvent)+":"+socket.readyState)};')!
	// Connection threads only wake the embedder; poll and run the queued
	// WebSocket tasks the way the browser frame loop does.
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := unsafe { &html.EventLoop(host.settings.responsible_event_loop()) }
	for runtime.evaluate_host('log.length>=8')! != 'true' && time.sys_mono_now() < deadline {
		poll_websocket_hosts()
		for loop.task_queue().has_runnable_tasks() {
			loop.process()
		}
		time.sleep(5 * time.millisecond)
	}
	log := runtime.evaluate_host('JSON.stringify(log)')!
	assert log == '["state:0:ws://127.0.0.1:${port}/ws/echo","early","open:chat:1","text:hello","text:echo:hi","binary:1.2.3","invalid-code","close:1000:true:true:3"]', log
}
