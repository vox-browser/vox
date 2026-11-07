module main

// https://drafts.csswg.org/css-transitions/#interface-transitionevent
// https://drafts.csswg.org/css-animations/#interface-animationevent
// https://html.spec.whatwg.org/multipage/interaction.html#commandevent
// Each interface is a native Event whose extra dictionary members are kept
// with the event in the script realm.
fn compact_event_interfaces_bootstrap() string {
	return r'
(function(){
 const records=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 const float=value=>{const number=Number(value);if(!isFinite(number))throw new TypeError("The value must be a finite number");return Math.fround(number);};
 const nullableElement=value=>{if(value===undefined||value===null)return null;if(!(value instanceof Element))throw new TypeError("The value must be an Element or null");return value;};
 for(const [name,members] of [
  ["TransitionEvent",[["elapsedTime",float,0],["propertyName",string,""],["pseudoElement",string,""]]],
  ["AnimationEvent",[["animationName",string,""],["elapsedTime",float,0],["pseudoElement",string,""]]],
  ["CommandEvent",[["command",string,""],["source",nullableElement,null]]]
 ]){
  if(typeof globalThis[name]==="function")continue;
  const constructor={[name]:function(type,init){
   if(!new.target)throw new TypeError(name+" constructor requires new");
   if(arguments.length<1)throw new TypeError(name+" constructor requires one argument");
   if(init!==undefined&&init!==null&&typeof init!=="object"&&typeof init!=="function")throw new TypeError(name+"Init must be an object");
   const values={};
   for(const [member,convert,fallback] of members){const value=init==null?undefined:init[member];values[member]=value===undefined?fallback:convert(value);}
   const event=Reflect.construct(Event,[type,init===null?undefined:init],new.target);
   __elementApply(set,records,[event,values]);
   return event;
  }}[name];
  Object.setPrototypeOf(constructor,Event);
  constructor.prototype=Object.create(Event.prototype,{constructor:{value:constructor,writable:true,configurable:true}});
  Object.defineProperty(constructor,"prototype",{writable:false});
  for(const [member] of members)Object.defineProperty(constructor.prototype,member,{get:function(){const values=__elementApply(get,records,[this]);if(!values)throw new TypeError("Illegal invocation");return values[member];},enumerable:true,configurable:true});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 // Natively dispatched CSS transition and animation events carry their
 // members from the native event.
 Object.defineProperty(globalThis,"__compactAdoptEventMembers",{value:function(event,name,elapsedTime,pseudoElement){
  const values=event instanceof globalThis.TransitionEvent?{propertyName:name,elapsedTime,pseudoElement}:{animationName:name,elapsedTime,pseudoElement};
  __elementApply(set,records,[event,values]);
 }});
})();
'
}
