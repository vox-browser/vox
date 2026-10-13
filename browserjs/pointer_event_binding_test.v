module browserjs

import dom
import html
import highresolutiontime

fn pointer_native_settings(url string) &html.EnvironmentSettingsObject {
	document := html.parse_document_with_url('<!doctype html><body>Pointer events</body>', dom.URL{
		value: url
	})
	mut owner_document := unsafe { &dom.Document(document) }
	owner_document.load_timing_info.navigation_start_time =
		highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'native-pointer-events') or { panic(err) }
	return unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
}

fn pointer_native_event_fixture(url string) (&Runtime, &html.EnvironmentSettingsObject) {
	settings := pointer_native_settings(url)
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn pointer_native_owner_window(settings &html.EnvironmentSettingsObject) &html.WindowModel {
	for window in html.all_windows() {
		if voidptr(window) == voidptr(settings.global_object()) {
			return window
		}
	}
	panic('missing actual PointerEvent owner Window')
}

fn pointer_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn test_native_pointer_event_metadata_defaults_and_secure_window_exposure() {
	$if !darwin { return }
	mut runtime, settings := pointer_native_event_fixture('https://native-pointer-events.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof PointerEvent==="function"')! == 'true'
	assert settings.is_secure_context()
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof PointerEvent==="undefined"')! == 'true'
	unbound.evaluate_host('globalThis.retainedPointerGlobal=globalThis;globalThis.retainedPointerEvent=Event;Event=function ReplacementEvent(){};MouseEvent=function ReplacementMouseEvent(){};globalThis={};0')!
	late_settings := pointer_native_settings('https://late-pointer-events.example/')
	unbound.bind_scripting_environment(late_settings)!
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof PointerEvent==="function"&&Object.getPrototypeOf(PointerEvent)===MouseEvent&&Object.getPrototypeOf(PointerEvent.prototype)===MouseEvent.prototype&&Object.getPrototypeOf(UIEvent)===retainedPointerEvent&&globalThis.PointerEvent===undefined&&new PointerEvent("late",{view:retainedPointerGlobal}).view===retainedPointerGlobal&&typeof PointerEvent.prototype.getCoalescedEvents==="function"')! == 'true'
	constructor := runtime.evaluate_host_value('PointerEvent')!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host_value('PointerEvent')! == constructor
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},C=PointerEvent,p=C.prototype,global=Object.getOwnPropertyDescriptor(globalThis,"PointerEvent"),constructor=Object.getOwnPropertyDescriptor(p,"constructor"),fields=["pointerId","width","height","pressure","tangentialPressure","tiltX","tiltY","twist","altitudeAngle","azimuthAngle","pointerType","isPrimary","persistentDeviceId"],native=[];
 check(C.name==="PointerEvent"&&C.length===1&&Object.getPrototypeOf(C)===MouseEvent&&Object.getPrototypeOf(p)===MouseEvent.prototype&&global.writable&&global.configurable&&!global.enumerable&&!Object.getOwnPropertyDescriptor(C,"prototype").writable&&constructor.value===C&&constructor.writable&&constructor.configurable&&!constructor.enumerable,"Pointer metadata");
 for(const name of fields){const d=Object.getOwnPropertyDescriptor(p,name);check(d&&d.set===undefined&&d.enumerable&&d.configurable&&d.get.name==="get "+name&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]"),"getter "+name);native.push(d.get)}
 for(const name of ["getCoalescedEvents","getPredictedEvents"]){const d=Object.getOwnPropertyDescriptor(p,name);check(d&&d.writable&&d.enumerable&&d.configurable&&d.value.name===name&&d.value.length===0&&Function.prototype.toString.call(d.value).includes("[native code]"),"method "+name);native.push(d.value)}
 for(const operation of native){let rejected=false;try{Reflect.construct(function Empty(){},[],operation)}catch(error){rejected=error instanceof TypeError}check(rejected,"native nonconstructor")}
 const value=new C("λ\u0000pointer"),expected=[0,1,1,0,0,0,0,0,Math.PI/2,0,"",false,0];class Child extends C{}const child=new Child("child");
 check(value instanceof C&&value instanceof MouseEvent&&value instanceof UIEvent&&value instanceof Event&&Object.prototype.toString.call(value)==="[object PointerEvent]"&&fields.every((name,index)=>value[name]===expected[index])&&value.type==="λ\u0000pointer"&&!value.isTrusted&&!value.bubbles&&!value.cancelable&&!value.composed&&value.view===null&&value.detail===0&&value.which===1&&value.clientX===0&&value.relatedTarget===null&&value.timeStamp>=0&&value.timeStamp<10000&&!Object.hasOwn(value,"pointerId")&&Object.getOwnPropertyDescriptor(value,"isTrusted").configurable===false&&child instanceof Child&&child instanceof C&&Object.getPrototypeOf(child)===Child.prototype,"Pointer defaults");
 check(value.getCoalescedEvents().length===0&&value.getPredictedEvents().length===0&&value.getPredictedEvents()!==value.getPredictedEvents(),"default sequences");
 let errors=0;for(const operation of [()=>C("call"),()=>new C(),()=>new C(Symbol("type"))])try{operation()}catch(error){if(error instanceof TypeError)errors++}check(errors===3&&new C(undefined).type==="undefined","constructor arity");
 const Alternative=function Alternative(){};for(const prototype of [null,1]){Alternative.prototype=prototype;check(Object.getPrototypeOf(Reflect.construct(C,["fallback"],Alternative))===p,"prototype fallback")}
 let reads=0,coercions=0;const custom=Object.create(p),next=new Proxy(function Next(){},{get(target,name,receiver){if(name==="prototype"){reads++;return custom}return Reflect.get(target,name,receiver)}}),made=Reflect.construct(C,["custom"],next);check(reads===1&&Object.getPrototypeOf(made)===custom&&made.type==="custom","newTarget prototype");
 const marker={},throwing=new Proxy(function Throwing(){},{get(target,name,receiver){if(name==="prototype")throw marker;return Reflect.get(target,name,receiver)}});let same=false;try{Reflect.construct(C,[{toString(){coercions++;return "ignored"}},new Proxy({},{get(){coercions++;return 0}})],throwing)}catch(error){same=error===marker}check(same&&coercions===0,"prototype before conversion");return true;
})()')! == 'true'
	mut insecure, insecure_settings :=
		pointer_native_event_fixture('http://insecure-pointer-events.example/')
	defer { insecure.close() }
	assert !insecure_settings.is_secure_context()
	assert insecure.evaluate_host('typeof PointerEvent==="function"&&!Object.hasOwn(PointerEvent.prototype,"getCoalescedEvents")&&typeof new PointerEvent("insecure").getCoalescedEvents==="undefined"&&typeof PointerEvent.prototype.getPredictedEvents==="function"&&new PointerEvent("insecure",{coalescedEvents:[]}).getPredictedEvents().length===0')! == 'true'
}

