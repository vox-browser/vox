module main

import dom
import x.json2

fn (mut binding CompactElementQueryBinding) insert_adjacent_html_query(root &dom.Node, input string) !string {
	mut element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
	request := json2.decode[map[string]json2.Any](input)!
	position := json_string_property(request, 'position') or { return error('TypeError: Missing insertion position') }
	markup := json_string_property(request, 'markup') or { return error('TypeError: Missing insertion markup') }
	element.insert_adjacent_html(position, markup)!
	if root.is_connected() { binding.note_node_tree_mutation() }
	return 'null'
}

fn compact_insert_adjacent_html_bootstrap() string {
	return r'
const __insertAdjacentHTML={insertAdjacentHTML(position,text){
 "use strict";
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Element receiver");
 if(arguments.length<2)throw new TypeError("insertAdjacentHTML requires two arguments");
 if(typeof position==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 position=String(position);
 if(typeof text==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 text=String(text);
 try{__queryElements(state.bridgeKey,"insertAdjacentHTML",JSON.stringify({position:position,markup:text}));}
 catch(error){const match=/^(NoModificationAllowedError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}
 __compactInvalidateContent(state);
 state.hasChildren=__queryElements(state.bridgeKey,"lastChild","")!==null;
 const parent=__queryElements(state.bridgeKey,"nodeParent","");
 if(parent&&parent!==document)__compactInvalidateContent(__compactNodeState(parent));
}};
Object.defineProperty(Element.prototype,"insertAdjacentHTML",{value:__insertAdjacentHTML.insertAdjacentHTML,writable:true,enumerable:true,configurable:true});
'
}
