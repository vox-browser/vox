module main

// Common facade accessors depend on their receiver, not on a per-element
// closure. Keep their existing own-property descriptors while sharing the
// functions across the realm. Legacy fragment facades have a separate registry
// so they do not acquire the native Element brand.
fn compact_element_common_properties_bootstrap() string {
	return r'
const __compactLegacyPropertyRecords=new WeakMap(),__compactDefineCommonProperties=Object.defineProperties;
// Bind the captured intrinsic once; a property read needs no argument array.
const __compactCommonElementGet=__elementApply(Function.prototype.bind,__elementRecordGet,[__elementRecords]);
const __compactCommonLegacyGet=__elementApply(Function.prototype.bind,__elementRecordGet,[__compactLegacyPropertyRecords]);
function __compactCommonPropertyState(receiver){
 const state=__compactCommonElementGet(receiver)||__compactCommonLegacyGet(receiver);
 if(!state)throw new TypeError("Illegal compact element property receiver");
 return state;
}
const __compactCommonProperties={
 id:{get:function(){return __compactCommonPropertyState(this).id;},set:function(value){__setAttribute(__compactCommonPropertyState(this),"id",value);}},
 firstChild:{get:function(){const s=__compactCommonPropertyState(this);if(s.tagName==="#document-fragment")return s.children.length?__element(s.children[0]):null;return __queryElements(s.bridgeKey,"firstChild","");}},
 parentNode:{get:function(){const s=__compactCommonPropertyState(this);if(s.nativeParent)return __compactNativeParent(s);const p=s.parentKey&&__state.elements[s.parentKey];if(p&&!p.removed)return __compactNodeWrapper(p);return !s.parentKey&&!s.removed&&!s.created&&s.tagName==="html"?document:null;}},
 parentElement:{get:function(){__compactCommonPropertyState(this);const parent=this.parentNode;return parent&&parent.nodeType===1?parent:null;}},
 textContent:{get:function(){return __elementContent(__compactCommonPropertyState(this),"textContent");},set:function(value){const s=__compactCommonPropertyState(this);s.textContent=String(value);s.innerHTML="";s.textContentDirty=true;s.innerHTMLDirty=false;__compactMutationFlush(false);}},
 innerHTML:{get:function(){return __elementContent(__compactCommonPropertyState(this),"innerHTML");},set:function(value){const s=__compactCommonPropertyState(this);s.innerHTML=String(value);s.innerHTMLDirty=true;s.textContentDirty=false;__compactMutationFlush(false);}},
 className:{get:function(){return __compactCommonPropertyState(this).className;},set:function(value){__setAttribute(__compactCommonPropertyState(this),"class",value);}},
 name:{get:function(){return __compactCommonPropertyState(this).attributes.name||"";},set:function(value){__setAttribute(__compactCommonPropertyState(this),"name",value);}},
 hidden:{get:function(){return Object.prototype.hasOwnProperty.call(__compactCommonPropertyState(this).attributes,"hidden");},set:function(value){const s=__compactCommonPropertyState(this);if(value)__setAttribute(s,"hidden","");else __removeAttribute(s,"hidden");}},
 disabled:{get:function(){return !!__compactCommonPropertyState(this).disabled;},set:function(value){const s=__compactCommonPropertyState(this);if(value)__setAttribute(s,"disabled","");else __removeAttribute(s,"disabled");}},
 checked:{get:function(){return !!__compactCommonPropertyState(this).checked;},set:function(value){const s=__compactCommonPropertyState(this);s.checked=!!value;s.checkedDirty=true;}},
 indeterminate:{get:function(){return !!__compactCommonPropertyState(this).indeterminate;},set:function(value){const s=__compactCommonPropertyState(this);s.indeterminate=!!value;s.indeterminateDirty=true;}},
 complete:{get:function(){const s=__compactCommonPropertyState(this);return s.tagName==="img"&&s.namespaceURI==="http://www.w3.org/1999/xhtml"?__nativeImageGet(this,"complete"):!!s.complete;}},
 data:{get:function(){return __compactCommonPropertyState(this).attributes.data||"";},set:function(value){__setElementData(__compactCommonPropertyState(this),value);}},
 sheet:{get:function(){const s=__compactCommonPropertyState(this);return s.tagName==="style"||s.tagName==="link"?__linkStyleSheet(s):null;}}
};
function __compactElementCommonProperties(object,state){
 if(!__compactCommonElementGet(object))__elementApply(__elementRecordSet,__compactLegacyPropertyRecords,[object,state]);
 __compactDefineCommonProperties(object,__compactCommonProperties);
}
'
}
