// SPDX-License-Identifier: BSD-2-Clause
// Shared worker connections use the existing independently owned worker process
// and MessagePort transport. The registry belongs to the browser process.
@[has_globals]
module browserjs

import dom
import highresolutiontime
import html
import platform
import webidl
import x.json2

@[heap]
struct SharedWorkerConnection {
	host &SharedWorkerHost
	target &dom.EventTarget
	port &html.MessagePort
	ports &WorkerPortRouter
	remote &RemoteSharedWorker
mut:
	closed bool
}

@[heap]
struct RemoteSharedWorker {
	key string
	options html.WorkerOptions
	secure bool
mut:
	process ?&WorkerProcess
	owners []&SharedWorkerConnection
	ready bool
	closed bool
}

@[heap]
pub struct SharedWorkerHost {
	settings &html.EnvironmentSettingsObject
	executable string
mut:
	runtime &Runtime = unsafe { nil }
	transfer &ArrayBufferTransferBridge = unsafe { nil }
	connections map[voidptr]&SharedWorkerConnection
	timer &platform.Timer = unsafe { nil }
	closed bool
}

__global (
	shared_worker_hosts_ = map[voidptr]&SharedWorkerHost{}
	remote_shared_workers_ = map[string]&RemoteSharedWorker{}
	shared_worker_port_namespace_ u64
)

pub fn SharedWorkerHost.create(settings &html.EnvironmentSettingsObject, executable string) !&SharedWorkerHost {
	if executable == '' || executable.contains('\x00') { return error('Invalid shared worker executable') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &SharedWorkerHost{settings: settings, executable: executable.clone()}
}

pub fn (mut host SharedWorkerHost) install(mut runtime Runtime) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	owner := voidptr(&runtime)
	if existing := shared_worker_hosts_[owner] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('SharedWorker binding already belongs to this runtime')
	}
	runtime.bind_scripting_environment(host.settings)!
	runtime.install_message_event_binding()!
	runtime.install_message_channel_binding()!
	host.runtime = &runtime
	host.transfer = ArrayBufferTransferBridge.create(&runtime)!
	handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &SharedWorkerHost(handle) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return host.operate(args) or {
			if err is JavaScriptValueException { return err }
			value := webidl.exception_value(err)
			if value.dom_exception_ != none { return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(value)!) }
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(shared_worker_host_bootstrap)!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [operation])!
	callback := fn [handle] () {
		mut host := unsafe { &SharedWorkerHost(handle) }
		host.poll()
	}
	runtime.own_closure(voidptr(callback))
	host.timer = platform.Timer.create_repeating(5, callback)
	register_runtime_binding(mut shared_worker_hosts_, owner, &host)
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &SharedWorkerHost(handle) }
		host.close()
		unregister_runtime_binding(mut shared_worker_hosts_, owner)
	})
}

