module main

import browserjs
import dom
import os
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

// How many children a parent's first navigation fetches at once (0: answer
// each navigation separately, the same-binary control).
const navigation_prefetch_limit = if os.getenv('VOX_DISABLE_NAVIGATION_PREFETCH') != '' { 0 } else { 64 }

fn compact_last_child_bootstrap() string {
	return 'const __compactNavigationPrefetchLimit=${navigation_prefetch_limit};' + r'
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
// The document tree version: two little-endian words the native document
// keeps current, read without a host call, or the host function. Versions
// past 2^53 are not exact numbers and disable the caches (-1).
const __compactTreeVersionWords=globalThis.__ladybirdTreeVersionCell instanceof Uint32Array?globalThis.__ladybirdTreeVersionCell:null;
if(__compactTreeVersionWords!==null)delete globalThis.__ladybirdTreeVersionCell;
const __compactTreeVersion=__compactTreeVersionWords!==null?function(){const high=__compactTreeVersionWords[1];return high>=2097152?-1:__compactTreeVersionWords[0]+high*4294967296;}:typeof globalThis.__ladybirdTreeVersion==="function"?globalThis.__ladybirdTreeVersion:null;
// firstChild/lastChild/nextSibling/previousSibling of any node: the last
// answer stands while the document tree is unchanged and no facade edits wait
// to be replayed. React hydration walks server text and elements this way.
function __compactNavigationCache(state,version){
 let cache=state.__navigation;
 if(!cache||cache.version!==version){cache={version,values:{}};Object.defineProperty(state,"__navigation",{value:cache,writable:true,configurable:true});}
 return cache;
}
// The first navigation from a parent asks for its first children at once and
// records the siblings of each, so a walk along them (firstChild, then
// nextSibling) makes one native query instead of one per node.
const __compactNavigationPrefetch=__compactNavigationPrefetchLimit>0?__compactNavigationPrefetchLimit:0;
function __compactPrefetchChildren(state,name,version){
 const children=__queryElements(state.bridgeKey,"childNodes",String(__compactNavigationPrefetch));
 const complete=children.length<__compactNavigationPrefetch;
 const value=name==="firstChild"?(children.length?children[0]:null):complete?(children.length?children[children.length-1]:null):__queryElements(state.bridgeKey,name,"");
 if(__compactHasPendingDOMState()||__compactTreeVersion()!==version)return value;
 const cache=__compactNavigationCache(state,version);
 cache.values.firstChild=children.length?children[0]:null;
 if(complete)cache.values.lastChild=children.length?children[children.length-1]:null;
 for(let index=0;index<children.length;++index){
  const child=__compactNodeState(children[index]);if(!child)continue;
  const values=__compactNavigationCache(child,version).values;
  values.previousSibling=index>0?children[index-1]:null;
  if(index+1<children.length)values.nextSibling=children[index+1];else if(complete)values.nextSibling=null;
 }
 return value;
}
function __compactCachedNavigation(state,name){
 if(__compactTreeVersion!==null&&!__compactHasPendingDOMState()){
  const version=__compactTreeVersion();
  if(version>=0){
   let cache=state.__navigation;
   if(cache&&cache.version===version&&Object.prototype.hasOwnProperty.call(cache.values,name))return cache.values[name];
   if(__compactNavigationPrefetch>0&&(name==="firstChild"||name==="lastChild")&&typeof __compactNodeState==="function")return __compactPrefetchChildren(state,name,version);
   const value=__queryElements(state.bridgeKey,name,"");
   if(__compactHasPendingDOMState()||__compactTreeVersion()!==version)return value;
   if(!cache||cache.version!==version){cache={version,values:{}};Object.defineProperty(state,"__navigation",{value:cache,writable:true,configurable:true});}
   cache.values[name]=value;
   return value;
  }
 }
 return __queryElements(state.bridgeKey,name,"");
}
for(const name of ["firstChild","lastChild","nextSibling","previousSibling"]){
Object.defineProperty(Element.prototype,name,{get:function(){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Node receiver");
 return __compactCachedNavigation(state,name);
},enumerable:true,configurable:true});
}'
}
