module main

import dom
import x.json2

fn (mut binding CompactElementQueryBinding) child_node_query(root &dom.Node, input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	action := json_string_property(request, 'method') or { return error('Missing ChildNode method') }
	values := request['nodes'] or { return error('Missing ChildNode arguments') }
	if values !is []json2.Any { return error('Invalid ChildNode arguments') }
	mut nodes := []dom.NodeOrString{}
	mut connected := root.is_connected()
	for value in values as []json2.Any {
		if value is string {
			nodes << dom.node_or_string_from_string(value)
			continue
		}
		if value !is map[string]json2.Any { return error('Invalid ChildNode argument') }
		state := value as map[string]json2.Any
		key := json_string_property(state, 'bridgeKey') or { return error('Missing Node identity') }
		node := if key == '' {
			binding.document.as_node()
		} else {
			binding.node_for_key(key) or {
				mut elements := binding.elements.clone()
				created := javascript_created_node(root.document(), state, mut elements) or {
					return error('Invalid ChildNode argument')
				}
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
	mut node := unsafe { &dom.Node(root) }
	// Native algorithms retain viable siblings when an argument moves this
	// node or its neighbours, and perform adoption and fragment insertion.
	match action {
		'before' { node.before(nodes)! }
		'after' { node.after(nodes)! }
		'replaceWith' { node.replace_with(nodes)! }
		else { return error('Invalid ChildNode method') }
	}
	if connected { binding.note_node_tree_mutation() }
	return 'null'
}

fn compact_child_node_bootstrap() string {
	return r'
const __compactChildMethods={
 before(){"use strict";__compactChildMutation(this,"before",Array.from(arguments));},
 after(){"use strict";__compactChildMutation(this,"after",Array.from(arguments));},
 replaceWith(){"use strict";__compactChildMutation(this,"replaceWith",Array.from(arguments));}
};
function __compactChildMutation(receiver,method,values){
 const own=__compactNodeState(receiver);
 if(own.nodeType!==undefined&&![1,3,4,7,8,10].includes(own.nodeType))throw new TypeError("Illegal ChildNode receiver");
 const nodes=values.map(value=>{
  const state=__elementApply(__elementRecordGet,__elementRecords,[value])||__elementApply(__compactNodeGet,__compactNodeRecords,[value])||__elementApply(__compactNodeGet,__compactDocuments,[value]);
  if(state)return state;
  if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
  return String(value);
 });
 for(const state of [own,...nodes.filter(value=>typeof value!=="string")])__compactInvalidateContent(state);
 try{__queryElements(own.bridgeKey,"childNodeMutation",JSON.stringify({method,nodes}));}
 catch(error){const match=/^(HierarchyRequestError|NotFoundError|NotSupportedError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}
 for(const state of [own,...nodes.filter(value=>typeof value!=="string")]){
  const parent=__queryElements(state.bridgeKey,"nodeParent","");
  state.parentKey=parent?__compactNodeState(parent).bridgeKey:"";
  state.nativeParent=true;
  if(parent)__compactInvalidateContent(__compactNodeState(parent));
 }
}
function __compactBindChildNode(target){for(const name of ["before","after","replaceWith"])Object.defineProperty(target,name,{value:__compactChildMethods[name],writable:true,enumerable:true,configurable:true});}
__compactBindChildNode(Element.prototype);
const __compactChildUnscopables=Object.assign(Object.create(null),Element.prototype[Symbol.unscopables],{before:true,after:true,replaceWith:true});
Object.defineProperty(Element.prototype,Symbol.unscopables,{value:__compactChildUnscopables,configurable:true});
'
}
