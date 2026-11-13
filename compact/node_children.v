module main

import browserjs
import dom
import x.json2

fn (mut binding CompactElementQueryBinding) node_tree_query(root &dom.Node, action string, value string) !string {
	if action == 'createText' {
		return binding.encode_node_state(root.document().create_text_node(value).as_node())
	}
	if action == 'createFragment' {
		return binding.encode_node_state(root.document().create_document_fragment().as_node())
	}
	if action in ['childNodes', 'childElements'] {
		mut nodes := []json2.Any{cap: root.children.len}
		for child in root.children {
			if action == 'childElements' && !child.is_element() { continue }
			nodes << binding.node_state(child)
		}
		return json2.encode(nodes)
	}
	if action == 'nodeText' { return json2.encode(root.text_content() or { '' }) }
	connected := root.is_connected()
	mut parent := unsafe { &dom.Node(root) }
	if action == 'setNodeText' {
		parent.set_text_content(value)!
	} else {
		request := compact_decode_query[map[string]json2.Any](value)!
		key := json_string_property(request, 'child') or { return error('TypeError: Invalid child node') }
		child := binding.node_for_key(key) or {
			state := request['state'] or { return error('TypeError: Invalid child node') }
			if state !is map[string]json2.Any { return error('TypeError: Invalid child node') }
			mut elements := binding.elements.clone()
			created := javascript_created_node(binding.document, state as map[string]json2.Any, mut elements) or {
				return error('TypeError: Invalid child node')
			}
			for element_key, element in elements {
				binding.elements[element_key] = element
				binding.keys[voidptr(element)] = element_key
			}
			created
		}
		was_connected := child.is_connected()
		if action == 'insertNode' {
			reference_key := json_string_property(request, 'reference') or { '' }
			mut reference := ?&dom.Node(none)
			if reference_key != '' {
				reference = binding.node_for_key(reference_key) or { return error('TypeError: Invalid reference node') }
			}
			parent.pre_insert(child, reference)!
		} else {
			parent.append_child(child)!
		}
		if connected || was_connected { binding.note_node_tree_mutation() }
		return binding.encode_node_state(child)
	}
	if connected { binding.note_node_tree_mutation() }
	return json2.encode(root.text_content() or { '' })
}

fn (mut binding CompactElementQueryBinding) note_node_tree_mutation() {
	mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
	runtime.mark_document_state_dirty()
	runtime.mark_document_replay_effects()
}

