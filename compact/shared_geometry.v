module main

import os

const disable_shared_element_geometry = os.getenv('VOX_DISABLE_SHARED_ELEMENT_GEOMETRY') == '1'

// Reuse accessor functions and descriptor records while keeping each wrapper's
// own properties, flags and live native queries. This also keeps the receiver
// check ahead of observable numeric conversion in scroll setters.
fn compact_element_geometry_bindings() string {
	// CSSOM View returns a fresh, mutable DOMRect, including its inherited
	// serialization API. Capture the intrinsic before author code can replace it.
	rectangle := r'
const __compactBoundingRectConstructor=globalThis.DOMRect;
function __compactBoundingRect(value){return new __compactBoundingRectConstructor(value.x,value.y,value.width,value.height);}
'
	if disable_shared_element_geometry {
		return rectangle + r'
function __compactElementGeometry(object,state){
 const read=function(receiver,name){const own=__elementApply(__elementRecordGet,__elementRecords,[receiver]);if(!own)throw new TypeError("Illegal Element receiver");return __queryElements(own.bridgeKey,"geometry",name);};
 object.getBoundingClientRect=function getBoundingClientRect(){return __compactBoundingRect(read(this,"rect"));};
 for(const name of ["clientTop","clientLeft","clientWidth","clientHeight","scrollWidth","scrollHeight"]){
  Object.defineProperty(object,name,{get(){return read(this,name);},enumerable:true,configurable:true});
 }
 for(const name of ["scrollTop","scrollLeft"]){
  Object.defineProperty(object,name,{get(){return read(this,name);},set(value){
   const own=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!own)throw new TypeError("Illegal Element receiver");
   value=+value;if(!__compactScrollFinite(value))value=0;
   __queryElements(own.bridgeKey,"setScroll",JSON.stringify({name,value}));
  },enumerable:true,configurable:true});
 }
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml")return;
 for(const name of ["offsetTop","offsetLeft","offsetWidth","offsetHeight"]){
  Object.defineProperty(object,name,{get(){return read(this,name);},enumerable:true,configurable:true});
 }
 Object.defineProperty(object,"offsetParent",{get(){return __queryElements(state.bridgeKey,"offsetParent","");},enumerable:true,configurable:true});
}
'
	}
	return rectangle + r'
function __compactReadElementGeometry(receiver,name){
 const own=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
 if(!own)throw new TypeError("Illegal Element receiver");
 return __queryElements(own.bridgeKey,"geometry",name);
}
const __compactGeometryDescriptors={getBoundingClientRect:{
 value:function getBoundingClientRect(){return __compactBoundingRect(__compactReadElementGeometry(this,"rect"));},
 writable:true,enumerable:true,configurable:true
}},__compactOffsetDescriptors={};
for(const name of ["clientTop","clientLeft","clientWidth","clientHeight","scrollWidth","scrollHeight"]){
 __compactGeometryDescriptors[name]={get(){return __compactReadElementGeometry(this,name);},enumerable:true,configurable:true};
}
for(const name of ["scrollTop","scrollLeft"]){
 __compactGeometryDescriptors[name]={get(){return __compactReadElementGeometry(this,name);},set(value){
  const own=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!own)throw new TypeError("Illegal Element receiver");
  value=+value;if(!__compactScrollFinite(value))value=0;
  __queryElements(own.bridgeKey,"setScroll",JSON.stringify({name,value}));
 },enumerable:true,configurable:true};
}
for(const name of ["offsetTop","offsetLeft","offsetWidth","offsetHeight"]){
 __compactOffsetDescriptors[name]={get(){return __compactReadElementGeometry(this,name);},enumerable:true,configurable:true};
}
function __compactElementGeometry(object,state){
 Object.defineProperties(object,__compactGeometryDescriptors);
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml")return;
 Object.defineProperties(object,__compactOffsetDescriptors);
 // Retain the existing owner-bound offsetParent accessor separately.
 Object.defineProperty(object,"offsetParent",{get(){return __queryElements(state.bridgeKey,"offsetParent","");},enumerable:true,configurable:true});
}
'
}
