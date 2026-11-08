// UIEvents/InputEvent.idl: native text editing payloads on Window globals.
module browserjs

import dom
import highresolutiontime
import html
import libjs

fn (mut runtime Runtime) install_input_event_binding() ! {
	mut binding := runtime.event_binding()!
	if binding.input_event_prototype != unsafe { nil } { return }
	owner := voidptr(&runtime)
	runtime.define_value_host_function('__ladybirdInstallStaticRange', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len != 1 || !C.JSObjectIsFunction(runtime.context, args[0]) { return runtime.event_binding_type_error('Expected AbstractRange') }
		runtime.install_static_range_binding(args[0])!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	check_range := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		binding := runtime.event_binding()!
		if args.len != 1 || args[0] !in binding.static_ranges { return runtime.event_binding_type_error('Expected a native StaticRange') }
		return args[0]
	})!
	range_factory := runtime.evaluate_host_value(r'(check=>{const T=TypeError;return function(value){const result=[];if(value===undefined)return result;if(value===null||(typeof value!=="object"&&typeof value!=="function"))throw new T("targetRanges must be a sequence");for(const item of value)result.push(check(item));return result;}})')!
	defer { runtime.release_javascript_value(range_factory) }
	validate_ranges := runtime.retain_javascript_value(runtime.call_javascript_function(range_factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [check_range])!)!
	construct := runtime.make_native_value_host_function('InputEvent', 1, fn [owner, validate_ranges] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 2 { return runtime.event_binding_type_error('Missing InputEvent arguments') }
		type_ := runtime.binding_dom_utf16(args[0])!.str()
		dictionary := args[1]
		mut init := dom.InputEventInit{}
		init.bubbles = runtime.event_binding_bool_property(dictionary, 'bubbles', false)!
		init.cancelable = runtime.event_binding_bool_property(dictionary, 'cancelable', false)!
		init.composed = runtime.event_binding_bool_property(dictionary, 'composed', false)!
		detail := runtime.ui_event_dictionary_member(dictionary, 'detail')!
		if !C.JSValueIsUndefined(runtime.context, detail) { init.detail = runtime.ui_event_long(detail)! }
		init.view = runtime.ui_event_native_view(runtime.ui_event_dictionary_member(dictionary, 'view')!)!
		data := runtime.ui_event_dictionary_member(dictionary, 'data')!
		if !C.JSValueIsUndefined(runtime.context, data) && !C.JSValueIsNull(runtime.context, data) {
			init.data = runtime.binding_dom_utf16(data)!.str()
		}
		transfer := runtime.ui_event_dictionary_member(dictionary, 'dataTransfer')!
		if !C.JSValueIsUndefined(runtime.context, transfer) && !C.JSValueIsNull(runtime.context, transfer) {
			init.data_transfer = voidptr(runtime.native_data_transfer(transfer)!)
		}
		input_type := runtime.ui_event_dictionary_member(dictionary, 'inputType')!
		if !C.JSValueIsUndefined(runtime.context, input_type) { init.input_type = runtime.binding_dom_utf16(input_type)!.str() }
		init.is_composing = runtime.event_binding_bool_property(dictionary, 'isComposing', false)!
		ranges := runtime.ui_event_dictionary_member(dictionary, 'targetRanges')!
		converted_ranges := runtime.call_javascript_function(validate_ranges, C.vox_jsc_JSValueMakeUndefined(runtime.context), [ranges])!
		length := runtime.ui_event_long(runtime.binding_property(converted_ranges, 'length')!)!
		binding := runtime.event_binding()!
		for index in 0 .. length {
			mut exception := unsafe { nil }
			value := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, converted_ranges, u32(index), &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			init.target_ranges << binding.static_ranges[value] or { return runtime.event_binding_type_error('Expected a native StaticRange') }
		}
		mut event := dom.InputEvent.construct_impl(type_, init)!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin: settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	mut functions := [construct]
	for name in ['data', 'dataTransfer', 'inputType', 'isComposing'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			event := runtime.native_event(receiver)!
			if event.interface_ != .input_event { return runtime.event_binding_type_error('Illegal InputEvent receiver') }
			input := unsafe { &dom.InputEvent(event) }
			match name {
				'data' {
					if data := input.data() { return runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(data))! }
					return C.vox_jsc_JSValueMakeNull(runtime.context)
				}
				'dataTransfer' {
					if input.data_transfer() == unsafe { nil } { return C.vox_jsc_JSValueMakeNull(runtime.context) }
					return runtime.javascript_data_transfer(unsafe { &html.DataTransfer(input.data_transfer()) })!
				}
				'inputType' { return runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(input.input_type()))! }
				'isComposing' { return C.vox_jsc_JSValueMakeBoolean(runtime.context, input.is_composing()) }
				else { return runtime.event_binding_type_error('Unknown InputEvent attribute') }
			}
		})!
	}
	functions << runtime.make_native_value_host_function('getTargetRanges', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		event := runtime.native_event(receiver)!
		if event.interface_ != .input_event { return runtime.event_binding_type_error('Illegal InputEvent receiver') }
		input := unsafe { &dom.InputEvent(event) }
		mut ranges := []voidptr{cap: input.target_ranges_.len}
		for range in input.target_ranges_ { ranges << runtime.javascript_static_range(range)! }
		mut exception := unsafe { nil }
		array := C.vox_jsc_JSObjectMakeArray(runtime.context, usize(ranges.len), ranges.data, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		return array
	})!
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,...functions){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const InputEvent=new Proxy(function InputEvent(type,eventInitDict={}){throw new T("InputEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("InputEvent requires one argument");apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(InputEvent,parent);define(InputEvent,"prototype",{value:prototype,writable:false});define(prototype,"constructor",{value:InputEvent,writable:true,configurable:true});
 const fields=["data","dataTransfer","inputType","isComposing"];for(let i=0;i<fields.length;i++)define(prototype,fields[i],{get:functions[i],enumerable:true,configurable:true});
 define(prototype,"getTargetRanges",{value:functions[4],writable:true,enumerable:true,configurable:true});define(prototype,Symbol.toStringTag,{value:"InputEvent",configurable:true});
 define(global,"InputEvent",{value:InputEvent,writable:true,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	mut arguments := [binding.ui_event_constructor, C.JSContextGetGlobalObject(runtime.context)]
	arguments << functions
	binding.input_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), arguments)!)!
}
