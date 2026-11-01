module main

// DOM/Node.idl supplies the common base used by cross-interface node checks.
fn compact_node_interface_bootstrap() string {
	return r'
function Node(){throw new TypeError("Illegal Node constructor");}
Object.setPrototypeOf(Node,EventTarget);Object.setPrototypeOf(Node.prototype,EventTarget.prototype);
Object.defineProperty(Node,"prototype",{writable:false});
Object.defineProperty(Node.prototype,Symbol.toStringTag,{value:"Node",configurable:true});
for(const [name,value] of Object.entries({ELEMENT_NODE:1,ATTRIBUTE_NODE:2,TEXT_NODE:3,CDATA_SECTION_NODE:4,ENTITY_REFERENCE_NODE:5,ENTITY_NODE:6,PROCESSING_INSTRUCTION_NODE:7,COMMENT_NODE:8,DOCUMENT_NODE:9,DOCUMENT_TYPE_NODE:10,DOCUMENT_FRAGMENT_NODE:11,NOTATION_NODE:12,DOCUMENT_POSITION_DISCONNECTED:1,DOCUMENT_POSITION_PRECEDING:2,DOCUMENT_POSITION_FOLLOWING:4,DOCUMENT_POSITION_CONTAINS:8,DOCUMENT_POSITION_CONTAINED_BY:16,DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC:32})){
 Object.defineProperty(Node,name,{value,enumerable:true});Object.defineProperty(Node.prototype,name,{value,enumerable:true});
}
Object.defineProperty(globalThis,"Node",{value:Node,writable:true,configurable:true});
function __compactEqualityState(node){
 if(node===document)return{bridgeKey:"",nodeType:9};
 const state=__elementApply(__elementRecordGet,__elementRecords,[node])||__elementApply(__compactNodeGet,__compactNodeRecords,[node])||__elementApply(__compactNodeGet,__compactDocuments,[node]);
 if(!state)throw new TypeError("Expected a Node");return state;
}
Object.defineProperty(Node.prototype,"isEqualNode",{value:{isEqualNode(other){
 "use strict";const own=__compactEqualityState(this);
 if(arguments.length===0)throw new TypeError("isEqualNode requires one argument");
 if(other===null||other===undefined)return false;
 const target=__compactEqualityState(other);
 if(this===other)return true;
 return __queryElements(own.bridgeKey,"isEqualNode",JSON.stringify({otherKey:target.bridgeKey,ownState:own.created?own:undefined,otherState:target.created?target:undefined}));
}}.isEqualNode,writable:true,enumerable:true,configurable:true});
Object.defineProperty(Node.prototype,"compareDocumentPosition",{value:{compareDocumentPosition(other){
 "use strict";const own=__compactEqualityState(this);
 if(arguments.length===0)throw new TypeError("compareDocumentPosition requires one argument");
 const target=__compactEqualityState(other);
 return __queryElements(own.bridgeKey,"compareDocumentPosition",JSON.stringify({otherKey:target.bridgeKey,ownState:own.created?own:undefined,otherState:target.created?target:undefined}));
}}.compareDocumentPosition,writable:true,enumerable:true,configurable:true});
'
}
