module browserjs

import dom
import html
import highresolutiontime
import math

fn wheel_native_settings(url string) &html.EnvironmentSettingsObject {
	document := html.parse_document_with_url('<!doctype html><body>Wheel events</body>', dom.URL{
		value: url
	})
	mut owner_document := unsafe { &dom.Document(document) }
	owner_document.load_timing_info.navigation_start_time =
		highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'native-wheel-events') or { panic(err) }
	return unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
}

fn wheel_native_event_fixture(url string) (&Runtime, &html.EnvironmentSettingsObject) {
	settings := wheel_native_settings(url)
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn wheel_native_owner_window(settings &html.EnvironmentSettingsObject) &html.WindowModel {
	for window in html.all_windows() {
		if voidptr(window) == voidptr(settings.global_object()) {
			return window
		}
	}
	panic('missing actual WheelEvent owner Window')
}

fn wheel_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn test_native_wheel_event_metadata_constants_defaults_subclasses_and_window_exposure() {
	$if !darwin { return }
	mut runtime, settings := wheel_native_event_fixture('https://native-wheel-events.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof WheelEvent==="function"')! == 'true'
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof WheelEvent==="undefined"')! == 'true'
	unbound.evaluate_host('globalThis.retainedWheelGlobal=globalThis;globalThis.retainedWheelEvent=Event;Event=function ReplacementEvent(){};MouseEvent=function ReplacementMouseEvent(){};globalThis={};0')!
	late_settings := wheel_native_settings('http://late-wheel-events.example/')
	unbound.bind_scripting_environment(late_settings)!
	unbound.install_event_target_binding()!
	assert !late_settings.is_secure_context()
	assert unbound.evaluate_host('typeof WheelEvent==="function"&&Object.getPrototypeOf(WheelEvent)===MouseEvent&&Object.getPrototypeOf(WheelEvent.prototype)===MouseEvent.prototype&&Object.getPrototypeOf(UIEvent)===retainedWheelEvent&&globalThis.WheelEvent===undefined&&new WheelEvent("late",{view:retainedWheelGlobal}).view===retainedWheelGlobal')! == 'true'
	constructor := runtime.evaluate_host_value('WheelEvent')!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host_value('WheelEvent')! == constructor
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},C=WheelEvent,p=C.prototype,global=Object.getOwnPropertyDescriptor(globalThis,"WheelEvent"),constructor=Object.getOwnPropertyDescriptor(p,"constructor"),fields=["deltaX","deltaY","deltaZ","deltaMode","wheelDeltaX","wheelDeltaY","wheelDelta"];
 check(C.name==="WheelEvent"&&C.length===1&&Object.getPrototypeOf(C)===MouseEvent&&Object.getPrototypeOf(p)===MouseEvent.prototype&&global.writable&&global.configurable&&!global.enumerable&&!Object.getOwnPropertyDescriptor(C,"prototype").writable&&constructor.value===C&&constructor.writable&&constructor.configurable&&!constructor.enumerable,"Wheel metadata");
 for(const name of fields){const d=Object.getOwnPropertyDescriptor(p,name);check(d&&d.set===undefined&&d.enumerable&&d.configurable&&d.get.name==="get "+name&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]"),"getter "+name);let rejected=false;try{Reflect.construct(function Empty(){},[],d.get)}catch(error){rejected=error instanceof TypeError}check(rejected,"native nonconstructor "+name)}
 for(const [name,value] of [["DOM_DELTA_PIXEL",0],["DOM_DELTA_LINE",1],["DOM_DELTA_PAGE",2]])for(const holder of [C,p]){const d=Object.getOwnPropertyDescriptor(holder,name);check(d&&d.value===value&&d.enumerable&&!d.writable&&!d.configurable,"constant "+name);check(!Reflect.set(holder,name,99)&&!Reflect.deleteProperty(holder,name)&&holder[name]===value,"immutable constant "+name)}
 const tag=Object.getOwnPropertyDescriptor(p,Symbol.toStringTag);check(tag.value==="WheelEvent"&&tag.configurable&&!tag.writable&&!tag.enumerable,"Wheel tag");
 const value=new C("λ\u0000wheel"),extra={get ignored(){throw new Error("extra argument read")}};class Child extends C{}const child=new Child("child",undefined,extra);
 check(value instanceof C&&value instanceof MouseEvent&&value instanceof UIEvent&&value instanceof Event&&!(value instanceof PointerEvent)&&Object.prototype.toString.call(value)==="[object WheelEvent]"&&fields.every(name=>value[name]===0)&&value.type==="λ\u0000wheel"&&!value.isTrusted&&!value.bubbles&&!value.cancelable&&!value.composed&&value.view===null&&value.detail===0&&value.which===1&&value.clientX===0&&value.relatedTarget===null&&value.timeStamp>=0&&value.timeStamp<10000&&!Object.hasOwn(value,"deltaX")&&Object.getOwnPropertyDescriptor(value,"isTrusted").configurable===false&&child instanceof Child&&child instanceof C&&Object.getPrototypeOf(child)===Child.prototype&&child.DOM_DELTA_PAGE===2,"Wheel defaults and subclass");
 let errors=0;for(const operation of [()=>C("call"),()=>new C(),()=>new C(Symbol("type"))])try{operation()}catch(error){if(error instanceof TypeError)errors++}check(errors===3&&new C(undefined).type==="undefined","constructor arity");
 const Alternative=function Alternative(){};for(const prototype of [null,1]){Alternative.prototype=prototype;check(Object.getPrototypeOf(Reflect.construct(C,["fallback"],Alternative))===p,"prototype fallback")}
 let reads=0,coercions=0;const custom=Object.create(p),next=new Proxy(function Next(){},{get(target,name,receiver){if(name==="prototype"){reads++;return custom}return Reflect.get(target,name,receiver)}}),made=Reflect.construct(C,["custom",{deltaX:3.25}],next);check(reads===1&&Object.getPrototypeOf(made)===custom&&made.type==="custom"&&made.deltaX===3.25,"newTarget prototype");
 const marker={},throwing=new Proxy(function Throwing(){},{get(target,name,receiver){if(name==="prototype"){reads++;throw marker}return Reflect.get(target,name,receiver)}});for(const args of [[{toString(){coercions++;return "ignored"}},new Proxy({},{get(){coercions++;return 0}})],[]]){let same=false;try{Reflect.construct(C,args,throwing)}catch(error){same=error===marker}check(same,"prototype before conversion and arity")}check(reads===3&&coercions===0,"single prototype Get");return true;
})()')! == 'true'
	actual :=
		runtime.native_event(runtime.evaluate_host_value('new WheelEvent("owner",{view:globalThis,detail:9,deltaX:1.25,deltaMode:2})')!)!
	assert actual.interface_ == .wheel_event && !actual.is_trusted()
	wheel := unsafe { &dom.WheelEvent(actual) }
	assert wheel.detail() == 9 && wheel.delta_x() == 1.25 && wheel.delta_mode() == 2
	assert wheel.view() == voidptr(wheel_native_owner_window(settings).window().dom_proxy())
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_wheel_event_dictionary_order_conversion_and_original_author_exceptions() {
	$if !darwin { return }
	mut runtime, settings := wheel_native_event_fixture('https://wheel-dictionary.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof WheelEvent==="function"')! == 'true'
	related := dom.EventTarget.new()
	wheel_native_export(mut runtime, '__wheelDictionaryTarget', runtime.javascript_event_target(related,
		none)!)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},target=__wheelDictionaryTarget(),members=["bubbles","cancelable","composed","detail","view","altKey","ctrlKey","metaKey","modifierAltGraph","modifierCapsLock","modifierFn","modifierFnLock","modifierHyper","modifierNumLock","modifierScrollLock","modifierSuper","modifierSymbol","modifierSymbolLock","shiftKey","button","buttons","clientX","clientY","movementX","movementY","relatedTarget","screenX","screenY","deltaMode","deltaX","deltaY","deltaZ","wheelDeltaX","wheelDeltaY"],order=[];
 const numbers={detail:2147483649.8,button:65537.8,buttons:65539.8,clientX:-3.75,clientY:4.625,movementX:1.25,movementY:-2.5,screenX:8.875,screenY:-7.125,deltaMode:4294967301.9,deltaX:7.25,deltaY:-8.75,deltaZ:9.125,wheelDeltaX:2147483648.9,wheelDeltaY:-4294967387.9},values={view:globalThis,relatedTarget:target};let booleanHooks=0;
 for(const name of members)if(!(name in values))values[name]=name in numbers?{[Symbol.toPrimitive](hint){order.push(name+":"+hint);return numbers[name]}}:true;values.ctrlKey={valueOf(){booleanHooks++;throw 0},toString(){booleanHooks++;throw 0}};
 const event=new WheelEvent({[Symbol.toPrimitive](hint){order.push("type:"+hint);return "ordered"}},new Proxy(values,{get(target,name){order.push(name);return Reflect.get(target,name)}})),expected=["type:string"];
 for(const name of members){expected.push(name);if(name in numbers)expected.push(name+":number")}check(order.join(",")===expected.join(",")&&booleanHooks===0,"34 dictionary conversions");
 check(event.type==="ordered"&&event.detail===-2147483647&&event.button===1&&event.buttons===3&&event.which===2&&event.view===globalThis&&event.relatedTarget===target&&event.clientX===-4&&event.pageY===4&&event.offsetX===-4&&event.x===-4&&event.screenY===-8&&event.movementY===-2.5&&event.deltaMode===5&&event.deltaX===7.25&&event.deltaY===-8.75&&event.deltaZ===9.125&&event.wheelDeltaX===-2147483648&&event.wheelDeltaY===-91&&event.wheelDelta===-91&&event.ctrlKey&&event.getModifierState("SymbolLock"),"converted Wheel and inherited Mouse values");globalThis.orderedNativeWheel=event;
 const ownWindow=new WheelEvent("owner-target",{view:globalThis,relatedTarget:globalThis});check(ownWindow.view===globalThis&&ownWindow.relatedTarget===globalThis,"owner Window identity");
 const savedDelta=Object.getOwnPropertyDescriptor(Object.prototype,"deltaX"),savedClient=Object.getOwnPropertyDescriptor(Object.prototype,"clientX");let inherited=0,correct=true;Object.defineProperty(Object.prototype,"deltaX",{get(){inherited++;return 7.5},configurable:true});Object.defineProperty(Object.prototype,"clientX",{get(){inherited++;return 8.5},configurable:true});try{for(const construct of [()=>new WheelEvent("missing"),()=>new WheelEvent("undefined",undefined),()=>new WheelEvent("null",null)]){const value=construct();if(value.deltaX!==0||value.clientX!==0)correct=false}if(inherited!==0)correct=false;const explicit=new WheelEvent("explicit",{});if(explicit.deltaX!==7.5||explicit.clientX!==8||inherited!==2)correct=false}finally{if(savedDelta)Object.defineProperty(Object.prototype,"deltaX",savedDelta);else delete Object.prototype.deltaX;if(savedClient)Object.defineProperty(Object.prototype,"clientX",savedClient);else delete Object.prototype.clientX}check(correct,"nullish dictionaries bypass inherited members");
 for(const dictionary of [1,true,"dictionary",Symbol("dictionary")]){let rejected=false;try{new WheelEvent("dictionary",dictionary)}catch(error){rejected=error instanceof TypeError}check(rejected,"dictionary object required")}
 const marker={};let typeSame=false,inheritedSame=false,getSame=false,numberSame=false,later=0,traps=0;try{new WheelEvent({toString(){throw marker}},{get bubbles(){later++;return false}})}catch(error){typeSame=error===marker}try{new WheelEvent("inherited",{get modifierAltGraph(){throw marker},get deltaMode(){later++;return 0}})}catch(error){inheritedSame=error===marker}try{new WheelEvent("get",{get deltaMode(){throw marker},get deltaX(){later++;return 0}})}catch(error){getSame=error===marker}try{new WheelEvent("number",{deltaX:{valueOf(){throw marker}},get deltaY(){later++;return 0}})}catch(error){numberSame=error===marker}
 const targetProxy=new Proxy(target,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});for(const relatedTarget of [{},Object.create(EventTarget.prototype),targetProxy]){let rejected=false;try{new WheelEvent("related-brand",{relatedTarget,get deltaMode(){later++;return 0}})}catch(error){rejected=error instanceof TypeError}check(rejected,"related target brand before Wheel fields")}
 const viewProxy=new Proxy(globalThis,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});for(const view of [{},viewProxy]){let rejected=false;try{new WheelEvent("view-brand",{view,get deltaMode(){later++;return 0}})}catch(error){rejected=error instanceof TypeError}check(rejected,"view brand before Wheel fields")}
 check(typeSame&&inheritedSame&&getSame&&numberSame&&later===0&&traps===0,"original conversion exceptions and no later Gets");return true;
})()')! == 'true'
	actual := runtime.native_event(runtime.evaluate_host_value('orderedNativeWheel')!)!
	assert actual.interface_ == .wheel_event && !actual.is_trusted()
	wheel := unsafe { &dom.WheelEvent(actual) }
	assert wheel.delta_x() == 7.25 && wheel.delta_y() == -8.75 && wheel.delta_z() == 9.125
	assert wheel.delta_mode() == 5 && wheel.wheel_delta_x() == -2147483647 - 1
	assert wheel.wheel_delta_y() == -91 && wheel.wheel_delta() == -91
	assert wheel.client_x_ == -3.75 && wheel.page_y_ == 4.625 && wheel.offset_x_ == -3.75
	assert wheel.related_target() or { panic('missing actual WheelEvent related target') } == related
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_wheel_event_numeric_edges_legacy_fallback_and_readonly_slots() {
	$if !darwin { return }
	mut runtime, settings := wheel_native_event_fixture('https://wheel-numeric.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof WheelEvent==="function"')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)};
 for(const field of ["deltaX","deltaY","deltaZ"])for(const value of [NaN,Infinity,-Infinity,1n,Symbol("double")]){let rejected=false;try{new WheelEvent("restricted",{[field]:value})}catch(error){rejected=error instanceof TypeError}check(rejected,"restricted double "+field)}
 for(const field of ["deltaMode","wheelDeltaX","wheelDeltaY"])for(const value of [1n,Symbol("long")]){let rejected=false;try{new WheelEvent("integer",{[field]:value})}catch(error){rejected=error instanceof TypeError}check(rejected,"integer ToNumber "+field)}
 for(const [input,unsigned,signed] of [[4294967301.9,5,5],[-4294967301.9,4294967291,-5],[2147483648.9,2147483648,-2147483648],[-1.9,4294967295,-1],[NaN,0,0],[Infinity,0,0],[-Infinity,0,0]]){const value=new WheelEvent("wrap",{deltaMode:input,wheelDeltaX:input,wheelDeltaY:input});check(value.deltaMode===unsigned&&value.wheelDeltaX===signed&&value.wheelDeltaY===signed&&value.wheelDelta===signed,"32-bit wrapping "+String(input))}
 const nulls=new WheelEvent("nulls",{deltaX:null,deltaY:null,deltaZ:null,deltaMode:null,wheelDeltaX:null,wheelDeltaY:null}),zeros=new WheelEvent("signed-zero",{deltaX:-0,deltaY:-0,deltaZ:-0});check(nulls.deltaX===0&&nulls.deltaMode===0&&nulls.wheelDelta===0&&Object.is(zeros.deltaX,-0)&&Object.is(zeros.deltaY,-0)&&Object.is(zeros.deltaZ,-0),"null conversion and signed double zero");
 // WheelEvent.cpp uses AK::clamp_to<Long>, which rounds floating-point values to nearest even.
 for(const [delta,legacy] of [[0.25,0],[1.5,-2],[2.5,-2],[3.5,-4],[-1.5,2],[-2.5,2],[-3.6,4],[1e30,-2147483648],[-1e30,2147483647]]){const implicit=new WheelEvent("implicit",{deltaX:delta}),explicitZero=new WheelEvent("explicit-zero",{deltaX:delta,wheelDeltaX:0}),wrappedZero=new WheelEvent("wrapped-zero",{deltaX:delta,wheelDeltaX:4294967296});check(implicit.deltaX===delta&&implicit.wheelDeltaX===legacy&&implicit.wheelDelta===legacy&&explicitZero.wheelDeltaX===legacy&&wrappedZero.wheelDeltaX===legacy,"clamped derived legacy delta "+delta)}
 const override=new WheelEvent("override",{deltaX:1e30,deltaY:-1e30,wheelDeltaX:17.9,wheelDeltaY:-23.9}),horizontal=new WheelEvent("horizontal",{wheelDeltaX:17,wheelDeltaY:0}),vertical=new WheelEvent("vertical",{wheelDeltaX:17,wheelDeltaY:-23});check(override.wheelDeltaX===17&&override.wheelDeltaY===-23&&override.wheelDelta===-23&&horizontal.wheelDelta===17&&vertical.wheelDelta===-23,"nonzero explicit override and Y preference");
 const readonly=new WheelEvent("readonly",{deltaX:1.25,deltaY:-2.75,deltaZ:3.5,deltaMode:4294967295,wheelDeltaX:7,wheelDeltaY:8});for(const field of ["deltaX","deltaY","deltaZ","deltaMode","wheelDeltaX","wheelDeltaY","wheelDelta"]){const before=readonly[field];check(!Reflect.set(readonly,field,99)&&readonly[field]===before&&!Object.hasOwn(readonly,field),"readonly "+field)}check(readonly.deltaMode===4294967295,"deltaMode is unrestricted unsigned long");return true;
})()')! == 'true'
	// Restricted doubles apply during dictionary conversion. Native record
	// getters still expose their retained values without another conversion.
	native := dom.WheelEvent.create('native-nonfinite', dom.WheelEventInit{
		delta_x: math.inf(1)
		delta_y: math.inf(-1)
		delta_z: math.nan()
	})
	wheel_native_export(mut runtime, '__wheelNativeNonfinite',
		runtime.javascript_event(unsafe { &dom.Event(native) })!)!
	assert native.wheel_delta_x() == -2147483647 - 1
	assert native.wheel_delta_y() == 2147483647
	assert runtime.evaluate_host('(()=>{const event=__wheelNativeNonfinite();return event instanceof WheelEvent&&event.deltaX===Infinity&&event.deltaY===-Infinity&&Number.isNaN(event.deltaZ)&&event.wheelDeltaX===-2147483648&&event.wheelDeltaY===2147483647&&event.wheelDelta===2147483647})()')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_wheel_event_getter_brands_reject_other_native_families_without_proxy_traps() {
	$if !darwin { return }
	mut runtime, settings := wheel_native_event_fixture('https://wheel-brands.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof WheelEvent==="function"')! == 'true'
	mouse := dom.MouseEvent.create('mousemove', dom.MouseEventInit{})
	pointer := dom.PointerEvent.create('pointermove', dom.PointerEventInit{})
	drag := html.DragEvent.create('drag', html.DragEventInit{}, 0, 0, 0, 0)
	keyboard := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{})
	events := [unsafe { &dom.Event(mouse) }, unsafe { &dom.Event(pointer) }, unsafe { &dom.Event(drag) },
		unsafe { &dom.Event(keyboard) }]
	runtime.evaluate_host('globalThis.wheelWrongNativeFamilies=[];0')!
	for index, event in events {
		wheel_native_export(mut runtime, '__wheelWrongFamily' + index.str(),
			runtime.javascript_event(event)!)!
		runtime.evaluate_host('wheelWrongNativeFamilies.push(__wheelWrongFamily' + index.str() +
			'());0')!
	}
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},p=WheelEvent.prototype,event=new WheelEvent("brand"),fields=["deltaX","deltaY","deltaZ","deltaMode","wheelDeltaX","wheelDeltaY","wheelDelta"],marker={};let traps=0,coercions=0;
 const proxy=new Proxy(event,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}}),argument={[Symbol.toPrimitive](){coercions++;throw marker}},receivers=[Object.create(p),new Event("base"),new UIEvent("ui"),new MouseEvent("mouse"),new PointerEvent("pointer"),...wheelWrongNativeFamilies,proxy,{},null,undefined,1];
 for(const receiver of receivers)for(const field of fields){let rejected=false;try{Object.getOwnPropertyDescriptor(p,field).get.call(receiver,argument)}catch(error){rejected=error instanceof TypeError}check(rejected,"Wheel getter brand "+field)}
 for(const field of fields)check(Object.getOwnPropertyDescriptor(p,field).get.call(event,argument)===0,"valid getter ignores arguments "+field);check(traps===0&&coercions===0,"no Proxy inspection or ignored argument coercion");return true;
})()')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_wheel_event_live_wrappers_and_inherited_initializers_preserve_wheel_slots() {
	$if !darwin { return }
	mut runtime, settings := wheel_native_event_fixture('https://wheel-live.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof WheelEvent==="function"')! == 'true'
	target := dom.EventTarget.new()
	related := dom.EventTarget.new()
	wheel_native_export(mut runtime, '__wheelLiveTarget', runtime.javascript_event_target(target,
		none)!)!
	wheel_native_export(mut runtime, '__wheelLiveRelated', runtime.javascript_event_target(related,
		none)!)!
	mouse_init := dom.MouseEventInit{
		EventModifierInit: dom.EventModifierInit{
			UIEventInit:        dom.UIEventInit{
				EventInit: dom.EventInit{
					bubbles:    true
					cancelable: true
					composed:   true
				}
				detail:    7
				view:      voidptr(wheel_native_owner_window(settings).window().dom_proxy())
			}
			ctrl_key:           true
			modifier_caps_lock: true
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
		related_target:    related
	}
	mut wheel := dom.WheelEvent.create('wheel', dom.WheelEventInit{
		MouseEventInit: mouse_init
		delta_x:        2.5
		delta_y:        -3.6
		delta_z:        0.25
		delta_mode:     dom.dom_delta_line
		wheel_delta_x:  120
	})
	mut base := unsafe { &dom.Event(wheel) }
	stamp := base.time_stamp()
	runtime.evaluate_host('globalThis.retainedNativeWheel=WheelEvent;globalThis.retainedNativeWheelPrototype=WheelEvent.prototype;delete globalThis.WheelEvent;globalThis.WheelEvent=function ReplacementWheelEvent(){};0')!
	wrapper := runtime.javascript_event(base)!
	assert runtime.native_event(wrapper)! == base && runtime.javascript_event(base)! == wrapper
	wheel_native_export(mut runtime, '__wheelLiveEvent', wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const event=__wheelLiveEvent(),check=(condition,label)=>{if(!condition)throw new Error(label)},coordinates=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY"],values=[10.25,-11.75,20.375,-21.625,30.5,-31.5,30.5,-31.5,40.125,-41.875];globalThis.nativeLiveWheel=event;globalThis.wheelLiveCoordinates=coordinates;globalThis.wheelLiveValues=values;
 check(event instanceof retainedNativeWheel&&!(event instanceof WheelEvent)&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&Object.getPrototypeOf(event)===retainedNativeWheelPrototype&&Object.prototype.toString.call(event)==="[object WheelEvent]"&&event.isTrusted&&event.view===globalThis&&event.detail===7&&event.which===3&&event.relatedTarget===__wheelLiveRelated()&&coordinates.every((name,index)=>event[name]===values[index]),"native Wheel prototype and coordinates");
 globalThis.wheelSlotSnapshot=()=>JSON.stringify([event.deltaX,event.deltaY,event.deltaZ,event.deltaMode,event.wheelDeltaX,event.wheelDeltaY,event.wheelDelta]);check(wheelSlotSnapshot()==="[2.5,-3.6,0.25,1,120,4,4]","native Wheel slots");return true;
})()')! == 'true'
	base.set_is_trusted(false)
	assert runtime.evaluate_host('wheelLiveCoordinates.every((name,index)=>nativeLiveWheel[name]===Math.floor(wheelLiveValues[index]))&&!nativeLiveWheel.isTrusted&&wheelSlotSnapshot()==="[2.5,-3.6,0.25,1,120,4,4]"')! == 'true'
	base.set_is_trusted(true)
	wheel.delta_x_ = 8.25
	wheel.delta_y_ = -9.5
	wheel.delta_z_ = 10.75
	wheel.delta_mode_ = u32(4294967295)
	wheel.wheel_delta_x_ = -17
	wheel.wheel_delta_y_ = 0
	base.set_related_target(target)
	assert runtime.evaluate_host('wheelLiveCoordinates.every((name,index)=>nativeLiveWheel[name]===wheelLiveValues[index])&&nativeLiveWheel.relatedTarget===__wheelLiveTarget()&&wheelSlotSnapshot()==="[8.25,-9.5,10.75,4294967295,-17,0,-17]"')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const event=nativeLiveWheel,check=(condition,label)=>{if(!condition)throw new Error(label)},slots=wheelSlotSnapshot(),stamp=event.timeStamp,marker={};event.preventDefault();event.stopImmediatePropagation();const before=JSON.stringify([event.type,event.clientX,event.defaultPrevented,event.cancelBubble,event.isTrusted]);let same=false;try{event.initMouseEvent("partial",false,false,null,{valueOf(){throw marker}})}catch(error){same=error===marker}check(same&&JSON.stringify([event.type,event.clientX,event.defaultPrevented,event.cancelBubble,event.isTrusted])===before,"inherited init atomic failure");
 event.initMouseEvent("wheel",true,true,globalThis,9,11,12,13,14,false,false,true,false,1,__wheelLiveRelated());check(event.type==="wheel"&&!event.isTrusted&&!event.defaultPrevented&&!event.cancelBubble&&event.detail===9&&event.screenX===11&&event.clientX===13&&event.which===2&&event.shiftKey&&!event.ctrlKey&&event.relatedTarget===__wheelLiveRelated()&&event.composed&&event.timeStamp===stamp&&wheelSlotSnapshot()===slots&&event.pageX===20&&event.pageY===-22&&event.offsetX===40&&event.offsetY===-42&&event.movementY===-2.75&&event.buttons===5&&event.getModifierState("CapsLock"),"legacy Mouse reset preserves Wheel slots");
 event.initUIEvent("wheel",true,true,globalThis,10);check(event.clientX===13&&event.pageX===20&&event.offsetY===-42&&event.detail===10&&wheelSlotSnapshot()===slots,"legacy UI reset preserves Wheel slots");globalThis.wheelDispatchChecks=[];globalThis.wheelDispatchConversions=[];
 __wheelLiveTarget().addEventListener("wheel",function(actual){const prior=JSON.stringify([actual.type,actual.detail,actual.clientX,actual.isTrusted,wheelSlotSnapshot()]);actual.initMouseEvent({toString(){wheelDispatchConversions.push("type");return "ignored"}},false,false,null,{valueOf(){wheelDispatchConversions.push("detail");return 100}},1,2,3,4,false,false,false,false,0,null);wheelDispatchChecks.push(actual===event&&this===__wheelLiveTarget()&&actual.currentTarget===this&&JSON.stringify([actual.type,actual.detail,actual.clientX,actual.isTrusted,wheelSlotSnapshot()])===prior);actual.preventDefault()});return true;
})()')! == 'true'
	base.set_is_trusted(true)
	assert !target.dispatch_event(base)
	assert runtime.evaluate_host('wheelDispatchChecks.length===1&&wheelDispatchChecks[0]&&wheelDispatchConversions.join(",")==="type,detail"&&nativeLiveWheel.type==="wheel"&&nativeLiveWheel.isTrusted&&nativeLiveWheel.currentTarget===null&&nativeLiveWheel.defaultPrevented&&wheelSlotSnapshot()==="[8.25,-9.5,10.75,4294967295,-17,0,-17]"')! == 'true'
	assert base.time_stamp() == stamp && wheel.delta_x() == 8.25 && wheel.wheel_delta() == -17
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
