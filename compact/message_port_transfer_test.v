module main

import browserjs
import dom
import html
import loader
import platform

fn local_transfer_fixture() !(&browserjs.Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://local-transfer.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_window_message_binding()!
	runtime.install_document_window_event_binding(document, runtime.evaluate_host_value('({})')!)!
	runtime.install_message_channel_binding()!
	return runtime, document
}

fn drain_local_transfer_messages() {
	mut queue := html.main_thread_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .posted_message
		}) or { break }
		task.execute()
	}
}

fn test_local_port_transfer_preserves_graph_and_event_ports_identity() {
	mut runtime, mut document := local_transfer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
globalThis.carrier=new MessageChannel();globalThis.channel=new MessageChannel();globalThis.event=null;globalThis.replies=[];
channel.port2.onmessage=e=>replies.push(e.data);
carrier.port2.onmessage=e=>{event=e;e.ports[0].postMessage("reply");};
const original={port:channel.port1,map:new Map([[channel.port1,channel.port1]]),set:new Set([channel.port1])};original.self=original;
carrier.port1.postMessage(original,[channel.port1]);
let detached=false;try{structuredClone(channel.port1,{transfer:[channel.port1]})}catch(e){detached=e instanceof DOMException&&e.name==="DataCloneError";}
detached&&event===null;
')! == 'true'
	drain_local_transfer_messages()
	assert runtime.evaluate_host(r'
event instanceof MessageEvent&&event.isTrusted&&event.data===event.data&&event.data.self===event.data
&&event.ports===event.ports&&Object.isFrozen(event.ports)&&event.ports.length===1
&&event.ports[0] instanceof MessagePort&&event.ports[0]!==channel.port1&&event.data.port===event.ports[0]
&&event.data.map.get(event.data.port)===event.data.port&&event.data.set.has(event.data.port)&&replies.join()==="reply";
')! == 'true'
}

fn test_local_port_transfer_moves_started_queues_and_messages_sent_in_transit() {
	mut runtime, mut document := local_transfer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
globalThis.channel=new MessageChannel();globalThis.carrier=new MessageChannel();globalThis.received=[];globalThis.oldCalls=0;
channel.port1.onmessage=()=>oldCalls++;
channel.port2.postMessage("scheduled");
carrier.port2.onmessage=e=>{const port=e.ports[0];port.onmessage=e=>received.push(e.data);};
carrier.port1.postMessage(0,[channel.port1]);channel.port2.postMessage("in transit");true;
')! == 'true'
	drain_local_transfer_messages()
	assert runtime.evaluate_host('oldCalls===0&&received.join("|")==="scheduled|in transit"')! == 'true'
}

fn test_local_clone_moves_both_entangled_endpoints_and_mixed_buffers() {
	mut runtime, mut document := local_transfer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
globalThis.channel=new MessageChannel();globalThis.received=[];
const buffer=new ArrayBuffer(8),view=new Uint16Array(buffer);view[1]=1234;
const rab=new ArrayBuffer(4,{maxByteLength:16});new Uint8Array(rab)[2]=57;
globalThis.moved=structuredClone({ports:[channel.port1,channel.port2],buffer,view,rab}, {transfer:[buffer,channel.port1,rab,channel.port2]});
moved.ports[1].onmessage=e=>received.push(e.data);moved.ports[0].postMessage("connected");
const good=buffer.byteLength===0&&rab.byteLength===0&&moved.view.buffer===moved.buffer&&moved.view[1]===1234
&&moved.rab.resizable&&moved.rab.maxByteLength===16&&new Uint8Array(moved.rab)[2]===57;
moved.rab.resize(12);return good&&moved.rab.byteLength===12&&new Uint8Array(moved.rab)[2]===57;
})()')! == 'true'
	drain_local_transfer_messages()
	assert runtime.evaluate_host('received.join()==="connected"')! == 'true'
}

