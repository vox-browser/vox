// DOM/Event.idl and DOM/EventTarget.idl actual native platform wrappers.
module browserjs

pub fn event_target_bootstrap() string {
	return r'
(function(){
 const native=__ladybirdEvent,apply=Reflect.apply,create=Object.create,define=Object.defineProperty;
 function call(method,receiver,args){return native(method,receiver,...(args||[]));}
 function EventTarget(){if(!new.target)throw new TypeError("EventTarget constructor requires new");call("constructTarget",this);}
 function Event(type,eventInitDict={}){if(!new.target)throw new TypeError("Event constructor requires new");if(arguments.length<1)throw new TypeError("Event constructor requires one argument");call("constructEvent",this,[type,eventInitDict]);}
 function BeforeUnloadEvent(){throw new TypeError("Illegal constructor");}
 Object.setPrototypeOf(BeforeUnloadEvent,Event);BeforeUnloadEvent.prototype=create(Event.prototype);define(BeforeUnloadEvent.prototype,"constructor",{value:BeforeUnloadEvent,writable:true,configurable:true});
 define(BeforeUnloadEvent,"prototype",{writable:false});define(BeforeUnloadEvent.prototype,"returnValue",{get:function(){return call("getBeforeUnloadReturnValue",this);},set:function(value){call("setBeforeUnloadReturnValue",this,[value]);},enumerable:true,configurable:true});
 define(BeforeUnloadEvent.prototype,Symbol.toStringTag,{value:"BeforeUnloadEvent",configurable:true});
 define(EventTarget,"prototype",{writable:false});define(Event,"prototype",{writable:false});
 for(const property of ["type","target","srcElement","currentTarget","eventPhase","bubbles","cancelable","defaultPrevented","composed","timeStamp"]){define(Event.prototype,property,{get:function(){return call("getEvent",this,[property]);},enumerable:true,configurable:true});}
 for(const property of ["cancelBubble","returnValue"]){define(Event.prototype,property,{get:function(){return call("getEvent",this,[property]);},set:function(value){call("setEvent",this,[property,value]);},enumerable:true,configurable:true});}
 function trusted(value){define(value,"isTrusted",{get:function(){return call("getEvent",this,["isTrusted"]);},enumerable:true,configurable:false});}
 for(const method of ["stopPropagation","stopImmediatePropagation","preventDefault","composedPath"]){define(Event.prototype,method,{value:function(){return call(method,this);},writable:true,enumerable:true,configurable:true});}
 define(Event.prototype,"initEvent",{value:function initEvent(type,bubbles=false,cancelable=false){if(arguments.length<1)throw new TypeError("initEvent requires one argument");return call("initEvent",this,[type,bubbles,cancelable]);},writable:true,enumerable:true,configurable:true});
 define(EventTarget.prototype,"addEventListener",{value:function addEventListener(type,callback,options={}){if(arguments.length<2)throw new TypeError("addEventListener requires two arguments");return call("add",this,[type,callback,options]);},writable:true,enumerable:true,configurable:true});
 define(EventTarget.prototype,"removeEventListener",{value:function removeEventListener(type,callback,options={}){if(arguments.length<2)throw new TypeError("removeEventListener requires two arguments");return call("remove",this,[type,callback,options]);},writable:true,enumerable:true,configurable:true});
 define(EventTarget.prototype,"dispatchEvent",{value:function dispatchEvent(event){if(arguments.length<1)throw new TypeError("dispatchEvent requires one argument");return call("dispatch",this,[event]);},writable:true,enumerable:true,configurable:true});
 for(const [name,value] of [["NONE",0],["CAPTURING_PHASE",1],["AT_TARGET",2],["BUBBLING_PHASE",3]]){define(Event,name,{value,enumerable:true});define(Event.prototype,name,{value,enumerable:true});}
 define(Event.prototype,Symbol.toStringTag,{value:"Event",configurable:true});define(EventTarget.prototype,Symbol.toStringTag,{value:"EventTarget",configurable:true});
 define(globalThis,"Event",{value:Event,writable:true,configurable:true});define(globalThis,"EventTarget",{value:EventTarget,writable:true,configurable:true});
 define(globalThis,"BeforeUnloadEvent",{value:BeforeUnloadEvent,writable:true,configurable:true});
 const eventPrototype=Event.prototype,targetPrototype=EventTarget.prototype;
 const beforeUnloadPrototype=BeforeUnloadEvent.prototype;
 globalThis.__ladybirdEventFactory=function(kind,prototype){return create(prototype|| (kind==="beforeunload"?beforeUnloadPrototype:kind==="event"?eventPrototype:targetPrototype));};
 globalThis.__ladybirdEventDefineTrusted=trusted;
})()
'
}