fn compact_node_children_bootstrap() string {
	return r'
const __compactChildLists=new WeakMap(),__compactChildReaders=new WeakMap(),__childTreeVersion=globalThis.__ladybirdDOMTreeVersion;
function NodeList(){throw new TypeError("Illegal NodeList constructor");}
Object.defineProperty(globalThis,"NodeList",{value:NodeList,writable:true,configurable:true});
Object.defineProperty(NodeList,"prototype",{writable:false});
Object.defineProperty(NodeList.prototype,Symbol.toStringTag,{value:"NodeList",configurable:true});
function __compactChildRead(receiver){const read=__elementApply(__compactNodeGet,__compactChildReaders,[receiver]);if(!read)throw new TypeError("Illegal NodeList receiver");return read();}
Object.defineProperty(NodeList.prototype,"length",{get:function(){return __compactChildRead(this).length;},enumerable:true,configurable:true});
Object.defineProperty(NodeList.prototype,"item",{value:function item(index){if(arguments.length===0)throw new TypeError("NodeList.item requires an index");const nodes=__compactChildRead(this);return nodes[(+index)>>>0]||null;},writable:true,enumerable:true,configurable:true});
for(const [name,kind] of [["keys",0],["values",1],["entries",2]])Object.defineProperty(NodeList.prototype,name,{value:function(){__compactChildRead(this);let index=0;const owner=this;return{next(){const nodes=__compactChildRead(owner);if(index>=nodes.length)return{done:true,value:undefined};const i=index++;return{done:false,value:kind===0?i:kind===1?nodes[i]:[i,nodes[i]]};},[Symbol.iterator](){return this;}};},writable:true,enumerable:true,configurable:true});
Object.defineProperty(NodeList.prototype,Symbol.iterator,{value:NodeList.prototype.values,writable:true,configurable:true});
Object.defineProperty(NodeList.prototype,"forEach",{value:function forEach(callback,thisArg){const nodes=__compactChildRead(this);if(typeof callback!=="function")throw new TypeError("callback must be callable");for(let i=0;i<nodes.length;i++){const current=__compactChildRead(this);if(i<current.length)callback.call(thisArg,current[i],i,this);}},writable:true,enumerable:true,configurable:true});
function __compactNodeState(node){if(node===document)return{bridgeKey:"",nodeType:9};const state=__elementApply(__elementRecordGet,__elementRecords,[node])||__elementApply(__compactNodeGet,__compactNodeRecords,[node]);if(state)return state;const local=__compactForeignNode(node);if(local)return __compactNodeState(local);throw new TypeError("Expected a Node");}
function __compactForeignNode(node){if(node===null||(typeof node!=="object"&&typeof node!=="function")||typeof __ladybirdForeignNodeState!=="function")return null;const encoded=__ladybirdForeignNodeState(node);return encoded?__queryElement(JSON.parse(encoded)):null;}
function __compactInvalidateContent(state){for(let current=state;current;current=current.parentKey&&__state.elements[current.parentKey]){if(!current.textContentDirty)delete current.textContent;if(!current.innerHTMLDirty)delete current.innerHTML;current.nativeContent=true;}}
function __compactInsertNode(parent,child,reference,insert){const own=__compactNodeState(parent),target=__compactNodeState(child),ref=reference==null?null:__compactNodeState(reference),moving=target.nodeType===11?__queryElements(target.bridgeKey,"childNodes",""):[child],oldParents=moving.map(node=>__state.elements[__compactNodeState(node).parentKey]).filter(Boolean);try{__queryElements(own.bridgeKey,insert?"insertNode":"appendNode",JSON.stringify({child:target.bridgeKey,reference:ref?ref.bridgeKey:"",state:target}));}catch(error){const match=/^(HierarchyRequestError|NotFoundError|NotSupportedError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}for(const state of oldParents)__compactInvalidateContent(state);for(const node of moving){const state=__compactNodeState(node);state.parentKey=own.bridgeKey;state.nativeParent=true;state.removed=false;}__compactInvalidateContent(own);return child;}
function __compactNodeList(read){
 const indexed=key=>typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key)&&Number(key)<4294967295;
 const target=Object.create(NodeList.prototype);
 const list=new Proxy(target,{
  get(target,key,receiver){return indexed(key)?read()[Number(key)]:Reflect.get(target,key,receiver);},
  has(target,key){return indexed(key)?Number(key)<read().length:Reflect.has(target,key);},
  ownKeys(target){return read().map((_,index)=>String(index)).concat(Reflect.ownKeys(target));},
  getOwnPropertyDescriptor(target,key){if(indexed(key)){const node=read()[Number(key)];return node?{value:node,writable:false,enumerable:true,configurable:true}:undefined;}return Reflect.getOwnPropertyDescriptor(target,key);},
  set(target,key,value,receiver){return indexed(key)?false:Reflect.set(target,key,value,receiver);},
  defineProperty(target,key,descriptor){return indexed(key)?false:Reflect.defineProperty(target,key,descriptor);},
  deleteProperty(target,key){return indexed(key)?false:Reflect.deleteProperty(target,key);},
  preventExtensions(){return false;}
 });
 __elementApply(__elementRecordSet,__compactChildReaders,[list,read]);
 return list;
}
function __compactChildNodes(receiver,state){
 const cached=__elementApply(__compactNodeGet,__compactChildLists,[receiver]);if(cached)return cached;
 let version=-1,nodes=[];
 const read=()=>{const current=__childTreeVersion();if(current>=0&&current===version&&!__compactHasPendingDOMState())return nodes;nodes=__queryElements(state.bridgeKey,"childNodes","");version=__childTreeVersion();return nodes;};
 const list=__compactNodeList(read);
 __elementApply(__elementRecordSet,__compactChildLists,[receiver,list]);
 return list;
}
const __compactArrayQuery=__queryElements;
__queryElements=function(key,action,selector,raw){
 const result=__compactArrayQuery(key,action,selector,raw);
 return !raw&&action==="querySelectorAll"?__compactNodeList(()=>result):result;
};
Object.defineProperty(Element.prototype,"childNodes",{get:function(){return __compactChildNodes(this,__compactNodeState(this));},enumerable:true,configurable:true});
Object.defineProperty(document,"childNodes",{get:function(){if(this!==document)throw new TypeError("Illegal Document receiver");return __compactChildNodes(this,{bridgeKey:""});},enumerable:true,configurable:true});
document.createDocumentFragment=function createDocumentFragment(){return __queryElements("","createFragment","");};
document.createTextNode=function createTextNode(data){if(arguments.length===0)throw new TypeError("createTextNode requires data");if(typeof data==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return __queryElements("","createText",String(data));};
// Elements and other node wrappers install their own tree methods. These keep
// documents, including created XML documents, on the same native operations.
for(const [name,value] of Object.entries({
 appendChild(child){if(arguments.length<1)throw new TypeError("appendChild requires a Node");return __compactInsertNode(this,child,null,false);},
 insertBefore(child,reference){if(arguments.length<2)throw new TypeError("insertBefore requires two arguments");return __compactInsertNode(this,child,reference,true);},
 removeChild(child){
  const own=__compactNodeState(this),target=__compactNodeState(child);
  try{__queryElements(own.bridgeKey,"removeChild",target.bridgeKey);}
  catch(error){const message=String(error.message);if(message.indexOf("NotFoundError:")===0)throw new DOMException(message.slice(14).trim(),"NotFoundError");throw error;}
  if(target.tagName&&target.tagName!=="#node"){target.parentKey="";target.removed=true;}
  return child;
 },
 cloneNode(deep){return __queryElements(__compactNodeState(this).bridgeKey,"cloneNode",deep?"deep":"shallow");},
 hasChildNodes(){__compactNodeState(this);return this.firstChild!==null;}
}))if(!Object.prototype.hasOwnProperty.call(Node.prototype,name))Object.defineProperty(Node.prototype,name,{value,writable:true,enumerable:true,configurable:true});
' + compact_child_node_bootstrap() + compact_fragment_elements_bootstrap() + compact_create_comment_bootstrap() + compact_parent_node_bootstrap() + compact_shadow_root_bootstrap() + compact_selector_matches_bootstrap() + compact_selector_first_bootstrap()
}
