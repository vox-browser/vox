// HTML/ErrorEvent.idl, exposed on Window and Worker globals.
module browserjs

import dom
import libjs
import webidl

fn (mut runtime Runtime) install_error_event_binding() ! {
	mut binding := runtime.event_binding()!
	if binding.error_event_prototype != unsafe { nil } { return }
	owner := voidptr(&runtime)
	construct := runtime.make_native_value_host_function('ErrorEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 1 { return runtime.event_binding_type_error('ErrorEvent requires one argument') }
		type_ := runtime.binding_dom_utf16(args[0])!.str()
		dictionary := if args.len > 1 { args[1] } else { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		mut init := dom.ErrorEventInit{}
		init.bubbles = runtime.event_binding_bool_property(dictionary, 'bubbles', false)!
		init.cancelable = runtime.event_binding_bool_property(dictionary, 'cancelable', false)!
		init.composed = runtime.event_binding_bool_property(dictionary, 'composed', false)!
		// Inherited members first, then this dictionary's lexical member order.
		for name in ['colno', 'error', 'filename', 'lineno', 'message'] {
			value := runtime.ui_event_dictionary_member(dictionary, name)!
			if C.JSValueIsUndefined(runtime.context, value) { continue }
			match name {
				'colno' { init.colno = u32(webidl.convert_to_int(runtime.webidl_value(value)!, 32, false, .no, .no)!) }
				'lineno' { init.lineno = u32(webidl.convert_to_int(runtime.webidl_value(value)!, 32, false, .no, .no)!) }
				'error' { init.error = runtime.event_callback_result(value)! }
				'filename' { init.filename = runtime.binding_dom_utf16(value)!.to_well_formed().str() }
				'message' { init.message = runtime.binding_dom_utf16(value)!.str() }
				else {}
			}
		}
		event := dom.ErrorEvent.construct_impl(type_, init)!
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	mut functions := [construct]
	for name in ['message', 'filename', 'lineno', 'colno', 'error'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			event := runtime.native_event(receiver)!
			if event.interface_ != .error_event { return runtime.event_binding_type_error('Illegal ErrorEvent receiver') }
			value := unsafe { &dom.ErrorEvent(event) }
			return match name {
				'message' { runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(value.message()))! }
				'filename' { runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(value.filename()))! }
				'lineno' { C.vox_jsc_JSValueMakeNumber(runtime.context, value.lineno()) }
				'colno' { C.vox_jsc_JSValueMakeNumber(runtime.context, value.colno()) }
				'error' { runtime.event_callback_argument(value.error())! }
				else { return runtime.event_binding_type_error('Unknown ErrorEvent attribute') }
			}
		})!
	}
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,...getters){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const ErrorEvent=new Proxy(function ErrorEvent(type,eventInitDict={}){throw new T("ErrorEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("ErrorEvent requires one argument");apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(ErrorEvent,parent);define(ErrorEvent,"prototype",{value:prototype,writable:false});define(prototype,"constructor",{value:ErrorEvent,writable:true,configurable:true});
 const fields=["message","filename","lineno","colno","error"];for(let i=0;i<fields.length;i++)define(prototype,fields[i],{get:getters[i],enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"ErrorEvent",configurable:true});define(global,"ErrorEvent",{value:ErrorEvent,writable:true,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	mut arguments := [binding.event_constructor, C.JSContextGetGlobalObject(runtime.context)]
	arguments << functions
	binding.error_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), arguments)!)!
}
