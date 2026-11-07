module main

import dom
import x.json2

fn compact_member_string(arguments []json2.Any, index int) ?string {
	if index >= arguments.len { return none }
	value := arguments[index]
	if value is json2.Null { return none }
	return value.str()
}

fn (mut binding CompactElementQueryBinding) member_node(value json2.Any) !&dom.Node {
	if value !is map[string]json2.Any { return error('TypeError: Expected a Node') }
	request := value as map[string]json2.Any
	key := json_string_property(request, 'key') or { return error('TypeError: Expected a Node') }
	return binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })
}

// Node and Element members that run the translated DOM algorithms directly:
// namespace lookups, namespaced attributes and adjacent insertion.
fn (mut binding CompactElementQueryBinding) node_member_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid Node operation') }
	mut node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	arguments := if values := request['args'] {
		if values is []json2.Any { values as []json2.Any } else { []json2.Any{} }
	} else {
		[]json2.Any{}
	}
	first := compact_member_string(arguments, 0)
	second := compact_member_string(arguments, 1)
	mut result := map[string]json2.Any{}
	match op {
		'baseURI' { result['value'] = json2.Any(node.base_uri()) }
		'lookupPrefix' { result['value'] = compact_optional_json(node.lookup_prefix(first)) }
		'lookupNamespaceURI' { result['value'] = compact_optional_json(node.lookup_namespace_uri(first)) }
		'isDefaultNamespace' { result['value'] = json2.Any(node.is_default_namespace(first)) }
		'getElementsByTagNameNS' {
			mut parent := unsafe { &dom.ParentNode(node) }
			collection := parent.get_elements_by_tag_name_ns(first, second or { '' })
			mut states := []json2.Any{}
			for matched in collection.collect_matching_elements() {
				states << binding.node_state(matched.as_node())
			}
			result['value'] = json2.Any(states)
		}
		'isSameNode' {
			other := binding.member_node(arguments[0] or { json2.Any(json2.Null{}) })!
			result['value'] = json2.Any(voidptr(other) == voidptr(node))
		}
		else {
			mut element := node.as_element() or { return error('TypeError: Illegal Element receiver') }
			match op {
				'getAttributeNS' {
					result['value'] = compact_optional_json(element.get_attribute_ns(first, second or { '' }))
				}
				'hasAttributeNS' { result['value'] = json2.Any(element.has_attribute_ns(first, second or { '' })) }
				'setAttributeNS' {
					element.set_attribute_ns_for_bindings(first, second or { '' }, compact_member_string(arguments, 2) or { '' })!
					result['refresh'] = binding.mutation_refresh(node.root())
				}
				'removeAttributeNS' {
					element.remove_attribute_ns(first, second or { '' })
					result['refresh'] = binding.mutation_refresh(node.root())
				}
				'insertAdjacentElement' {
					other := binding.member_node(arguments[1] or { json2.Any(json2.Null{}) })!
					inserted_element := other.as_element() or { return error('TypeError: Expected an Element') }
					scope := node.root()
					inserted := element.insert_adjacent_element(first or { '' }, inserted_element)!
					result['value'] = binding.node_state(inserted.as_node())
					result['refresh'] = binding.mutation_refresh(scope)
				}
				'insertAdjacentText' {
					scope := node.root()
					element.insert_adjacent_text(first or { '' }, second or { '' })!
					result['refresh'] = binding.mutation_refresh(scope)
				}
				else { return error('Invalid Node operation') }
			}
		}
	}
	return json2.encode(result)
}

fn compact_optional_json(value ?string) json2.Any {
	if text := value { return json2.Any(text) }
	return json2.Any(json2.Null{})
}

fn compact_element_members_bootstrap() string {
	return r'
(function(){
 const refresh=globalThis.__compactApplyMutationRefresh;
 function fail(error){
  const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));
  if(!match)throw error;
  if(match[1]==="TypeError")throw new TypeError(match[2]);
  throw new DOMException(match[2],match[1]);
 }
 function string(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);}
 function nullable(value){return value===null||value===undefined?null:string(value);}
 function node(value){
  if(value===null||(typeof value!=="object"&&typeof value!=="function"))throw new TypeError("Expected a Node");
  const state=__compactNodeState(value);
  return {key:state.bridgeKey,state:state.created?state:undefined};
 }
 function call(receiver,op,args){
  const state=__compactNodeState(receiver);
  let result;
  try{result=__queryElements(state.bridgeKey,"nodeMember",JSON.stringify({op,args,state:state.created?state:undefined}),true);}catch(error){fail(error);}
  refresh(result);
  return result;
 }
 function required(count,name){if(count)throw new TypeError(name+" requires more arguments");}
 const nodeMembers={
  get baseURI(){return call(this,"baseURI",[]).value;},
  lookupPrefix(namespace){return call(this,"lookupPrefix",[nullable(namespace)]).value;},
  lookupNamespaceURI(prefix){return call(this,"lookupNamespaceURI",[nullable(prefix)]).value;},
  isDefaultNamespace(namespace){return call(this,"isDefaultNamespace",[nullable(namespace)]).value;},
  isSameNode(other){if(other===null||other===undefined)return false;return call(this,"isSameNode",[node(other)]).value;}
 };
 const elementMembers={
  get nodeValue(){__compactNodeState(this);return null;},
  set nodeValue(value){__compactNodeState(this);},
  getAttributeNS(namespace,localName){required(arguments.length<2,"getAttributeNS");return call(this,"getAttributeNS",[nullable(namespace),string(localName)]).value;},
  hasAttributeNS(namespace,localName){required(arguments.length<2,"hasAttributeNS");return call(this,"hasAttributeNS",[nullable(namespace),string(localName)]).value;},
  setAttributeNS(namespace,qualifiedName,value){required(arguments.length<3,"setAttributeNS");call(this,"setAttributeNS",[nullable(namespace),string(qualifiedName),string(value)]);},
  removeAttributeNS(namespace,localName){required(arguments.length<2,"removeAttributeNS");call(this,"removeAttributeNS",[nullable(namespace),string(localName)]);},
  insertAdjacentElement(where,element){required(arguments.length<2,"insertAdjacentElement");const state=call(this,"insertAdjacentElement",[string(where),node(element)]).value;return state?element:null;},
  insertAdjacentText(where,data){required(arguments.length<2,"insertAdjacentText");call(this,"insertAdjacentText",[string(where),string(data)]);},
  getElementsByTagNameNS(namespace,localName){required(arguments.length<2,"getElementsByTagNameNS");return call(this,"getElementsByTagNameNS",[nullable(namespace),string(localName)]).value.map(__queryElement);}
 };
 function install(prototype,members){
  for(const name of Object.getOwnPropertyNames(members)){
   if(Object.prototype.hasOwnProperty.call(prototype,name))continue;
   const descriptor=Object.getOwnPropertyDescriptor(members,name);
   if(typeof descriptor.value==="function")Object.defineProperty(prototype,name,{value:descriptor.value,writable:true,enumerable:true,configurable:true});
   else Object.defineProperty(prototype,name,{get:descriptor.get,set:descriptor.set,enumerable:true,configurable:true});
  }
 }
 install(Element.prototype,nodeMembers);install(Document.prototype,nodeMembers);
 install(Element.prototype,elementMembers);
 if(!Object.prototype.hasOwnProperty.call(Document.prototype,"getElementsByTagNameNS"))Object.defineProperty(Document.prototype,"getElementsByTagNameNS",{value:elementMembers.getElementsByTagNameNS,writable:true,enumerable:true,configurable:true});
})();
'
}
