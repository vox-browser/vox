module main

import dom
import x.json2

fn (mut binding CompactElementQueryBinding) tag_collection_query(root &dom.Node, input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	name := json_string_property(request, 'name') or { return error('Missing tag name') }
	version := binding.document.dom_tree_version().str()
	// Iterating an unchanged live collection must not serialize every member for
	// every indexed read. Pending script writes have already been replayed here;
	// native insertions and removals also advance the document's tree version.
	if (json_string_property(request, 'version') or { '' }) == version {
		return json2.encode({
			'version':  json2.Any(version)
			'elements': json2.Any(json2.Null{})
		})
	}
	mut parent := unsafe { &dom.ParentNode(root) }
	collection := parent.get_elements_by_tag_name(name)
	mut result := []json2.Any{}
	for element in collection.collect_matching_elements() {
		result << binding.element_state(element)
	}
	return json2.encode({
		'version':  json2.Any(version)
		'elements': json2.Any(result)
	})
}

fn compact_tag_collection_bootstrap() string {
	return r'
const __tagTreeVersion=globalThis.__ladybirdDOMTreeVersion;
function __tagCollection(key,name){
 let version="",elements=[];
 return __classCollection(key,"",()=>{
  if(version!==""&&__state.operations.length===0&&__dirtyElementStates.size===0&&__tagTreeVersion("")===version)return elements;
  const snapshot=__queryElements(key,"getElementsByTagName",JSON.stringify({name,version}));
  if(snapshot.elements!==null){elements=snapshot.elements.map(__queryElement);version=snapshot.version;}
  return elements;
 });
}
Object.defineProperty(Element.prototype,"getElementsByTagName",{value:function getElementsByTagName(name){
 "use strict";
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Element receiver");
 if(arguments.length===0)throw new TypeError("getElementsByTagName requires a name");
 if(typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 name=String(name);
 return __tagCollection(state.bridgeKey,name);
},writable:true,enumerable:true,configurable:true});
document.getElementsByTagName=function getElementsByTagName(name){
 "use strict";
 if(this!==document)throw new TypeError("Illegal Document receiver");
 if(arguments.length===0)throw new TypeError("getElementsByTagName requires a name");
 if(typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 name=String(name);
 return __tagCollection("",name);
};'
}
