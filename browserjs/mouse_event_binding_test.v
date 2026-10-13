module browserjs

import dom
import html
import highresolutiontime

fn mouse_native_event_fixture() (&Runtime, &html.EnvironmentSettingsObject) {
	document := html.parse_document_with_url('<!doctype html><body>Mouse events</body>', dom.URL{
		value: 'https://native-mouse-events.example/'
	})
	mut owner_document := unsafe { &dom.Document(document) }
	owner_document.load_timing_info.navigation_start_time =
		highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'native-mouse-events') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn mouse_native_owner_window(settings &html.EnvironmentSettingsObject) &html.WindowModel {
	for window in html.all_windows() {
		if voidptr(window) == voidptr(settings.global_object()) {
			return window
		}
	}
	panic('missing actual MouseEvent owner Window')
}

fn mouse_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn test_native_mouse_event_metadata_defaults_subclasses_and_late_window_exposure() {
	$if !darwin { return }
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof MouseEvent==="undefined"')! == 'true'
	mut runtime, settings := mouse_native_event_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof MouseEvent==="function"')! == 'true'
	late_document := html.parse_document_with_url('<!doctype html><body>late Mouse owner</body>', dom.URL{
		value: 'https://late-mouse-events.example/'
	})
	_ = html.WindowModel.create_top_level(late_document, none, 'late-mouse-events')!
	late_settings := unsafe { &html.EnvironmentSettingsObject(late_document.relevant_settings_object()) }
	unbound.evaluate_host('globalThis.retainedGlobal=globalThis;globalThis.retainedEvent=Event;Event=function ReplacementEvent(){};UIEvent=function ReplacementUIEvent(){};globalThis={};0')!
	unbound.bind_scripting_environment(late_settings)!
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof MouseEvent==="function"&&typeof UIEvent==="function"&&Object.getPrototypeOf(MouseEvent)===UIEvent&&Object.getPrototypeOf(MouseEvent.prototype)===UIEvent.prototype&&Object.getPrototypeOf(UIEvent)===retainedEvent&&globalThis.MouseEvent===undefined&&new MouseEvent("late",{view:retainedGlobal}).view===retainedGlobal')! == 'true'
	constructor := runtime.evaluate_host_value('MouseEvent')!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host_value('MouseEvent')! == constructor
	assert runtime.evaluate_host(r'(()=>{
 const C=MouseEvent,p=C.prototype,global=Object.getOwnPropertyDescriptor(globalThis,"MouseEvent"),constructor=Object.getOwnPropertyDescriptor(p,"constructor");
 const fields=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY","ctrlKey","shiftKey","altKey","metaKey","movementX","movementY","button","buttons","relatedTarget"];
 if(C.name!=="MouseEvent"||C.length!==1||Object.getPrototypeOf(C)!==UIEvent||Object.getPrototypeOf(p)!==UIEvent.prototype||!global.writable||!global.configurable||global.enumerable||Object.getOwnPropertyDescriptor(C,"prototype").writable||constructor.value!==C||!constructor.writable||!constructor.configurable||constructor.enumerable)return false;
 const native=[];for(const field of fields){const d=Object.getOwnPropertyDescriptor(p,field);if(!d||d.set!==undefined||!d.enumerable||!d.configurable||d.get.name!=="get "+field||d.get.length!==0||!Function.prototype.toString.call(d.get).includes("[native code]"))return false;native.push(d.get)}
 for(const name of ["getModifierState","initMouseEvent"]){const d=Object.getOwnPropertyDescriptor(p,name);if(!d||!d.writable||!d.enumerable||!d.configurable||d.value.name!==name||d.value.length!==1||!Function.prototype.toString.call(d.value).includes("[native code]"))return false;native.push(d.value)}
 for(const operation of native){let rejected=false;try{Reflect.construct(function Empty(){},[],operation)}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 const Alternative=function Alternative(){};for(const prototype of [null,1]){Alternative.prototype=prototype;const value=Reflect.construct(C,["fallback"],Alternative);if(Object.getPrototypeOf(value)!==p||!(value instanceof C))return false}
 const custom=Object.create(p);let prototypeReads=0,coercions=0;const next=new Proxy(function Next(){},{get(target,name,receiver){if(name==="prototype"){prototypeReads++;return custom}return Reflect.get(target,name,receiver)}});
 const customEvent=Reflect.construct(C,["custom"],next);if(prototypeReads!==1||Object.getPrototypeOf(customEvent)!==custom||customEvent.type!=="custom")return false;
 const marker={},throwingNext=new Proxy(function ThrowingNext(){},{get(target,name,receiver){if(name==="prototype"){prototypeReads++;throw marker}return Reflect.get(target,name,receiver)}}),type={toString(){coercions++;return "ignored"}},dictionary=new Proxy({},{get(){coercions++;return 0}});
 for(const args of [[type,dictionary],[]]){let same=false;try{Reflect.construct(C,args,throwingNext)}catch(error){same=error===marker}if(!same)return false}
 if(prototypeReads!==3||coercions!==0)return false;
 const event=new C("μ\u0000mouse");class Child extends C{};const child=new Child("child");let errors=0;
 for(const operation of [()=>C("call"),()=>new C(),()=>new C(Symbol("type")),()=>event.getModifierState(),()=>event.initMouseEvent()])try{operation()}catch(error){if(error instanceof TypeError)errors++}
 return event instanceof C&&event instanceof UIEvent&&event instanceof Event&&Object.prototype.toString.call(event)==="[object MouseEvent]"&&event.type==="μ\u0000mouse"&&!event.isTrusted&&!event.bubbles&&!event.cancelable&&!event.composed&&event.view===null&&event.detail===0&&event.which===1&&event.relatedTarget===null&&event.timeStamp>=0&&event.timeStamp<10000&&fields.filter(name=>name!=="relatedTarget").every(name=>event[name]===(name.endsWith("Key")?false:0))&&!Object.hasOwn(event,"clientX")&&Object.getOwnPropertyDescriptor(event,"isTrusted").configurable===false&&child instanceof Child&&child instanceof C&&Object.getPrototypeOf(child)===Child.prototype&&new C(undefined).type==="undefined"&&errors===5;
})()')! == 'true'
	actual :=
		runtime.native_event(runtime.evaluate_host_value('new MouseEvent("owner",{view:globalThis,detail:9})')!)!
	assert actual.interface_ == .mouse_event && !actual.is_trusted()
	mouse := unsafe { &dom.MouseEvent(actual) }
	assert mouse.detail() == 9
	assert mouse.view() == voidptr(mouse_native_owner_window(settings).window().dom_proxy())
}

