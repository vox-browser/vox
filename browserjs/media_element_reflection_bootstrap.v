module browserjs

// Install before author scripts and record each newly bound media facade with
// __recordMediaAttributes(). Native reflection updates those captured attributes
// as getAttribute()/hasAttribute() without calling author-overridable methods.
// Boolean values add/remove empty attributes; string values retain their raw value.
// General mutation of the compact compiler's exposed state remains unsupported.
pub fn media_element_reflection_bootstrap() string {
	return r'const __recordMediaAttributes=(function(register,records,get,set,apply,define,remove){
 "use strict";
 register(function(receiver,name,value){
  const state=apply(get,records,[receiver]);
  if(!state)return;
  if(typeof value==="string"||value)define(state.attributes,name,{value:typeof value==="string"?value:"",writable:true,enumerable:true,configurable:true});
  else remove(state.attributes,name);
  state.attributesDirty=true;
 });
 return function(receiver,state){apply(set,records,[receiver,state]);};
})(globalThis.__ladybirdMediaElementSetAttributeSync,new WeakMap(),WeakMap.prototype.get,WeakMap.prototype.set,Reflect.apply,Object.defineProperty,Reflect.deleteProperty);'
}