fn (mut host SharedWorkerHost) construct(args []voidptr) ! {
	mut runtime := host.runtime
	url := host.settings.encoding_parse_url(runtime.binding_dom_string(args[2])!) or {
		return webidl.throw_value(webidl.dom_exception_value(webidl.DOMException.create('SyntaxError', 'SharedWorker constructed with an invalid URL')))
	}
	if host.settings.origin().is_opaque() {
		return webidl.throw_value(webidl.dom_exception_value(webidl.DOMException.create('SecurityError', 'SharedWorker requires a non-opaque storage origin')))
	}
	options := html.WorkerOptions{
		credentials: match runtime.binding_dom_string(args[3])! { 'omit' { .omit } 'include' { .include } else { .same_origin } }
		name: runtime.binding_dom_string(args[4])!
		type_: if runtime.binding_dom_string(args[5])! == 'module' { .module_ } else { .classic }
	}
	// A remote worker is shared by every connecting document and outlives
	// the one whose script (and document arena) created it.
	record_storage := platform.enter_persistent()
	key := json2.encode([host.settings.origin().serialize(), url.serialize(), options.name])
	mut remote := remote_shared_workers_[key] or {
		&RemoteSharedWorker{key: key, options: html.WorkerOptions{...options, name: options.name.clone()}, secure: host.settings.is_secure_context()}
	}
	if remote.closed { remote = &RemoteSharedWorker{key: key, options: html.WorkerOptions{...options, name: options.name.clone()}, secure: host.settings.is_secure_context()} }
	platform.leave_persistent(record_storage)
	if remote.secure != host.settings.is_secure_context() {
		return webidl.throw_value(webidl.dom_exception_value(webidl.DOMException.create('SecurityError', 'SharedWorker secure context mismatch')))
	}
	channel := html.MessageChannel.create_for_settings(host.settings)
	mut ports := WorkerPortRouter.create(runtime, true)!
	if shared_worker_port_namespace_ >= 0x7fff_ffff { return error('SharedWorker port namespaces exhausted') }
	shared_worker_port_namespace_++
	ports.next_token = (shared_worker_port_namespace_ << 32) | 1
	connection := &SharedWorkerConnection{
		host: &host
		target: dom.EventTarget.new()
		port: channel.port1()
		ports: ports
		remote: remote
	}
	runtime.bind_event_target(args[1], connection.target)!
	host.connections[args[1]] = connection
	if !html.worker_constructor_csp_allows(host.settings, url, true) {
		mut inside := channel.port2()
		mut outside := channel.port1()
		inside.close()
		outside.close()
		host.queue_failure(connection)
		return
	}
	owner_storage := platform.enter_persistent()
	remote.owners << connection
	platform.leave_persistent(owner_storage)
	if remote.options.type_ != options.type_ || remote.options.credentials != options.credentials {
		host.queue_failure(connection)
		return
	}
	if remote.process == none {
		if count_worker_processes_for_site(worker_process_site_key(host.settings))
			>= maximum_worker_processes_per_top_level_origin {
			remote.finish(true)
			return
		}
		startup := encode_worker_startup(WorkerStartup{url: url, options: options,
			outside: host.settings.serialize(), creation_time: highresolutiontime.unsafe_shared_current_time(), is_shared: true})!
		mut process := WorkerProcess.spawn(host.executable) or { remote.finish(true); return }
		process.queue(u32(WorkerAgentFrameKind.start), startup) or { process.close(); remote.finish(true); return }
		remote.process = process
		registry_storage := platform.enter_persistent()
		remote_shared_workers_[key] = remote
		platform.leave_persistent(registry_storage)
	}
	inside := runtime.javascript_message_port(channel.port2())!
	message := host.transfer.serialize_for_worker(C.vox_jsc_JSValueMakeNull(runtime.context), [inside], ports)!
	if mut process := remote.process {
		process.queue(u32(WorkerAgentFrameKind.message), encode_worker_message(message)!) or { remote.finish(true); return }
	}
	host.timer.start()
}

fn (mut host SharedWorkerHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('SharedWorker binding is closed') }
	operation := host.runtime.binding_dom_string(args[0])!
	if operation == 'construct' { host.construct(args)!; return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
	connection := host.connections[args[1]] or { return error('TypeError: Illegal SharedWorker receiver') }
	match operation {
		'brand' {}
		'port' { return host.runtime.javascript_message_port(connection.port) }
		'getHandler' { return host.runtime.javascript_event_handler(connection.target, 'error') }
		'setHandler' { host.runtime.set_javascript_event_handler(connection.target, 'error', args[2])! }
		else { return error('Unknown SharedWorker operation') }
	}
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host SharedWorkerHost) queue_failure(connection &SharedWorkerConnection) {
	html.queue_a_task(.posted_message, host.settings.responsible_event_loop(), host.settings.responsible_document(), fn [connection] () {
		if connection.closed || connection.host.closed || connection.host.settings.discarded() { return }
		mut event := dom.Event.create('error', dom.EventInit{cancelable: true})
		event.set_is_trusted(true)
		connection.target.dispatch_event(event)
	})
}

fn (mut remote RemoteSharedWorker) finish(failed bool) {
	if remote.closed { return }
	remote.closed = true
	if mut process := remote.process { process.close() }
	remote.process = none
	if current := remote_shared_workers_[remote.key] {
		if voidptr(current) == voidptr(&remote) { remote_shared_workers_.delete(remote.key) }
	}
	for connection in remote.owners {
		mut ports := connection.ports
		ports.close()
		if failed { connection.host.queue_failure(connection) }
	}
}