fn test_native_mouse_event_inherited_dictionary_order_numeric_conversion_and_original_exceptions() {
	$if !darwin { return }
	mut runtime, settings := mouse_native_event_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof MouseEvent==="function"')! == 'true'
	related := dom.EventTarget.new()
	related_wrapper := runtime.javascript_event_target(related, none)!
	mouse_native_export(mut runtime, '__mouseDictionaryTarget', related_wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const target=__mouseDictionaryTarget(),members=["bubbles","cancelable","composed","detail","view","altKey","ctrlKey","metaKey","modifierAltGraph","modifierCapsLock","modifierFn","modifierFnLock","modifierHyper","modifierNumLock","modifierScrollLock","modifierSuper","modifierSymbol","modifierSymbolLock","shiftKey","button","buttons","clientX","clientY","movementX","movementY","relatedTarget","screenX","screenY"],order=[];
 const numbers={detail:2147483649.8,button:65537.8,buttons:65539.8,clientX:-3.75,clientY:4.625,movementX:1.25,movementY:-2.5,screenX:8.875,screenY:-7.125};let booleanHooks=0;
 const values={view:globalThis,relatedTarget:target},numericNames=Object.keys(numbers);
 for(const name of members)if(!(name in values))values[name]=numericNames.includes(name)?{[Symbol.toPrimitive](hint){order.push(name+":"+hint);return numbers[name]}}:true;
 values.ctrlKey={valueOf(){booleanHooks++;throw 0},toString(){booleanHooks++;throw 0}};
 const init=new Proxy(values,{get(object,name){order.push(name);return Reflect.get(object,name)}});
 const event=new MouseEvent({[Symbol.toPrimitive](hint){order.push("type:"+hint);return "ordered"}},init),expected=["type:string"];
 for(const name of members){expected.push(name);if(numericNames.includes(name))expected.push(name+":number")}
 if(order.join(",")!==expected.join(",")||booleanHooks!==0||event.type!=="ordered"||event.detail!==-2147483647||event.view!==globalThis||event.relatedTarget!==target||event.button!==1||event.buttons!==3||event.which!==2||event.clientX!==-4||event.clientY!==4||event.pageX!==-4||event.pageY!==4||event.offsetX!==-4||event.offsetY!==4||event.x!==-4||event.y!==4||event.screenX!==8||event.screenY!==-8||event.movementX!==1.25||event.movementY!==-2.5||!event.ctrlKey||!event.shiftKey||!event.altKey||!event.metaKey)return false;
 globalThis.orderedNativeMouse=event;
 for(const [input,short,unsigned] of [[65537.9,1,1],[-65537.9,-1,65535],[32768.9,-32768,32768],[NaN,0,0],[Infinity,0,0]]){const value=new MouseEvent("wrap",{button:input,buttons:input});if(value.button!==short||value.buttons!==unsigned)return false}
 for(const field of ["screenX","screenY","clientX","clientY","movementX","movementY"])for(const input of [NaN,Infinity,-Infinity]){let rejected=false;try{new MouseEvent("finite",{[field]:input})}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 for(const input of [1n,Symbol("number")])for(const field of ["detail","button","buttons","clientX"]){let rejected=false;try{new MouseEvent("number",{[field]:input})}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 const originalClient=Object.getOwnPropertyDescriptor(Object.prototype,"clientX");let inheritedReads=0,defaultsCorrect=true;Object.defineProperty(Object.prototype,"clientX",{get(){inheritedReads++;return 7.75},configurable:true});
 try{for(const construct of [()=>new MouseEvent("missing"),()=>new MouseEvent("undefined",undefined),()=>new MouseEvent("null",null)])if(construct().clientX!==0)defaultsCorrect=false;if(inheritedReads!==0)defaultsCorrect=false;const explicit=new MouseEvent("explicit",{});if(explicit.clientX!==7||inheritedReads!==1)defaultsCorrect=false}finally{if(originalClient)Object.defineProperty(Object.prototype,"clientX",originalClient);else delete Object.prototype.clientX}
 if(!defaultsCorrect)return false;
 const ownWindow=new MouseEvent("owner-target",{view:globalThis,relatedTarget:globalThis});if(ownWindow.view!==globalThis||ownWindow.relatedTarget!==globalThis)return false;
 for(const init of [undefined,null,{}]){const value=new MouseEvent("defaults",init);if(value.view!==null||value.detail!==0||value.clientX!==0||value.relatedTarget!==null)return false}
 for(const relatedTarget of [null,undefined])if(new MouseEvent("null",{relatedTarget}).relatedTarget!==null)return false;
 for(const init of [true,1,"dictionary",Symbol("dictionary")]){let rejected=false;try{new MouseEvent("bad",init)}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 const marker={};let typeSame=false,memberSame=false,numberSame=false,later=0,traps=0;
 try{new MouseEvent({toString(){throw marker}},{get bubbles(){later++;return true}})}catch(error){typeSame=error===marker}
 try{new MouseEvent("member",{get modifierAltGraph(){throw marker},get button(){later++;return 0}})}catch(error){memberSame=error===marker}
 try{new MouseEvent("number",{clientX:{valueOf(){throw marker}},get clientY(){later++;return 0}})}catch(error){numberSame=error===marker}
 const proxy=new Proxy(target,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});
 for(const relatedTarget of [{},Object.create(EventTarget.prototype),proxy]){let rejected=false;try{new MouseEvent("brand",{relatedTarget,get screenX(){later++;return 0}})}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 const viewProxy=new Proxy(globalThis,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});
 for(const view of [{},viewProxy]){let rejected=false;try{new MouseEvent("view",{view,get altKey(){later++;return false}})}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 return typeSame&&memberSame&&numberSame&&later===0&&traps===0;
})()')! == 'true'
	event := runtime.native_event(runtime.evaluate_host_value('orderedNativeMouse')!)!
	mouse := unsafe { &dom.MouseEvent(event) }
	assert mouse.screen_x_ == 8.875 && mouse.screen_y_ == -7.125
	assert mouse.client_x_ == -3.75 && mouse.client_y_ == 4.625
	assert mouse.page_x_ == -3.75 && mouse.offset_y_ == 4.625
	assert mouse.related_target() or { panic('missing actual MouseEvent related target') } == related
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_mouse_event_brands_and_live_mouse_family_wrappers_use_concrete_pointer_coordinates() {
	$if !darwin { return }
	mut runtime, settings := mouse_native_event_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof MouseEvent==="function"')! == 'true'
	keyboard := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{})
	mouse_native_export(mut runtime, '__mouseWrongKeyboard',
		runtime.javascript_event(unsafe { &dom.Event(keyboard) })!)!
	assert runtime.evaluate_host(r'(()=>{
 const p=MouseEvent.prototype,event=new MouseEvent("brand"),fields=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY","ctrlKey","shiftKey","altKey","metaKey","movementX","movementY","button","buttons","relatedTarget"],marker={};let traps=0,coercions=0;
 const argument={[Symbol.toPrimitive](){coercions++;throw marker}},proxy=new Proxy(event,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});
 for(const receiver of [Object.create(p),new Event("base"),new UIEvent("ui"),__mouseWrongKeyboard(),proxy,{},null,undefined,1]){
  for(const field of fields){let rejected=false;try{Object.getOwnPropertyDescriptor(p,field).get.call(receiver)}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
  for(const operation of [()=>p.getModifierState.call(receiver,argument),()=>p.initMouseEvent.call(receiver,argument,false,false,null,argument)]){let rejected=false;try{operation()}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 }
 let original=false,keyCalls=0;try{event.getModifierState({toString(){throw marker}})}catch(error){original=error===marker}
 let symbolRejected=false;try{event.getModifierState(Symbol("key"))}catch(error){symbolRejected=error instanceof TypeError}return traps===0&&coercions===0&&original&&symbolRejected&&event.getModifierState(undefined)===false&&event.getModifierState({toString(){keyCalls++;return "unknown"}})===false&&keyCalls===1;
})()')! == 'true'
	first_target := dom.EventTarget.new()
	second_target := dom.EventTarget.new()
	mouse_native_export(mut runtime, '__mouseLiveFirstTarget', runtime.javascript_event_target(first_target,
		none)!)!
	mouse_native_export(mut runtime, '__mouseLiveSecondTarget', runtime.javascript_event_target(second_target,
		none)!)!
	init := dom.MouseEventInit{
		EventModifierInit: dom.EventModifierInit{
			UIEventInit:          dom.UIEventInit{
				detail: 7
				view:   voidptr(mouse_native_owner_window(settings).window().dom_proxy())
			}
			ctrl_key:             true
			shift_key:            true
			meta_key:             true
			modifier_alt_graph:   true
			modifier_caps_lock:   true
			modifier_fn_lock:     true
			modifier_num_lock:    true
			modifier_super:       true
			modifier_symbol_lock: true
		}
		screen_x:          10.25
		screen_y:          -11.75
		page_x:            20.375
		page_y:            -21.625
		client_x:          30.5
		client_y:          -31.5
		offset_x:          40.125
		offset_y:          -41.875
		movement_x:        1.25
		movement_y:        -2.75
		button:            2
		buttons:           5
		related_target:    first_target
	}
	mut mouse := dom.MouseEvent.create('mousemove', init)
	mut pointer :=
		dom.PointerEvent.create('pointermove', dom.PointerEventInit{ MouseEventInit: init })
	wheel := dom.WheelEvent.create('wheel', dom.WheelEventInit{ MouseEventInit: init })
	drag := html.DragEvent.create('drag', html.DragEventInit{ MouseEventInit: init }, init.page_x,
		init.page_y, init.offset_x, init.offset_y)
	events := [unsafe { &dom.Event(mouse) }, unsafe { &dom.Event(pointer) }, unsafe { &dom.Event(wheel) },
		unsafe { &dom.Event(drag) }]
	runtime.evaluate_host('globalThis.retainedMouse=MouseEvent;globalThis.retainedMousePrototype=MouseEvent.prototype;globalThis.retainedMouseUI=UIEvent;delete globalThis.MouseEvent;globalThis.MouseEvent=function ReplacementMouseEvent(){};globalThis.nativeMouseFamilies=[];0')!
	for index, event in events {
		wrapper := runtime.javascript_event(event)!
		assert runtime.native_event(wrapper)! == event
		assert runtime.javascript_event(event)! == wrapper
		mouse_native_export(mut runtime, '__mouseFamily' + index.str(), wrapper)!
		runtime.evaluate_host('nativeMouseFamilies.push(__mouseFamily' + index.str() + '());0')!
	}
	assert runtime.evaluate_host(r'(()=>{
 const coordinates=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY"],values=[10.25,-11.75,20.375,-21.625,30.5,-31.5,30.5,-31.5,40.125,-41.875];
 const keys=["Control","Shift","Alt","Meta","AltGraph","CapsLock","Fn","FnLock","Hyper","NumLock","ScrollLock","Super","Symbol","SymbolLock"],states=[true,true,false,true,true,true,false,true,false,true,false,true,false,true];
 return nativeMouseFamilies.length===4&&nativeMouseFamilies.every((event,family)=>event instanceof retainedMouse&&event instanceof retainedMouseUI&&event instanceof Event&&!(event instanceof MouseEvent)&&Object.getPrototypeOf(event)===(family===1?PointerEvent.prototype:family===2?WheelEvent.prototype:retainedMousePrototype)&&(event instanceof PointerEvent)===(family===1)&&(event instanceof WheelEvent)===(family===2)&&Object.prototype.toString.call(event)===(family===1?"[object PointerEvent]":family===2?"[object WheelEvent]":"[object MouseEvent]")&&event.isTrusted&&event.view===globalThis&&event.detail===7&&coordinates.every((name,index)=>event[name]===values[index])&&event.movementX===1.25&&event.movementY===-2.75&&event.button===2&&event.buttons===5&&event.which===3&&event.ctrlKey&&event.shiftKey&&!event.altKey&&event.metaKey&&event.relatedTarget===__mouseLiveFirstTarget()&&keys.every((key,index)=>event.getModifierState(key)===states[index])&&!event.getModifierState("control")&&!event.getModifierState("Control\u0000"));
})()')! == 'true'
	for event in events {
		mut actual := unsafe { &dom.Event(event) }
		actual.set_is_trusted(false)
	}
	assert runtime.evaluate_host(r'(()=>{
 const coordinates=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY"],values=[10.25,-11.75,20.375,-21.625,30.5,-31.5,30.5,-31.5,40.125,-41.875];
 return nativeMouseFamilies.every((event,family)=>!event.isTrusted&&coordinates.every((name,index)=>event[name]===(family===1?values[index]:Math.floor(values[index])))&&event.movementX===1.25&&event.movementY===-2.75);
})()')! == 'true'
	for name in ['click', 'auxclick', 'contextmenu'] {
		pointer.set_type(name)
		assert runtime.evaluate_host(r'(()=>{
 const event=nativeMouseFamilies[1],coordinates=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY"],values=[10.25,-11.75,20.375,-21.625,30.5,-31.5,30.5,-31.5,40.125,-41.875];
 return coordinates.every((name,index)=>event[name]===Math.floor(values[index]));
})()')! == 'true'
	}
	pointer.set_is_trusted(true)
	assert runtime.evaluate_host('nativeMouseFamilies[1].screenX===10.25&&nativeMouseFamilies[1].pageY===-21.625&&nativeMouseFamilies[1].clientX===30.5&&nativeMouseFamilies[1].x===30.5&&nativeMouseFamilies[1].offsetY===-41.875')! == 'true'
	mouse.set_is_trusted(true)
	mouse.screen_x_ = 99.625
	mouse.movement_y_ = 8.5
	mouse.button_ = -1
	mouse.buttons_ = 2
	mouse.ctrl_key_ = false
	mut mouse_base := unsafe { &dom.Event(mouse) }
	mouse_base.set_related_target(second_target)
	assert runtime.evaluate_host('nativeMouseFamilies[0].screenX===99.625&&nativeMouseFamilies[0].movementY===8.5&&nativeMouseFamilies[0].button===-1&&nativeMouseFamilies[0].buttons===2&&nativeMouseFamilies[0].which===0&&!nativeMouseFamilies[0].ctrlKey&&!nativeMouseFamilies[0].getModifierState("Control")&&nativeMouseFamilies[0].relatedTarget===__mouseLiveSecondTarget()')! == 'true'
	mouse_base.set_related_target(none)
	assert runtime.evaluate_host('nativeMouseFamilies[0].relatedTarget===null')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_mouse_event_legacy_init_converts_atomically_during_dispatch_and_resets_only_source_slots() {
	$if !darwin { return }
	mut runtime, settings := mouse_native_event_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof MouseEvent==="function"')! == 'true'
	target := dom.EventTarget.new()
	related := dom.EventTarget.new()
	mouse_native_export(mut runtime, '__mouseLegacyTarget', runtime.javascript_event_target(target,
		none)!)!
	mouse_native_export(mut runtime, '__mouseLegacyRelated', runtime.javascript_event_target(related,
		none)!)!
	mut mouse := dom.MouseEvent.create('original', dom.MouseEventInit{
		EventModifierInit: dom.EventModifierInit{
			UIEventInit:        dom.UIEventInit{
				EventInit: dom.EventInit{
					bubbles:    true
					cancelable: true
					composed:   true
				}
				detail:    4
				view:      voidptr(mouse_native_owner_window(settings).window().dom_proxy())
			}
			modifier_caps_lock: true
		}
		screen_x:          8.5
		screen_y:          -9.5
		client_x:          3.75
		client_y:          -4.5
		page_x:            13.75
		page_y:            -14.5
		offset_x:          23.75
		offset_y:          -24.5
		movement_x:        1.25
		movement_y:        -2.75
		button:            2
		buttons:           9
		related_target:    related
	})
	mut base := unsafe { &dom.Event(mouse) }
	base.set_target(target)
	wrapper := runtime.javascript_event(base)!
	mouse_native_export(mut runtime, '__mouseLegacyEvent', wrapper)!
	stamp := mouse.time_stamp()
	assert runtime.evaluate_host(r'(()=>{
 globalThis.legacyMouse=__mouseLegacyEvent();const event=legacyMouse,marker={};globalThis.mouseLegacySnapshot=()=>JSON.stringify([event.type,event.view===globalThis,event.detail,event.screenX,event.screenY,event.clientX,event.clientY,event.pageX,event.pageY,event.offsetX,event.offsetY,event.movementX,event.movementY,event.button,event.buttons,event.relatedTarget===__mouseLegacyRelated(),event.ctrlKey,event.altKey,event.shiftKey,event.metaKey,event.getModifierState("CapsLock"),event.bubbles,event.cancelable,event.composed,event.isTrusted,event.defaultPrevented,event.cancelBubble,event.target===__mouseLegacyTarget(),event.timeStamp]);
 event.preventDefault();event.stopImmediatePropagation();const before=mouseLegacySnapshot();let typeSame=false,numberSame=false,invalidView=false,invalidRelated=false,traps=0;
 try{event.initMouseEvent({toString(){throw marker}})}catch(error){typeSame=error===marker}
 try{event.initMouseEvent("partial",false,false,null,{valueOf(){throw marker}})}catch(error){numberSame=error===marker}
 try{event.initMouseEvent("partial",false,false,{},7)}catch(error){invalidView=error instanceof TypeError}
 const proxy=new Proxy(__mouseLegacyRelated(),{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});
 try{event.initMouseEvent("partial",false,false,null,1,2,3,4,5,false,false,false,false,6,proxy)}catch(error){invalidRelated=error instanceof TypeError}
 if(!typeSame||!numberSame||!invalidView||!invalidRelated||traps!==0||mouseLegacySnapshot()!==before)return false;
 const order=[],number=(name,value)=>({[Symbol.toPrimitive](hint){order.push(name+":"+hint);return value}});
 event.initMouseEvent({[Symbol.toPrimitive](hint){order.push("type:"+hint);return "legacy"}},true,true,globalThis,number("detail",2147483649.8),number("screenX",4294967301.9),number("screenY",-1.9),number("clientX",NaN),number("clientY",Infinity),true,false,true,false,number("button",65537.8),__mouseLegacyRelated());
 return order.join(",")==="type:string,detail:number,screenX:number,screenY:number,clientX:number,clientY:number,button:number"&&event.type==="legacy"&&event.detail===-2147483647&&event.screenX===5&&event.screenY===-1&&event.clientX===0&&event.clientY===0&&event.button===1&&event.which===2&&event.ctrlKey&&!event.altKey&&event.shiftKey&&!event.metaKey&&event.view===globalThis&&event.relatedTarget===__mouseLegacyRelated()&&!event.isTrusted&&!event.defaultPrevented&&!event.cancelBubble&&event.target===null&&event.bubbles&&event.cancelable&&event.composed&&event.pageX===13&&event.pageY===-15&&event.offsetX===23&&event.offsetY===-25&&event.movementX===1.25&&event.movementY===-2.75&&event.buttons===9&&event.getModifierState("CapsLock");
})()')! == 'true'
	assert mouse.time_stamp() == stamp && mouse.page_x_ == 13.75 && mouse.offset_y_ == -24.5
	base.set_is_trusted(true)
	assert runtime.evaluate_host(r'globalThis.mouseDispatchConversions=[];globalThis.mouseDispatchChecks=[];
 __mouseLegacyTarget().addEventListener("legacy",function(event){
  const before=mouseLegacySnapshot(),number=(name)=>({valueOf(){mouseDispatchConversions.push(name);return 99}});
  mouseDispatchChecks.push(this===__mouseLegacyTarget()&&event===legacyMouse&&event.isTrusted&&event.target===this&&event.currentTarget===this);
  event.initMouseEvent({toString(){mouseDispatchConversions.push("type");return "ignored"}},false,false,null,number("detail"),number("screenX"),number("screenY"),number("clientX"),number("clientY"),false,false,false,false,number("button"),null);
  mouseDispatchChecks.push(mouseLegacySnapshot()===before);
  let rejected=false;try{event.initMouseEvent("bad",false,false,null,0,Symbol("long"))}catch(error){rejected=error instanceof TypeError}
  mouseDispatchChecks.push(rejected&&mouseLegacySnapshot()===before);
  event.preventDefault();event.stopImmediatePropagation();
 });0')! == '0'
	assert !target.dispatch_event(base)
	assert mouse.is_trusted() && mouse.type_name() == 'legacy' && mouse.detail() == -2147483647
	assert runtime.evaluate_host('mouseDispatchConversions.join(",")==="type,detail,screenX,screenY,clientX,clientY,button"&&mouseDispatchChecks.length===3&&mouseDispatchChecks.every(Boolean)&&legacyMouse.defaultPrevented&&!legacyMouse.cancelBubble&&legacyMouse.currentTarget===null&&legacyMouse.target===__mouseLegacyTarget()')! == 'true'
	assert runtime.evaluate_host('legacyMouse.stopImmediatePropagation();legacyMouse.cancelBubble')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const event=legacyMouse;event.initMouseEvent("reset");
 return event.type==="reset"&&!event.isTrusted&&!event.defaultPrevented&&!event.cancelBubble&&event.target===null&&event.currentTarget===null&&!event.bubbles&&!event.cancelable&&event.composed&&event.view===null&&event.detail===0&&event.screenX===0&&event.screenY===0&&event.clientX===0&&event.clientY===0&&event.x===0&&event.y===0&&!event.ctrlKey&&!event.altKey&&!event.shiftKey&&!event.metaKey&&event.button===0&&event.which===1&&event.relatedTarget===null&&event.pageX===13&&event.pageY===-15&&event.offsetX===23&&event.offsetY===-25&&event.movementX===1.25&&event.movementY===-2.75&&event.buttons===9&&event.getModifierState("CapsLock");
})()')! == 'true'
	assert mouse.time_stamp() == stamp && mouse.related_target() == none
	assert mouse.page_x_ == 13.75 && mouse.offset_y_ == -24.5 && mouse.buttons() == 9
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
