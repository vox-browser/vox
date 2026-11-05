module main

import os

const eager_named_elements = os.getenv('VOX_EAGER_NAMED_ELEMENTS') == '1'

// Window exposes elements with an id as named properties. Building a wrapper
// installs dozens of closures and accessors, and a page usually reads few or
// none of its named elements, so an id that names no existing window property
// gets an accessor that builds the wrapper on its first read. The read or an
// assignment replaces the accessor with the ordinary data property. Ids that
// collide with an existing property keep the eager assignment, including the
// repeated assignment for a duplicated id and any setter it reaches.
fn compact_named_elements_bootstrap() string {
	if eager_named_elements {
		return 'const __initialNamedElements=Object.create(null); for (const s of __elementStates()) { if(!s.id)continue; if(!Object.prototype.hasOwnProperty.call(__initialNamedElements,s.id))__initialNamedElements[s.id]=s; try { window[s.id] = __element(__initialNamedElements[s.id]); } catch (_) {} }'
	}
	return r'
const __initialNamedElements=Object.create(null);
{
 const lazy=Object.create(null),own=Object.prototype.hasOwnProperty;
 const settle=function(id,value){Object.defineProperty(window,id,{value:value,writable:true,enumerable:true,configurable:true});};
 for (const s of __elementStates()) {
  if(!s.id)continue;
  const id=s.id;
  if(!own.call(__initialNamedElements,id)){
   __initialNamedElements[id]=s;
   if(!(id in window)){
    const state=s;lazy[id]=true;
    try{Object.defineProperty(window,id,{get:function(){const value=__element(state);settle(id,value);return value;},set:function(value){settle(id,value);},enumerable:true,configurable:true});continue;}catch(_){lazy[id]=false;}
   }
  }else if(lazy[id])continue;
  try { window[id] = __element(__initialNamedElements[id]); } catch (_) {}
 }
}
'
}
