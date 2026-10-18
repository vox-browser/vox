module main

import browserjs
import dom
import x.json2

fn (mut binding CompactElementQueryBinding) node_state(node &dom.Node) json2.Any {
	if element := node.as_element() { return binding.element_state(element) }
	key := '__node_${node.unique_id()}'
	binding.nodes[key] = node
	return json2.Any({
		'bridgeKey': json2.Any(key)
		'nodeType':  json2.Any(int(node.node_type_value()))
		'nodeName':  json2.Any(node.node_name())
		'tagName':   json2.Any('#node')
		'id':        json2.Any('')
	})
}

fn (mut binding CompactElementQueryBinding) node_relation_query(root &dom.Node, relation string) string {
	node := match relation {
		'first' { root.first_child() }
		'last' { root.last_child() }
		'next' { root.next_sibling() }
		'previous' { root.previous_sibling() }
		else { root.parent() }
	}
	return if found := node { json2.encode(binding.node_state(found)) } else { 'null' }
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
function __compactNodeWrapper(state){
 if(state.nodeType===9)return document;
 if(state.tagName!=="#node")return __element(state);
 if(state.__object)return state.__object;
 const node={};
 function record(receiver){const own=__elementApply(__compactNodeGet,__compactNodeRecords,[receiver]);if(!own)throw new TypeError("Illegal Node receiver");return own;}
 function read(){return __queryElements(record(this).bridgeKey,"nodeValue","");}
 function write(receiver,value,nullable){const own=record(receiver);if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");__queryElements(own.bridgeKey,"setNodeValue",nullable&&value===null?"":String(value));}
 Object.defineProperties(node,{
  __state:{value:state},nodeType:{value:state.nodeType},nodeName:{value:state.nodeName},ownerDocument:{value:document},
  parentNode:{get(){return __queryElements(record(this).bridgeKey,"nodeParent","");}},
  parentElement:{get(){const parent=this.parentNode;return parent&&parent.nodeType===1?parent:null;}},
  firstChild:{value:null},lastChild:{value:null},
  nextSibling:{get(){return __queryElements(record(this).bridgeKey,"nextSibling","");}},
  previousSibling:{get(){return __queryElements(record(this).bridgeKey,"previousSibling","");}},
  __firstChildOf:{get(){const parent=this.parentNode;return parent&&parent.nodeType===1&&parent.firstChild===this?parent.__state.bridgeKey:undefined;}},
  nodeValue:{get:read,set(value){write(this,value,true);}},textContent:{get:read,set(value){write(this,value,true);}},
  data:{get:read,set(value){write(this,value,false);}},length:{get(){return __elementApply(read,this,[]).length;}},
  cloneNode:{value:function cloneNode(deep){return __queryElements(record(this).bridgeKey,"cloneNode",deep?"deep":"shallow");}}
 });
 __elementApply(__elementRecordSet,__compactNodeRecords,[node,state]);
 Object.defineProperty(state,"__object",{value:node});
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
