module main

// Native code changes element state that the compact facade caches: activation
// toggles a checkbox or a <details> element's open attribute, checking a radio
// button unchecks its group and a dialog form closes its dialog. Read that state
// back from the native element rather than trusting the cache. The query
// commits pending compact edits first, so the native state includes them.
fn compact_native_state_bootstrap() string {
	return r'
function __compactRefreshNativeState(s){
 if(!s||!s.bridgeKey||s.tagName==="#document-fragment"||s.tagName==="#text")return false;
 const request={op:"nativeState"};if(s.created)request.state=s;
 let state;
 try{state=__queryElements(s.bridgeKey,"formControls",JSON.stringify(request));}catch(error){return false;}
 if(!state||!state.attributes)return false;
 const values=state.attributes.values;
 s.attributes=values;s.attributeRecords=state.attributes.records;
 s.id=values.id||"";s.className=values.class||"";s.styleText=values.style||"";s.src=values.src||"";
 s.disabled=Object.prototype.hasOwnProperty.call(values,"disabled");s.attributesDirty=false;
 if(state.checked!==undefined){s.checked=state.checked;s.indeterminate=state.indeterminate;s.checkedDirty=false;s.indeterminateDirty=false;}
 return true;
}
// Only these elements have activation behavior or form state that changes
// cached state as a side effect of a click.
function __compactRefreshActivatedStates(path){
 for(const s of path){
  if(s&&s.namespaceURI==="http://www.w3.org/1999/xhtml"&&(s.tagName==="input"||s.tagName==="details"||s.tagName==="dialog"))
   __compactRefreshNativeState(s);
 }
}
// https://html.spec.whatwg.org/multipage/interactive-elements.html#dom-details-open
for(const [name,tag] of [["HTMLDetailsElement","details"],["HTMLDialogElement","dialog"]]){
 const constructor=globalThis[name];
 if(typeof constructor!=="function")continue;
 const receiverState=function(receiver){
  const s=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!s||s.namespaceURI!=="http://www.w3.org/1999/xhtml"||s.tagName!==tag)throw new TypeError("Illegal "+name+" receiver");
  return s;
 };
 Object.defineProperty(constructor.prototype,"open",{get:function(){
  const s=receiverState(this);__compactRefreshNativeState(s);
  return Object.prototype.hasOwnProperty.call(s.attributes,"open");
 },set:function(value){
  const s=receiverState(this);
  if(value)__setAttribute(s,"open","");else __removeAttribute(s,"open");
 },enumerable:true,configurable:true});
}
'
}
