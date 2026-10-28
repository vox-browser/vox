// SPDX-License-Identifier: BSD-2-Clause
// Native DedicatedWorkerGlobalScope identity and process-message endpoint.
@[has_globals]
module browserjs

import dom
import html
import platform
import webidl

@[heap]
pub struct WorkerGlobalHost {
	environment &html.WorkerEnvironmentSettingsObject
	scope       &html.DedicatedWorkerGlobalScope
mut:
	runtime     &Runtime = unsafe { nil }
	transfer    &ArrayBufferTransferBridge = unsafe { nil }
	outgoing    [][]u8
	queued_bytes int
	closed      bool
}

__global worker_global_bindings_ = map[voidptr]&WorkerGlobalHost{}

pub fn WorkerGlobalHost.create(environment &html.WorkerEnvironmentSettingsObject) !&WorkerGlobalHost {
	scope := environment.global_scope.dedicated_worker_global_scope() or {
		return error('Dedicated worker binding requires its actual dedicated scope')
	}
	if voidptr(&scope.WorkerGlobalScope) != voidptr(environment.global_scope) ||
		voidptr(environment.settings.global_object()) != voidptr(scope.this_impl()) {
		return error('Dedicated worker binding requires its own global scope')
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &WorkerGlobalHost{environment: environment, scope: scope}
}

pub fn (mut host WorkerGlobalHost) install(mut runtime Runtime) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.environment.settings)!
	owner := voidptr(&runtime)
	if host.closed { return error('Dedicated worker binding is closed') }
	if existing := worker_global_bindings_[owner] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('Dedicated worker binding already belongs to this runtime')
	}
	if host.runtime != unsafe { nil } && voidptr(host.runtime) != owner {
		return error('Dedicated worker binding already belongs to another runtime')
	}
	mut environment := WorkerEnvironmentHost.create(host.environment)!
	environment.install(mut runtime)!
	runtime.install_message_event_binding()!
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.bind_event_target(global, host.scope.this_impl())!
	host.runtime = &runtime
	host.transfer = ArrayBufferTransferBridge.create(&runtime)!
	handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &WorkerGlobalHost(handle) }
		return host.operate(args) or {
			if err is JavaScriptValueException { return err }
			native := webidl.exception_value(err)
			if native.dom_exception_ != none { return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native)!) }
			host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(worker_global_bootstrap)!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, global, [operation, global])!
	worker_global_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &WorkerGlobalHost(handle) }
		host.close()
		worker_global_bindings_.delete(owner)
	})
}

// The embedding drains these owned, framed payloads into WorkerProcess. Keep
// the same aggregate queue bound as the native transport while it is busy.
pub fn (mut host WorkerGlobalHost) take_outgoing() [][]u8 {
	result := host.outgoing
	host.outgoing = []
	host.queued_bytes = 0
	return result
}

pub fn (mut host WorkerGlobalHost) close() {
	if host.closed { return }
	host.closed = true
	host.outgoing = []
	host.queued_bytes = 0
	mut scope := unsafe { &html.DedicatedWorkerGlobalScope(host.scope) }
	scope.terminate_worker()
}

