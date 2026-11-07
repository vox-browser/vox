module main

import dom
import x.json2

fn (mut binding CompactElementQueryBinding) parent_node_query(root &dom.Node, input string) !string {
	if !root.is_parent_node() { return error('TypeError: Illegal ParentNode receiver') }
	request := json2.decode[map[string]json2.Any](input)!
	action := json_string_property(request, 'method') or { return error('Missing ParentNode method') }
	values := request['nodes'] or { return error('Missing ParentNode arguments') }
	if values !is []json2.Any { return error('Invalid ParentNode arguments') }
	mut nodes := []dom.NodeOrString{}
	mut connected := root.is_connected()
	for value in values as []json2.Any {
		if value is string {
			nodes << dom.node_or_string_from_string(value)
			continue
		}
		if value !is map[string]json2.Any { return error('Invalid ParentNode argument') }
		state := value as map[string]json2.Any
		key := json_string_property(state, 'bridgeKey') or { return error('Missing Node identity') }
		node := if key == '' {
			binding.document.as_node()
		} else {
			binding.node_for_key(key) or {
				mut elements := binding.elements.clone()
				created := javascript_created_node(root.document(), state, mut elements) or { return error('Invalid ParentNode argument') }
				for element_key, element in elements {
					binding.elements[element_key] = element
					binding.keys[voidptr(element)] = element_key
				}
				created
			}
		}
		connected = connected || node.is_connected()
		nodes << dom.node_or_string_from_node(node)
	}
	mut parent := unsafe { &dom.ParentNode(root) }
	match action {
		'append' { parent.append(nodes)! }
		'prepend' { parent.prepend(nodes)! }
		'replaceChildren' { parent.replace_children(nodes)! }
		else { return error('Invalid ParentNode method') }
	}
	if connected { binding.note_node_tree_mutation() }
	return 'null'
}

fn compact_parent_node_bootstrap() string {
	return r'
const __compactParentMethods={
 append(){"use strict";__compactParentMutation(this,"append",Array.from(arguments));},
 prepend(){"use strict";__compactParentMutation(this,"prepend",Array.from(arguments));},
 replaceChildren(){"use strict";__compactParentMutation(this,"replaceChildren",Array.from(arguments));}
};
function __compactParentMutation(receiver,method,values){
 const own=__compactNodeState(receiver);
 if(own.nodeType!==undefined&&![1,9,11].includes(own.nodeType))throw new TypeError("Illegal ParentNode receiver");
 const nodes=values.map(value=>{
  const state=__elementApply(__elementRecordGet,__elementRecords,[value])||__elementApply(__compactNodeGet,__compactNodeRecords,[value])||__elementApply(__compactNodeGet,__compactDocuments,[value]);
  if(state)return state;
  if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
  return String(value);
 });
 const touched=[own,...nodes.filter(value=>typeof value!=="string")];
 for(const state of touched)__compactInvalidateContent(state);
 try{__queryElements(own.bridgeKey,"parentNodeMutation",JSON.stringify({method,nodes}));}
 catch(error){const match=/^(HierarchyRequestError|NotFoundError|NotSupportedError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}
 for(const state of touched){
  const parent=__queryElements(state.bridgeKey,"nodeParent","");
  state.parentKey=parent?__compactNodeState(parent).bridgeKey:"";
  state.removed=!parent;
  state.nativeParent=true;
  if(parent)__compactInvalidateContent(__compactNodeState(parent));
 }
}
for(const target of [Element.prototype,Document.prototype,DocumentFragment.prototype]){
 for(const name of ["append","prepend","replaceChildren"])Object.defineProperty(target,name,{value:__compactParentMethods[name],writable:true,enumerable:true,configurable:true});
 Object.defineProperty(target,Symbol.unscopables,{value:Object.assign(Object.create(null),target[Symbol.unscopables],{append:true,prepend:true,replaceChildren:true}),configurable:true});
}
'
}
