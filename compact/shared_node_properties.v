module main

import os

const disable_shared_node_properties = os.getenv('VOX_DISABLE_SHARED_NODE_PROPERTIES') == '1'
const shared_node_properties_diagnostics = os.getenv('VOX_SHARED_NODE_PROPERTIES_DIAGNOSTICS') == '1'

// Keep wrapper metadata local, while reusing the receiver-based accessors and
// methods. Initialize descriptors on first use, after the other Node bindings
// exist, and preserve the original own-property order and flags.
fn compact_node_properties_bootstrap() string {
	mut prefix := r'const __compactSharedNodeRecord=function record(receiver){const own=__elementApply(__compactNodeGet,__compactNodeRecords,[receiver]);if(!own)throw new TypeError("Illegal Node receiver");return own;};
'
	if shared_node_properties_diagnostics {
		prefix += 'Object.defineProperty(globalThis,"__voxSharedNodeWrappers",{value:0,writable:true});\n'
	}
	if disable_shared_node_properties {
		return prefix + r'
function __compactInstallNodeProperties(node,state){
 function record(receiver){const own=__elementApply(__compactNodeGet,__compactNodeRecords,[receiver]);if(!own)throw new TypeError("Illegal Node receiver");return own;}
 function read(){return __queryElements(record(this).bridgeKey,"nodeValue","");}
 function write(receiver,value,nullable){const own=record(receiver);if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");__queryElements(own.bridgeKey,"setNodeValue",nullable&&value===null?"":String(value));__compactInvalidateContent(own);}
 Object.defineProperties(node,{
  __state:{value:state},nodeType:{value:state.nodeType},nodeName:{value:state.nodeName},ownerDocument:{get:function(){record(this);return __compactOwnerDocument(this);}},
  contains:{value:__compactNodeContains,writable:true,enumerable:true,configurable:true},
  isConnected:{get:__compactNodeConnected,enumerable:true,configurable:true},
  parentNode:{get(){return __compactNativeParent(record(this));}},
  parentElement:{get(){const parent=this.parentNode;return parent&&parent.nodeType===1?parent:null;}},
  firstChild:{get(){return __queryElements(record(this).bridgeKey,"firstChild","");}},
  lastChild:{get(){return __queryElements(record(this).bridgeKey,"lastChild","");}},
  childNodes:{get(){return __compactChildNodes(this,record(this));}},
  nextSibling:{get(){return __queryElements(record(this).bridgeKey,"nextSibling","");}},
  previousSibling:{get(){return __queryElements(record(this).bridgeKey,"previousSibling","");}},
  __firstChildOf:{get(){const parent=this.parentNode;return parent&&parent.nodeType===1&&parent.firstChild===this?parent.__state.bridgeKey:undefined;}},
  nodeValue:{get(){return [3,4,7,8].includes(record(this).nodeType)?__elementApply(read,this,[]):null;},set(value){write(this,value,true);}},
  textContent:{get(){return __queryElements(record(this).bridgeKey,"nodeText","");},set(value){const own=record(this);if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");__queryElements(own.bridgeKey,"setNodeText",value===null?"":String(value));__compactInvalidateContent(own);}},
  appendChild:{value:function appendChild(child){record(this);return __compactInsertNode(this,child,null,false);}},
  insertBefore:{value:function insertBefore(child,reference){record(this);return __compactInsertNode(this,child,reference,true);}},
  removeChild:{value:function removeChild(child){const own=record(this),target=__compactNodeState(child);__queryElements(own.bridgeKey,"removeChild",target.bridgeKey);return child;}},
  cloneNode:{value:function cloneNode(deep){return __queryElements(record(this).bridgeKey,"cloneNode",deep?"deep":"shallow");}}
 });
 if([3,4,7,8].includes(state.nodeType))Object.defineProperties(node,{data:{get:read,set(value){write(this,value,false);}},length:{get(){return __elementApply(read,this,[]).length;}}});
}
'
	}
	mut code := r'
const __compactSharedNodeRead=function read(){return __queryElements(__compactSharedNodeRecord(this).bridgeKey,"nodeValue","");};
const __compactSharedNodeWrite=function write(receiver,value,nullable){const own=__compactSharedNodeRecord(receiver);if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");__queryElements(own.bridgeKey,"setNodeValue",nullable&&value===null?"":String(value));__compactInvalidateContent(own);};
let __compactNodePropertyDescriptors;
const __compactCharacterPropertyDescriptors={
 data:{get:__compactSharedNodeRead,set(value){__compactSharedNodeWrite(this,value,false);}},length:{get(){return __elementApply(__compactSharedNodeRead,this,[]).length;}}
};
function __compactInstallNodeProperties(node,state){
 if(!__compactNodePropertyDescriptors)__compactNodePropertyDescriptors={
  ownerDocument:{get:function(){__compactSharedNodeRecord(this);return __compactOwnerDocument(this);}},
  contains:{value:__compactNodeContains,writable:true,enumerable:true,configurable:true},
  isConnected:{get:__compactNodeConnected,enumerable:true,configurable:true},
  parentNode:{get(){return __compactNativeParent(__compactSharedNodeRecord(this));}},
  parentElement:{get(){const parent=this.parentNode;return parent&&parent.nodeType===1?parent:null;}},
  firstChild:{get(){return __queryElements(__compactSharedNodeRecord(this).bridgeKey,"firstChild","");}},
  lastChild:{get(){return __queryElements(__compactSharedNodeRecord(this).bridgeKey,"lastChild","");}},
  childNodes:{get(){return __compactChildNodes(this,__compactSharedNodeRecord(this));}},
  nextSibling:{get(){return __queryElements(__compactSharedNodeRecord(this).bridgeKey,"nextSibling","");}},
  previousSibling:{get(){return __queryElements(__compactSharedNodeRecord(this).bridgeKey,"previousSibling","");}},
  __firstChildOf:{get(){const parent=this.parentNode;return parent&&parent.nodeType===1&&parent.firstChild===this?parent.__state.bridgeKey:undefined;}},
  nodeValue:{get(){return [3,4,7,8].includes(__compactSharedNodeRecord(this).nodeType)?__elementApply(__compactSharedNodeRead,this,[]):null;},set(value){__compactSharedNodeWrite(this,value,true);}},
  textContent:{get(){return __queryElements(__compactSharedNodeRecord(this).bridgeKey,"nodeText","");},set(value){const own=__compactSharedNodeRecord(this);if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");__queryElements(own.bridgeKey,"setNodeText",value===null?"":String(value));__compactInvalidateContent(own);}},
  appendChild:{value:function appendChild(child){__compactSharedNodeRecord(this);return __compactInsertNode(this,child,null,false);}},
  insertBefore:{value:function insertBefore(child,reference){__compactSharedNodeRecord(this);return __compactInsertNode(this,child,reference,true);}},
  removeChild:{value:function removeChild(child){const own=__compactSharedNodeRecord(this),target=__compactNodeState(child);__queryElements(own.bridgeKey,"removeChild",target.bridgeKey);return child;}},
  cloneNode:{value:function cloneNode(deep){return __queryElements(__compactSharedNodeRecord(this).bridgeKey,"cloneNode",deep?"deep":"shallow");}}
 };
 Object.defineProperties(node,{__state:{value:state},nodeType:{value:state.nodeType},nodeName:{value:state.nodeName}});
 Object.defineProperties(node,__compactNodePropertyDescriptors);
 if([3,4,7,8].includes(state.nodeType))Object.defineProperties(node,__compactCharacterPropertyDescriptors);
}

'
	if shared_node_properties_diagnostics {
		code = code.replace('Object.defineProperties(node,__compactNodePropertyDescriptors);',
			'Object.defineProperties(node,__compactNodePropertyDescriptors);++globalThis.__voxSharedNodeWrappers;')
	}
	return prefix + code
}
