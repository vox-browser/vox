module main

import browserjs
import dom
import fetch
import html
import http
import time

fn worker_file_parent() (&browserjs.Runtime, &dom.Document) {
	mut runtime := browserjs.Runtime.create()
	document := dom.Document.create(dom.URL{value: 'https://worker-files.test/owner'})
	mut streams := browserjs.TransformStreamHost.create(document) or { panic(err) }
	streams.install(mut runtime) or { panic(err) }
	mut blobs := browserjs.BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := browserjs.FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	files.install_constructor() or { panic(err) }
	mut lists := browserjs.FileListHost.create(document) or { panic(err) }
	lists.install(mut runtime) or { panic(err) }
	lists.install_constructor() or { panic(err) }
	return runtime, document
}

fn worker_file_agent(source string, module_ bool, shared bool) !&browserjs.WorkerAgentRuntime {
	url := dom.URL{value: 'https://worker-files.test/entry.js'}
	transport := &fetch.FetchHost{perform: fn [source] (_ &fetch.Request) !&fetch.Response {
		mut response := fetch.Response.create()
		response.header_list.append(http.Header{name: 'Content-Type', value: 'text/javascript'})
		response.set_body_bytes(source.bytes())
		return response
	}}
	outside := html.SerializedEnvironmentSettingsObject{
		creation_url: url
		api_base_url: url
		origin: url.origin()
		global: html.SerializedWindow{associated_document: html.SerializedDocument{url: url, relevant_settings_object_is_secure_context: true}}
	}
	options := html.WorkerOptions{type_: if module_ { .module_ } else { .classic }}
	if shared { return browserjs.WorkerAgentRuntime.create_shared(url, options, outside, 1, transport) }
	return browserjs.WorkerAgentRuntime.create(url, options, outside, 1, transport)
}