fn test_local_transfer_validation_and_author_exceptions_precede_detachment() {
	mut runtime, mut document := local_transfer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
const carrier=new MessageChannel(),channel=new MessageChannel(),buffer=new ArrayBuffer(4),marker={};let errors=0,reads=0;
const badLists=[[channel.port1,channel.port1],[buffer,buffer],[channel.port1,{}],[new Proxy(channel.port1,{})],[new Proxy(buffer,{})]];
for(const transfer of badLists){try{structuredClone({get value(){reads++;return 1}},{transfer})}catch(e){if(e instanceof DOMException&&e.name==="DataCloneError")errors++;}}
let selfError=false;try{carrier.port1.postMessage({get value(){reads++;return 1}},[carrier.port1])}catch(e){selfError=e instanceof DOMException&&e.name==="DataCloneError";}
let getterError=false;try{structuredClone({get value(){reads++;throw marker}},{transfer:[channel.port1,buffer]})}catch(e){getterError=e===marker;}
let unlisted=false;try{structuredClone(channel.port1)}catch(e){unlisted=e instanceof DOMException&&e.name==="DataCloneError";}
const clone=structuredClone(channel.port1,{transfer:[channel.port1]});
return errors===5&&reads===1&&selfError&&getterError&&unlisted&&buffer.byteLength===4&&clone instanceof MessagePort;
})()')! == 'true'
}

fn test_local_port_transfer_uses_receiver_native_file_context_and_survives_scratch() {
	mut runtime, mut document := local_transfer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	mut streams := browserjs.TransformStreamHost.create(document)!
	streams.install(mut runtime)!
	mut blobs := browserjs.BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut files := browserjs.FileHost.create(document)!
	files.install(mut runtime)!
	files.install_constructor()!
	mut scratch := platform.begin_thread_scratch('local transfer sender')
	assert runtime.evaluate_host(r'
globalThis.carrier=new MessageChannel();globalThis.channel=new MessageChannel();globalThis.saved=null;
carrier.port2.onmessage=e=>{saved=e;};
const file=new File(["Санкт-Петербург 😀"],"name.txt",{type:"TEXT/PLAIN",lastModified:17});
carrier.port1.postMessage({file,again:file,blob:new Blob(["blob"]),port:channel.port1},[channel.port1]);true;
')! == 'true'
	scratch.finish()
	gc_collect()
	mut delivery := platform.begin_thread_scratch('local transfer delivery')
	drain_local_transfer_messages()
	delivery.finish()
	gc_collect()
	assert runtime.evaluate_host(r'
saved!==null&&saved.data.file instanceof File&&saved.data.file instanceof Blob&&saved.data.file===saved.data.again
&&saved.data.file.name==="name.txt"&&saved.data.file.lastModified===17&&saved.data.file.type==="text/plain"
&&saved.data.blob instanceof Blob&&saved.data.port===saved.ports[0];
')! == 'true'
	file := runtime.native_file(runtime.evaluate_host_value('saved.data.file')!)!
	assert file.raw_bytes() == 'Санкт-Петербург 😀'.bytes()
	assert runtime.evaluate_host('carrier.port1.postMessage("after");true')! == 'true'
	runtime.close()
	drain_local_transfer_messages()
}

fn test_local_transfer_checks_detached_slots_after_getters_and_commits_in_list_order() {
	mut runtime, mut document := local_transfer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
const channel=new MessageChannel(),closed=new MessageChannel(),buffer=new ArrayBuffer(4),marker={};closed.port1.close();
let reads=0,getterError=false;try{structuredClone({get value(){reads++;throw marker}},{transfer:[closed.port1]})}catch(e){getterError=e===marker;}
let transferError=false;try{structuredClone(1,{transfer:[buffer,channel.port1,closed.port1]})}catch(e){transferError=e instanceof DOMException&&e.name==="DataCloneError";}
let portDetached=false;try{structuredClone(channel.port1,{transfer:[channel.port1]})}catch(e){portDetached=e instanceof DOMException&&e.name==="DataCloneError";}
return reads===1&&getterError&&transferError&&portDetached&&buffer.byteLength===0;
})()')! == 'true'
}

fn test_local_transfer_doomed_target_and_closed_sender_still_detach_sources() {
	mut runtime, mut document := local_transfer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
globalThis.calls=0;const channel=new MessageChannel(),orphan=new MessageChannel();channel.port2.onmessage=()=>calls++;
const buffer=new ArrayBuffer(2);channel.port1.postMessage("doomed",[channel.port2,buffer]);
channel.port1.close();const other=new ArrayBuffer(3);channel.port1.postMessage(1,[orphan.port1,other]);
let detached=false;try{structuredClone(orphan.port1,{transfer:[orphan.port1]})}catch(e){detached=e instanceof DOMException&&e.name==="DataCloneError";}
return buffer.byteLength===0&&other.byteLength===0&&detached;
})()')! == 'true'
	drain_local_transfer_messages()
	assert runtime.evaluate_host('calls===0')! == 'true'
}
