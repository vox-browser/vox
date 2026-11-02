module browserjs

import dom
import fetch
import html
import http
import loader
import platform

fn worker_port_parent() !(&Runtime, &WorkerHost, &RemoteWorker, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://worker-port.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut host := WorkerHost.create(settings, '/nonexistent-worker-port-test')!
	host.install(mut runtime)!
	worker := runtime.evaluate_host_value('globalThis.worker=new Worker("entry.js");worker')!
	return runtime, host, host.workers[worker] or { return error('Missing worker') }, document
}

fn worker_port_child(source string) !&WorkerChildSession {
	url := dom.URL{ value: 'https://worker-port.test/entry.js' }
	transport := &fetch.FetchHost{ perform: fn [source] (request &fetch.Request) !&fetch.Response {
		mut response := fetch.Response.create()
		response.url_list = request.url_list.clone()
		response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
		response.set_body_bytes(source.bytes())
		return response
	} }
	mut child := WorkerChildSession.create(transport)
	child.accept(WorkerProcessFrame{ kind: u32(WorkerAgentFrameKind.start), bytes: encode_worker_startup(WorkerStartup{
		url: url
		options: html.WorkerOptions{ type_: .module_ }
		outside: html.SerializedEnvironmentSettingsObject{ creation_url: url, api_base_url: url, origin: url.origin(),
			policy_container: html.SerializedPolicyContainer{ referrer_policy: .strict_origin_when_cross_origin }
			global: html.SerializedWindow{ associated_document: html.SerializedDocument{ url: url, relevant_settings_object_is_secure_context: true } }
		}
	})! })!
	frames := child.take_outgoing()
	assert frames.len == 1 && frames[0].kind == u32(WorkerAgentFrameKind.ready)
	return child
}

fn worker_port_parent_tasks(host &WorkerHost) {
	mut queue := host.settings.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .posted_message }) or { break }
		task.execute()
	}
}

fn test_worker_port_transfer_preserves_aliases_event_ports_and_messages_before_deserialization() {
	mut parent, mut host, mut remote, mut document := worker_port_parent()!
	defer { parent.close(); document.finalize() }
	mut child := worker_port_child(r'
 onmessage=event=>{
  const port=event.data.port;
  port.postMessage({ready:port instanceof MessagePort&&event.ports[0]===port&&event.ports.length===1&&Object.isFrozen(event.ports)&&event.data.alias===port&&event.data.self===event.data&&event.data.view.buffer===event.data.buffer,bytes:Array.from(event.data.view)});
  port.onmessage=event=>{const buffer=new ArrayBuffer(2);new Uint8Array(buffer).set([128,255]);port.postMessage({echo:event.data,buffer,view:new Uint8Array(buffer)},[buffer]);postMessage(buffer.detached)};
 };
 ')!
	defer { child.close() }
	parent.evaluate_host('globalThis.channel=new MessageChannel();globalThis.received=[];globalThis.detached=[];channel.port1.onmessage=event=>received.push({data:event.data,target:event.target,trusted:event.isTrusted});worker.onmessage=event=>detached.push(event.data);globalThis.buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([0,128,255]);globalThis.payload={port:channel.port2,alias:channel.port2,buffer,view:new Uint8Array(buffer,1)};payload.self=payload;')!
	mut caller := platform.begin_thread_scratch('worker port transfer caller')
	value := parent.evaluate_host_value('payload')!
	port := parent.evaluate_host_value('channel.port2')!
	buffer := parent.evaluate_host_value('buffer')!
	record := host.transfer.serialize_for_worker(value, [port, buffer], remote.ports)!
	bytes := encode_worker_message(record)!
	assert bytes[..4] == 'VXM2'.bytes()
	caller.finish()
	assert parent.native_message_port(port)?.is_detached()
	assert parent.evaluate_host('buffer.detached')! == 'true'
	child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.message), bytes: bytes})!
	// The port frame reaches the child before the posted Worker message runs.
	parent.evaluate_host('channel.port1.postMessage("early native port message")')!
	for frame in remote.ports.take_outgoing()! {
		child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.port_message), bytes: frame})!
	}
	for _ in 0 .. 5 {
		child.process()
		for frame in child.take_outgoing() {
			match frame.kind {
				u32(WorkerAgentFrameKind.port_message) { remote.ports.queue_incoming(frame.bytes)! }
				u32(WorkerAgentFrameKind.message) { host.queue_message(remote, frame.bytes)! }
				else { assert false, 'Unexpected worker frame' }
			}
		}
	}
	assert parent.evaluate_host('received.length')! == '0'
	mut delivery := platform.begin_thread_scratch('worker port transfer delivery')
	worker_port_parent_tasks(host)
	delivery.finish()
	assert parent.evaluate_host(r'
 received.length===2&&received[0].data.ready&&received[0].data.bytes.join()==="128,255"&&received.every(item=>item.target===channel.port1&&item.trusted)&&received[1].data.echo==="early native port message"&&received[1].data.buffer instanceof ArrayBuffer&&received[1].data.view instanceof Uint8Array&&received[1].data.view.buffer===received[1].data.buffer&&Array.from(received[1].data.view).join()==="128,255"&&detached.length===1&&detached[0]===true;
 ')! == 'true'
}

