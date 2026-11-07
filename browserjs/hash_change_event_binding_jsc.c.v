// HTML/HashChangeEvent.{idl,h,cpp}: the event fired at Window after a
// same-document navigation changes the URL's fragment.
module browserjs

import dom
import highresolutiontime

fn (mut runtime Runtime) install_hash_change_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.hash_change_event_prototype != unsafe { nil } { return }
	construct := runtime.make_native_value_host_function('HashChangeEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.hash_change_event_binding_call('construct', receiver, args)
	})!
	get_old_url := runtime.make_native_value_host_function('get oldURL', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.hash_change_event_binding_call('oldURL', receiver, [])
	})!
	get_new_url := runtime.make_native_value_host_function('get newURL', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.hash_change_event_binding_call('newURL', receiver, [])
	})!
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,getOldURL,getNewURL){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const HashChangeEvent=new Proxy(function HashChangeEvent(type,eventInitDict={}){throw new T("HashChangeEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("HashChangeEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(HashChangeEvent,parent);define(HashChangeEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:HashChangeEvent,writable:true,configurable:true});
 define(prototype,"oldURL",{get:getOldURL,enumerable:true,configurable:true});
 define(prototype,"newURL",{get:getNewURL,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"HashChangeEvent",configurable:true});
 define(global,"HashChangeEvent",{value:HashChangeEvent,writable:true,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	binding.hash_change_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [binding.event_constructor,
		C.JSContextGetGlobalObject(runtime.context), construct, get_old_url, get_new_url])!)!
}

// USVString dictionary members default to the empty string.
fn (runtime &Runtime) hash_change_event_url_member(options voidptr, name string) !string {
	if C.JSValueIsUndefined(runtime.context, options) || C.JSValueIsNull(runtime.context, options) {
		return ''
	}
	value := runtime.binding_property(options, name)!
	if C.JSValueIsUndefined(runtime.context, value) { return '' }
	return runtime.binding_dom_utf16(value)!.to_well_formed().str()
}

fn (mut runtime Runtime) hash_change_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	if method == 'construct' {
		if args.len < 2 { return runtime.event_binding_type_error('Missing internal HashChangeEvent arguments') }
		options := args[1]
		if !C.JSValueIsUndefined(runtime.context, options) && !C.JSValueIsNull(runtime.context, options)
			&& !C.JSValueIsObject(runtime.context, options) {
			return runtime.event_binding_type_error('HashChangeEvent options must be a dictionary')
		}
		type_ := runtime.binding_dom_utf16(args[0])!.str()
		// EventInit members first, then HashChangeEventInit's in lexicographic order.
		bubbles := runtime.event_binding_bool_property(options, 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(options, 'cancelable', false)!
		composed := runtime.event_binding_bool_property(options, 'composed', false)!
		new_url := runtime.hash_change_event_url_member(options, 'newURL')!
		old_url := runtime.hash_change_event_url_member(options, 'oldURL')!
		mut event := dom.HashChangeEvent.create(type_, dom.HashChangeEventInit{
			EventInit: dom.EventInit{bubbles: bubbles, cancelable: cancelable, composed: composed}
			old_url: old_url
			new_url: new_url
		})
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin: settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	event := runtime.native_event(receiver)!
	if event.interface_ != .hash_change_event { return runtime.event_binding_type_error('Illegal HashChangeEvent receiver') }
	hash_change := unsafe { &dom.HashChangeEvent(event) }
	return runtime.binding_string(if method == 'oldURL' { hash_change.old_url() } else { hash_change.new_url() })
}