fn (mut remote RemoteSharedWorker) poll() {
	mut process := remote.process or { return }
	for connection in remote.owners {
		if connection.closed { continue }
		mut ports := connection.ports
		frames := ports.take_outgoing() or { remote.finish(true); return }
		for bytes in frames {
			process.queue(u32(WorkerAgentFrameKind.port_message), bytes) or { remote.finish(true); return }
		}
	}
	process.flush() or { remote.finish(true); return }
	for _ in 0 .. 64 {
		read := process.receive() or { remote.finish(true); return }
		if read.ended { remote.finish(!remote.ready); return }
		frame := read.frame or { break }
		if frame.kind == u32(WorkerAgentFrameKind.ready) && !remote.ready && frame.bytes.len == 0 {
			remote.ready = true
		} else if frame.kind == u32(WorkerAgentFrameKind.port_message) && remote.ready {
			mut reader := WorkerMessageReader{bytes: frame.bytes}
			version := reader.take(4) or { remote.finish(true); return }
			if version != 'VXP1'.bytes() { remote.finish(true); return }
			token := reader.read_u64() or { remote.finish(true); return }
			mut found := false
			for connection in remote.owners {
				if connection.closed || token !in connection.ports.proxies { continue }
				mut ports := connection.ports
				ports.queue_incoming(frame.bytes) or { remote.finish(true); return }
				found = true
				break
			}
			if !found { remote.finish(true); return }
		} else { remote.finish(true); return }
	}
}

pub fn (mut host SharedWorkerHost) poll() {
	if host.closed { return }
	if host.settings.discarded() { host.close(); return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut active := false
	for _, connection in host.connections {
		mut remote := connection.remote
		if remote.closed { continue }
		remote.poll()
		if remote.process != none { active = true }
	}
	if !active { host.timer.stop() }
}

pub fn (mut host SharedWorkerHost) close() {
	if host.closed { return }
	host.closed = true
	if host.timer != unsafe { nil } { host.timer.stop() }
	for _, mut connection in host.connections {
		connection.closed = true
		connection.ports.close()
		mut remote := connection.remote
		remote.owners = remote.owners.filter(!it.closed)
		if remote.owners.len == 0 { remote.finish(false) }
	}
	host.connections = {}
}

const shared_worker_host_bootstrap = r'(function(operate){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,setPrototype=Object.setPrototypeOf,T=TypeError;
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 function SharedWorker(scriptURL){
  if(!new.target)throw new T("SharedWorker requires new");if(arguments.length<1)throw new T("SharedWorker requires a URL");
  const url=`${scriptURL}`;let options=arguments[1];if(options!=null&&!object(options))options={name:`${options}`};
  let credentials=options==null?undefined:options.credentials;credentials=credentials===undefined?"same-origin":`${credentials}`;
  if(!["omit","same-origin","include"].includes(credentials))throw new T("Invalid SharedWorker credentials");
  if(options!=null)void !!options.extendedLifetime;
  let name=options==null?undefined:options.name;name=name===undefined?"":`${name}`;
  let type=options==null?undefined:options.type;type=type===undefined?"classic":`${type}`;
  if(type!=="classic"&&type!=="module")throw new T("Invalid SharedWorker type");
  operate("construct",this,url,credentials,name,type);
 }
 setPrototype(SharedWorker,EventTarget);SharedWorker.prototype=create(EventTarget.prototype);
 define(SharedWorker,"prototype",{writable:false});define(SharedWorker.prototype,"constructor",{value:SharedWorker,writable:true,configurable:true});
 define(SharedWorker.prototype,Symbol.toStringTag,{value:"SharedWorker",configurable:true});
 const properties={get port(){return operate("port",this)},get onerror(){return operate("getHandler",this)},set onerror(value){operate("setHandler",this,value)}};
 for(const key of ["port","onerror"])define(SharedWorker.prototype,key,{...descriptor(properties,key),enumerable:true,configurable:true});
 define(globalThis,"SharedWorker",{value:SharedWorker,writable:true,configurable:true});
})'
