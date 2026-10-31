module browserjs

import dom
import html
import highresolutiontime

fn ui_native_event_binding_fixture() (&Runtime, &html.EnvironmentSettingsObject) {
	document := html.parse_document_with_url('<!doctype html><body>UI events</body>', dom.URL{
		value: 'https://native-ui-events.example/'
	})
	mut owner_document := unsafe { &dom.Document(document) }
	owner_document.load_timing_info.navigation_start_time =
		highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'native-ui-events') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn ui_native_owner_window(settings &html.EnvironmentSettingsObject) &html.WindowModel {
	for window in html.all_windows() {
		if voidptr(window) == voidptr(settings.global_object()) {
			return window
		}
	}
	panic('missing actual UIEvent owner Window')
}

fn test_native_ui_event_constructor_metadata_defaults_and_window_exposure() {
	$if !darwin { return }
	mut unbound := Runtime.create()
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof UIEvent==="undefined"')! == 'true'
	mut runtime, settings := ui_native_event_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof UIEvent==="function"')! == 'true'
	upgrade_document := html.parse_document_with_url('<!doctype html><body>late owner</body>', dom.URL{
		value: 'https://late-ui-events.example/'
	})
	_ = html.WindowModel.create_top_level(upgrade_document, none, 'late-ui-events')!
	upgrade_settings := unsafe { &html.EnvironmentSettingsObject(upgrade_document.relevant_settings_object()) }
	unbound.evaluate_host('globalThis.retainedEventConstructor=Event;globalThis.retainedGlobal=globalThis;globalThis={};Event=function ReplacementEvent(){};0')!
	unbound.bind_scripting_environment(upgrade_settings)!
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof UIEvent==="function"&&Object.getPrototypeOf(UIEvent)===retainedEventConstructor&&Object.getPrototypeOf(UIEvent.prototype)===retainedEventConstructor.prototype&&globalThis.UIEvent===undefined&&new UIEvent("upgrade",{view:retainedGlobal}).view===retainedGlobal')! == 'true'
	unbound.close()
	constructor := runtime.evaluate_host_value('UIEvent')!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host_value('UIEvent')! == constructor
	assert runtime.evaluate_host(r'(()=>{
 const prototype=UIEvent.prototype,constructor=Object.getOwnPropertyDescriptor(prototype,"constructor"),method=Object.getOwnPropertyDescriptor(prototype,"initUIEvent"),global=Object.getOwnPropertyDescriptor(globalThis,"UIEvent");
 if(UIEvent.name!=="UIEvent"||UIEvent.length!==1||Object.getPrototypeOf(UIEvent)!==Event||Object.getPrototypeOf(prototype)!==Event.prototype||constructor.value!==UIEvent||!constructor.writable||!constructor.configurable||constructor.enumerable||!global.writable||!global.configurable||global.enumerable||Object.getOwnPropertyDescriptor(UIEvent,"prototype").writable)return false;
 for(const name of ["view","detail","which"]){const descriptor=Object.getOwnPropertyDescriptor(prototype,name);if(!descriptor||!descriptor.enumerable||!descriptor.configurable||descriptor.set!==undefined||descriptor.get.name!=="get "+name||descriptor.get.length!==0||!Function.prototype.toString.call(descriptor.get).includes("[native code]"))return false}
 if(!method.writable||!method.enumerable||!method.configurable||method.value.name!=="initUIEvent"||method.value.length!==1||!Function.prototype.toString.call(method.value).includes("[native code]"))return false;
 for(const operation of [method.value,...["view","detail","which"].map(name=>Object.getOwnPropertyDescriptor(prototype,name).get)]){let rejected=false;try{Reflect.construct(function Empty(){},[],operation)}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 const value=new UIEvent("λ\u0000ui");class Child extends UIEvent{};const child=new Child("child");
 let errors=0;for(const operation of [()=>UIEvent("call"),()=>new UIEvent(),()=>value.initUIEvent()])try{operation()}catch(error){if(error instanceof TypeError)errors++}
 return value instanceof UIEvent&&value instanceof Event&&Object.prototype.toString.call(value)==="[object UIEvent]"&&value.type==="λ\u0000ui"&&value.view===null&&value.detail===0&&value.which===0&&!value.isTrusted&&!value.bubbles&&!value.cancelable&&!value.composed&&value.timeStamp>=0&&value.timeStamp<10000&&!Object.hasOwn(value,"detail")&&Object.getOwnPropertyDescriptor(value,"isTrusted").configurable===false&&child instanceof Child&&child instanceof UIEvent&&Object.getPrototypeOf(child)===Child.prototype&&errors===3;
})()')! == 'true'
	actual :=
		runtime.native_event(runtime.evaluate_host_value('new UIEvent("owner",{view:globalThis,detail:9})')!)!
	assert actual.interface_ == .ui_event && !actual.is_trusted()
	ui := unsafe { &dom.UIEvent(actual) }
	assert ui.detail() == 9
	assert ui.view() == voidptr(ui_native_owner_window(settings).window().dom_proxy())
}