// Decode framing now, but reconstruct values only in the receiving worker's
// posted-message task. Neither sender scratch bytes nor sender JS values enter
// the queued closure. A graph that cannot deserialize fires messageerror.
pub fn (mut host WorkerGlobalHost) queue_message(bytes []u8) ! {
	if host.closed || host.scope.is_closing() { return }
	if host.runtime == unsafe { nil } { return error('Dedicated worker binding is not installed') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	record := decode_worker_message(bytes)!
	handle := voidptr(&host)
	html.queue_a_task(.posted_message, host.scope.event_loop, none, fn [handle, record] () {
		mut host := unsafe { &WorkerGlobalHost(handle) }
		if host.closed || host.scope.is_closing() { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		host.deliver(record) or {
			mut event := html.MessageEvent.create('messageerror', html.MessageEventInit{})
			event.set_is_trusted(true)
			host.scope.dispatch_event(unsafe { &dom.Event(event) })
		}
	})
}

fn (mut host WorkerGlobalHost) deliver(record NativeArrayBufferTransferRecord) ! {
	actual := host.transfer.deserialize(record)!
	mut event := html.MessageEvent.create('message', html.MessageEventInit{
		data: host.runtime.event_callback_result(actual)!
	})
	mut binding := window_message_bindings_[voidptr(host.runtime)] or { return error('Missing worker MessageEvent binding') }
	// deserialize returned the one Runtime root owned by this event's cache.
	binding.data[voidptr(event)] = actual
	event.set_is_trusted(true)
	host.scope.dispatch_event(unsafe { &dom.Event(event) })
}

fn (mut host WorkerGlobalHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('Dedicated worker binding is closed') }
	if args.len == 0 { return error('Missing dedicated worker operation') }
	mut runtime := host.runtime
	method := runtime.binding_dom_string(args[0])!
	match method {
		'name' { return runtime.binding_string(host.scope.name()) }
		'origin' { return runtime.binding_string(host.environment.settings.origin().serialize()) }
		'isSecureContext' { return C.JSValueMakeBoolean(runtime.context, host.environment.settings.is_secure_context()) }
		'close' {
			mut scope := unsafe { &html.DedicatedWorkerGlobalScope(host.scope) }
			scope.close()
		}
		'getHandler' { return runtime.javascript_event_handler(host.scope.this_impl(), runtime.binding_dom_string(args[1])!) }
		'setHandler' { runtime.set_javascript_event_handler(host.scope.this_impl(), runtime.binding_dom_string(args[1])!, args[2])! }
		'post' {
			list := args[2]
			clone := host.transfer.clone
			length := int(clone.number(clone.engine('list_length', [list])!)!)
			mut buffers := []voidptr{cap: length}
			for index in 0 .. length {
				buffers << clone.engine('list_item', [list, C.JSValueMakeNumber(runtime.context, f64(index))])!
			}
			bytes := encode_worker_message(host.transfer.serialize(args[1], buffers)!)!
			if bytes.len > 64 * 1024 * 1024 - host.queued_bytes { return error('Dedicated worker outgoing queue is full') }
			host.outgoing << bytes
			host.queued_bytes += bytes.len
		}
		else { return error('Unknown dedicated worker operation') }
	}
	return C.JSValueMakeUndefined(runtime.context)
}

const worker_global_bootstrap = r'(function(operate,global){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,setPrototype=Object.setPrototypeOf,apply=Reflect.apply,TypeError=global.TypeError,iterator=Symbol.iterator;
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 function WorkerGlobalScope(){throw new TypeError("Illegal constructor")}
 function DedicatedWorkerGlobalScope(){throw new TypeError("Illegal constructor")}
 setPrototype(WorkerGlobalScope,EventTarget);setPrototype(DedicatedWorkerGlobalScope,WorkerGlobalScope);
 WorkerGlobalScope.prototype=create(EventTarget.prototype);
 const dedicatedPrototype=Object.getPrototypeOf(global);
 if(dedicatedPrototype===Object.prototype||dedicatedPrototype===null)throw new TypeError("Worker runtime requires a host global class");
 setPrototype(dedicatedPrototype,WorkerGlobalScope.prototype);DedicatedWorkerGlobalScope.prototype=dedicatedPrototype;
 for(const constructor of [WorkerGlobalScope,DedicatedWorkerGlobalScope]){
  define(constructor,"prototype",{writable:false});
  define(constructor.prototype,"constructor",{value:constructor,writable:true,configurable:true});
  define(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});
  define(global,constructor.name,{value:constructor,writable:true,configurable:true});
 }
 function brand(value){if(value!==global&&value!==undefined&&value!==null)throw new TypeError("Illegal DedicatedWorkerGlobalScope receiver")}
 for(const name of ["self","origin","isSecureContext","name"]){
  const get=descriptor({get [name](){brand(this);return name==="self"?global:operate(name)}},name).get;
  const property={get,enumerable:true,configurable:true};
  if(name==="name"||name==="origin")property.set=descriptor({set [name](value){brand(this);define(global,name,{value,writable:true,enumerable:true,configurable:true})}},name).set;
  define(name==="name"?DedicatedWorkerGlobalScope.prototype:WorkerGlobalScope.prototype,name,property);
 }
 for(const name of ["error","languagechange","offline","online","rejectionhandled","unhandledrejection","message","messageerror"]){
  const key="on"+name;
  const property=descriptor({get [key](){brand(this);return operate("getHandler",name)},set [key](value){brand(this);operate("setHandler",name,value)}},key);
  define(name==="message"||name==="messageerror"?DedicatedWorkerGlobalScope.prototype:WorkerGlobalScope.prototype,key,property);
 }
 function sequence(value,method){
  if(!object(value))throw new TypeError("transfer must be an iterable object");
  const iterate=method===undefined?value[iterator]:method;
  if(typeof iterate!=="function")throw new TypeError("transfer must be iterable");
  const iterable={[iterator](){return apply(iterate,value,[])}};
  const result=[];let index=0;for(const entry of iterable){if(!object(entry))throw new TypeError("transfer entries must be objects");define(result,index++,{value:entry,writable:true,enumerable:true,configurable:true})}return result;
 }
 const methods={postMessage(message){
  brand(this);if(arguments.length<1)throw new TypeError("postMessage requires one argument");
  const second=arguments[1];let transfer=[];
  if(second!=null){
   if(!object(second))throw new TypeError("postMessage options must be an object");
   const iterate=second[iterator];
   if(iterate!=null){transfer=sequence(second,iterate)}
   else{const value=second.transfer;if(value!==undefined)transfer=sequence(value)}
  }
  return operate("post",message,transfer);
 },close(){brand(this);return operate("close")}};
 for(const name of ["postMessage","close"])define(DedicatedWorkerGlobalScope.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 // Global EventTarget methods also support the unqualified calls used by worker scripts.
 const add=EventTarget.prototype.addEventListener,remove=EventTarget.prototype.removeEventListener,dispatch=EventTarget.prototype.dispatchEvent;
 const events={addEventListener(type,callback){brand(this);return apply(add,global,arguments)},removeEventListener(type,callback){brand(this);return apply(remove,global,arguments)},dispatchEvent(event){brand(this);return apply(dispatch,global,arguments)}};
 for(const name of ["addEventListener","removeEventListener","dispatchEvent"])define(global,name,{value:events[name],writable:true,enumerable:true,configurable:true});

})'
