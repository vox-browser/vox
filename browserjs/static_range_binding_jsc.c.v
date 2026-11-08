module browserjs

import dom
import webidl

fn (mut runtime Runtime) static_range_node(value voidptr) !&dom.Node {
	target := runtime.native_event_target(value)!
	if target.data.kind != .node { return runtime.event_binding_type_error('Expected a Node') }
	return unsafe { &dom.Node(target) }
}

fn (mut runtime Runtime) install_static_range_binding(parent voidptr) ! {
	mut binding := runtime.event_binding()!
	if binding.static_range_prototype != unsafe { nil } { return }
	owner := voidptr(&runtime)
	construct := runtime.make_native_value_host_function('StaticRange', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len == 0 { return runtime.event_binding_type_error('StaticRange requires an init dictionary') }
		init := args[0]
		// Required dictionary members are read in WebIDL lexicographic order.
		end_node := runtime.static_range_node(runtime.ui_event_dictionary_member(init, 'endContainer')!)!
		end_value := runtime.ui_event_dictionary_member(init, 'endOffset')!
		if C.JSValueIsUndefined(runtime.context, end_value) { return runtime.event_binding_type_error('Missing endOffset') }
		end_offset := int(webidl.convert_to_int(runtime.webidl_value(end_value)!, 32, false, .no, .no)!)
		start_node := runtime.static_range_node(runtime.ui_event_dictionary_member(init, 'startContainer')!)!
		start_value := runtime.ui_event_dictionary_member(init, 'startOffset')!
		if C.JSValueIsUndefined(runtime.context, start_value) { return runtime.event_binding_type_error('Missing startOffset') }
		start_offset := int(webidl.convert_to_int(runtime.webidl_value(start_value)!, 32, false, .no, .no)!)
		range := dom.StaticRange.construct_impl(dom.StaticRangeInit{
			start_container: start_node
			start_offset: start_offset
			end_container: end_node
			end_offset: end_offset
		}) or {
			return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(
				webidl.DOMException.create('InvalidNodeTypeError', err.msg())))!)
		}
		mut binding := runtime.event_binding()!
		binding.static_ranges[receiver] = range
		binding.static_range_wrappers[voidptr(range)] = runtime.retain_javascript_value(receiver)!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	has_range := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		binding := runtime.event_binding()!
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, args.len == 1 && args[0] in binding.static_ranges)
	})!
	mut functions := [construct, has_range]
	for name in ['startContainer', 'startOffset', 'endContainer', 'endOffset', 'collapsed'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			binding := runtime.event_binding()!
			range := binding.static_ranges[receiver] or { return runtime.event_binding_type_error('Illegal StaticRange receiver') }
			return match name {
				'startContainer' { runtime.javascript_event_target(unsafe { &dom.EventTarget(range.start_container()) }, none)! }
				'endContainer' { runtime.javascript_event_target(unsafe { &dom.EventTarget(range.end_container()) }, none)! }
				'startOffset' { C.vox_jsc_JSValueMakeNumber(runtime.context, range.start_offset()) }
				'endOffset' { C.vox_jsc_JSValueMakeNumber(runtime.context, range.end_offset()) }
				else { C.vox_jsc_JSValueMakeBoolean(runtime.context, voidptr(range.start_container()) == voidptr(range.end_container()) && range.start_offset() == range.end_offset()) }
			}
		})!
	}
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,isStatic,...getters){
 const create=Object.create,define=Object.defineProperty,apply=Reflect.apply,T=TypeError;
 const prototype=create(parent.prototype);
 const StaticRange=new Proxy(function StaticRange(init){throw new T("StaticRange constructor requires new")},{construct(target,args,newTarget){
  const candidate=newTarget.prototype,object=create(candidate!==null&&(typeof candidate==="object"||typeof candidate==="function")?candidate:prototype);
  apply(construct,object,args);return object;
 }});
 Object.setPrototypeOf(StaticRange,parent);define(StaticRange,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:StaticRange,writable:true,configurable:true});
 for(const [i,name] of ["startContainer","startOffset","endContainer","endOffset","collapsed"].entries()){
  const live=Object.getOwnPropertyDescriptor(parent.prototype,name).get;
  const getter=Object.getOwnPropertyDescriptor({get [name](){return isStatic(this)?apply(getters[i],this,[]):apply(live,this,[])}},name).get;
  define(parent.prototype,name,{get:getter,enumerable:true,configurable:true});
 }
 define(prototype,Symbol.toStringTag,{value:"StaticRange",configurable:true});define(global,"StaticRange",{value:StaticRange,writable:true,configurable:true});
 return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	mut arguments := [parent, C.JSContextGetGlobalObject(runtime.context)]
	arguments << functions
	binding.static_range_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), arguments)!)!
}

fn (mut runtime Runtime) javascript_static_range(range &dom.StaticRange) !voidptr {
	mut binding := runtime.event_binding()!
	if wrapper := binding.static_range_wrappers[voidptr(range)] { return wrapper }
	if binding.static_range_prototype == unsafe { nil } { return error('NotSupportedError: StaticRange is not installed') }
	wrapper := runtime.call_javascript_function(binding.factory, C.vox_jsc_JSValueMakeUndefined(runtime.context),
		[runtime.binding_string('target'), binding.static_range_prototype])!
	binding.static_ranges[wrapper] = range
	binding.static_range_wrappers[voidptr(range)] = runtime.retain_javascript_value(wrapper)!
	return wrapper
}
