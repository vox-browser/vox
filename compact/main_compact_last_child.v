module main

import browserjs
import dom
import x.json2

fn (mut binding CompactElementQueryBinding) node_state(node &dom.Node) json2.Any {
	if node.is_document() { return binding.document_state(node.document()) }
	if element := node.as_element() { return binding.element_state(element) }
	key := '__node_${node.unique_id()}'
	binding.nodes[key] = node
	mut parent_key := ''
	if parent := node.parent() {
		if element := parent.as_element() {
			parent_key = binding.element_key(element)
		} else if !parent.is_document() {
			parent_key = '__node_${parent.unique_id()}'
			binding.nodes[parent_key] = parent
		}
	}
	mut state := {
		'bridgeKey': json2.Any(key)
		'nodeType':  json2.Any(int(node.node_type_value()))
		'nodeName':  json2.Any(node.node_name())
		'tagName':   json2.Any('#node')
		'parentKey': json2.Any(parent_key)
		'id':        json2.Any('')
	}
	if node.is_shadow_root() { state['isShadowRoot'] = json2.Any(true) }
	return json2.Any(state)
}

fn (mut binding CompactElementQueryBinding) node_relation_query(root &dom.Node, relation string) string {
	node := match relation {
		'first' { root.first_child() }
		'last' { root.last_child() }
		'next' { root.next_sibling() }
		'previous' { root.previous_sibling() }
		else { root.parent() }
	}
	return if found := node { binding.encode_node_state(found) } else { 'null' }
}

// Only connected owners in this realm's document can use its mutation clock.
// Removing a connected node invalidates that clock before adoption elsewhere.
fn (mut binding CompactElementQueryBinding) cached_parent_query(root &dom.Node) string {
	parent := if found := root.parent() { binding.node_state(found) } else { json2.Any(json2.Null{}) }
	return json2.encode({
		'parent': parent
		'cacheable': json2.Any(root.is_connected() && voidptr(root.document()) == voidptr(binding.document))
	})
}

fn (mut binding CompactElementQueryBinding) node_value_query(root &dom.Node, action string, value string) !string {
	if action == 'setNodeValue' {
		mut node := unsafe { &dom.Node(root) }
		node.set_node_value(value)!
		mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
		runtime.mark_document_state_dirty()
		runtime.mark_document_replay_effects()
	}
	return json2.encode(root.node_value() or { '' })
}

fn compact_last_child_bootstrap() string {
	return r'
const __compactNodeRecords=new WeakMap(),__compactNodeGet=WeakMap.prototype.get;
const __compactBindNodeTarget=typeof globalThis.__ladybirdBindNodeEventTarget==="function"?globalThis.__ladybirdBindNodeEventTarget:null;
if(typeof globalThis.__ladybirdNodeEventTargetSetResolver==="function")globalThis.__ladybirdNodeEventTargetSetResolver(function(json){return __queryElement(JSON.parse(json));});
function DocumentFragment(){if(!new.target)throw new TypeError("DocumentFragment requires new");return __queryElements("","createFragment","");}
Object.setPrototypeOf(DocumentFragment,Node);Object.setPrototypeOf(DocumentFragment.prototype,Node.prototype);
Object.defineProperty(DocumentFragment,"prototype",{writable:false});
Object.defineProperty(DocumentFragment.prototype,Symbol.toStringTag,{value:"DocumentFragment",configurable:true});
Object.defineProperty(globalThis,"DocumentFragment",{value:DocumentFragment,writable:true,configurable:true});
' + compact_node_properties_bootstrap() + r'
function __compactNodeWrapper(state){
 if(state.nodeType===9)return __compactDocumentWrapper(state);
 if(state.tagName!=="#node")return __element(state);
 if(state.__object)return state.__object;
 const node=Object.create(state.isShadowRoot?ShadowRoot.prototype:state.nodeType===11?DocumentFragment.prototype:(__compactCharacterPrototype(state.nodeType)||Node.prototype));
 __compactInstallNodeProperties(node,state);
 __elementApply(__elementRecordSet,__compactNodeRecords,[node,state]);
 Object.defineProperty(state,"__object",{value:node});
 if(__compactBindNodeTarget)__compactBindNodeTarget(node,state.bridgeKey);
 if([3,4,7,8,10].includes(state.nodeType))__compactBindChildNode(node);
 if(state.nodeType===11)for(const name of ["querySelector","querySelectorAll"]){
  Object.defineProperty(node,name,{value:function(selectors){const own=__compactSharedNodeRecord(this);if(arguments.length===0)throw new TypeError(name+" requires a selector");if(typeof selectors==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return __queryElements(own.bridgeKey,name,String(selectors));}});
 }
 return node;
}
for(const name of ["firstChild","lastChild","nextSibling","previousSibling"]){
Object.defineProperty(Element.prototype,name,{get:function(){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Node receiver");
 return __queryElements(state.bridgeKey,name,"");
},enumerable:true,configurable:true});
}'
}
