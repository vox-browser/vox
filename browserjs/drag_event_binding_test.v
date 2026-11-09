module browserjs

import dom
import html
import highresolutiontime

fn drag_native_settings(url string) &html.EnvironmentSettingsObject {
	document := html.parse_document_with_url('<!doctype html><body>Drag events</body>', dom.URL{
		value: url
	})
	mut owner_document := unsafe { &dom.Document(document) }
	owner_document.load_timing_info.navigation_start_time =
		highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'native-drag-events') or { panic(err) }
	return unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
}

fn drag_native_event_fixture(url string) (&Runtime, &html.EnvironmentSettingsObject) {
	settings := drag_native_settings(url)
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn drag_native_owner_window(settings &html.EnvironmentSettingsObject) &html.WindowModel {
	for window in html.all_windows() {
		if voidptr(window) == voidptr(settings.global_object()) {
			return window
		}
	}
	panic('missing actual DragEvent owner Window')
}

fn drag_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn test_native_drag_event_metadata_defaults_subclasses_and_window_exposure() {
	$if !darwin { return }
	mut runtime, settings := drag_native_event_fixture('https://native-drag-events.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DragEvent==="function"')! == 'true'
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof DragEvent==="undefined"')! == 'true'
	unbound.evaluate_host('globalThis.retainedDragGlobal=globalThis;globalThis.retainedDragEvent=Event;Event=function ReplacementEvent(){};MouseEvent=function ReplacementMouseEvent(){};globalThis={};0')!
	late_settings := drag_native_settings('http://late-drag-events.example/')
	unbound.bind_scripting_environment(late_settings)!
	unbound.install_event_target_binding()!
	assert !late_settings.is_secure_context()
	assert unbound.evaluate_host('typeof DragEvent==="function"&&Object.getPrototypeOf(DragEvent)===MouseEvent&&Object.getPrototypeOf(DragEvent.prototype)===MouseEvent.prototype&&Object.getPrototypeOf(UIEvent)===retainedDragEvent&&globalThis.DragEvent===undefined&&new DragEvent("late",{view:retainedDragGlobal}).view===retainedDragGlobal')! == 'true'
	constructor := runtime.evaluate_host_value('DragEvent')!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host_value('DragEvent')! == constructor
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},C=DragEvent,p=C.prototype,global=Object.getOwnPropertyDescriptor(globalThis,"DragEvent"),constructor=Object.getOwnPropertyDescriptor(p,"constructor"),d=Object.getOwnPropertyDescriptor(p,"dataTransfer");
 check(C.name==="DragEvent"&&C.length===1&&Object.getPrototypeOf(C)===MouseEvent&&Object.getPrototypeOf(p)===MouseEvent.prototype&&global.writable&&global.configurable&&!global.enumerable&&!Object.getOwnPropertyDescriptor(C,"prototype").writable&&constructor.value===C&&constructor.writable&&constructor.configurable&&!constructor.enumerable,"Drag metadata");
 check(d&&d.set===undefined&&d.enumerable&&d.configurable&&d.get.name==="get dataTransfer"&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]"),"native getter metadata");let nonconstructor=false;try{Reflect.construct(function Empty(){},[],d.get)}catch(error){nonconstructor=error instanceof TypeError}check(nonconstructor,"native getter is not a constructor");
 const tag=Object.getOwnPropertyDescriptor(p,Symbol.toStringTag);check(tag.value==="DragEvent"&&tag.configurable&&!tag.writable&&!tag.enumerable&&Object.getOwnPropertyNames(p).sort().join(",")==="constructor,dataTransfer","Drag own prototype members");
 const value=new C("λ\u0000drag"),extra={get ignored(){throw new Error("extra argument read")}};class Child extends C{}const child=new Child("child",undefined,extra);
 check(value instanceof C&&value instanceof MouseEvent&&value instanceof UIEvent&&value instanceof Event&&!(value instanceof PointerEvent)&&!(value instanceof WheelEvent)&&Object.prototype.toString.call(value)==="[object DragEvent]"&&value.dataTransfer===null&&value.type==="λ\u0000drag"&&!value.isTrusted&&!value.bubbles&&!value.cancelable&&!value.composed&&value.view===null&&value.detail===0&&value.which===1&&value.clientX===0&&value.pageX===0&&value.offsetY===0&&value.relatedTarget===null&&value.timeStamp>=0&&value.timeStamp<10000&&!Object.hasOwn(value,"dataTransfer")&&Object.getOwnPropertyDescriptor(value,"isTrusted").configurable===false&&child instanceof Child&&child instanceof C&&Object.getPrototypeOf(child)===Child.prototype&&child.dataTransfer===null,"Drag defaults and subclass");
 let errors=0;for(const operation of [()=>C("call"),()=>new C(),()=>new C(Symbol("type"))])try{operation()}catch(error){if(error instanceof TypeError)errors++}check(errors===3&&new C(undefined).type==="undefined","constructor arity");
 const Alternative=function Alternative(){};for(const prototype of [null,1]){Alternative.prototype=prototype;check(Object.getPrototypeOf(Reflect.construct(C,["fallback"],Alternative))===p,"prototype fallback")}
 let reads=0,coercions=0;const custom=Object.create(p),next=new Proxy(function Next(){},{get(target,name,receiver){if(name==="prototype"){reads++;return custom}return Reflect.get(target,name,receiver)}}),made=Reflect.construct(C,["custom",{clientX:3.25}],next);check(reads===1&&Object.getPrototypeOf(made)===custom&&made.type==="custom"&&made.clientX===3&&made.dataTransfer===null,"newTarget prototype");
 const marker={},throwing=new Proxy(function Throwing(){},{get(target,name,receiver){if(name==="prototype"){reads++;throw marker}return Reflect.get(target,name,receiver)}});for(const args of [[{toString(){coercions++;return "ignored"}},new Proxy({},{get(){coercions++;return 0}})],[]]){let same=false;try{Reflect.construct(C,args,throwing)}catch(error){same=error===marker}check(same,"prototype before conversion and arity")}check(reads===3&&coercions===0,"single prototype Get");
 globalThis.retainedDragConstructor=C;globalThis.retainedDragParent=MouseEvent;globalThis.retainedDragPrototype=p;globalThis.DragEvent=function ReplacementDragEvent(){};globalThis.MouseEvent=function ReplacementMouseEvent(){};const retained=new C("retained");check(Object.getPrototypeOf(C)===retainedDragParent&&Object.getPrototypeOf(retained)===p&&retained instanceof retainedDragParent&&!(retained instanceof DragEvent)&&retained.dataTransfer===null,"captured parent and replaced globals");return true;
})()')! == 'true'
	actual :=
		runtime.native_event(runtime.evaluate_host_value('new retainedDragConstructor("owner",{view:globalThis,detail:9})')!)!
	assert actual.interface_ == .drag_event && !actual.is_trusted()
	drag := unsafe { &html.DragEvent(actual) }
	assert drag.detail() == 9 && drag.data_transfer() == none
	assert drag.view() == voidptr(drag_native_owner_window(settings).window().dom_proxy())
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_drag_event_dictionary_order_nullable_transfer_and_original_author_exceptions() {
	$if !darwin { return }
	mut runtime, settings := drag_native_event_fixture('https://drag-dictionary.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DragEvent==="function"')! == 'true'
	related := dom.EventTarget.new()
	transfer := html.DataTransfer.construct()
	transfer_wrapper := runtime.javascript_data_transfer(transfer)!
	drag_native_export(mut runtime, '__dragDictionaryTransfer', transfer_wrapper)!
	drag_native_export(mut runtime, '__dragDictionaryTarget', runtime.javascript_event_target(related,
		none)!)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},target=__dragDictionaryTarget(),transfer=__dragDictionaryTransfer(),members=["bubbles","cancelable","composed","detail","view","altKey","ctrlKey","metaKey","modifierAltGraph","modifierCapsLock","modifierFn","modifierFnLock","modifierHyper","modifierNumLock","modifierScrollLock","modifierSuper","modifierSymbol","modifierSymbolLock","shiftKey","button","buttons","clientX","clientY","movementX","movementY","relatedTarget","screenX","screenY","dataTransfer"],order=[];
 const numbers={detail:2147483649.8,button:65537.8,buttons:65539.8,clientX:-3.75,clientY:4.625,movementX:1.25,movementY:-2.5,screenX:8.875,screenY:-7.125},values={view:globalThis,relatedTarget:target,dataTransfer:transfer};let booleanHooks=0;
 for(const name of members)if(!(name in values))values[name]=name in numbers?{[Symbol.toPrimitive](hint){order.push(name+":"+hint);return numbers[name]}}:true;values.ctrlKey={valueOf(){booleanHooks++;throw 0},toString(){booleanHooks++;throw 0}};
 const event=new DragEvent({[Symbol.toPrimitive](hint){order.push("type:"+hint);return "ordered"}},new Proxy(values,{get(target,name){order.push(name);return Reflect.get(target,name)}})),expected=["type:string"];
 for(const name of members){expected.push(name);if(name in numbers)expected.push(name+":number")}check(order.join(",")===expected.join(",")&&booleanHooks===0,"29 dictionary conversions");
 check(event.type==="ordered"&&event.detail===-2147483647&&event.button===1&&event.buttons===3&&event.which===2&&event.view===globalThis&&event.relatedTarget===target&&event.clientX===-4&&event.pageY===4&&event.offsetX===-4&&event.x===-4&&event.screenY===-8&&event.movementY===-2.5&&event.ctrlKey&&event.getModifierState("SymbolLock")&&event.dataTransfer===transfer,"converted Drag and inherited Mouse values");globalThis.orderedNativeDrag=event;
 const ownWindow=new DragEvent("owner-target",{view:globalThis,relatedTarget:globalThis});check(ownWindow.view===globalThis&&ownWindow.relatedTarget===globalThis,"owner Window identity");
 const savedTransfer=Object.getOwnPropertyDescriptor(Object.prototype,"dataTransfer"),savedClient=Object.getOwnPropertyDescriptor(Object.prototype,"clientX");let inherited=0,correct=true;Object.defineProperty(Object.prototype,"dataTransfer",{get(){inherited++;return transfer},configurable:true});Object.defineProperty(Object.prototype,"clientX",{get(){inherited++;return 8.5},configurable:true});try{for(const construct of [()=>new DragEvent("missing"),()=>new DragEvent("undefined",undefined),()=>new DragEvent("null",null)]){const value=construct();if(value.dataTransfer!==null||value.clientX!==0)correct=false}if(inherited!==0)correct=false;const explicit=new DragEvent("explicit",{});if(explicit.dataTransfer!==transfer||explicit.clientX!==8||inherited!==2)correct=false}finally{if(savedTransfer)Object.defineProperty(Object.prototype,"dataTransfer",savedTransfer);else delete Object.prototype.dataTransfer;if(savedClient)Object.defineProperty(Object.prototype,"clientX",savedClient);else delete Object.prototype.clientX}check(correct,"nullish dictionaries bypass inherited members");
 for(const dataTransfer of [null,undefined])check(new DragEvent("nullish",{dataTransfer}).dataTransfer===null,"nullable transfer default");
 for(const dictionary of [1,true,"dictionary",Symbol("dictionary")]){let rejected=false;try{new DragEvent("dictionary",dictionary)}catch(error){rejected=error instanceof TypeError}check(rejected,"dictionary object required")}
 const marker={};let typeSame=false,inheritedSame=false,getSame=false,numberSame=false,later=0,traps=0;try{new DragEvent({toString(){throw marker}},{get bubbles(){later++;return false}})}catch(error){typeSame=error===marker}try{new DragEvent("inherited",{get modifierAltGraph(){throw marker},get dataTransfer(){later++;return transfer}})}catch(error){inheritedSame=error===marker}try{new DragEvent("get",{get dataTransfer(){throw marker}})}catch(error){getSame=error===marker}try{new DragEvent("number",{screenY:{valueOf(){throw marker}},get dataTransfer(){later++;return transfer}})}catch(error){numberSame=error===marker}
 const targetProxy=new Proxy(target,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});for(const relatedTarget of [{},Object.create(EventTarget.prototype),targetProxy]){let rejected=false;try{new DragEvent("related-brand",{relatedTarget,get dataTransfer(){later++;return transfer}})}catch(error){rejected=error instanceof TypeError}check(rejected,"related target brand before Drag field")}
 const viewProxy=new Proxy(globalThis,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});for(const view of [{},viewProxy]){let rejected=false;try{new DragEvent("view-brand",{view,get dataTransfer(){later++;return transfer}})}catch(error){rejected=error instanceof TypeError}check(rejected,"view brand before Drag field")}
 check(typeSame&&inheritedSame&&getSame&&numberSame&&later===0&&traps===0,"original conversion exceptions and no later Gets");return true;
})()')! == 'true'
	actual := runtime.native_event(runtime.evaluate_host_value('orderedNativeDrag')!)!
	assert actual.interface_ == .drag_event && !actual.is_trusted()
	drag := unsafe { &html.DragEvent(actual) }
	assert voidptr(drag.data_transfer() or { panic('missing actual DragEvent DataTransfer') }) == voidptr(transfer)
	assert drag.client_x_ == -3.75 && drag.page_y_ == 4.625 && drag.offset_x_ == -3.75
	assert voidptr(drag.related_target() or { panic('missing actual DragEvent related target') }) == voidptr(related)
	assert voidptr(runtime.native_data_transfer(transfer_wrapper)!) == voidptr(transfer)
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_drag_event_transfer_identity_ignores_author_slots_and_rejects_forged_brands() {
	$if !darwin { return }
	mut runtime, settings := drag_native_event_fixture('https://drag-transfer.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DragEvent==="function"')! == 'true'
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text/plain', 'retained native drag data')
	wrapper := runtime.javascript_data_transfer(transfer)!
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	assert voidptr(runtime.native_data_transfer(wrapper)!) == voidptr(transfer)
	drag_native_export(mut runtime, '__dragIdentityTransfer', wrapper)!
	other_transfer := html.DataTransfer.construct()
	other_wrapper := runtime.javascript_data_transfer(other_transfer)!
	assert other_wrapper != wrapper
	assert voidptr(runtime.native_data_transfer(other_wrapper)!) == voidptr(other_transfer)
	drag_native_export(mut runtime, '__dragOtherTransfer', other_wrapper)!
	// Wrapper brands are local to the runtime, even when two runtimes wrap
	// the same underlying implementation. Do not pass foreign JSC values to
	// a JavaScript call; query the private implementation registry directly.
	mut foreign_runtime, _ := drag_native_event_fixture('https://drag-foreign.example/')
	defer { foreign_runtime.close() }
	foreign_wrapper := foreign_runtime.javascript_data_transfer(transfer)!
	assert voidptr(foreign_runtime.native_data_transfer(foreign_wrapper)!) == voidptr(transfer)
	if _ := runtime.native_data_transfer(foreign_wrapper) {
		assert false, 'accepted a DataTransfer wrapper from another Runtime'
	}
	if _ := foreign_runtime.native_data_transfer(wrapper) {
		assert false, 'foreign Runtime accepted this DataTransfer wrapper'
	}
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},transfer=__dragIdentityTransfer(),other=__dragOtherTransfer(),marker={};let traps=0,authorGets=0;
 for(const name of ["constructor","dropEffect","effectAllowed","items","types","files","getData","valueOf","toString"])Object.defineProperty(transfer,name,{get(){authorGets++;throw marker},configurable:true});Object.defineProperty(transfer,Symbol.toPrimitive,{get(){authorGets++;throw marker},configurable:true});
 const first=new DragEvent("first",{dataTransfer:transfer}),second=new DragEvent("second",{dataTransfer:transfer}),third=new DragEvent("third",{dataTransfer:other});check(first.dataTransfer===transfer&&first.dataTransfer===first.dataTransfer&&second.dataTransfer===transfer&&third.dataTransfer===other&&third.dataTransfer!==first.dataTransfer,"native DataTransfer identity");
 const proxy=new Proxy(transfer,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker},has(){traps++;throw marker}}),forged=Object.create(Object.getPrototypeOf(transfer));
 for(const dataTransfer of [{},forged,proxy,[],new Event("event"),new DragEvent("drag"),1,true,"transfer",1n,Symbol("transfer")]){let rejected=false;try{new DragEvent("invalid",{dataTransfer})}catch(error){rejected=error instanceof TypeError}check(rejected,"native DataTransfer input brand")}
 check(!Reflect.set(first,"dataTransfer",other)&&first.dataTransfer===transfer&&!Object.hasOwn(first,"dataTransfer"),"readonly transfer");
 const C=DragEvent,prototype=C.prototype;globalThis.DragEvent=function ReplacementDragEvent(){};globalThis.DataTransfer=function ReplacementDataTransfer(){throw marker};const retained=new C("retained",{dataTransfer:transfer});check(Object.getPrototypeOf(retained)===prototype&&retained.dataTransfer===transfer&&authorGets===0&&traps===0,"captured wrapping ignores replacement globals and author fields");globalThis.dragIdentityEvent=first;return true;
})()')! == 'true'
	assert transfer.get_data('text/plain') == 'retained native drag data'
	actual := runtime.native_event(runtime.evaluate_host_value('dragIdentityEvent')!)!
	drag := unsafe { &html.DragEvent(actual) }
	assert voidptr(drag.data_transfer() or { panic('missing retained DataTransfer') }) == voidptr(transfer)
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_drag_event_getter_brands_and_native_mouse_family_prototypes() {
	$if !darwin { return }
	mut runtime, settings := drag_native_event_fixture('https://drag-brands.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DragEvent==="function"')! == 'true'
	transfer := html.DataTransfer.construct()
	transfer_wrapper := runtime.javascript_data_transfer(transfer)!
	drag_native_export(mut runtime, '__dragBrandedTransfer', transfer_wrapper)!
	mouse := dom.MouseEvent.create('mousemove', dom.MouseEventInit{})
	pointer := dom.PointerEvent.create('pointermove', dom.PointerEventInit{})
	wheel := dom.WheelEvent.create('wheel', dom.WheelEventInit{})
	drag := html.DragEvent.create('drag', html.DragEventInit{ data_transfer: transfer }, 0, 0, 0, 0)
	keyboard := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{})
	events := [unsafe { &dom.Event(mouse) }, unsafe { &dom.Event(pointer) }, unsafe { &dom.Event(wheel) },
		unsafe { &dom.Event(drag) }, unsafe { &dom.Event(keyboard) }]
	runtime.evaluate_host('globalThis.dragNativeFamilies=[];0')!
	for index, event in events {
		wrapper := runtime.javascript_event(event)!
		assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
			&& runtime.javascript_event(event)! == wrapper
		drag_native_export(mut runtime, '__dragNativeFamily' + index.str(), wrapper)!
		runtime.evaluate_host('dragNativeFamilies.push(__dragNativeFamily' + index.str() + '());0')!
	}
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},p=DragEvent.prototype,event=new DragEvent("brand"),getter=Object.getOwnPropertyDescriptor(p,"dataTransfer").get,marker={};let traps=0,coercions=0;
 const proxy=new Proxy(event,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}}),argument={[Symbol.toPrimitive](){coercions++;throw marker}},receivers=[Object.create(p),new Event("base"),new UIEvent("ui"),new MouseEvent("mouse"),new PointerEvent("pointer"),new WheelEvent("wheel"),...dragNativeFamilies.filter((event,index)=>index!==3),proxy,{},null,undefined,1];
 for(const receiver of receivers){let rejected=false;try{getter.call(receiver,argument)}catch(error){rejected=error instanceof TypeError}check(rejected,"Drag getter brand")}
 check(getter.call(event,argument)===null&&getter.call(dragNativeFamilies[3],argument)===__dragBrandedTransfer()&&traps===0&&coercions===0,"native getter ignores extra arguments without Proxy inspection");
 const prototypes=[MouseEvent.prototype,PointerEvent.prototype,WheelEvent.prototype,DragEvent.prototype],tags=["MouseEvent","PointerEvent","WheelEvent","DragEvent"];
 check(dragNativeFamilies.slice(0,4).every((event,index)=>Object.getPrototypeOf(event)===prototypes[index]&&Object.prototype.toString.call(event)==="[object "+tags[index]+"]"&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&(event instanceof PointerEvent)===(index===1)&&(event instanceof WheelEvent)===(index===2)&&(event instanceof DragEvent)===(index===3)),"exact concrete native family prototypes");return true;
})()')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
}

