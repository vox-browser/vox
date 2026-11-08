// SPDX-License-Identifier: BSD-2-Clause
// Parent endpoint for dedicated workers in an independent JSC process.
@[has_globals]
module browserjs

import dom
import highresolutiontime
import html
import platform
import webidl

@[heap]
struct RemoteWorker {
	worker &html.Worker
mut:
	process ?&WorkerProcess
	ports &WorkerPortRouter
	ready bool
}

@[heap]
pub struct WorkerHost {
	settings &html.EnvironmentSettingsObject
	executable string
mut:
	runtime &Runtime = unsafe { nil }
	transfer &ArrayBufferTransferBridge = unsafe { nil }
	workers map[voidptr]&RemoteWorker
	timer &platform.Timer = unsafe { nil }
	closed bool
}

__global worker_host_bindings_ = map[voidptr]&WorkerHost{}

pub fn WorkerHost.create(settings &html.EnvironmentSettingsObject, executable string) !&WorkerHost {
	if executable == '' || executable.contains('\x00') { return error('Invalid worker executable') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &WorkerHost{settings: settings, executable: executable.clone()}
}

pub fn (mut host WorkerHost) install(mut runtime Runtime) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	runtime.require_javascript_value_context()!
	if host.closed { return error('Worker binding is closed') }
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if existing := worker_host_bindings_[owner] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('Worker binding already belongs to this runtime')
	}
	if host.runtime != unsafe { nil } && voidptr(host.runtime) != owner {
		return error('Worker binding already belongs to another runtime')
	}
	runtime.install_message_event_binding()!
	runtime.install_message_channel_binding()!
	host.runtime = &runtime
	host.transfer = ArrayBufferTransferBridge.create(&runtime)!
	handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &WorkerHost(handle) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return host.operate(args) or {
			if err is JavaScriptValueException { return err }
			native := webidl.exception_value(err)
			if native.dom_exception_ != none { return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native)!) }
			host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(worker_host_bootstrap)!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [operation])!
	callback := fn [handle] () {
		mut host := unsafe { &WorkerHost(handle) }
		host.poll()
	}
	runtime.own_closure(voidptr(callback))
	host.timer = platform.Timer.create_repeating(5, callback)
	worker_host_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &WorkerHost(handle) }
		host.close()
		worker_host_bindings_.delete(owner)
	})
	mut shared_host := SharedWorkerHost.create(host.settings, host.executable)!
	shared_host.install(mut runtime)!
}

fn (mut remote RemoteWorker) disconnect() {
	if mut process := remote.process { process.close() }
	remote.process = none
	remote.ports.close()
}

fn (mut remote RemoteWorker) terminate() {
	mut worker := unsafe { &html.Worker(remote.worker) }
	worker.terminate()
	remote.disconnect()
}

pub fn (mut host WorkerHost) close() {
	if host.closed { return }
	host.closed = true
	if host.timer != unsafe { nil } { host.timer.stop() }
	for _, mut remote in host.workers {
		remote.terminate()
	}
	host.workers = {}
}

