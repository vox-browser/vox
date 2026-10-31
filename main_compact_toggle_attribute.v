module main

// Keep toggleAttribute on the ordinary mutation path, including namespaced
// Attr identity, reflected control state, invalidation and the replay journal.
fn compact_toggle_attribute_bootstrap() string {
	return r'
Object.defineProperty(Element.prototype,"toggleAttribute",{value:function toggleAttribute(name){
 "use strict";
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Element receiver");
 if(arguments.length===0)throw new TypeError("toggleAttribute requires a name");
 if(typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 name=__attributeName(state,String(name));
 if(!name||/[\x00\t\n\f\r \/=>]/.test(name))throw new DOMException("Invalid attribute name","InvalidCharacterError");
 const present=Object.prototype.hasOwnProperty.call(state.attributes,name);
	const force=arguments[1];
 const desired=force===undefined?!present:!!force;
 if(desired&&!present)__setAttribute(state,name,"");
 else if(!desired&&present)__removeAttribute(state,name);
 return desired;
},writable:true,enumerable:true,configurable:true});
'
}
