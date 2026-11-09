module browserjs

import dom
import fetch
import html
import http

fn test_shared_worker_agent_owns_its_global_and_queues_connect_port_messages() {
	url := dom.URL{value: 'https://shared-agent.test/entry.js'}
	transport := &fetch.FetchHost{perform: fn (request &fetch.Request) !&fetch.Response {
		assert (request.destination or { panic("Missing destination") }) == fetch.Destination.shared_worker
		mut response := fetch.Response.create()
		response.header_list.append(http.Header{name: 'Content-Type', value: 'text/javascript'})
		response.set_body_bytes(r'
globalThis.connections=0;
onconnect=event=>{
 connections++;
 if(event.source!==event.ports[0]||event.target!==self||event.data!=="")throw new Error("connect event");
 const port=event.ports[0];port.onmessage=event=>port.postMessage({echo:event.data,count:connections});
 port.postMessage({count:connections,name,scope:self instanceof SharedWorkerGlobalScope});
};
'.bytes())
		return response
	}}
	outside := html.SerializedEnvironmentSettingsObject{
		creation_url: url
		api_base_url: url
		origin: url.origin()
		global: html.SerializedWindow{associated_document: html.SerializedDocument{url: url, relevant_settings_object_is_secure_context: true}}
	}
	mut agent := WorkerAgentRuntime.create_shared(url, html.WorkerOptions{name: 'shared map'}, outside, 1, transport)!
	defer { agent.close() }
	agent.load_entry()!
	assert agent.runtime.evaluate_host('self===globalThis&&self instanceof SharedWorkerGlobalScope&&self instanceof WorkerGlobalScope&&Object.getPrototypeOf(self)===SharedWorkerGlobalScope.prototype&&Object.prototype.toString.call(self)==="[object SharedWorkerGlobalScope]"&&typeof DedicatedWorkerGlobalScope==="undefined"&&typeof postMessage==="undefined"&&typeof window==="undefined"&&typeof indexedDB==="object"&&connections===0&&name==="shared map"')! == 'true', agent.runtime.evaluate_host('JSON.stringify({self:self===globalThis,shared:self instanceof SharedWorkerGlobalScope,worker:self instanceof WorkerGlobalScope,prototype:Object.getPrototypeOf(self)===SharedWorkerGlobalScope.prototype,tag:Object.prototype.toString.call(self),dedicated:typeof DedicatedWorkerGlobalScope,post:typeof postMessage,window:typeof window,indexed:typeof indexedDB,connections,name})')!
	mut parent := Runtime.create()
	defer { parent.close() }
	document := &dom.Document{url: url, origin_: url.origin()}
	mut streams := TransformStreamHost.create(document)!
	streams.install(mut parent)!
	parent.install_message_channel_binding()!
	bridge := ArrayBufferTransferBridge.create(parent)!
	mut ports := WorkerPortRouter.create(parent, true)!
	defer { ports.close() }
	parent.evaluate_host('globalThis.channel=new MessageChannel();globalThis.messages=[];channel.port1.onmessage=event=>messages.push(event.data);')!
	record := bridge.serialize_for_worker(parent.evaluate_host_value('null')!, [parent.evaluate_host_value('channel.port2')!], ports)!
	agent.queue_message(encode_worker_message(record)!)!
	assert agent.runtime.evaluate_host('connections')! == '0'
	agent.process()
	assert agent.runtime.evaluate_host('connections')! == '1'
	for bytes in agent.take_outgoing_port_messages()! { ports.queue_incoming(bytes)! }
	mut owner := streams.settings.responsible_event_loop()
	owner.process()
	assert parent.evaluate_host('messages.length===1&&messages[0].count===1&&messages[0].name==="shared map"&&messages[0].scope')! == 'true'
	parent.evaluate_host('channel.port1.postMessage("payload")')!
	for bytes in ports.take_outgoing()! { agent.queue_port_message(bytes)! }
	agent.process()
	for bytes in agent.take_outgoing_port_messages()! { ports.queue_incoming(bytes)! }
	owner.process()
	assert parent.evaluate_host('messages.length===2&&messages[1].echo==="payload"&&messages[1].count===1')! == 'true'
	agent.runtime.evaluate_host('close()')!
	assert agent.environment.global_scope.is_closing()
}

fn test_shared_worker_startup_preserves_dedicated_wire_version_and_round_trips_shared_kind() {
	url := dom.URL{value: 'https://shared-agent.test/entry.js'}
	startup := WorkerStartup{
		url: url
		outside: html.SerializedEnvironmentSettingsObject{creation_url: url, api_base_url: url, origin: url.origin()}
		creation_time: 1
	}
	assert encode_worker_startup(startup)![..4].bytestr() == 'VXS1'
	assert !decode_worker_startup(encode_worker_startup(startup)!)!.is_shared
	wire := encode_worker_startup(WorkerStartup{...startup, is_shared: true})!
	assert wire[..4].bytestr() == 'VXS2'
	actual := decode_worker_startup(wire)!
	assert actual.is_shared && actual.url == url
}