fn test_native_ui_event_dictionary_order_long_conversion_and_original_exceptions() {
	$if !darwin { return }
	mut runtime, settings := ui_native_event_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof UIEvent==="function"')! == 'true'
	foreign_document := html.parse_document_with_url('<!doctype html><body>foreign</body>', dom.URL{
		value: 'https://foreign-ui-events.example/'
	})
	foreign_window :=
		html.WindowModel.create_top_level(foreign_document, none, 'foreign-ui-events')!
	foreign_wrapper :=
		runtime.javascript_event_target(unsafe { &dom.EventTarget(foreign_window) }, none)!
	runtime.define_value_host_function('__foreignUIWindow', fn [foreign_wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return foreign_wrapper
	})!
	assert runtime.evaluate_host(r'(()=>{
 const order=[],type={[Symbol.toPrimitive](hint){order.push("type:"+hint);return "ordered"}},detail={valueOf(){order.push("detail-number");return 2147483649.8}};
 const init={get bubbles(){order.push("bubbles");return true},get cancelable(){order.push("cancelable");return true},get composed(){order.push("composed");return true},get detail(){order.push("detail-get");return detail},get view(){order.push("view");return globalThis}};
 const event=new UIEvent(type,init);
 if(order.join(",")!=="type:string,bubbles,cancelable,composed,detail-get,detail-number,view"||event.type!=="ordered"||event.detail!==-2147483647||event.view!==globalThis||!event.bubbles||!event.cancelable||!event.composed)return false;
 for(const [input,expected] of [[NaN,0],[Infinity,0],[-Infinity,0],[-1.9,-1],[4294967301.9,5],[2147483648,-2147483648],[-4294967297.8,-1],["3.9",3]])if(new UIEvent("long",{detail:input}).detail!==expected)return false;
 for(const init of [undefined,null,{}]){const value=new UIEvent("defaults",init);if(value.detail!==0||value.view!==null)return false}
 for(const input of [1n,Symbol("long")]){let rejected=false,viewReads=0;try{new UIEvent("bad",{detail:input,get view(){viewReads++;return globalThis}})}catch(error){rejected=error instanceof TypeError}if(!rejected||viewReads!==0)return false}
 const marker={};let typeSame=false,detailSame=false,viewSame=false,laterReads=0;
 try{new UIEvent({toString(){throw marker}},{get bubbles(){laterReads++;return false}})}catch(error){typeSame=error===marker}
 try{new UIEvent("detail",{detail:{valueOf(){throw marker}},get view(){laterReads++;return globalThis}})}catch(error){detailSame=error===marker}
 try{new UIEvent("view",{get view(){throw marker}})}catch(error){viewSame=error===marker}
 let proxyReads=0;const proxy=new Proxy(globalThis,{get(){proxyReads++;throw marker},getPrototypeOf(){proxyReads++;throw marker}});
 for(const view of [{},proxy,__foreignUIWindow()]){let rejected=false;try{new UIEvent("view",{view})}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 return typeSame&&detailSame&&viewSame&&laterReads===0&&proxyReads===0&&new UIEvent("null",{view:null}).view===null;
})()')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_ui_event_brands_precede_coercion_and_legacy_init_is_atomic() {
	$if !darwin { return }
	mut runtime, _ := ui_native_event_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof UIEvent==="function"')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const event=new UIEvent("original",{detail:4,view:globalThis,composed:true}),prototype=UIEvent.prototype,marker={};let traps=0,coercions=0;
 const type={toString(){coercions++;throw marker}},detail={valueOf(){coercions++;throw marker}},proxy=new Proxy(event,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});
 for(const receiver of [Object.create(prototype),new Event("base"),proxy,{},null,undefined,1]){
  for(const name of ["view","detail","which"]){let rejected=false;try{Object.getOwnPropertyDescriptor(prototype,name).get.call(receiver)}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
  let rejected=false;try{prototype.initUIEvent.call(receiver,type,true,true,globalThis,detail)}catch(error){rejected=error instanceof TypeError}if(!rejected)return false;
 }
 if(traps!==0||coercions!==0)return false;
 let sameType=false,sameDetail=false,invalidView=false;
 try{event.initUIEvent(type,false,false,null,0)}catch(error){sameType=error===marker}
 try{event.initUIEvent("partial",false,false,null,detail)}catch(error){sameDetail=error===marker}
 try{event.initUIEvent("partial",false,false,{},7)}catch(error){invalidView=error instanceof TypeError}
 if(!sameType||!sameDetail||!invalidView||event.type!=="original"||event.detail!==4||event.view!==globalThis||!event.composed)return false;
 const order=[];event.initUIEvent({toString(){order.push("type");return "legacy"}},true,false,globalThis,{valueOf(){order.push("detail");return 4294967302.75}});
 return order.join(",")==="type,detail"&&event.type==="legacy"&&event.detail===6&&event.view===globalThis&&event.bubbles&&!event.cancelable&&event.composed&&coercions===2;
})()')! == 'true'
}

