module browserjs

import dom
import html

fn input_event_binding_runtime() &Runtime {
	mut document := html.parse_document('<!doctype html><body>Input</body>')
	_ = html.WindowModel.create_top_level(document, none, 'native-input') or { panic(err) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime
}

fn test_input_event_constructor_payload_identity_utf16_and_inheritance() {
	$if !darwin { return }
	mut runtime := input_event_binding_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const transfer=new DataTransfer(),text="a\u0000\ud800😀",e=new InputEvent(text,{data:text,inputType:text,dataTransfer:transfer,isComposing:true,bubbles:true,cancelable:true,composed:true,detail:7,view:globalThis});
 const defaults=new InputEvent("input");class Derived extends InputEvent{};
 return Object.getPrototypeOf(InputEvent)===UIEvent&&e instanceof InputEvent&&e instanceof UIEvent&&e instanceof Event&&e.type===text&&e.data===text&&e.inputType===text&&e.dataTransfer===transfer&&e.isComposing&&e.bubbles&&e.cancelable&&e.composed&&e.detail===7&&e.view===globalThis&&!e.isTrusted&&e.getTargetRanges().length===0&&e.getTargetRanges()!==e.getTargetRanges()&&defaults.data===null&&defaults.dataTransfer===null&&defaults.inputType===""&&!defaults.isComposing&&new Derived("input") instanceof Derived&&Object.prototype.toString.call(e)==="[object InputEvent]";
})()')! == 'true'
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof InputEvent')! == 'undefined'
}

fn test_input_event_dictionary_conversion_branding_and_original_getter_failures() {
	$if !darwin { return }
	mut runtime := input_event_binding_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 let rejected=0;for(const call of [()=>InputEvent("x"),()=>new InputEvent(),()=>new InputEvent(Symbol()),()=>new InputEvent("x",1),()=>new InputEvent("x",{data:Symbol()}),()=>new InputEvent("x",{dataTransfer:{}}),()=>new InputEvent("x",{targetRanges:null}),()=>new InputEvent("x",{targetRanges:""}),()=>InputEvent.prototype.getTargetRanges.call(new Event("x")),()=>Object.getOwnPropertyDescriptor(InputEvent.prototype,"data").get.call({})])try{call()}catch(error){if(error instanceof TypeError)rejected++}
 const reads=[],options=new Proxy({data:null,inputType:undefined},{get(object,key){reads.push(key);return object[key]}});new InputEvent("input",options);
 let closed=false;const ranges={[Symbol.iterator](){return{next(){return{done:false,value:{}}},return(){closed=true;return{done:true}}}}};try{new InputEvent("input",{targetRanges:ranges})}catch(error){if(!(error instanceof TypeError))return false}
 const marker={identity:true};let original=false;try{new InputEvent("input",{get data(){throw marker}})}catch(error){original=error===marker}
 const descriptor=Object.getOwnPropertyDescriptor(InputEvent.prototype,"inputType"),method=InputEvent.prototype.getTargetRanges;
 return rejected===10&&reads.join(",")==="bubbles,cancelable,composed,detail,view,data,dataTransfer,inputType,isComposing,targetRanges"&&closed&&original&&InputEvent.length===1&&method.length===0&&method.name==="getTargetRanges"&&!("prototype"in method)&&descriptor.enumerable&&descriptor.configurable;
})()')! == 'true'
}

fn test_native_input_event_wrapper_preserves_platform_data_and_composition_state() {
	$if !darwin { return }
	mut runtime := input_event_binding_runtime()
	defer { runtime.close() }
	mut input := dom.InputEvent.create_from_platform_event('input', dom.InputEventInit{
		data: '中😀'
		input_type: 'insertText'
		is_composing: true
	}, [], 12)
	wrapper := runtime.javascript_event(unsafe { &dom.Event(input) })!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(input)
	runtime.define_value_host_function('nativeInput', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	assert runtime.evaluate_host('(()=>{const e=nativeInput();return e instanceof InputEvent&&e.isTrusted&&e.data==="中😀"&&e.inputType==="insertText"&&e.isComposing&&e.bubbles&&e.composed&&!e.cancelable&&e.getTargetRanges().length===0})()')! == 'true'
	input.data_ = none
	input.input_type_ = 'deleteContentBackward'
	input.is_composing_ = false
	assert runtime.evaluate_host('nativeInput().data===null&&nativeInput().inputType==="deleteContentBackward"&&!nativeInput().isComposing')! == 'true'
	before := runtime.protected_values_.len
	runtime.evaluate_host('for(let index=0;index<100;index++)nativeInput().getTargetRanges()')!
	assert runtime.protected_values_.len == before
}