fn test_native_drag_event_live_wrappers_and_inherited_initializers_preserve_transfer() {
	$if !darwin { return }
	mut runtime, settings := drag_native_event_fixture('https://drag-live.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DragEvent==="function"')! == 'true'
	target := dom.EventTarget.new()
	related := dom.EventTarget.new()
	transfer := html.DataTransfer.construct()
	drag_native_export(mut runtime, '__dragLiveTarget', runtime.javascript_event_target(target,
		none)!)!
	drag_native_export(mut runtime, '__dragLiveRelated', runtime.javascript_event_target(related,
		none)!)!
	drag_native_export(mut runtime, '__dragLiveTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	mouse_init := dom.MouseEventInit{
		EventModifierInit: dom.EventModifierInit{
			UIEventInit:        dom.UIEventInit{
				EventInit: dom.EventInit{
					bubbles:    true
					cancelable: true
					composed:   true
				}
				detail:    7
				view:      voidptr(drag_native_owner_window(settings).window().dom_proxy())
			}
			ctrl_key:           true
			modifier_caps_lock: true
		}
		screen_x:          10.25
		screen_y:          -11.75
		client_x:          30.5
		client_y:          -31.5
		movement_x:        1.25
		movement_y:        -2.75
		button:            2
		buttons:           5
		related_target:    related
	}
	mut drag := html.DragEvent.create('drag', html.DragEventInit{
		MouseEventInit: mouse_init
		data_transfer:  transfer
	}, 20.375, -21.625, 40.125, -41.875)
	mut base := unsafe { &dom.Event(drag) }
	stamp := base.time_stamp()
	runtime.evaluate_host('globalThis.retainedNativeDrag=DragEvent;globalThis.retainedNativeDragPrototype=DragEvent.prototype;delete globalThis.DragEvent;globalThis.DragEvent=function ReplacementDragEvent(){};0')!
	wrapper := runtime.javascript_event(base)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(base) && runtime.javascript_event(base)! == wrapper
	drag_native_export(mut runtime, '__dragLiveEvent', wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const event=__dragLiveEvent(),check=(condition,label)=>{if(!condition)throw new Error(label)},coordinates=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY"],values=[10.25,-11.75,20.375,-21.625,30.5,-31.5,30.5,-31.5,40.125,-41.875];globalThis.nativeLiveDrag=event;globalThis.dragLiveCoordinates=coordinates;globalThis.dragLiveValues=values;
 check(event instanceof retainedNativeDrag&&!(event instanceof DragEvent)&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&!(event instanceof WheelEvent)&&Object.getPrototypeOf(event)===retainedNativeDragPrototype&&Object.prototype.toString.call(event)==="[object DragEvent]"&&event.isTrusted&&event.view===globalThis&&event.detail===7&&event.which===3&&event.relatedTarget===__dragLiveRelated()&&coordinates.every((name,index)=>event[name]===values[index])&&event.dataTransfer===__dragLiveTransfer(),"native Drag prototype and live coordinates");return true;
})()')! == 'true'
	base.set_is_trusted(false)
	assert runtime.evaluate_host('dragLiveCoordinates.every((name,index)=>nativeLiveDrag[name]===Math.floor(dragLiveValues[index]))&&!nativeLiveDrag.isTrusted&&nativeLiveDrag.dataTransfer===__dragLiveTransfer()')! == 'true'
	base.set_is_trusted(true)
	drag.screen_x_ = 99.625
	drag.movement_y_ = 8.5
	drag.button_ = -1
	drag.buttons_ = 2
	drag.ctrl_key_ = false
	base.set_related_target(target)
	assert runtime.evaluate_host('nativeLiveDrag.screenX===99.625&&nativeLiveDrag.movementY===8.5&&nativeLiveDrag.button===-1&&nativeLiveDrag.buttons===2&&nativeLiveDrag.which===0&&!nativeLiveDrag.ctrlKey&&nativeLiveDrag.relatedTarget===__dragLiveTarget()&&nativeLiveDrag.dataTransfer===__dragLiveTransfer()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const event=nativeLiveDrag,check=(condition,label)=>{if(!condition)throw new Error(label)},transfer=event.dataTransfer,stamp=event.timeStamp,marker={};event.preventDefault();event.stopImmediatePropagation();const before=JSON.stringify([event.type,event.clientX,event.defaultPrevented,event.cancelBubble,event.isTrusted]);let same=false;try{event.initMouseEvent("partial",false,false,null,{valueOf(){throw marker}})}catch(error){same=error===marker}check(same&&JSON.stringify([event.type,event.clientX,event.defaultPrevented,event.cancelBubble,event.isTrusted])===before&&event.dataTransfer===transfer,"inherited init atomic failure");
 event.initMouseEvent("drag",true,true,globalThis,9,11,12,13,14,false,false,true,false,1,__dragLiveRelated());check(event.type==="drag"&&!event.isTrusted&&!event.defaultPrevented&&!event.cancelBubble&&event.detail===9&&event.screenX===11&&event.clientX===13&&event.which===2&&event.shiftKey&&!event.ctrlKey&&event.relatedTarget===__dragLiveRelated()&&event.composed&&event.timeStamp===stamp&&event.dataTransfer===transfer&&event.pageX===20&&event.pageY===-22&&event.offsetX===40&&event.offsetY===-42&&event.movementY===8.5&&event.buttons===2&&event.getModifierState("CapsLock"),"legacy Mouse reset preserves Drag transfer");
 event.initUIEvent("drag",true,true,globalThis,10);check(event.clientX===13&&event.pageX===20&&event.offsetY===-42&&event.detail===10&&event.dataTransfer===transfer,"legacy UI reset preserves Drag transfer");event.initEvent("drag",true,true);check(event.detail===10&&event.dataTransfer===transfer&&Object.getPrototypeOf(event)===retainedNativeDragPrototype,"legacy Event reset preserves Drag transfer");globalThis.dragDispatchChecks=[];globalThis.dragDispatchConversions=[];
 __dragLiveTarget().addEventListener("drag",function(actual){const prior=JSON.stringify([actual.type,actual.detail,actual.clientX,actual.isTrusted]);actual.initMouseEvent({toString(){dragDispatchConversions.push("type");return "ignored"}},false,false,null,{valueOf(){dragDispatchConversions.push("detail");return 100}},1,2,3,4,false,false,false,false,0,null);dragDispatchChecks.push(actual===event&&this===__dragLiveTarget()&&actual.currentTarget===this&&actual.dataTransfer===transfer&&JSON.stringify([actual.type,actual.detail,actual.clientX,actual.isTrusted])===prior);let rejected=false;try{actual.initMouseEvent("bad",false,false,null,0,Symbol("long"))}catch(error){rejected=error instanceof TypeError}dragDispatchChecks.push(rejected&&JSON.stringify([actual.type,actual.detail,actual.clientX,actual.isTrusted])===prior&&actual.dataTransfer===transfer);actual.preventDefault()});return true;
})()')! == 'true'
	base.set_is_trusted(true)
	assert !target.dispatch_event(base)
	assert runtime.evaluate_host('dragDispatchChecks.length===2&&dragDispatchChecks.every(Boolean)&&dragDispatchConversions.join(",")==="type,detail"&&nativeLiveDrag.type==="drag"&&nativeLiveDrag.isTrusted&&nativeLiveDrag.currentTarget===null&&nativeLiveDrag.defaultPrevented&&nativeLiveDrag.dataTransfer===__dragLiveTransfer()')! == 'true'
	assert base.time_stamp() == stamp
	assert voidptr(drag.data_transfer() or { panic('missing actual live Drag transfer') }) == voidptr(transfer)
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
