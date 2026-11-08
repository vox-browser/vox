// HTML/PageTransitionEvent.{idl,h,cpp}: pagehide and pageshow expose whether
// the document is leaving for, or returning from, the back/forward cache.
module browserjs

import dom
import highresolutiontime

fn (mut runtime Runtime) install_page_transition_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.page_transition_event_prototype != unsafe { nil } { return }
	construct := runtime.make_native_value_host_function('PageTransitionEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.page_transition_event_binding_call('construct', receiver, args)
	})!
	get_persisted := runtime.make_native_value_host_function('get persisted', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.page_transition_event_binding_call('persisted', receiver, [])
	})!
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,getPersisted){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const PageTransitionEvent=new Proxy(function PageTransitionEvent(type,eventInitDict={}){throw new T("PageTransitionEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("PageTransitionEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(PageTransitionEvent,parent);define(PageTransitionEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:PageTransitionEvent,writable:true,configurable:true});
 define(prototype,"persisted",{get:getPersisted,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"PageTransitionEvent",configurable:true});
 define(global,"PageTransitionEvent",{value:PageTransitionEvent,writable:true,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	binding.page_transition_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [binding.event_constructor,
		C.JSContextGetGlobalObject(runtime.context), construct, get_persisted])!)!
}

fn (mut runtime Runtime) page_transition_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	if method == 'construct' {
		if args.len < 2 { return runtime.event_binding_type_error('Missing internal PageTransitionEvent arguments') }
		// Convert the required argument before reading the optional dictionary.
		type_ := runtime.binding_dom_utf16(args[0])!.str()
		options := args[1]
		if !C.JSValueIsUndefined(runtime.context, options) && !C.JSValueIsNull(runtime.context, options)
			&& !C.JSValueIsObject(runtime.context, options) {
			return runtime.event_binding_type_error('PageTransitionEvent options must be a dictionary')
		}
		bubbles := runtime.event_binding_bool_property(options, 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(options, 'cancelable', false)!
		composed := runtime.event_binding_bool_property(options, 'composed', false)!
		persisted := runtime.event_binding_bool_property(options, 'persisted', false)!
		mut event := dom.PageTransitionEvent.create(type_, dom.PageTransitionEventInit{
			EventInit: dom.EventInit{bubbles: bubbles, cancelable: cancelable, composed: composed}
			persisted: persisted
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
	if event.interface_ != .page_transition_event { return runtime.event_binding_type_error('Illegal PageTransitionEvent receiver') }
	transition := unsafe { &dom.PageTransitionEvent(event) }
	return C.vox_jsc_JSValueMakeBoolean(runtime.context, transition.persisted())
}
