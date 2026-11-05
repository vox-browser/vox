// Document.idl GlobalEventHandlers and the Document-only onreadystatechange
// and onvisibilitychange attributes, over the actual Document's handler slots.
// React feature-detects `"oninput" in document`; without these attributes it
// fell back to Internet Explorer's propertychange polyfill and its text
// inputs never reported changes.
module browserjs

import dom
import json2

const window_only_event_handlers = ['afterprint', 'beforeprint', 'beforeunload', 'gamepadconnected',
	'gamepaddisconnected', 'hashchange', 'languagechange', 'message', 'messageerror', 'offline',
	'online', 'pagehide', 'pagereveal', 'pageshow', 'pageswap', 'popstate', 'rejectionhandled',
	'storage', 'unhandledrejection', 'unload']

fn document_event_handler_names() []WindowEventHandlerName {
	mut names := window_event_handler_names().filter(it.event !in window_only_event_handlers)
	names << WindowEventHandlerName{'onreadystatechange', 'readystatechange'}
	names << WindowEventHandlerName{'onvisibilitychange', 'visibilitychange'}
	return names
}

fn is_document_event_handler_name(value string) bool {
	return document_event_handler_names().any(it.event == value)
}

fn (mut runtime Runtime) install_document_event_handlers(document_wrapper voidptr) ! {
	owner := voidptr(&runtime)
	native := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 3 {
			return runtime.event_binding_type_error('Missing internal Document handler arguments')
		}
		method := runtime.binding_dom_string(args[0])!
		target := runtime.native_event_target(args[1])!
		if target.data.kind != .node || unsafe { &dom.Node(target) }.as_document() == none {
			return runtime.event_binding_type_error('Illegal Document receiver')
		}
		name := runtime.binding_dom_string(args[2])!
		if !is_document_event_handler_name(name) {
			return runtime.event_binding_type_error('Unknown Document event handler')
		}
		if method == 'get' { return runtime.javascript_event_handler(target, name) }
		if method == 'set' {
			value := if args.len > 3 { args[3] } else { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			runtime.set_javascript_event_handler(target, name, value)!
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		return runtime.event_binding_type_error('Unknown Document handler operation')
	})!
	mut entries := []string{}
	for name in document_event_handler_names() {
		entries << '[${json2.encode(name.attribute)},${json2.encode(name.event)}]'
	}
	factory := runtime.evaluate_host_value(r'(function(entries){return function(document,native){
 const target=typeof Document==="function"?Document.prototype:document,define=Object.defineProperty,own=Object.getOwnPropertyDescriptor;
 for(let index=0;index<entries.length;index++){
  const attribute=entries[index][0],event=entries[index][1];
  if(own(target,attribute))continue;
  const getter=function(){return native("get",this,event);};
  const setter=function(value){native("set",this,event,value);};
  define(getter,"name",{value:"get "+attribute,configurable:true});
  define(setter,"name",{value:"set "+attribute,configurable:true});
  define(target,attribute,{get:getter,set:setter,enumerable:true,configurable:true});
 }
};})([' + entries.join(',') + '])')!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [document_wrapper, native])!
}
