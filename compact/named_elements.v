module main

import css
import os
import platform
import strings
import x.json2

const eager_named_elements = os.getenv('VOX_EAGER_NAMED_ELEMENTS') == '1'

// Parser progress changes the set of names after the compact realm has been
// initialized. Return identities only: discovering a name must not hydrate its
// element or build a wrapper. Attribute changes matter independently of tree
// changes, and strings preserve the full width of both version counters.
fn (mut binding CompactElementQueryBinding) named_elements_query(previous_version string) string {
	mut reply := platform.ThreadScratchScope{}
	$if prealloc {
		if binding.temporary_reply_enabled && binding.document.native_storage() != unsafe { nil } {
			reply = platform.begin_thread_scratch('compact named elements reply')
			binding.reply_workspace = reply
		}
	}
	defer { reply.leave() }
	version := '${binding.document.dom_tree_version()}:${binding.document.attribute_version()}'
	if previous_version == version {
		return '{"version":${json2.encode(version)},"elements":null}'
	}
	elements := css.query_selector_all(binding.document.as_node(), '[id]')
	mut output := strings.new_builder(elements.len * 48 + 64)
	output.write_string('{"version":${json2.encode(version)},"elements":[')
	mut count := 0
	for element in elements {
		id := element.get_attribute_value('id')
		if id == '' { continue }
		// The reply is temporary; newly registered bridge keys belong to the
		// document and remain valid when a lazy accessor is read later.
		mut retained := platform.enter_retained_allocations()
		key := binding.element_key(element)
		retained.finish()
		if count > 0 { output.write_u8(`,`) }
		output.write_string('{"id":${json2.encode(id)},"bridgeKey":${json2.encode(key)}}')
		count++
	}
	output.write_string(']}')
	return output.str()
}

// Window exposes elements with an id as named properties. Building a wrapper
// installs dozens of closures and accessors, and a page usually reads few or
// none of its named elements, so an id that names no existing window property
// gets an accessor that builds the wrapper on its first read. The read or an
// assignment replaces the accessor with the ordinary data property. Ids that
// collide with an existing property keep the eager assignment, including the
// repeated assignment for a duplicated id and any setter it reaches.
fn compact_named_elements_bootstrap() string {
	mut bootstrap := ''
	if eager_named_elements {
		bootstrap = 'const __initialNamedElements=Object.create(null); for (const s of __elementStates()) { if(!s.id)continue; if(!Object.prototype.hasOwnProperty.call(__initialNamedElements,s.id))__initialNamedElements[s.id]=s; try { window[s.id] = __element(__initialNamedElements[s.id]); } catch (_) {} }'
	} else {
		bootstrap = r'
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
	return bootstrap + r'
{
 const own=Object.prototype.hasOwnProperty,define=Object.defineProperty;
 const settle=function(id,value){define(window,id,{value:value,writable:true,enumerable:true,configurable:true});};
 let version="";
 define(window,"__ladybirdRefreshNamedElements",{value:function(){
  const snapshot=__queryElements("","namedElements",version,true);
  version=snapshot.version;
  if(snapshot.elements===null)return;
  for(const record of snapshot.elements){
   const id=record.id;
   if(own.call(__initialNamedElements,id))continue;
   __initialNamedElements[id]=record;
   // Previously exposed names stay settled or deleted. A new parser name
   // must also preserve an author property installed by an earlier script.
   if(id in window)continue;
   try{define(window,id,{get:function(){const value=__queryElements(record.bridgeKey,"state","");settle(id,value);return value;},set:function(value){settle(id,value);},enumerable:true,configurable:true});}catch(_){}
  }
 },writable:false,enumerable:false,configurable:false});
}
'
}
