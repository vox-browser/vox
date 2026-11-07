module main

import dom
import x.json2

// https://dom.spec.whatwg.org/#interface-nodeiterator
// The native NodeIterator is registered with its document, so node removal
// keeps its reference and its traversal pointer current. Traversal and the
// filter callback run in the script realm, like TreeWalker.
fn (mut binding CompactElementQueryBinding) node_iterator_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid NodeIterator operation') }
	if op == 'create' {
		root := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
		what := request['whatToShow'] or { json2.Any(0) }
		iterator := dom.NodeIterator.create(root, u32(what.u64()), none)
		binding.next_key++
		iterator_key := '__iterator_${binding.next_key}'
		binding.node_iterators[iterator_key] = iterator
		return json2.encode(iterator_key)
	}
	iterator_key := json_string_property(request, 'iterator') or { return error('TypeError: Illegal NodeIterator receiver') }
	mut iterator := binding.node_iterators[iterator_key] or { return error('TypeError: Illegal NodeIterator receiver') }
	match op {
		'reference' {
			return json2.encode({
				'node':   binding.node_state(iterator.reference_node())
				'before': json2.Any(iterator.pointer_before_reference_node())
			})
		}
		'begin' {
			iterator.traversal_pointer = dom.NodePointer{
				node:           iterator.reference_node()
				is_before_node: iterator.pointer_before_reference_node()
			}
		}
		'setPointer' {
			node_key := json_string_property(request, 'node') or { return error('TypeError: Expected a Node') }
			node := binding.equality_node(node_key, request['state'] or { json2.Any(json2.Null{}) })!
			before := request['before'] or { json2.Any(false) }
			iterator.traversal_pointer = dom.NodePointer{
				node:           node
				is_before_node: before is bool && before as bool
			}
		}
		'commit' {
			if pointer := iterator.traversal_pointer {
				iterator.reference_node_ = pointer.node
				iterator.pointer_before_reference_node_ = pointer.is_before_node
			}
			iterator.traversal_pointer = none
		}
		'abort' {
			iterator.traversal_pointer = none
		}
		'pointer' {}
		else {
			return error('Invalid NodeIterator operation')
		}
	}
	pointer := iterator.traversal_pointer or {
		return json2.encode({
			'node':   binding.node_state(iterator.reference_node())
			'before': json2.Any(iterator.pointer_before_reference_node())
		})
	}
	return json2.encode({
		'node':   binding.node_state(pointer.node)
		'before': json2.Any(pointer.is_before_node)
	})
}

// Runs after the TreeWalker bootstrap, sharing its filter invocation.
fn compact_node_iterator_bootstrap() string {
	return r'
(function(){
 const iterators=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 function NodeIterator(){throw new TypeError("Illegal NodeIterator constructor");}
 Object.defineProperty(NodeIterator,"prototype",{writable:false});
 Object.defineProperty(NodeIterator.prototype,Symbol.toStringTag,{value:"NodeIterator",configurable:true});
 Object.defineProperty(globalThis,"NodeIterator",{value:NodeIterator,writable:true,configurable:true});
 function record(receiver){const state=__elementApply(get,iterators,[receiver]);if(!state)throw new TypeError("Illegal NodeIterator receiver");return state;}
 function native(state,op,fields){return __queryElements("","nodeIterator",JSON.stringify(Object.assign({op,iterator:state.key},fields||{})),true);}
 const relative=(node,relation)=>__compactWalkRelative(node,relation);
 function following(node,root){
  const child=relative(node,"firstChild");if(child)return child;
  for(let current=node;current&&current!==root;current=relative(current,"nodeParent")){const sibling=relative(current,"nextSibling");if(sibling)return sibling;}
  return null;
 }
 function preceding(node,root){
  if(node===root)return null;
  let sibling=relative(node,"previousSibling");
  if(!sibling)return relative(node,"nodeParent");
  for(let child=relative(sibling,"lastChild");child;child=relative(sibling,"lastChild"))sibling=child;
  return sibling;
 }
 function pointer(state,result){return {node:__queryElement(result.node),before:result.before};}
 function traverse(receiver,next){
  "use strict";
  const state=record(receiver);
  let current=pointer(state,native(state,"begin"));
  try{
   while(true){
    if(next){
     if(!current.before){const node=following(current.node,state.root);if(!node){native(state,"abort");return null;}current.node=node;}
     else current.before=false;
    }else{
     if(current.before){const node=preceding(current.node,state.root);if(!node){native(state,"abort");return null;}current.node=node;}
     else current.before=true;
    }
    const target=__compactNodeState(current.node);
    native(state,"setPointer",{node:target.bridgeKey,state:target.created?target:undefined,before:current.before});
    const result=__compactWalkFilter(state,current.node);
    current=pointer(state,native(state,"pointer"));
    if(result===1)break;
   }
  }catch(error){native(state,"abort");throw error;}
  native(state,"commit");
  return current.node;
 }
 const methods={
  nextNode(){return traverse(this,true);},
  previousNode(){return traverse(this,false);},
  detach(){record(this);}
 };
 for(const [name,value] of Object.entries(methods))Object.defineProperty(NodeIterator.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 for(const name of ["root","whatToShow","filter"])Object.defineProperty(NodeIterator.prototype,name,{get:function(){return record(this)[name];},enumerable:true,configurable:true});
 Object.defineProperty(NodeIterator.prototype,"referenceNode",{get:function(){const state=record(this);return pointer(state,native(state,"reference")).node;},enumerable:true,configurable:true});
 Object.defineProperty(NodeIterator.prototype,"pointerBeforeReferenceNode",{get:function(){const state=record(this);return native(state,"reference").before;},enumerable:true,configurable:true});
 Object.defineProperty(Document.prototype,"createNodeIterator",{value:function createNodeIterator(root){
  "use strict";__compactDocumentState(this);
  if(!arguments.length)throw new TypeError("createNodeIterator requires a root");
  const rootState=__compactNodeState(root);
  const whatToShow=arguments[1]===undefined?4294967295:(+arguments[1])>>>0,filter=arguments[2]==null?null:arguments[2];
  if(filter!==null&&typeof filter!=="object"&&typeof filter!=="function")throw new TypeError("NodeFilter must be an object");
  const key=__queryElements(rootState.bridgeKey,"nodeIterator",JSON.stringify({op:"create",whatToShow,state:rootState.created?rootState:undefined}),true);
  const iterator=Object.create(NodeIterator.prototype);
  __elementApply(set,iterators,[iterator,{key,root,whatToShow,filter,active:false}]);
  return iterator;
 },writable:true,enumerable:true,configurable:true});
})();
'
}