fn test_native_pointer_event_dictionary_order_optional_values_and_numeric_exceptions() {
	$if !darwin { return }
	mut runtime, settings := pointer_native_event_fixture('https://pointer-dictionary.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof PointerEvent==="function"')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},members=["bubbles","cancelable","composed","detail","view","altKey","ctrlKey","metaKey","modifierAltGraph","modifierCapsLock","modifierFn","modifierFnLock","modifierHyper","modifierNumLock","modifierScrollLock","modifierSuper","modifierSymbol","modifierSymbolLock","shiftKey","button","buttons","clientX","clientY","movementX","movementY","relatedTarget","screenX","screenY","altitudeAngle","azimuthAngle","coalescedEvents","height","isPrimary","persistentDeviceId","pointerId","pointerType","predictedEvents","pressure","tangentialPressure","tiltX","tiltY","twist","width"],order=[];
 const numbers={detail:2147483649.8,button:65537.8,buttons:65539.8,clientX:-3.75,clientY:4.625,movementX:1.25,movementY:-2.5,screenX:8.875,screenY:-7.125,altitudeAngle:-1.25,azimuthAngle:8.5,height:-2.5,persistentDeviceId:4294967301.9,pointerId:2147483648.9,pressure:1.1,tangentialPressure:-1.1,tiltX:4294967386.9,tiltY:-4294967387.9,twist:1080.75,width:-7.25},values={view:globalThis,relatedTarget:globalThis,coalescedEvents:[],predictedEvents:[]};
 for(const name of members)if(!(name in values))values[name]=name==="pointerType"?{[Symbol.toPrimitive](hint){order.push(name+":"+hint);return "pen\u0000λ"}}:name in numbers?{[Symbol.toPrimitive](hint){order.push(name+":"+hint);return numbers[name]}}:true;
 let booleanHooks=0;values.isPrimary={valueOf(){booleanHooks++;throw 0}};
 const event=new PointerEvent({[Symbol.toPrimitive](hint){order.push("type:"+hint);return "ordered"}},new Proxy(values,{get(target,name){order.push(name);return Reflect.get(target,name)}})),expected=["type:string"];
 for(const name of members){expected.push(name);if(name in numbers)expected.push(name+":number");else if(name==="pointerType")expected.push(name+":string")}
 check(order.join(",")===expected.join(",")&&booleanHooks===0,"43 dictionary conversions");
 check(event.detail===-2147483647&&event.button===1&&event.buttons===3&&event.which===2&&event.view===globalThis&&event.relatedTarget===globalThis&&event.clientX===-3.75&&event.pageY===4.625&&event.offsetX===-3.75&&event.x===-3.75&&event.screenY===-7.125&&event.movementY===-2.5&&event.altitudeAngle===-1.25&&event.azimuthAngle===8.5&&event.width===-7.25&&event.height===-2.5&&event.pressure===Math.fround(1.1)&&event.tangentialPressure===Math.fround(-1.1)&&event.pointerId===-2147483648&&event.persistentDeviceId===5&&event.tiltX===90&&event.tiltY===-91&&event.twist===1080&&event.pointerType==="pen\u0000λ"&&event.isPrimary&&event.ctrlKey&&event.getModifierState("SymbolLock"),"converted Pointer values");globalThis.orderedNativePointer=event;
 const optional=new PointerEvent("optional",{tiltX:undefined,tiltY:undefined,altitudeAngle:undefined,azimuthAngle:undefined}),nulls=new PointerEvent("nulls",{tiltX:null,tiltY:null,altitudeAngle:null,azimuthAngle:null});check(optional.tiltX===0&&optional.tiltY===0&&optional.altitudeAngle===Math.PI/2&&optional.azimuthAngle===0&&nulls.altitudeAngle===0&&nulls.azimuthAngle===0,"optional defaults versus null");
 for(const field of ["width","height","altitudeAngle","azimuthAngle","pressure","tangentialPressure"])for(const value of [NaN,Infinity,-Infinity,1n,Symbol("number")]){let rejected=false;try{new PointerEvent("restricted",{[field]:value})}catch(error){rejected=error instanceof TypeError}check(rejected,"restricted "+field)}
 for(const field of ["pressure","tangentialPressure"]){let rejected=false;try{new PointerEvent("overflow",{[field]:3.5e38})}catch(error){rejected=error instanceof TypeError}check(rejected,"f32 overflow "+field)}
 for(const field of ["pointerId","persistentDeviceId","tiltX","twist","button","buttons"])for(const value of [1n,Symbol("integer")]){let rejected=false;try{new PointerEvent("integer",{[field]:value})}catch(error){rejected=error instanceof TypeError}check(rejected,"integer ToNumber "+field)}
 const zeros=new PointerEvent("signed-zero",{pressure:-0,tangentialPressure:-0,width:-0});check(Object.is(zeros.pressure,-0)&&Object.is(zeros.tangentialPressure,-0)&&Object.is(zeros.width,-0),"signed zero");
 for(const value of [NaN,Infinity,-Infinity]){const result=new PointerEvent("longs",{pointerId:value,tiltX:value,twist:value,persistentDeviceId:value});check(result.pointerId===0&&result.tiltX===0&&result.twist===0&&result.persistentDeviceId===0,"long nonfinite")}
 const savedWidth=Object.getOwnPropertyDescriptor(Object.prototype,"width");let inherited=0,correct=true;Object.defineProperty(Object.prototype,"width",{get(){inherited++;return 7.5},configurable:true});try{if(new PointerEvent("missing").width!==1||new PointerEvent("undefined",undefined).width!==1||new PointerEvent("null",null).width!==1||inherited!==0)correct=false;if(new PointerEvent("explicit",{}).width!==7.5||inherited!==1)correct=false}finally{if(savedWidth)Object.defineProperty(Object.prototype,"width",savedWidth);else delete Object.prototype.width}check(correct,"nullish dictionaries");
 for(const dictionary of [1,true,"dictionary",Symbol("dictionary")]){let rejected=false;try{new PointerEvent("dictionary",dictionary)}catch(error){rejected=error instanceof TypeError}check(rejected,"dictionary object required")}
 const marker={};let typeSame=false,getSame=false,numberSame=false,stringSame=false,later=0;try{new PointerEvent({toString(){throw marker}},{get bubbles(){later++;return false}})}catch(error){typeSame=error===marker}try{new PointerEvent("get",{get altitudeAngle(){throw marker},get azimuthAngle(){later++;return 0}})}catch(error){getSame=error===marker}try{new PointerEvent("number",{pressure:{valueOf(){throw marker}},get tangentialPressure(){later++;return 0}})}catch(error){numberSame=error===marker}try{new PointerEvent("string",{pointerType:{toString(){throw marker}},get predictedEvents(){later++;return []}})}catch(error){stringSame=error===marker}check(typeSame&&getSame&&numberSame&&stringSame&&later===0,"original conversion errors");return true;
})()')! == 'true'
	actual := runtime.native_event(runtime.evaluate_host_value('orderedNativePointer')!)!
	assert actual.interface_ == .pointer_event && !actual.is_trusted()
	pointer := unsafe { &dom.PointerEvent(actual) }
	assert pointer.pointer_id() == -2147483647 - 1 && pointer.width() == -7.25
	assert pointer.pressure() == f32(1.1) && pointer.tangential_pressure() == f32(-1.1)
	assert pointer.client_x_ == -3.75 && pointer.page_y_ == 4.625
	assert pointer.view() == voidptr(pointer_native_owner_window(settings).window().dom_proxy())
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_pointer_event_sequences_capture_iteration_preserve_identity_and_do_not_close_on_error() {
	$if !darwin { return }
	mut runtime, settings := pointer_native_event_fixture('https://pointer-sequences.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof PointerEvent==="function"')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},a=new PointerEvent("first",{pointerId:7}),b=new PointerEvent("second",{pointerId:8}),steps=[];let index=0,nextGets=0,iteratorGets=0,closes=0;
 const iterator={get next(){nextGets++;return function(){check(this===iterator,"next receiver");steps.push("next");const current=index++;if(current===3)return {get done(){steps.push("done");return true},get value(){throw new Error("done value read")}};return {get done(){steps.push("done");return false},get value(){steps.push("value");return current===1?b:a}}}},get return(){closes++;throw new Error("return read")}},iterable={get [Symbol.iterator](){iteratorGets++;return function(){check(this===iterable,"iterator receiver");steps.push("iterator");return iterator}}};
 const event=new PointerEvent("sequence",{coalescedEvents:iterable,predictedEvents:new Set([b,a])});check(iteratorGets===1&&nextGets===1&&closes===0&&steps.join(",")==="iterator,next,done,value,next,done,value,next,done,value,next,done","captured iterator order");
 const first=event.getCoalescedEvents(),second=event.getCoalescedEvents(),predicted=event.getPredictedEvents();check(Array.isArray(first)&&Object.getPrototypeOf(first)===Array.prototype&&first!==second&&first.length===3&&first[0]===a&&first[1]===b&&first[2]===a&&second[0]===a&&predicted.length===2&&predicted[0]===b&&predicted[1]===a&&predicted!==event.getPredictedEvents(),"fresh native sequences");first.length=0;second[0]=b;predicted.push(a);check(event.getCoalescedEvents().length===3&&event.getCoalescedEvents()[0]===a&&event.getPredictedEvents().length===2,"result mutation isolation");globalThis.pointerSequenceOwner=event;globalThis.pointerSequenceFirst=a;globalThis.pointerSequenceSecond=b;
 const saved=Object.getOwnPropertyDescriptor(Array.prototype,Symbol.iterator),marker={};let defaultReads=0;Object.defineProperty(Array.prototype,Symbol.iterator,{get(){defaultReads++;throw marker},configurable:true});let defaults;try{defaults=[new PointerEvent("missing"),new PointerEvent("undefined",undefined),new PointerEvent("null",null),new PointerEvent("explicit",{}),new PointerEvent("members",{coalescedEvents:undefined,predictedEvents:undefined})]}finally{Object.defineProperty(Array.prototype,Symbol.iterator,saved)}check(defaultReads===0&&defaults.every(value=>value.getCoalescedEvents().length===0&&value.getPredictedEvents().length===0),"empty defaults bypass Array iterator");
 let returns=0,later=0;const invalidProxy=new Proxy(a,{get(){throw new Error("Pointer proxy read")},getPrototypeOf(){throw new Error("Pointer proxy prototype read")}});
 for(const stage of ["method-get","method-call","next-get","next-call","done-get","value-get","item"]){let same=false,typeError=false;const iterator={get next(){if(stage==="next-get")throw marker;return function(){if(stage==="next-call")throw marker;return {get done(){if(stage==="done-get")throw marker;return false},get value(){if(stage==="value-get")throw marker;return invalidProxy}}}},get return(){returns++;throw marker}},input={get [Symbol.iterator](){if(stage==="method-get")throw marker;return function(){if(stage==="method-call")throw marker;return iterator}}};try{new PointerEvent("failure",{coalescedEvents:input,get height(){later++;return 0}})}catch(error){same=error===marker;typeError=error instanceof TypeError}check(stage==="item"?typeError:same,"original iterable "+stage)}check(returns===0&&later===0,"no IteratorClose or later member");
 let predictedSame=false;try{new PointerEvent("predicted-error",{predictedEvents:{[Symbol.iterator](){return {next(){throw marker},get return(){returns++;throw marker}}}},get pressure(){later++;return 0}})}catch(error){predictedSame=error===marker}check(predictedSame&&returns===0&&later===0,"predicted error stops pressure conversion");
 for(const value of [null,"string",1,{},[new MouseEvent("mouse")],[undefined]]){let rejected=false;try{new PointerEvent("bad-sequence",{predictedEvents:value})}catch(error){rejected=error instanceof TypeError}check(rejected,"Pointer sequence brand")}
 const invalidIterables=[{[Symbol.iterator]:1},{[Symbol.iterator](){return 1}},{[Symbol.iterator](){return {next:1,get return(){returns++;throw marker}}}},{[Symbol.iterator](){return {next(){return 1},get return(){returns++;throw marker}}}}];for(const value of invalidIterables){let rejected=false;try{new PointerEvent("invalid-iterator",{coalescedEvents:value})}catch(error){rejected=error instanceof TypeError}check(rejected,"iterator object/callable requirements")}
 let ignoredValue=0;const done=new PointerEvent("done",{predictedEvents:{[Symbol.iterator](){return {next(){return {done:{valueOf(){throw marker}},get value(){ignoredValue++;throw marker}}}}}}});check(done.getPredictedEvents().length===0&&ignoredValue===0&&returns===0,"truthy done skips value");return true;
})()')! == 'true'
	owner := unsafe { &dom.PointerEvent(runtime.native_event(runtime.evaluate_host_value('pointerSequenceOwner')!)!) }
	first := unsafe { &dom.PointerEvent(runtime.native_event(runtime.evaluate_host_value('pointerSequenceFirst')!)!) }
	second := unsafe { &dom.PointerEvent(runtime.native_event(runtime.evaluate_host_value('pointerSequenceSecond')!)!) }
	assert owner.coalesced_events_.len == 3 && owner.coalesced_events_[0] == first
	assert owner.coalesced_events_[1] == second && owner.coalesced_events_[2] == first
	assert owner.predicted_events_.len == 2 && owner.predicted_events_[0] == second
	assert owner.predicted_events_[1] == first
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_pointer_event_getter_and_sequence_brands_reject_other_native_families_without_traps() {
	$if !darwin { return }
	mut runtime, settings := pointer_native_event_fixture('https://pointer-brands.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof PointerEvent==="function"')! == 'true'
	mouse := dom.MouseEvent.create('mousemove', dom.MouseEventInit{})
	wheel := dom.WheelEvent.create('wheel', dom.WheelEventInit{})
	drag := html.DragEvent.create('drag', html.DragEventInit{}, 0, 0, 0, 0)
	keyboard := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{})
	events := [unsafe { &dom.Event(mouse) }, unsafe { &dom.Event(wheel) }, unsafe { &dom.Event(drag) },
		unsafe { &dom.Event(keyboard) }]
	runtime.evaluate_host('globalThis.pointerWrongNativeFamilies=[];0')!
	for index, event in events {
		pointer_native_export(mut runtime, '__pointerWrongFamily' + index.str(),
			runtime.javascript_event(event)!)!
		runtime.evaluate_host('pointerWrongNativeFamilies.push(__pointerWrongFamily' + index.str() +
			'());0')!
	}
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},p=PointerEvent.prototype,event=new PointerEvent("brand"),fields=["pointerId","width","height","pressure","tangentialPressure","tiltX","tiltY","twist","altitudeAngle","azimuthAngle","pointerType","isPrimary","persistentDeviceId"],marker={};let traps=0,coercions=0;
 const proxy=new Proxy(event,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}}),argument={[Symbol.toPrimitive](){coercions++;throw marker}},receivers=[Object.create(p),new Event("base"),new UIEvent("ui"),new MouseEvent("mouse"),...pointerWrongNativeFamilies,proxy,{},null,undefined,1];
 for(const receiver of receivers){for(const field of fields){let rejected=false;try{Object.getOwnPropertyDescriptor(p,field).get.call(receiver)}catch(error){rejected=error instanceof TypeError}check(rejected,"Pointer getter brand "+field)}for(const name of ["getCoalescedEvents","getPredictedEvents"]){let rejected=false;try{p[name].call(receiver,argument)}catch(error){rejected=error instanceof TypeError}check(rejected,"Pointer method brand "+name)}}
 check(event.getCoalescedEvents(argument).length===0&&event.getPredictedEvents(argument).length===0&&traps===0&&coercions===0,"ignored arguments and no Proxy inspection");return true;
})()')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_pointer_event_live_wrappers_and_inherited_mouse_initializers_preserve_pointer_slots() {
	$if !darwin { return }
	mut runtime, settings := pointer_native_event_fixture('https://pointer-live.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof PointerEvent==="function"')! == 'true'
	target := dom.EventTarget.new()
	related := dom.EventTarget.new()
	pointer_native_export(mut runtime, '__pointerLiveTarget', runtime.javascript_event_target(target,
		none)!)!
	pointer_native_export(mut runtime, '__pointerLiveRelated', runtime.javascript_event_target(related,
		none)!)!
	coalesced := dom.PointerEvent.create('sample', dom.PointerEventInit{ pointer_id: 4 })
	predicted := dom.PointerEvent.create('prediction', dom.PointerEventInit{ pointer_id: 5 })
	mouse_init := dom.MouseEventInit{
		EventModifierInit: dom.EventModifierInit{
			UIEventInit:        dom.UIEventInit{
				EventInit: dom.EventInit{
					bubbles:    true
					cancelable: true
					composed:   true
				}
				detail:    7
				view:      voidptr(pointer_native_owner_window(settings).window().dom_proxy())
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
	mut pointer := dom.PointerEvent.create('pointermove', dom.PointerEventInit{
		MouseEventInit:       mouse_init
		pointer_id:           42
		width:                3.5
		height:               4.5
		pressure:             f32(0.25)
		tangential_pressure:  f32(-0.5)
		tilt_x:               20
		tilt_y:               -30
		twist:                450
		altitude_angle:       0.75
		azimuth_angle:        1.25
		pointer_type:         'pen'
		is_primary:           true
		persistent_device_id: 73
		coalesced_events:     [coalesced, coalesced]
		predicted_events:     [predicted]
	})
	mut base := unsafe { &dom.Event(pointer) }
	stamp := base.time_stamp()
	runtime.evaluate_host('globalThis.retainedNativePointer=PointerEvent;globalThis.retainedNativePointerPrototype=PointerEvent.prototype;delete globalThis.PointerEvent;globalThis.PointerEvent=function ReplacementPointerEvent(){};0')!
	wrapper := runtime.javascript_event(base)!
	assert runtime.native_event(wrapper)! == base && runtime.javascript_event(base)! == wrapper
	pointer_native_export(mut runtime, '__pointerLiveEvent', wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const event=__pointerLiveEvent(),check=(condition,label)=>{if(!condition)throw new Error(label)},coordinates=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY"],values=[10.25,-11.75,20.375,-21.625,30.5,-31.5,30.5,-31.5,40.125,-41.875];globalThis.nativeLivePointer=event;globalThis.pointerLiveCoordinates=coordinates;globalThis.pointerLiveValues=values;
 check(event instanceof retainedNativePointer&&!(event instanceof PointerEvent)&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&Object.getPrototypeOf(event)===retainedNativePointerPrototype&&Object.prototype.toString.call(event)==="[object PointerEvent]"&&event.isTrusted&&event.view===globalThis&&event.detail===7&&event.which===3&&event.relatedTarget===__pointerLiveRelated()&&coordinates.every((name,index)=>event[name]===values[index]),"native Pointer prototype and coordinates");
 globalThis.pointerSlotSnapshot=()=>JSON.stringify([event.pointerId,event.width,event.height,event.pressure,event.tangentialPressure,event.tiltX,event.tiltY,event.twist,event.altitudeAngle,event.azimuthAngle,event.pointerType,event.isPrimary,event.persistentDeviceId]);check(pointerSlotSnapshot()==="[42,3.5,4.5,0.25,-0.5,20,-30,450,0.75,1.25,\"pen\",true,73]","native Pointer slots");globalThis.pointerLiveSample=event.getCoalescedEvents()[0];globalThis.pointerLivePrediction=event.getPredictedEvents()[0];check(event.getCoalescedEvents()[1]===pointerLiveSample&&pointerLiveSample instanceof retainedNativePointer&&pointerLiveSample.pointerId===4&&pointerLivePrediction.pointerId===5,"native sample wrapper identity");return true;
})()')! == 'true'
	base.set_is_trusted(false)
	assert runtime.evaluate_host('pointerLiveCoordinates.every((name,index)=>nativeLivePointer[name]===pointerLiveValues[index])&&!nativeLivePointer.isTrusted')! == 'true'
	for name in ['click', 'auxclick', 'contextmenu'] {
		base.set_type(name)
		assert runtime.evaluate_host('pointerLiveCoordinates.every((name,index)=>nativeLivePointer[name]===Math.floor(pointerLiveValues[index]))')! == 'true'
	}
	base.set_is_trusted(true)
	pointer.pointer_id_ = 99
	pointer.width_ = 8.25
	pointer.pressure_ = f32(0.75)
	pointer.pointer_type_ = 'touch'
	base.set_related_target(target)
	assert runtime.evaluate_host('pointerLiveCoordinates.every((name,index)=>nativeLivePointer[name]===pointerLiveValues[index])&&nativeLivePointer.pointerId===99&&nativeLivePointer.width===8.25&&nativeLivePointer.pressure===0.75&&nativeLivePointer.pointerType==="touch"&&nativeLivePointer.relatedTarget===__pointerLiveTarget()')! == 'true'
	base.set_type('pointermove')
	assert runtime.evaluate_host(r'(()=>{
 const event=nativeLivePointer,check=(condition,label)=>{if(!condition)throw new Error(label)},slots=pointerSlotSnapshot(),stamp=event.timeStamp,marker={};event.preventDefault();event.stopImmediatePropagation();const before=JSON.stringify([event.type,event.clientX,event.defaultPrevented,event.cancelBubble,event.isTrusted]);let same=false;try{event.initMouseEvent("partial",false,false,null,{valueOf(){throw marker}})}catch(error){same=error===marker}check(same&&JSON.stringify([event.type,event.clientX,event.defaultPrevented,event.cancelBubble,event.isTrusted])===before,"inherited init atomic failure");
 event.initMouseEvent("click",true,true,globalThis,9,11,12,13,14,false,false,true,false,1,__pointerLiveRelated());check(event.type==="click"&&!event.isTrusted&&!event.defaultPrevented&&!event.cancelBubble&&event.detail===9&&event.screenX===11&&event.clientX===13&&event.x===13&&event.which===2&&event.shiftKey&&!event.ctrlKey&&event.relatedTarget===__pointerLiveRelated()&&event.composed&&event.timeStamp===stamp&&pointerSlotSnapshot()===slots&&event.pageX===20&&event.pageY===-22&&event.offsetX===40&&event.offsetY===-42&&event.movementY===-2.75&&event.buttons===5&&event.getModifierState("CapsLock")&&event.getCoalescedEvents()[0]===pointerLiveSample&&event.getPredictedEvents()[0]===pointerLivePrediction,"legacy Mouse reset preserves Pointer slots");
 event.initUIEvent("pointermove",true,true,globalThis,10);check(event.clientX===13&&event.pageX===20.375&&event.offsetY===-41.875&&event.detail===10&&pointerSlotSnapshot()===slots&&event.getCoalescedEvents()[0]===pointerLiveSample,"legacy UI reset preserves Pointer slots");globalThis.pointerDispatchChecks=[];globalThis.pointerDispatchConversions=[];
 __pointerLiveTarget().addEventListener("pointermove",function(actual){const prior=JSON.stringify([actual.type,actual.detail,actual.clientX,actual.isTrusted,pointerSlotSnapshot()]);actual.initMouseEvent({toString(){pointerDispatchConversions.push("type");return "ignored"}},false,false,null,{valueOf(){pointerDispatchConversions.push("detail");return 100}},1,2,3,4,false,false,false,false,0,null);pointerDispatchChecks.push(actual===event&&this===__pointerLiveTarget()&&actual.currentTarget===this&&JSON.stringify([actual.type,actual.detail,actual.clientX,actual.isTrusted,pointerSlotSnapshot()])===prior);actual.preventDefault()});return true;
})()')! == 'true'
	base.set_is_trusted(true)
	assert !target.dispatch_event(base)
	assert runtime.evaluate_host('pointerDispatchChecks.length===1&&pointerDispatchChecks[0]&&pointerDispatchConversions.join(",")==="type,detail"&&nativeLivePointer.type==="pointermove"&&nativeLivePointer.isTrusted&&nativeLivePointer.currentTarget===null&&nativeLivePointer.defaultPrevented')! == 'true'
	assert base.time_stamp() == stamp && pointer.pointer_id() == 99
	assert pointer.coalesced_events_.len == 2 && pointer.coalesced_events_[0] == coalesced
	assert pointer.predicted_events_.len == 1 && pointer.predicted_events_[0] == predicted
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
