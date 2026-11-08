module main

import clipboard
import browserjs
import dom
import highresolutiontime
import html

fn clipboard_binding_fixture() (&browserjs.Runtime, &html.EnvironmentSettingsObject) {
	mut document := html.parse_document_with_url('<!doctype html><body>Clipboard events</body>', dom.URL{value:'https://clipboard-events.test/'})
	document.load_timing_info.navigation_start_time = highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'clipboard-events') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := browserjs.Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn test_native_clipboard_event_metadata_default_members_and_subclasses() {
	mut runtime, _ := clipboard_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const check=(value,message)=>{if(!value)throw Error(message);},C=ClipboardEvent,event=new C("copy"),g=Object.getOwnPropertyDescriptor(globalThis,"ClipboardEvent"),p=Object.getOwnPropertyDescriptor(C,"prototype"),d=Object.getOwnPropertyDescriptor(C.prototype,"clipboardData");
 check(C.name==="ClipboardEvent"&&C.length===1&&g.writable&&g.configurable&&!g.enumerable&&!p.writable&&!p.configurable,"interface metadata");
 check(Object.getPrototypeOf(C)===Event&&Object.getPrototypeOf(C.prototype)===Event.prototype&&event instanceof Event&&Object.prototype.toString.call(event)==="[object ClipboardEvent]","Event inheritance");
 check(event.type==="copy"&&event.clipboardData===null&&!event.bubbles&&!event.cancelable&&!event.composed&&!event.isTrusted,"defaults");
 check(d.enumerable&&d.configurable&&d.get.name==="get clipboardData"&&d.set===undefined,"readonly descriptor");
 class Sub extends C{};check(new Sub("paste") instanceof Sub&&new Sub("paste") instanceof C,"subclass");
 for(const create of [()=>C("copy"),()=>new C()]){let rejected=false;try{create()}catch(error){rejected=error instanceof TypeError;}check(rejected,"constructor rejection");}
 globalThis.nativeCopyEvent=event;return true;
})()')! == 'true'
	event := runtime.native_event(runtime.evaluate_host_value('nativeCopyEvent')!)!
	assert event.interface_ == .clipboard_event
	assert !event.is_trusted()
}

fn test_native_clipboard_event_uses_native_transfer_identity_and_dictionary_order() {
	mut runtime, _ := clipboard_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const check=(value,message)=>{if(!value)throw Error(message);},transfer=new DataTransfer(),order=[];
 transfer.setData("text/plain","retained text");
 const dictionary=new Proxy({bubbles:true,cancelable:true,composed:true,clipboardData:transfer},{get(target,name){order.push(name);return target[name];}});
 const event=new ClipboardEvent({toString(){order.push("type");return "paste";}},dictionary);
 check(order.join() === "type,bubbles,cancelable,composed,clipboardData","dictionary order: "+order);
 check(event.bubbles&&event.cancelable&&event.composed&&event.clipboardData===transfer,"native transfer identity");
 transfer.setData("text/plain","changed");check(event.clipboardData.getData("text/plain")==="changed","live transfer");
 globalThis.clipboardTransferEvent=event;return true;
})()')! == 'true'
	event := runtime.native_event(runtime.evaluate_host_value('clipboardTransferEvent')!)!
	copy_event := unsafe { &clipboard.ClipboardEvent(event) }
	transfer := copy_event.clipboard_data() or { panic('transfer') }
	assert transfer.get_data('text/plain') == 'changed'
}

fn test_native_clipboard_event_validates_brands_without_author_inspection_and_preserves_exceptions() {
	mut runtime, _ := clipboard_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const check=(value,message)=>{if(!value)throw Error(message);},getter=Object.getOwnPropertyDescriptor(ClipboardEvent.prototype,"clipboardData").get,transfer=new DataTransfer(),event=new ClipboardEvent("copy");
 let traps=0;const fake=new Proxy(transfer,{get(){traps++;throw 1;},getPrototypeOf(){traps++;throw 2;}});
 for(const clipboardData of [{},Object.create(DataTransfer.prototype),fake]){let rejected=false;try{new ClipboardEvent("copy",{clipboardData})}catch(error){rejected=error instanceof TypeError;}check(rejected,"DataTransfer brand");}
 for(const receiver of [{},null,ClipboardEvent.prototype,new Event("copy"),new Proxy(event,{get(){traps++;throw 3;},getPrototypeOf(){traps++;throw 4;}})]){let rejected=false;try{getter.call(receiver)}catch(error){rejected=error instanceof TypeError;}check(rejected,"ClipboardEvent brand");}
 check(traps===0,"no author traps");
 const marker={};let same=false,later=0;try{new ClipboardEvent({toString(){throw marker;}},{get bubbles(){later++;return true;}})}catch(error){same=error===marker;}check(same&&later===0,"type exception");
 same=false;try{new ClipboardEvent("copy",{get clipboardData(){throw marker;}})}catch(error){same=error===marker;}check(same,"member exception");
 for(const init of [1,true,"init",Symbol()]){let rejected=false;try{new ClipboardEvent("copy",init)}catch(error){rejected=error instanceof TypeError;}check(rejected,"dictionary brand");}
 for(const init of [undefined,null])check(new ClipboardEvent("copy",init).clipboardData===null,"nullish init");
 for(const clipboardData of [undefined,null])check(new ClipboardEvent("copy",{clipboardData}).clipboardData===null,"nullish transfer");return true;
})()')! == 'true'
}

fn test_native_clipboard_event_wrapping_dispatch_and_window_only_exposure() {
	mut runtime, settings := clipboard_binding_fixture()
	defer { runtime.close() }
	mut event := clipboard.ClipboardEvent.create('copy', clipboard.ClipboardEventInit{clipboard_data:html.DataTransfer.construct()})
	wrapper := runtime.javascript_event(unsafe { &dom.Event(event) })!
	runtime.define_value_host_function('__wrappedClipboardEvent', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	assert runtime.evaluate_host(r'(()=>{const event=__wrappedClipboardEvent(),target=new EventTarget();let received=false;target.addEventListener("copy",current=>{received=current===event&&current.clipboardData===event.clipboardData&&current.currentTarget===target;});target.dispatchEvent(event);return event instanceof ClipboardEvent&&event.clipboardData instanceof DataTransfer&&received;})()')! == 'true'
	mut unbound := browserjs.Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof ClipboardEvent')! == 'undefined'
	unbound.bind_scripting_environment(settings)!
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('new ClipboardEvent("copy") instanceof ClipboardEvent')! == 'true'
}
