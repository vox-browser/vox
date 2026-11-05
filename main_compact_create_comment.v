module main

import dom

fn (mut binding CompactElementQueryBinding) create_comment_query(root &dom.Node, data string) string {
	return binding.encode_node_state(root.document().create_comment(data).as_node())
}

fn compact_create_comment_bootstrap() string {
	return r'
Object.defineProperty(Document.prototype,"createComment",{value:function createComment(data){
 "use strict";
 const state=__compactDocumentState(this);
 if(arguments.length===0)throw new TypeError("createComment requires data");
 if(typeof data==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 return __queryElements(state.bridgeKey,"createComment",String(data));
},writable:true,enumerable:true,configurable:true});
'
}
