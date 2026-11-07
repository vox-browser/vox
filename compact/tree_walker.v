module main

// DOM/TreeWalker.cpp's traversal algorithms operate on live native relations.
// Keep the callback invocation in its JavaScript realm so exceptions retain
// their identity and the active flag is cleared even when conversion throws.
fn compact_tree_walker_bootstrap() string {
	return r'
const __compactWalkers=new WeakMap();
const NodeFilter=()=>{throw new TypeError("Illegal NodeFilter invocation");};
for(const [name,value] of Object.entries({FILTER_ACCEPT:1,FILTER_REJECT:2,FILTER_SKIP:3,SHOW_ALL:4294967295,SHOW_ELEMENT:1,SHOW_ATTRIBUTE:2,SHOW_TEXT:4,SHOW_CDATA_SECTION:8,SHOW_ENTITY_REFERENCE:16,SHOW_ENTITY:32,SHOW_PROCESSING_INSTRUCTION:64,SHOW_COMMENT:128,SHOW_DOCUMENT:256,SHOW_DOCUMENT_TYPE:512,SHOW_DOCUMENT_FRAGMENT:1024,SHOW_NOTATION:2048}))Object.defineProperty(NodeFilter,name,{value,enumerable:true});
Object.defineProperty(globalThis,"NodeFilter",{value:NodeFilter,writable:true,configurable:true});
function TreeWalker(){throw new TypeError("Illegal TreeWalker constructor");}
Object.defineProperty(TreeWalker,"prototype",{writable:false});
Object.defineProperty(TreeWalker.prototype,Symbol.toStringTag,{value:"TreeWalker",configurable:true});
Object.defineProperty(globalThis,"TreeWalker",{value:TreeWalker,writable:true,configurable:true});
function __compactWalker(receiver){const state=__elementApply(__compactNodeGet,__compactWalkers,[receiver]);if(!state)throw new TypeError("Illegal TreeWalker receiver");return state;}
function __compactWalkRelative(node,relation){return __queryElements(__compactNodeState(node).bridgeKey,relation,"");}
function __compactWalkFilter(state,node){
 if(state.active)throw new DOMException("The TreeWalker filter is already active","InvalidStateError");
 const type=__compactNodeState(node).nodeType||1;
 if(!(state.whatToShow&(1<<(type-1))))return 3;
 if(state.filter===null)return 1;
 state.active=true;
 try{
  const callback=typeof state.filter==="function"?state.filter:state.filter.acceptNode;
  if(typeof callback!=="function")throw new TypeError("NodeFilter.acceptNode is not callable");
  return (+__elementApply(callback,typeof state.filter==="function"?undefined:state.filter,[node]))&65535;
 }finally{state.active=false;}
}
function __compactWalkAccept(state,node){state.currentNode=node;return node;}
function __compactWalkChild(state,last){
 const child=last?"lastChild":"firstChild",sibling=last?"previousSibling":"nextSibling";
 let node=__compactWalkRelative(state.currentNode,child);
 while(node){
  const result=__compactWalkFilter(state,node);
  if(result===1)return __compactWalkAccept(state,node);
  if(result===3){const next=__compactWalkRelative(node,child);if(next){node=next;continue;}}
  while(node){
   const next=__compactWalkRelative(node,sibling);if(next){node=next;break;}
   const parent=__compactWalkRelative(node,"nodeParent");
   if(!parent||parent===state.root||parent===state.currentNode)return null;
   node=parent;
  }
 }
 return null;
}
function __compactWalkSibling(state,previous){
 let node=state.currentNode;if(node===state.root)return null;
 const relation=previous?"previousSibling":"nextSibling",child=previous?"lastChild":"firstChild";
 while(true){
  let sibling=__compactWalkRelative(node,relation);
  while(sibling){
   node=sibling;const result=__compactWalkFilter(state,node);
   if(result===1)return __compactWalkAccept(state,node);
   sibling=__compactWalkRelative(node,child);
   if(result===2||!sibling)sibling=__compactWalkRelative(node,relation);
  }
  node=__compactWalkRelative(node,"nodeParent");
  if(!node||node===state.root)return null;
  if(__compactWalkFilter(state,node)===1)return null;
 }
}
const __compactWalkMethods={
 parentNode(){"use strict";const state=__compactWalker(this);let node=state.currentNode;
  while(node&&node!==state.root){node=__compactWalkRelative(node,"nodeParent");if(node&&__compactWalkFilter(state,node)===1)return __compactWalkAccept(state,node);}return null;},
 firstChild(){"use strict";return __compactWalkChild(__compactWalker(this),false);},
 lastChild(){"use strict";return __compactWalkChild(__compactWalker(this),true);},
 previousSibling(){"use strict";return __compactWalkSibling(__compactWalker(this),true);},
 nextSibling(){"use strict";return __compactWalkSibling(__compactWalker(this),false);},
 previousNode(){"use strict";const state=__compactWalker(this);let node=state.currentNode;
  while(node!==state.root){
   let sibling=__compactWalkRelative(node,"previousSibling");
   while(sibling){node=sibling;let result=__compactWalkFilter(state,node),child;
    while(result!==2&&(child=__compactWalkRelative(node,"lastChild"))){node=child;result=__compactWalkFilter(state,node);}
    if(result===1)return __compactWalkAccept(state,node);
    sibling=__compactWalkRelative(node,"previousSibling");
   }
   if(node===state.root)return null;
   node=__compactWalkRelative(node,"nodeParent");if(!node)return null;
   if(__compactWalkFilter(state,node)===1)return __compactWalkAccept(state,node);
  }return null;},
 nextNode(){"use strict";const state=__compactWalker(this);let node=state.currentNode,result=1;
  while(true){let child;
   while(result!==2&&(child=__compactWalkRelative(node,"firstChild"))){node=child;result=__compactWalkFilter(state,node);if(result===1)return __compactWalkAccept(state,node);}
   let temporary=node,sibling=null;
   while(temporary){if(temporary===state.root)return null;sibling=__compactWalkRelative(temporary,"nextSibling");if(sibling)break;temporary=__compactWalkRelative(temporary,"nodeParent");}
   if(!sibling)return null;node=sibling;result=__compactWalkFilter(state,node);if(result===1)return __compactWalkAccept(state,node);
  }}
};
for(const name of Object.keys(__compactWalkMethods))Object.defineProperty(TreeWalker.prototype,name,{value:__compactWalkMethods[name],writable:true,enumerable:true,configurable:true});
for(const name of ["root","whatToShow","filter","currentNode"])Object.defineProperty(TreeWalker.prototype,name,{get:function(){return __compactWalker(this)[name];},set:name==="currentNode"?function(node){const state=__compactWalker(this);__compactNodeState(node);state.currentNode=node;}:undefined,enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"createTreeWalker",{value:function createTreeWalker(root){
 "use strict";__compactDocumentState(this);if(!arguments.length)throw new TypeError("createTreeWalker requires a root");__compactNodeState(root);
 const whatToShow=arguments[1]===undefined?4294967295:(+arguments[1])>>>0,filter=arguments[2]==null?null:arguments[2];
 if(filter!==null&&typeof filter!=="object"&&typeof filter!=="function")throw new TypeError("NodeFilter must be an object");
 const walker=Object.create(TreeWalker.prototype);
 __elementApply(__elementRecordSet,__compactWalkers,[walker,{root,currentNode:root,whatToShow,filter,active:false}]);return walker;
},writable:true,enumerable:true,configurable:true});
'
}
