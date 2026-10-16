module browserjs

// Install before author scripts and record each newly bound media facade with
// __recordMediaAttributes(). Native reflection updates those captured attributes
// as getAttribute()/hasAttribute() without calling author-overridable methods.
// Boolean values add/remove empty attributes; string values retain their raw value.
// The optional qualified-removal flag follows generated boolean reflection.
// The optional captured synchronizer updates ordered compact attribute records;
// two-argument registrations retain the original flat-state adapter.
// General mutation of the compact compiler's exposed state remains unsupported.
pub fn media_element_reflection_bootstrap() string {
	return r'const __recordMediaAttributes=(function(register,records,get,set,apply,define,remove){
 "use strict";
 register(function(receiver,name,value,qualifiedRemoval){
  const record=apply(get,records,[receiver]);
  if(!record)return;
  const state=record.state;
  if(record.synchronize){record.synchronize(state,name,value,qualifiedRemoval);return;}
  if(typeof value==="string"||value)define(state.attributes,name,{value:typeof value==="string"?value:"",writable:true,enumerable:true,configurable:true});
  else remove(state.attributes,name);
  state.attributesDirty=true;
 });
 return function(receiver,state,synchronize){apply(set,records,[receiver,{state:state,synchronize:synchronize}]);};
})(globalThis.__ladybirdMediaElementSetAttributeSync,new WeakMap(),WeakMap.prototype.get,WeakMap.prototype.set,Reflect.apply,Object.defineProperty,Reflect.deleteProperty);
function __createMediaSourceSynchronizer(reflect,sources){
 const own=Object.prototype.hasOwnProperty,apply=Reflect.apply;
 return function(s,name,value,qualifiedRemoval){reflect(s,name,value,qualifiedRemoval);if(name!=="src")return;s.src=s.attributes.src||"";if(s.tagName==="video"&&apply(own,sources,[s.src])){const frame=sources[s.src];if(frame){s.readyState=2;s.videoWidth=frame.width;s.videoHeight=frame.height;s.videoPixels=frame.pixels;s.__videoFrame=null;}}};
}'
}
