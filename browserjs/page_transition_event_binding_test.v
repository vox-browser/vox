module browserjs

import dom
import html

fn page_transition_event_fixture() !(&Runtime, &dom.Document) {
	url := dom.URL{value: 'https://page-transition.example/'}
	mut document := html.parse_navigation_document('<!doctype html><p>page</p>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_event_target_binding()!
	return runtime, document
}

fn test_page_transition_event_constructor_defaults_metadata_and_subclasses() {
	mut runtime, mut document := page_transition_event_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const check=(v,n)=>{if(!v)throw new Error(n)},C=PageTransitionEvent,p=C.prototype,d=Object.getOwnPropertyDescriptor(p,"persisted"),g=Object.getOwnPropertyDescriptor(globalThis,"PageTransitionEvent");
 check(C.name==="PageTransitionEvent"&&C.length===1&&Object.getPrototypeOf(C)===Event&&Object.getPrototypeOf(p)===Event.prototype&&!Object.getOwnPropertyDescriptor(C,"prototype").writable&&g.writable&&g.configurable&&!g.enumerable,"constructor metadata");
 check(d.get.name==="get persisted"&&d.get.length===0&&d.set===undefined&&d.enumerable&&d.configurable&&Function.prototype.toString.call(d.get).includes("[native code]"),"getter metadata");
 const event=new C("λ\0event");class Child extends C{}const child=new Child("child",{persisted:true});
 check(event instanceof C&&event instanceof Event&&!(event instanceof UIEvent)&&event.type==="λ\0event"&&event.persisted===false&&!event.bubbles&&!event.cancelable&&!event.composed&&!event.isTrusted&&event.timeStamp>=0&&event.timeStamp<10000&&!Object.hasOwn(event,"persisted")&&Object.prototype.toString.call(event)==="[object PageTransitionEvent]","defaults");
 check(child instanceof Child&&child instanceof C&&child.persisted===true,"subclass");
 for(const init of [undefined,null,{}])check(new C("default",init).persisted===false,"dictionary defaults");
 for(const value of [undefined,null,false,0,NaN,""])check(new C("false",{persisted:value}).persisted===false,"false conversion");
 for(const value of [true,1,"false",Symbol(),{valueOf(){throw 0}}])check(new C("true",{persisted:value}).persisted===true,"true conversion");
 for(const op of [()=>C("x"),()=>new C(),()=>new C(Symbol()),()=>Reflect.construct(function(){},[],d.get)]){let rejected=false;try{op()}catch(e){rejected=e instanceof TypeError}check(rejected,"constructor requirement")}
 return true;
})()')! == 'true'
	value := runtime.evaluate_host_value('new PageTransitionEvent("native",{persisted:true})')!
	event := runtime.native_event(value)!
	assert event.interface_ == .page_transition_event
	assert unsafe { &dom.PageTransitionEvent(event) }.persisted()
	assert runtime.javascript_event(event)! == value
}

fn test_page_transition_event_dictionary_order_original_exceptions_and_brands() {
	mut runtime, mut document := page_transition_event_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const check=(v,n)=>{if(!v)throw new Error(n)},C=PageTransitionEvent,log=[],marker={};
 const init=new Proxy({bubbles:true,cancelable:true,composed:true,persisted:true},{get(target,key){log.push(key);return target[key]}});
 const event=new C({toString(){log.push("type");return "ordered"}},init);
 check(log.join() === "type,bubbles,cancelable,composed,persisted"&&event.bubbles&&event.cancelable&&event.composed&&event.persisted,"dictionary order");
 let later=0;
 for(const args of [[{toString(){throw marker}},1],["x",{get bubbles(){throw marker},get persisted(){later++}}],["x",{get persisted(){throw marker}}]]){let same=false;try{new C(...args)}catch(e){same=e===marker}check(same,"original exception")}
 check(later===0,"stop after failed conversion");
 for(const init of [1,true,"x",Symbol()]){let rejected=false;try{new C("x",init)}catch(e){rejected=e instanceof TypeError}check(rejected,"dictionary brand")}
 const get=Object.getOwnPropertyDescriptor(C.prototype,"persisted").get;let traps=0;
 for(const fake of [null,{},C.prototype,Object.create(event),new Event("base"),new HashChangeEvent("other"),new Proxy(event,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}})]){let rejected=false;try{get.call(fake)}catch(e){rejected=e instanceof TypeError}check(rejected,"getter brand")}
 const old=Object.getOwnPropertyDescriptor(Object.prototype,"persisted");let reads=0,valid=true;
 Object.defineProperty(Object.prototype,"persisted",{get(){reads++;return true},configurable:true});
 try{valid=new C("absent").persisted===false&&new C("null",null).persisted===false&&reads===0&&new C("inherited",{}).persisted===true&&reads===1}finally{if(old)Object.defineProperty(Object.prototype,"persisted",old);else delete Object.prototype.persisted}
 return traps===0&&valid;
})()')! == 'true'
}

fn test_native_page_transition_events_keep_persisted_identity_and_retained_prototype() {
	mut runtime, mut document := page_transition_event_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_window_event_handler_binding()!
	// Window's page transition dispatch uses its Document as the legacy target.
	document_wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(document) }, none)!
	runtime.define_value_host_function('__pageTransitionDocument', fn [document_wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return document_wrapper
	})!
	assert runtime.evaluate_host(r'
 globalThis.savedPageTransition=PageTransitionEvent;globalThis.transitions=[];
 for(const name of ["pagehide","pageshow"])EventTarget.prototype.addEventListener.call(globalThis,name,event=>transitions.push(event));
 globalThis.PageTransitionEvent=function Replacement(){};0;
 ')! == '0'
	window := document.get_window() or { panic('missing Window') }
	model := unsafe { &html.WindowModel(window) }
	model.fire_a_page_transition_event('pageshow', false)
	model.fire_a_page_transition_event('pagehide', true)
	model.fire_a_page_transition_event('pageshow', true)
	assert runtime.evaluate_host(r'(()=>{
 const events=transitions.slice(),last=events[2];let same=false;
 EventTarget.prototype.addEventListener.call(globalThis,"pageshow",event=>{same=event===last});EventTarget.prototype.dispatchEvent.call(globalThis,last);
 const check=(value,label)=>{if(!value)throw new Error(label)};
 check(same&&events.length===3,"native delivery and redispatch identity");
 check(events.map(e=>e.type+":"+e.persisted).join()==="pageshow:false,pagehide:true,pageshow:true","native persisted values");
 check(events.every(e=>e instanceof savedPageTransition&&e instanceof Event&&!(e instanceof PageTransitionEvent)&&Object.getPrototypeOf(e)===savedPageTransition.prototype),"retained native prototype");
 check(events.every(e=>e.target===__pageTransitionDocument()&&e.currentTarget===null),"legacy document target");
 check(events[0].isTrusted&&events[1].isTrusted&&!last.isTrusted,"native trust and untrusted redispatch");return true;
})()')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
}

fn test_page_transition_event_is_installed_only_for_window_and_can_be_installed_later() {
	mut runtime, mut document := page_transition_event_fixture()!
	defer { runtime.close(); document.finalize() }
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof PageTransitionEvent')! == 'undefined'
	unbound.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	unbound.install_event_target_binding()!
	constructor := unbound.evaluate_host_value('PageTransitionEvent')!
	assert unbound.evaluate_host('new PageTransitionEvent("late").persisted')! == 'false'
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host_value('PageTransitionEvent')! == constructor
}
