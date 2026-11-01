// HTML/FormDataEvent.idl; the payload shares XHR's live native entry list.
module browserjs

import dom
import html
import xhr

fn (mut host FormDataHost) html_form_data(data &xhr.FormData) &html.FormData {
	mut payload := html.FormData.create([]html.FormDataEntry{})
	payload.bind_entry_list(unsafe { &xhr.FormData(data) })
	return payload
}

fn (mut host FormDataHost) wrap_html_form_data(payload &html.FormData) !voidptr {
	if owner := payload.entry_list() {
		if owner is xhr.FormData { return host.wrap(unsafe { &xhr.FormData(owner) }) }
	}
	data := xhr.FormData.from_html_entries(payload.entries())
	mut shared := unsafe { &html.FormData(payload) }
	shared.bind_entry_list(data)
	return host.wrap(data)
}

fn (mut runtime Runtime) install_form_data_event_binding() ! {
	runtime.install_event_target_binding()!
	mut binding := runtime.event_binding()!
	if binding.form_data_event_prototype != unsafe { nil } { return }
	owner := voidptr(&runtime)
	construct := runtime.make_native_value_host_function('FormDataEvent', 2, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 2 { return runtime.event_binding_type_error('FormDataEvent requires two arguments') }
		type_ := runtime.binding_dom_string(args[0])!
		bubbles := runtime.event_binding_bool_property(args[1], 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(args[1], 'cancelable', false)!
		composed := runtime.event_binding_bool_property(args[1], 'composed', false)!
		value := runtime.ui_event_dictionary_member(args[1], 'formData')!
		mut host := form_data_bindings_[owner] or { return runtime.event_binding_type_error('FormData binding is unavailable') }
		data := host.record(value) or { return runtime.event_binding_type_error('FormDataEvent requires a native FormData') }
		event := html.FormDataEvent.construct_impl(type_, html.FormDataEventInit{
			EventInit: dom.EventInit{bubbles: bubbles, cancelable: cancelable, composed: composed}
			form_data: host.html_form_data(data)
		})!
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.JSValueMakeUndefined(runtime.context)
	})!
	getter := runtime.make_native_value_host_function('get formData', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		event := runtime.native_event(receiver)!
		if event.interface_ != .form_data_event { return runtime.event_binding_type_error('Illegal FormDataEvent receiver') }
		payload := unsafe { &html.FormDataEvent(event) }.form_data() or {
			return runtime.event_binding_type_error('FormDataEvent has no native payload')
		}
		mut host := form_data_bindings_[owner] or { return runtime.event_binding_type_error('FormData binding is unavailable') }
		return host.wrap_html_form_data(payload)
	})!
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,getData){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const FormDataEvent=new Proxy(function FormDataEvent(type,eventInitDict){throw new T("FormDataEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<2)throw new T("FormDataEvent requires two arguments");apply(construct,receiver,[args[0],args[1]]);return receiver;
 }});
 Object.setPrototypeOf(FormDataEvent,parent);define(FormDataEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:FormDataEvent,writable:true,configurable:true});
 define(prototype,"formData",{get:getData,enumerable:true,configurable:true});define(prototype,Symbol.toStringTag,{value:"FormDataEvent",configurable:true});
 define(global,"FormDataEvent",{value:FormDataEvent,writable:true,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	binding.form_data_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [binding.event_constructor,
		C.JSContextGetGlobalObject(runtime.context), construct, getter])!)!
}
