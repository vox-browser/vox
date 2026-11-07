module main

import browserjs
import dom
import x.json2

fn (mut binding CompactElementQueryBinding) remove_child_query(root &dom.Node, key string) !string {
	child := binding.node_for_key(key) or { return error('TypeError: Invalid child node') }
	mut parent := unsafe { &dom.Node(root) }
	parent.remove_child(child)!
	mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
	runtime.mark_document_state_dirty()
	runtime.mark_document_replay_effects()
	return json2.encode(parent.has_children())
}

fn compact_remove_child_bootstrap() string {
	return r'
Object.defineProperty(Element.prototype,"removeChild",{value:function removeChild(child){
 "use strict";
 const parent=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!parent)throw new TypeError("Illegal Node receiver");
	 const state=__elementApply(__elementRecordGet,__elementRecords,[child])||__elementApply(__compactNodeGet,__compactNodeRecords,[child]);
 if(!state)throw new TypeError("removeChild requires a Node");
 try{parent.hasChildren=__queryElements(parent.bridgeKey,"removeChild",state.bridgeKey);}
 catch(error){const message=String(error.message);if(message.indexOf("NotFoundError:")===0)throw new DOMException(message.slice(14).trim(),"NotFoundError");throw error;}
 state.parentKey="";state.removed=true;
 return child;
},writable:true,enumerable:true,configurable:true});'
}
