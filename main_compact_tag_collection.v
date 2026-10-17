module main

import dom
import x.json2

fn (mut binding CompactElementQueryBinding) tag_collection_query(root &dom.Node, name string) string {
	mut parent := unsafe { &dom.ParentNode(root) }
	collection := parent.get_elements_by_tag_name(name)
	mut result := []json2.Any{}
	for element in collection.collect_matching_elements() {
		result << binding.element_state(element)
	}
	return json2.encode(result)
}

fn compact_tag_collection_bootstrap() string {
	return r'
Object.defineProperty(Element.prototype,"getElementsByTagName",{value:function getElementsByTagName(name){
 "use strict";
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Element receiver");
 if(arguments.length===0)throw new TypeError("getElementsByTagName requires a name");
 if(typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 name=String(name);
 return __classCollection(state.bridgeKey,"",()=>__queryElements(state.bridgeKey,"getElementsByTagName",name));
},writable:true,enumerable:true,configurable:true});
document.getElementsByTagName=function getElementsByTagName(name){
 "use strict";
 if(this!==document)throw new TypeError("Illegal Document receiver");
 if(arguments.length===0)throw new TypeError("getElementsByTagName requires a name");
 if(typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 name=String(name);
 return __classCollection("","",()=>__queryElements("","getElementsByTagName",name));
};'
}