fn test_worker_file_interfaces_keep_native_blob_inheritance_and_clone_file_bytes() {
	for module_ in [false, true] {
		mut parent, mut document := worker_file_parent()
		defer { parent.close(); document.finalize() }
		mut agent := worker_file_agent(r'
const check=(value,message)=>{if(!value)throw Error(message)};
check(typeof window==="undefined"&&typeof document==="undefined","worker realm");
check(Object.getPrototypeOf(File)===Blob&&Object.getPrototypeOf(File.prototype)===Blob.prototype,"native inheritance");
check(File.length===2&&File.name==="File"&&Object.prototype.toString.call(FileList.prototype)==="[object FileList]","interface metadata");
let rejected=false;try{new FileList()}catch(error){rejected=error instanceof TypeError}check(rejected,"illegal FileList constructor");
const file=new File(["a\r\nb\rc\n",new Uint8Array([0,255])],"name.txt",{type:"TEXT/PLAIN",endings:"native",lastModified:42});
check(file instanceof File&&file instanceof Blob&&file.name==="name.txt"&&file.lastModified===42,"File members");
const slice=file.slice(0,1);check(slice instanceof Blob&&!(slice instanceof File),"slice returns Blob");
Promise.all([file.arrayBuffer(),slice.text()]).then(([bytes,text])=>{check(Array.from(new Uint8Array(bytes)).join() === "97,10,98,10,99,10,0,255"&&text==="a","native bytes");postMessage(file)});
', module_, false)!
		defer { agent.close() }
		agent.load_entry()!
		deadline := time.sys_mono_now() + 5 * time.second
		mut frames := [][]u8{}
		for frames.len == 0 && time.sys_mono_now() < deadline {
			agent.process()
			frames << agent.take_outgoing()
		}
		assert frames.len == 1, 'module=${module_}'
		bridge := browserjs.ArrayBufferTransferBridge.create(parent)!
		wrapper := bridge.deserialize(browserjs.decode_worker_message(frames[0])!)!
		file := parent.native_file(wrapper)!
		assert file.name() == 'name.txt' && file.type_() == 'text/plain' && file.last_modified() == 42
		assert file.raw_bytes() == [u8(97), 10, 98, 10, 99, 10, 0, 255]
		agent.close()
		assert file.raw_bytes().len == 8
	}
}

fn test_shared_worker_exposes_file_and_file_list_in_its_actual_global() {
	mut parent, mut document := worker_file_parent()
	defer { parent.close(); document.finalize() }
	parent.install_message_channel_binding()!
	mut agent := worker_file_agent(r'
onconnect=event=>{
 const file=new File(["shared"],"shared.txt",{lastModified:7});
 if(!(file instanceof File)||!(file instanceof Blob)||typeof FileList!=="function")throw Error("shared File interfaces");
 event.ports[0].postMessage({file:file instanceof File,blob:file instanceof Blob,name:file.name,lastModified:file.lastModified,list:typeof FileList});
};', false, true)!
	defer { agent.close() }
	agent.load_entry()!
	bridge := browserjs.ArrayBufferTransferBridge.create(parent)!
	mut ports := browserjs.WorkerPortRouter.create(parent, true)!
	defer { ports.close() }
	parent.evaluate_host('globalThis.fileChannel=new MessageChannel();globalThis.sharedFile=null;fileChannel.port1.onmessage=event=>sharedFile=event.data;')!
	record := bridge.serialize_for_worker(parent.evaluate_host_value('null')!, [parent.evaluate_host_value('fileChannel.port2')!], ports)!
	agent.queue_message(browserjs.encode_worker_message(record)!)!
	mut loop := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.responsible_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	for parent.evaluate_host('sharedFile===null')! == 'true' && time.sys_mono_now() < deadline {
		agent.process()
		for bytes in agent.take_outgoing_port_messages()! { ports.queue_incoming(bytes)! }
		loop.process()
	}
	assert parent.evaluate_host('sharedFile.file&&sharedFile.blob&&sharedFile.name==="shared.txt"&&sharedFile.lastModified===7&&sharedFile.list==="function"')! == 'true'
}

fn test_shared_worker_port_clones_native_file_into_the_receiver_context() {
	mut parent, mut document := worker_file_parent()
	defer { parent.close(); document.finalize() }
	parent.install_message_channel_binding()!
	mut agent := worker_file_agent(r'
onconnect=event=>event.ports[0].postMessage(new File(["shared bytes"],"shared.txt",{type:"TEXT/PLAIN",lastModified:7}));
', false, true)!
	defer { agent.close() }
	agent.load_entry()!
	bridge := browserjs.ArrayBufferTransferBridge.create(parent)!
	mut ports := browserjs.WorkerPortRouter.create(parent, true)!
	defer { ports.close() }
	parent.evaluate_host('globalThis.fileChannel=new MessageChannel();globalThis.sharedFile=null;fileChannel.port1.onmessage=event=>sharedFile=event.data;')!
	record := bridge.serialize_for_worker(parent.evaluate_host_value('null')!, [parent.evaluate_host_value('fileChannel.port2')!], ports)!
	agent.queue_message(browserjs.encode_worker_message(record)!)!
	mut loop := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.responsible_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	for parent.evaluate_host('sharedFile===null')! == 'true' && time.sys_mono_now() < deadline {
		agent.process()
		for bytes in agent.take_outgoing_port_messages()! { ports.queue_incoming(bytes)! }
		loop.process()
	}
	assert parent.evaluate_host('sharedFile instanceof File&&sharedFile instanceof Blob&&sharedFile.name==="shared.txt"&&sharedFile.lastModified===7&&sharedFile.type==="text/plain"')! == 'true'
	file := parent.native_file(parent.evaluate_host_value('sharedFile')!)!
	agent.close()
	assert file.raw_bytes() == 'shared bytes'.bytes()
}

fn test_shared_worker_port_keeps_array_buffer_transfers_and_view_aliases() {
	mut parent, mut document := worker_file_parent()
	defer { parent.close(); document.finalize() }
	parent.install_message_channel_binding()!
	mut agent := worker_file_agent(r'
onconnect=event=>{const port=event.ports[0];port.onmessage=event=>{
 const data=event.data;if(data.view.buffer!==data.buffer||data.view[1]!==42)throw Error("received buffer aliases");
 port.postMessage(data,[data.buffer]);if(data.buffer.byteLength!==0)throw Error("worker source not detached");
};};
', false, true)!
	defer { agent.close() }
	agent.load_entry()!
	bridge := browserjs.ArrayBufferTransferBridge.create(parent)!
	mut ports := browserjs.WorkerPortRouter.create(parent, true)!
	defer { ports.close() }
	parent.evaluate_host('globalThis.bufferChannel=new MessageChannel();globalThis.bufferReply=null;bufferChannel.port1.onmessage=event=>bufferReply=event.data;')!
	record := bridge.serialize_for_worker(parent.evaluate_host_value('null')!, [parent.evaluate_host_value('bufferChannel.port2')!], ports)!
	agent.queue_message(browserjs.encode_worker_message(record)!)!
	agent.process()
	assert parent.evaluate_host('globalThis.sentBuffer=new ArrayBuffer(4);new Uint8Array(sentBuffer)[1]=42;bufferChannel.port1.postMessage({buffer:sentBuffer,view:new Uint8Array(sentBuffer)},[sentBuffer]);sentBuffer.byteLength===0')! == 'true'
	for bytes in ports.take_outgoing()! { agent.queue_port_message(bytes)! }
	mut loop := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.responsible_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	for parent.evaluate_host('bufferReply===null')! == 'true' && time.sys_mono_now() < deadline {
		agent.process()
		for bytes in agent.take_outgoing_port_messages()! { ports.queue_incoming(bytes)! }
		loop.process()
	}
	assert parent.evaluate_host('bufferReply!==null&&bufferReply.view.buffer===bufferReply.buffer&&bufferReply.buffer.byteLength===4&&bufferReply.view[1]===42')! == 'true'
}
