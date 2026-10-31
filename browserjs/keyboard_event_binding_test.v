module browserjs

import dom
import html

fn keyboard_binding_runtime() &Runtime {
	mut document := html.parse_document('<!doctype html><body>Keyboard</body>')
	_ = html.WindowModel.create_top_level(document, none, 'native-keyboard') or { panic(err) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime
}

fn test_keyboard_event_constructor_inheritance_constants_and_native_data() {
	$if !darwin {
		return
	}
	mut runtime := keyboard_binding_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const e=new KeyboardEvent("keydown",{key:"A",code:"KeyA",location:1,ctrlKey:true,shiftKey:true,repeat:true,isComposing:true,charCode:65,keyCode:66,bubbles:true,view:globalThis});
 globalThis.keyboard=e;
 return Object.getPrototypeOf(KeyboardEvent)===UIEvent&&e instanceof KeyboardEvent&&e instanceof UIEvent&&e instanceof Event&&!e.isTrusted&&e.key==="A"&&e.code==="KeyA"&&e.location===1&&e.ctrlKey&&e.shiftKey&&e.repeat&&e.isComposing&&e.charCode===65&&e.keyCode===66&&e.which===66&&e.view===globalThis&&e.getModifierState("Control")&&KeyboardEvent.DOM_KEY_LOCATION_NUMPAD===3&&e.DOM_KEY_LOCATION_LEFT===1&&Object.prototype.toString.call(e)==="[object KeyboardEvent]";
})()')! == 'true'
	native := runtime.native_event(runtime.evaluate_host_value('keyboard')!)!
	assert native.interface_ == .keyboard_event
	assert unsafe { &dom.KeyboardEvent(native) }.key() == 'A'
	assert unsafe { &dom.KeyboardEvent(native) }.code() == 'KeyA'
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof KeyboardEvent')! == 'undefined'
}

fn test_keyboard_event_webidl_conversion_and_legacy_reinitialization() {
	$if !darwin {
		return
	}
	mut runtime := keyboard_binding_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 let failures=0;for(const invoke of [()=>KeyboardEvent("x"),()=>new KeyboardEvent(),()=>new KeyboardEvent(Symbol()),()=>new KeyboardEvent("x",1),()=>Object.getOwnPropertyDescriptor(KeyboardEvent.prototype,"key").get.call({}),()=>KeyboardEvent.prototype.getModifierState.call(new Event("x"),"Shift")])try{invoke()}catch(e){if(e instanceof TypeError)failures++}
 const reads=[],options=new Proxy({key:"Enter",keyCode:4294967297,location:-1},{get(target,key){reads.push(key);return target[key]}}),e=new KeyboardEvent("keydown",options);
 if(e.keyCode!==1||e.location!==4294967295||reads.slice(-7).join(",")!=="charCode,code,isComposing,key,keyCode,location,repeat")return false;
 e.initKeyboardEvent("keyup",true,true,globalThis,"Escape",2,true,false,true,false);
 return failures===6&&e.type==="keyup"&&e.key==="Escape"&&e.location===2&&e.ctrlKey&&e.shiftKey&&!e.altKey&&!e.metaKey&&e.bubbles&&e.cancelable&&e.view===globalThis;
})()')! == 'true'
}

fn test_native_keyboard_wrapper_keeps_platform_identity_and_state() {
	$if !darwin {
		return
	}
	mut runtime := keyboard_binding_runtime()
	defer { runtime.close() }
	event := dom.KeyboardEvent.create_from_platform_event('keydown', .a, dom.modifier_ctrl, u32(`a`), true)
	wrapper := runtime.javascript_event(unsafe { &dom.Event(event) })!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	runtime.define_value_host_function('nativeKeyboard', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	assert runtime.evaluate_host('(()=>{const e=nativeKeyboard();return e instanceof KeyboardEvent&&e.isTrusted&&e.ctrlKey&&e.repeat&&e.key==="a"&&e.code==="KeyA"&&e.getModifierState("Control")})()')! == 'true'
}
