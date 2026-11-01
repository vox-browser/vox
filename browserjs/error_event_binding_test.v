module browserjs

import dom

fn test_error_event_constructor_converts_dictionaries_and_preserves_error_identity() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host(r'(()=>{
 const reason={},order=[],init={};for(const [key,value]of [["bubbles",true],["cancelable",true],["composed",true],["colno",4294967298],["error",reason],["filename","bad\ud800\0.js"],["lineno",-1],["message","message\ud800\0"]])Object.defineProperty(init,key,{get(){order.push(key);return value}});
 const event=new ErrorEvent({toString(){order.push("type");return "error\ud800\0"}},init),empty=new ErrorEvent("empty");
 class Child extends ErrorEvent{}const child=new Child("child",{error:reason});

 const checks=[[0,order.join()==="type,bubbles,cancelable,composed,colno,error,filename,lineno,message"],[1,event instanceof ErrorEvent],[2,event instanceof Event],[3,event.error===reason],[4,child.error===reason],[5,child instanceof Child],[6,event.type==="error\ud800\0"],[7,event.message==="message\ud800\0"],[8,event.filename==="bad�\0.js"],[9,event.colno===2],[10,event.lineno===4294967295],[11,event.bubbles],[12,event.cancelable],[13,event.composed],[14,!event.isTrusted],[15,empty.message===""],[16,empty.filename===""],[17,empty.lineno===0],[18,empty.colno===0],[19,empty.error===undefined],[20,new ErrorEvent("null",{error:null}).error===null]];
 for(const [index,valid]of checks)if(!valid)throw new Error("ErrorEvent check "+index+"; order="+order.join()+"; fields="+JSON.stringify([event.type,event.message,event.filename,event.colno,event.lineno,empty.error]));return true;
})()')! == 'true'
}

fn test_error_event_getters_use_native_brands_and_preserve_abrupt_conversions() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host(r'(()=>{
 if(ErrorEvent.length!==1||ErrorEvent.prototype.constructor!==ErrorEvent||Object.getPrototypeOf(ErrorEvent.prototype)!==Event.prototype||Object.getOwnPropertyDescriptor(ErrorEvent,"prototype").writable)return false;
 let hooks=0;const event=new ErrorEvent("error"),fake={get message(){hooks++;throw 1}},proxy=new Proxy(event,{get(){hooks++;throw 2},getPrototypeOf(){hooks++;throw 3}});
 function rejects(run){try{run();return false}catch(error){return error instanceof TypeError}}
 for(const name of ["message","filename","lineno","colno","error"]){const d=Object.getOwnPropertyDescriptor(ErrorEvent.prototype,name);if(!d.enumerable||!d.configurable||d.set!==undefined||!d.get.name.startsWith("get "))return false;for(const value of [null,undefined,{},fake,proxy,Object.create(event),new Event("error")])if(!rejects(()=>d.get.call(value)))return false;}
 if(hooks||!rejects(()=>new ErrorEvent())||!rejects(()=>ErrorEvent("error"))||!rejects(()=>new ErrorEvent("error",1))||!rejects(()=>new ErrorEvent(Symbol())))return false;
 const marker={};let caught;try{new ErrorEvent("error",{get message(){throw marker}})}catch(error){caught=error}
 return caught===marker&&Object.prototype.toString.call(event)==="[object ErrorEvent]";
})()')! == 'true'
}

fn test_native_error_event_wrappers_keep_the_payload_and_saved_prototype() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_event_target_binding()!
	marker := runtime.evaluate_host_value('globalThis.reason={};reason')!
	event := dom.ErrorEvent.create('error', dom.ErrorEventInit{
		message: 'native failure'
		filename: 'native.js'
		lineno: 7
		colno: 11
		error: runtime.event_callback_result(marker)!
	})
	wrapper := runtime.javascript_event(unsafe { &dom.Event(event) })!
	runtime.define_value_host_function('__nativeError', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	assert runtime.evaluate_host(r'globalThis.savedErrorPrototype=ErrorEvent.prototype;globalThis.originalErrorEvent=ErrorEvent;ErrorEvent=function Replacement(){};globalThis.nativeError=__nativeError();nativeError instanceof originalErrorEvent&&Object.getPrototypeOf(nativeError)===savedErrorPrototype&&nativeError.error===reason&&nativeError.message==="native failure"&&nativeError.filename==="native.js"&&nativeError.lineno===7&&nativeError.colno===11&&nativeError.isTrusted')! == 'true'
}
