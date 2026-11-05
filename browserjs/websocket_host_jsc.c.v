module browserjs

import browsernet
import dom
import html
import x.json2
import webidl

fn C.JSValueIsString(context voidptr, value voidptr) bool

pub fn (mut host WebSocketHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	if host.installed {
		if voidptr(host.runtime) != voidptr(&runtime) {
			return error('WebSocket already belongs to another runtime')
		}
		return
	}
	host.runtime = &runtime
	host_handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [host_handle] (_ voidptr, arguments []voidptr) !voidptr {
		mut host := unsafe { &WebSocketHost(host_handle) }
		return host.operate(arguments) or {
			host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(websocket_host_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	deliver := runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		operation,
	])!
	host.function = runtime.retain_javascript_value(deliver)!
	host.deliver = runtime.webidl_callback(host.function, fn [host_handle] (value webidl.Value) !voidptr {
		host := unsafe { &WebSocketHost(host_handle) }
		// The callback receives an undefined receiver; arguments carry actual values.
		return match value.kind {
			.undefined { C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
			.boolean { C.vox_jsc_JSValueMakeBoolean(host.runtime.context, value.boolean_value) }
			.number { C.vox_jsc_JSValueMakeNumber(host.runtime.context, value.number_value) }
			else { host.runtime.actual_webidl_value(value)! }
		}
	})!
	websocket_hosts_ << &host
	runtime.add_close_handler(fn [host_handle] () {
		mut host := unsafe { &WebSocketHost(host_handle) }
		host.close()
	})
	host.installed = true
}

fn (mut host WebSocketHost) operate(arguments []voidptr) !voidptr {
	if host.closed { return error('WebSocket binding is closed') }
	if arguments.len < 1 { return error('TypeError: Invalid WebSocket operation') }
	mut runtime := host.runtime
	op := runtime.binding_dom_string(arguments[0])!
	match op {
		'open' {
			if arguments.len != 3 { return error('TypeError: Invalid WebSocket operation') }
			address := runtime.binding_dom_string(arguments[1])!
			encoded := runtime.binding_dom_string(arguments[2])!
			parsed := json2.decode[json2.Any](encoded) or { json2.Any([]json2.Any{}) }
			mut protocols := []string{}
			for value in parsed.as_array() {
				protocols << value.str()
			}
			host.next_id++
			id := host.next_id
			host.sockets[id] = browsernet.WebSocketConnection.open(address, host.document.origin().serialize(),
				host.document.url.serialize(), protocols, host.ca_bundle, fn () { websocket_wake_() })
			return C.vox_jsc_JSValueMakeNumber(runtime.context, id)
		}
		'send' {
			if arguments.len != 3 { return error('TypeError: Invalid WebSocket operation') }
			id := int(host.number(arguments[1])!)
			mut connection := host.sockets[id] or { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			if C.JSValueIsString(runtime.context, arguments[2]) {
				connection.send_text(runtime.binding_dom_string(arguments[2])!)
			} else {
				// The bootstrap passes a fresh ArrayBuffer copy of any buffer source.
				buffer := runtime.webidl_value(arguments[2])!
				defer { runtime.release_javascript_value(arguments[2]) }
				connection.send_binary(runtime.source_array_buffer_bytes(buffer)!)
			}
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		'close' {
			if arguments.len != 4 { return error('TypeError: Invalid WebSocket operation') }
			id := int(host.number(arguments[1])!)
			code := host.number(arguments[2])!
			reason := runtime.binding_dom_string(arguments[3])!
			if mut connection := host.sockets[id] {
				connection.close(if code < 0 { u16(0) } else { u16(code) }, reason)
			}
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		else {
			return error('TypeError: Invalid WebSocket operation')
		}
	}
}

fn (host &WebSocketHost) number(value voidptr) !f64 {
	mut exception := unsafe { nil }
	number := C.vox_jsc_JSValueToNumber(host.runtime.context, value, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return number
}

fn (mut host WebSocketHost) report(exception IError) {
	mut realm := unsafe { &html.ScriptingRealm(host.settings.realm()) }
	if exception is JavaScriptValueException {
		value := host.runtime.webidl_value(exception.value) or { return }
		html.report_exception(dom.js_webidl_value(value), mut realm)
		return
	}
	html.report_exception(dom.js_webidl_value(webidl.exception_value(exception)), mut realm)
}

fn (mut host WebSocketHost) dispatch(id int, event browsernet.WebSocketEvent) {
	if host.closed || host.runtime.closed { return }
	callback := host.deliver or { return }
	mut runtime := host.runtime
	context := runtime.context
	kind := match event.kind {
		.open { 'open' }
		.message { 'message' }
		.error { 'error' }
		.close { 'close' }
	}
	mut data := C.vox_jsc_JSValueMakeUndefined(context)
	if event.kind == .message {
		if event.text {
			data = runtime.binding_string(event.data.bytestr())
		} else {
			mut exception := unsafe { nil }
			data = C.vox_jsc_make_source_array_buffer_copy(context, event.data.data, uint(event.data.len),
				&exception)
			if exception != unsafe { nil } || data == unsafe { nil } { return }
		}
	}
	values := [
		C.vox_jsc_JSValueMakeNumber(context, id),
		runtime.binding_string(kind),
		data,
		C.vox_jsc_JSValueMakeNumber(context, event.code),
		runtime.binding_string(event.reason),
		C.vox_jsc_JSValueMakeBoolean(context, event.was_clean),
		runtime.binding_string(event.protocol),
	]
	mut arguments := []webidl.Value{cap: values.len}
	for value in values {
		arguments << runtime.webidl_value(value) or { return }
	}
	defer {
		for value in values { runtime.release_javascript_value(value) }
	}
	result := webidl.invoke_callback(callback, none, arguments) or {
		if replay := host.replay { replay(runtime) or {} }
		host.report(err)
		return
	}
	if actual := result.runtime_value_ { runtime.release_javascript_value(actual.value) }
	if replay := host.replay { replay(runtime) or { host.report(err) } }
}

// WebSocket.idl and CloseEvent.idl. The constructor parses the URL against
// the document base, maps http(s) to ws(s), rejects fragments and invalid or
// duplicate subprotocols, and the returned function delivers native events.
const websocket_host_bootstrap = r'(function(operate){
 "use strict";
 const global=globalThis,define=Object.defineProperty,TypeError=global.TypeError,EventTargetType=global.EventTarget,EventType=global.Event,MessageEventType=global.MessageEvent,BlobType=global.Blob,URLType=global.URL,DOMExceptionType=global.DOMException,ArrayBufferType=global.ArrayBuffer,isView=ArrayBufferType.isView,TextEncoderType=global.TextEncoder,addListener=EventTargetType.prototype.addEventListener;
 function domException(message,name){return typeof DOMExceptionType==="function"?new DOMExceptionType(message,name):new TypeError(message)}
 function utf8Length(text){return typeof TextEncoderType==="function"?new TextEncoderType().encode(text).length:unescape(encodeURIComponent(text)).length}
 const states=new WeakMap,sockets=new Map,closeEvents=new WeakMap;
 const token=/^[!#$%&\x27*+\-.^_`|~0-9A-Za-z]+$/;
 function state(value){const s=states.get(value);if(!s)throw new TypeError("Illegal invocation");return s}
 class CloseEvent extends EventType{constructor(type,init){super(type,init);const options=init==null?{}:init;closeEvents.set(this,{wasClean:!!options.wasClean,code:options.code===undefined?0:Number(options.code)&65535,reason:options.reason===undefined?"":String(options.reason)})}}
 for(const name of ["wasClean","code","reason"])define(CloseEvent.prototype,name,{get(){const data=closeEvents.get(this);if(!data)throw new TypeError("Illegal invocation");return data[name]},enumerable:true,configurable:true});
 function baseURL(){try{const document=global.document;if(document&&document.baseURI)return document.baseURI}catch(error){}return String(global.location&&global.location.href)}
 function transmit(s,payload){if(s.readyState===1)operate("send",s.id,payload)}
 class WebSocket extends EventTargetType{
  constructor(url,protocols=undefined){
   super();
   if(arguments.length<1)throw new TypeError("WebSocket requires a URL");
   let record;try{record=new URLType(String(url),baseURL())}catch(error){throw domException("Invalid WebSocket URL","SyntaxError")}
   if(record.protocol==="http:")record.protocol="ws:";else if(record.protocol==="https:")record.protocol="wss:";
   if(record.protocol!=="ws:"&&record.protocol!=="wss:")throw domException("WebSocket URLs must use ws or wss","SyntaxError");
   if(record.href.includes("#"))throw domException("WebSocket URLs must not have a fragment","SyntaxError");
   const list=protocols===undefined?[]:(typeof protocols==="object"&&protocols!==null&&typeof protocols[Symbol.iterator]==="function"?Array.from(protocols,String):[String(protocols)]);
   const seen=new Set;for(const protocol of list){if(!token.test(protocol)||seen.has(protocol))throw domException("Invalid WebSocket subprotocol","SyntaxError");seen.add(protocol)}
   const s={url:record.href,origin:record.origin,readyState:0,protocol:"",extensions:"",binaryType:"blob",bufferedAmount:0,handlers:{},listening:{},chain:null,id:0};
   states.set(this,s);
   s.id=operate("open",record.href,JSON.stringify(list));
   sockets.set(s.id,this);
  }
  get url(){return state(this).url}
  get readyState(){return state(this).readyState}
  get bufferedAmount(){return state(this).bufferedAmount}
  get extensions(){return state(this).extensions}
  get protocol(){return state(this).protocol}
  get binaryType(){return state(this).binaryType}
  set binaryType(value){const s=state(this);value=String(value);if(value==="blob"||value==="arraybuffer")s.binaryType=value}
  send(data){
   const s=state(this);
   if(arguments.length<1)throw new TypeError("WebSocket.send requires 1 argument");
   if(s.readyState===0)throw domException("WebSocket is still connecting","InvalidStateError");
   let payload,size;
   if(BlobType&&data instanceof BlobType){size=data.size;payload=null}
   else if(data instanceof ArrayBufferType){payload=data.slice(0);size=payload.byteLength}
   else if(isView(data)){payload=data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength);size=payload.byteLength}
   else{payload=String(data);size=utf8Length(payload)}
   if(s.readyState!==1){s.bufferedAmount+=size;return}
   if(payload===null){const blob=data;s.chain=(s.chain||Promise.resolve()).then(()=>blob.arrayBuffer()).then(buffer=>transmit(s,buffer));return}
   if(s.chain){s.chain=s.chain.then(()=>transmit(s,payload));return}
   transmit(s,payload);
  }
  close(code=undefined,reason=undefined){
   const s=state(this);
   if(code!==undefined){code=Number(code);code=Number.isNaN(code)?0:Math.min(65535,Math.max(0,Math.trunc(code)));if(code!==1000&&(code<3000||code>4999))throw domException("Invalid WebSocket close code","InvalidAccessError")}
   if(reason!==undefined){reason=String(reason);if(utf8Length(reason)>123)throw domException("WebSocket close reason is too long","SyntaxError")}
   if(s.readyState>=2)return;
   s.readyState=2;
   operate("close",s.id,code===undefined?-1:code,reason===undefined?"":reason);
  }
 }
 for(const [name,value] of [["CONNECTING",0],["OPEN",1],["CLOSING",2],["CLOSED",3]]){define(WebSocket,name,{value,enumerable:true});define(WebSocket.prototype,name,{value,enumerable:true})}
 for(const type of ["open","message","error","close"]){
  define(WebSocket.prototype,"on"+type,{get(){const handler=state(this).handlers[type];return handler===undefined?null:handler},set(value){const s=state(this);s.handlers[type]=typeof value==="function"||(typeof value==="object"&&value!==null)?value:null;if(!s.listening[type]&&s.handlers[type]!==null){s.listening[type]=true;addListener.call(this,type,function(event){const handler=s.handlers[type];if(typeof handler==="function")return handler.call(this,event)})}},enumerable:true,configurable:true});
 }
 define(WebSocket.prototype,Symbol.toStringTag,{value:"WebSocket",configurable:true});
 define(CloseEvent.prototype,Symbol.toStringTag,{value:"CloseEvent",configurable:true});
 define(global,"WebSocket",{value:WebSocket,writable:true,configurable:true});
 define(global,"CloseEvent",{value:CloseEvent,writable:true,configurable:true});
 return function deliver(id,kind,data,code,reason,wasClean,protocol){
  const socket=sockets.get(id);if(!socket)return;const s=states.get(socket);
  if(kind==="open"){if(s.readyState===0)s.readyState=1;else if(s.readyState!==2)return;s.protocol=protocol;socket.dispatchEvent(new EventType("open"));return}
  if(kind==="message"){if(s.readyState!==1)return;const value=typeof data==="string"||s.binaryType==="arraybuffer"||!BlobType?data:new BlobType([data]);const event=typeof MessageEventType==="function"?new MessageEventType("message",{data:value,origin:s.origin}):new EventType("message");if(typeof MessageEventType!=="function")define(event,"data",{value});socket.dispatchEvent(event);return}
  if(kind==="error"){s.readyState=3;socket.dispatchEvent(new EventType("error"));return}
  if(kind==="close"){s.readyState=3;sockets.delete(id);socket.dispatchEvent(new CloseEvent("close",{wasClean,code,reason}))}
 };
})'