fn test_worker_can_transfer_a_fresh_port_to_parent_and_route_messages_in_both_directions() {
	mut parent, mut host, mut remote, mut document := worker_port_parent()!
	defer { parent.close(); document.finalize() }
	mut child := worker_port_child('onmessage=()=>{const channel=new MessageChannel();channel.port1.onmessage=event=>channel.port1.postMessage(event.data+1);postMessage({port:channel.port2},[channel.port2]);channel.port1.postMessage(40)};')!
	defer { child.close() }
	parent.evaluate_host('globalThis.received=[];worker.onmessage=event=>{globalThis.port=event.data.port;globalThis.portIdentity=event.ports[0]===port&&port instanceof MessagePort;port.onmessage=event=>received.push(event.data)};')!
	child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.message), bytes: encode_worker_message(host.transfer.serialize(parent.evaluate_host_value('1')!, [])!)!})!
	child.process()
	for frame in child.take_outgoing() {
		if frame.kind == u32(WorkerAgentFrameKind.message) { host.queue_message(remote, frame.bytes)! }
		else if frame.kind == u32(WorkerAgentFrameKind.port_message) { remote.ports.queue_incoming(frame.bytes)! }
		else { assert false }
	}
	worker_port_parent_tasks(host)
	assert parent.evaluate_host('portIdentity&&received.join()==="40"')! == 'true'
	parent.evaluate_host('port.postMessage(41)')!
	for bytes in remote.ports.take_outgoing()! { child.accept(WorkerProcessFrame{kind: u32(WorkerAgentFrameKind.port_message), bytes: bytes})! }
	child.process()
	for frame in child.take_outgoing() { assert frame.kind == u32(WorkerAgentFrameKind.port_message); remote.ports.queue_incoming(frame.bytes)! }
	worker_port_parent_tasks(host)
	assert parent.evaluate_host('received.join()==="40,42"')! == 'true'
}

fn test_worker_port_rejections_preserve_sources_and_do_not_serialize_native_ports_as_plain_objects() {
	mut parent, mut host, mut remote, mut document := worker_port_parent()!
	defer { parent.close(); document.finalize() }
	parent.evaluate_host('globalThis.channel=new MessageChannel();globalThis.buffer=new ArrayBuffer(1);globalThis.getters=0;')!
	port := parent.evaluate_host_value('channel.port2')!
	buffer := parent.evaluate_host_value('buffer')!
	value := parent.evaluate_host_value('({get value(){getters++;return 1}})')!
	if _ := host.transfer.serialize_for_worker(value, [port, port, buffer], remote.ports) { assert false }
	assert !parent.native_message_port(port)?.is_detached()
	assert parent.evaluate_host('getters===0&&!buffer.detached')! == 'true'
	if _ := host.transfer.serialize_for_worker(port, [], remote.ports) { assert false }
	parent.evaluate_host('channel.port1.postMessage("queued")')!
	if _ := host.transfer.serialize_for_worker(value, [port], remote.ports) { assert false }
	assert !parent.native_message_port(port)?.is_detached()
	parent.evaluate_host('globalThis.received=[];channel.port2.onmessage=event=>received.push(event.data)')!
	worker_port_parent_tasks(host)
	assert parent.evaluate_host('received.join()==="queued"')! == 'true'
	if _ := host.transfer.serialize_for_worker(value, [port], remote.ports) { assert false }
	assert !parent.native_message_port(port)?.is_detached()
	assert parent.evaluate_host(r'
 let caught=false;try{worker.postMessage({get value(){getters++;return 1}},[channel.port2])}catch(error){caught=error instanceof DOMException&&error.name==="DataCloneError"}
 caught&&getters===0&&!buffer.detached;
 ')! == 'true'
}

fn test_message_port_buffer_transfer_uses_captured_intrinsics_and_keeps_queued_data_owned() {
	mut parent, host, _, mut document := worker_port_parent()!
	defer { parent.close(); document.finalize() }
	mut caller := platform.begin_thread_scratch('local port buffer transfer caller')
	assert parent.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.received=[];
 channel.port1.onmessage=event=>received.push(event.data);
 globalThis.buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([0,128,255]);
 const original=ArrayBuffer.prototype.transfer;
 try{ArrayBuffer.prototype.transfer=function(){throw new Error("author transfer")};channel.port2.postMessage({buffer,view:new Uint8Array(buffer,1)},{transfer:[buffer]})}finally{ArrayBuffer.prototype.transfer=original}
 buffer.detached&&received.length===0;
 ')! == 'true'
	caller.finish()
	mut delivery := platform.begin_thread_scratch('local port buffer transfer delivery')
	worker_port_parent_tasks(host)
	delivery.finish()
	assert parent.evaluate_host('received.length===1&&received[0].buffer instanceof ArrayBuffer&&received[0].view instanceof Uint8Array&&received[0].view.buffer===received[0].buffer&&Array.from(received[0].view).join()==="128,255"')! == 'true'
}

fn test_terminated_worker_still_transfers_fresh_ports_and_buffers_then_discards_delivery() {
	mut parent, _, mut remote, mut document := worker_port_parent()!
	defer { parent.close(); document.finalize() }
	assert parent.evaluate_host('worker.terminate();globalThis.channel=new MessageChannel();globalThis.buffer=new ArrayBuffer(1);worker.postMessage({port:channel.port2,buffer},[channel.port2,buffer]);buffer.detached')! == 'true'
	port := parent.native_message_port(parent.evaluate_host_value('channel.port2')!)?
	peer := parent.native_message_port(parent.evaluate_host_value('channel.port1')!)?
	assert port.is_detached()
	assert !peer.is_detached() && !peer.is_entangled()
	assert remote.ports.closed && remote.ports.proxies.len == 0
}