fn test_native_ui_event_family_wrappers_keep_identity_virtual_which_and_dispatch_init_guard() {
	$if !darwin { return }
	mut runtime, settings := ui_native_event_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof UIEvent==="function"')! == 'true'
	owner := ui_native_owner_window(settings)
	ui_init := dom.UIEventInit{
		EventInit: dom.EventInit{
			bubbles:    true
			cancelable: true
			composed:   true
		}
		detail:    7
		view:      voidptr(owner.window().dom_proxy())
	}
	modifiers := dom.EventModifierInit{
		UIEventInit: ui_init
	}
	mouse_init := dom.MouseEventInit{
		EventModifierInit: modifiers
		button:            2
	}
	mut ui := dom.UIEvent.create('native-ui', ui_init)
	mut mouse := dom.MouseEvent.create('click', mouse_init)
	pointer := dom.PointerEvent.create('pointermove', dom.PointerEventInit{
		MouseEventInit: mouse_init
	})
	mut keyboard := dom.KeyboardEvent.create('keypress', dom.KeyboardEventInit{
		EventModifierInit: modifiers
		key_code:          65
		char_code:         97
	})
	composition := dom.CompositionEvent.create('compositionstart', dom.CompositionEventInit{
		UIEventInit: ui_init
	})
	focus := dom.FocusEvent.create('focusin', dom.FocusEventInit{ UIEventInit: ui_init })
	input := dom.InputEvent.create_from_platform_event('beforeinput', dom.InputEventInit{
		UIEventInit: ui_init
	}, [], 42)
	text := dom.TextEvent.create('textInput')
	wheel := dom.WheelEvent.create('wheel', dom.WheelEventInit{ MouseEventInit: mouse_init })
	drag := html.DragEvent.create('drag', html.DragEventInit{ MouseEventInit: mouse_init }, 0, 0,
		0, 0)
	events := [unsafe { &dom.Event(ui) }, unsafe { &dom.Event(mouse) }, unsafe { &dom.Event(pointer) },
		unsafe { &dom.Event(keyboard) }, unsafe { &dom.Event(composition) }, unsafe { &dom.Event(focus) },
		unsafe { &dom.Event(input) }, unsafe { &dom.Event(text) }, unsafe { &dom.Event(wheel) },
		unsafe { &dom.Event(drag) }]
	assert runtime.evaluate_host('globalThis.originalUIEvent=UIEvent;globalThis.originalUIPrototype=UIEvent.prototype;globalThis.originalMouseEvent=MouseEvent;globalThis.originalMousePrototype=MouseEvent.prototype;delete globalThis.UIEvent;globalThis.UIEvent=function ReplacementUIEvent(){};globalThis.nativeUIFamilies=[];0')! == '0'
	for index, event in events {
		wrapper := runtime.javascript_event(event)!
		assert runtime.native_event(wrapper)! == event
		assert runtime.javascript_event(event)! == wrapper
		runtime.define_value_host_function('__uiFamily${index}', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
			return wrapper
		})!
		runtime.evaluate_host('nativeUIFamilies.push(__uiFamily${index}());0')!
	}
	assert runtime.evaluate_host(r'(()=>{
 const which=[0,3,3,65,0,0,0,0,3,3],mouse=[1,2,8,9];
 return nativeUIFamilies.length===10&&nativeUIFamilies.every((event,index)=>event instanceof originalUIEvent&&event instanceof Event&&Object.getPrototypeOf(event)===(index===2?PointerEvent.prototype:index===8?WheelEvent.prototype:index===9?DragEvent.prototype:index===3?KeyboardEvent.prototype:mouse.includes(index)?originalMousePrototype:originalUIPrototype)&&(event instanceof PointerEvent)===(index===2)&&(event instanceof WheelEvent)===(index===8)&&(event instanceof DragEvent)===(index===9)&&(event instanceof originalMouseEvent)===mouse.includes(index)&&Object.prototype.toString.call(event)===(index===2?"[object PointerEvent]":index===8?"[object WheelEvent]":index===9?"[object DragEvent]":index===3?"[object KeyboardEvent]":mouse.includes(index)?"[object MouseEvent]":"[object UIEvent]")&&event.isTrusted&&event.detail===(index===7?0:7)&&event.which===which[index]&&event.view===(index===7?null:globalThis)&&event.currentTarget===null)&&nativeUIFamilies.every(event=>!(event instanceof UIEvent))&&new Event("base").detail===undefined;
})()')! == 'true'
	mouse.button_ = 4
	keyboard.key_code_ = 90
	ui.detail_ = 11
	ui.view_ = voidptr(settings.global_object())
	assert runtime.evaluate_host('nativeUIFamilies[1].which===5&&nativeUIFamilies[3].which===90&&nativeUIFamilies[0].detail===11&&nativeUIFamilies[0].view===globalThis')! == 'true'
	target := dom.EventTarget.new()
	wrapper := runtime.javascript_event_target(target, none)!
	runtime.define_value_host_function('__uiNativeTarget', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	assert runtime.evaluate_host(r'globalThis.uiInitOrder=[];globalThis.uiDispatchChecks=[];
 __uiNativeTarget().addEventListener("native-ui",function(event){
  uiDispatchChecks.push(this===__uiNativeTarget()&&event===nativeUIFamilies[0]&&event.isTrusted&&event.detail===11&&event.view===globalThis&&event.target===this&&event.currentTarget===this);
  event.initUIEvent({toString(){uiInitOrder.push("type");return "ignored"}},false,false,null,{valueOf(){uiInitOrder.push("detail");return 99.8}});
  uiDispatchChecks.push(event.type==="native-ui"&&event.detail===11&&event.view===globalThis&&event.isTrusted&&event.bubbles&&event.cancelable&&event.composed);
  event.preventDefault();event.stopImmediatePropagation();
 });0')! == '0'
	assert !target.dispatch_event(unsafe { &dom.Event(ui) })
	assert ui.is_trusted() && ui.detail() == 11 && ui.type_name() == 'native-ui'
	assert runtime.evaluate_host('uiInitOrder.join(",")==="type,detail"&&uiDispatchChecks.length===2&&uiDispatchChecks.every(Boolean)&&nativeUIFamilies[0].defaultPrevented&&!nativeUIFamilies[0].cancelBubble&&nativeUIFamilies[0].currentTarget===null')! == 'true'
	assert runtime.evaluate_host('nativeUIFamilies[0].stopImmediatePropagation();nativeUIFamilies[0].cancelBubble')! == 'true'
	stamp := ui.time_stamp()
	assert runtime.evaluate_host('nativeUIFamilies[0].initUIEvent("reset");nativeUIFamilies[0].type==="reset"&&nativeUIFamilies[0].detail===0&&nativeUIFamilies[0].view===null&&!nativeUIFamilies[0].isTrusted&&!nativeUIFamilies[0].defaultPrevented&&!nativeUIFamilies[0].cancelBubble&&nativeUIFamilies[0].target===null&&!nativeUIFamilies[0].bubbles&&!nativeUIFamilies[0].cancelable&&nativeUIFamilies[0].composed')! == 'true'
	assert ui.time_stamp() == stamp && ui.view() == unsafe { nil } && ui.detail() == 0
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