fn (mut host WorkerHost) construct(receiver voidptr, args []voidptr) !voidptr {
	mut runtime := host.runtime
	address := runtime.binding_dom_string(args[2])!
	url := host.settings.encoding_parse_url(address) or {
		return webidl.throw_value(webidl.dom_exception_value(webidl.DOMException.create('SyntaxError', 'Worker constructed with an invalid URL')))
	}
	options := html.WorkerOptions{
		credentials: match runtime.binding_dom_string(args[3])! {
			'omit' { .omit }
			'include' { .include }
			else { .same_origin }
		}
		name: runtime.binding_dom_string(args[4])!
		type_: if runtime.binding_dom_string(args[5])! == 'module' { .module_ } else { .classic }
	}
	worker := &html.Worker{script_url: url, options: options}
	mut remote := &RemoteWorker{worker: worker, ports: WorkerPortRouter.create(runtime, true)!}
	runtime.bind_event_target(receiver, worker.this_event_target())!
	host.workers[receiver] = remote
	// Fetch/startup failures are asynchronous events on the constructed Worker.
	bytes := encode_worker_startup(WorkerStartup{
		url: url
		options: options
		outside: host.settings.serialize()
		creation_time: highresolutiontime.unsafe_shared_current_time()
	}) or {
		host.queue_failure(remote)
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	mut process := WorkerProcess.spawn(host.executable) or {
		host.queue_failure(remote)
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	process.queue(u32(WorkerAgentFrameKind.start), bytes) or {
		process.close()
		host.queue_failure(remote)
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	remote.process = process
	host.timer.start()
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}

fn (mut host WorkerHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('Worker binding is closed') }
	if args.len < 2 { return error('Missing Worker operation') }
	mut runtime := host.runtime
	method := runtime.binding_dom_string(args[0])!
	if method == 'construct' { return host.construct(args[1], args) }
	mut remote := host.workers[args[1]] or { return runtime.event_binding_type_error('Illegal Worker receiver') }
	match method {
		'brand' {}
		'terminate' {
			remote.terminate()
		}
		'getHandler' { return runtime.javascript_event_handler(remote.worker.this_event_target(), runtime.binding_dom_string(args[2])!) }
		'setHandler' { runtime.set_javascript_event_handler(remote.worker.this_event_target(), runtime.binding_dom_string(args[2])!, args[3])! }
		'post' {
			clone := host.transfer.clone
			length := int(clone.number(clone.engine('list_length', [args[3]])!)!)
			mut buffers := []voidptr{cap: length}
			for index in 0 .. length {
				buffers << clone.engine('list_item', [args[3], C.vox_jsc_JSValueMakeNumber(runtime.context, f64(index))])!
			}
			bytes := encode_worker_message(host.transfer.serialize_for_worker(args[2], buffers, remote.ports)!)!
			if remote.worker.terminated_ { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			if process := remote.process {
				process.queue(u32(WorkerAgentFrameKind.message), bytes) or {
					remote.disconnect()
					host.queue_failure(remote)
				}
			}
		}
		else { return error('Unknown Worker operation') }
	}
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}

// Never wait on a worker from the browser thread. Each endpoint has a bounded
// read turn; all script-visible deliveries run later on the owning task queue.
pub fn (mut host WorkerHost) poll() {
	if host.closed { return }
	if host.settings.discarded() { host.close(); return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut active := false
	for _, mut remote in host.workers {
		mut process := remote.process or { continue }
		port_frames := remote.ports.take_outgoing() or { remote.disconnect(); host.queue_failure(remote); continue }
		mut port_failed := false
		for bytes in port_frames {
			process.queue(u32(WorkerAgentFrameKind.port_message), bytes) or { port_failed = true; break }
		}
		if port_failed { remote.disconnect(); host.queue_failure(remote); continue }
		process.flush() or { remote.disconnect(); host.queue_failure(remote); continue }
		for _ in 0 .. 64 {
			read := process.receive() or { remote.disconnect(); host.queue_failure(remote); break }
			if read.ended {
				remote.disconnect()
				if !remote.ready { host.queue_failure(remote) }
				break
			}
			frame := read.frame or { break }
			if frame.kind == u32(WorkerAgentFrameKind.ready) && !remote.ready && frame.bytes.len == 0 {
				remote.ready = true
			} else if frame.kind == u32(WorkerAgentFrameKind.message) && remote.ready {
				host.queue_message(remote, frame.bytes) or { remote.disconnect(); host.queue_failure(remote); break }
			} else if frame.kind == u32(WorkerAgentFrameKind.port_message) && remote.ready {
				remote.ports.queue_incoming(frame.bytes) or { remote.disconnect(); host.queue_failure(remote); break }
			} else {
				remote.disconnect()
				host.queue_failure(remote)
				break
			}
		}
		if remote.process != none { active = true }
	}
	if !active { host.timer.stop() }
}

fn (mut host WorkerHost) queue_failure(remote &RemoteWorker) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	handle := voidptr(&host)
	html.queue_a_task(.posted_message, host.settings.responsible_event_loop(), host.settings.responsible_document(), fn [handle, remote] () {
		mut host := unsafe { &WorkerHost(handle) }
		if host.closed || host.settings.discarded() || remote.worker.terminated_ { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut event := dom.Event.create('error', dom.EventInit{cancelable: true})
		remote.worker.dispatch_event(event)
	})
}

fn (mut host WorkerHost) queue_message(remote &RemoteWorker, bytes []u8) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	record := decode_worker_message(bytes)!
	handle := voidptr(&host)
	html.queue_a_task(.posted_message, host.settings.responsible_event_loop(), host.settings.responsible_document(), fn [handle, remote, record] () {
		mut host := unsafe { &WorkerHost(handle) }
		if host.closed || host.settings.discarded() || remote.worker.terminated_ { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		host.deliver(remote, record) or {
			mut event := html.MessageEvent.create('messageerror', html.MessageEventInit{})
			event.set_is_trusted(true)
			remote.worker.dispatch_event(unsafe { &dom.Event(event) })
		}
	})
}

fn (mut host WorkerHost) deliver(remote &RemoteWorker, record NativeArrayBufferTransferRecord) ! {
	message := host.transfer.deserialize_for_worker(record, remote.ports)!
	actual := message.data
	mut event := html.MessageEvent.create('message', html.MessageEventInit{data: host.runtime.event_callback_result(actual)!, ports: message.ports})
	mut binding := window_message_bindings_[voidptr(host.runtime)] or { return error('Missing MessageEvent binding') }
	binding.data[voidptr(event)] = actual
	event.set_is_trusted(true)
	remote.worker.dispatch_event(unsafe { &dom.Event(event) })
}

const worker_host_bootstrap = r'(function(operate){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,setPrototype=Object.setPrototypeOf,apply=Reflect.apply,TypeError=globalThis.TypeError,iterator=Symbol.iterator;
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 function Worker(scriptURL){
  if(!new.target)throw new TypeError("Worker requires new");
  if(arguments.length<1)throw new TypeError("Worker requires one argument");
  const url=`${scriptURL}`,options=arguments[1];
  if(options!=null&&!object(options))throw new TypeError("Worker options must be an object");
  let credentials=options==null?undefined:options.credentials;credentials=credentials===undefined?"same-origin":`${credentials}`;
  if(credentials!=="omit"&&credentials!=="same-origin"&&credentials!=="include")throw new TypeError("Invalid Worker credentials");
  let name=options==null?undefined:options.name;name=name===undefined?"":`${name}`;
  let type=options==null?undefined:options.type;type=type===undefined?"classic":`${type}`;
  if(type!=="classic"&&type!=="module")throw new TypeError("Invalid Worker type");
  operate("construct",this,url,credentials,name,type);
 }
 setPrototype(Worker,EventTarget);Worker.prototype=create(EventTarget.prototype);
 define(Worker,"prototype",{writable:false});define(Worker.prototype,"constructor",{value:Worker,writable:true,configurable:true});
 define(Worker.prototype,Symbol.toStringTag,{value:"Worker",configurable:true});
 function sequence(value,method){
  if(!object(value))throw new TypeError("transfer must be an iterable object");
  const iterate=method===undefined?value[iterator]:method;
  if(typeof iterate!=="function")throw new TypeError("transfer must be iterable");
  const iterable={[iterator](){return apply(iterate,value,[])}};
  const result=[];let index=0;for(const entry of iterable){if(!object(entry))throw new TypeError("transfer entries must be objects");define(result,index++,{value:entry,writable:true,enumerable:true,configurable:true})}return result;
 }
 const methods={postMessage(message){
  operate("brand",this);if(arguments.length<1)throw new TypeError("postMessage requires one argument");
  const second=arguments[1];let transfer=[];
  if(second!=null){if(!object(second))throw new TypeError("postMessage options must be an object");const iterate=second[iterator];if(iterate!=null)transfer=sequence(second,iterate);else{const value=second.transfer;if(value!==undefined)transfer=sequence(value)}}
  return operate("post",this,message,transfer);
 },terminate(){return operate("terminate",this)}};
 for(const name of ["postMessage","terminate"])define(Worker.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 for(const name of ["error","message","messageerror"]){const key="on"+name;define(Worker.prototype,key,descriptor({get [key](){return operate("getHandler",this,name)},set [key](value){operate("setHandler",this,name,value)}},key))}
 define(globalThis,"Worker",{value:Worker,writable:true,configurable:true});
})'
