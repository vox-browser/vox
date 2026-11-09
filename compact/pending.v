module main

// Native reads must replay every pending edit, but an unchanged indexed
// collection read should not enumerate every facade in the document.
fn compact_pending_elements_bootstrap() string {
	return compact_element_content_cache_bootstrap() + r'
const __dirtyElementStates=new Set(),__trackedElementStates=new WeakSet();
const __pendingKeys=Object.keys,__pendingAssign=Object.assign,__pendingStringify=JSON.stringify;
const __pendingApply=Reflect.apply,__pendingSetSize=Object.getOwnPropertyDescriptor(Set.prototype,"size").get;
function __compactHasPendingDOMState(){
 return __state.operations.length!==0||__pendingApply(__pendingSetSize,__dirtyElementStates,[])!==0||!!__state.bodyHTMLDirty||!!__state.bodyTextDirty;
}
function __trackElementEdits(state){
 if(__trackedElementStates.has(state))return state;
 __trackedElementStates.add(state);
 __compactRegisterContent(state);
 for(const name of ["attributesDirty","textContentDirty","innerHTMLDirty","checkedDirty","indeterminateDirty"]){
  let value=state[name];
  if(value)__dirtyElementStates.add(state);
  Object.defineProperty(state,name,{get(){return value;},set(next){value=next;if(next)__dirtyElementStates.add(state);},enumerable:true,configurable:true});
 }
 return state;
}
for(const state of Object.values(__state.elements))__trackElementEdits(state);
__state.elements=new Proxy(__state.elements,{set(target,key,state){return Reflect.set(target,key,__trackElementEdits(state));}});
function __pendingElementStates(includeCanvases){
 const pending=Object.create(null);
 for(const state of __dirtyElementStates){
  if(state.attributesDirty||state.textContentDirty||state.innerHTMLDirty||state.checkedDirty||state.indeterminateDirty){__compactRefreshContent(state);pending[state.bridgeKey]=state;}
  else __dirtyElementStates.delete(state);
 }
 if(includeCanvases)for(const key of Object.keys(__canvases)){
  const state=__canvases[key].state;
  if(state.canvasNative&&__state.elements[state.bridgeKey]===state){__compactRefreshContent(state);pending[state.bridgeKey]=state;}
 }
 return pending;
}
// One handoff owns the pending journal for queries, native host calls and task
// completion. Drain it before entering native code: reentrant callbacks then
// write into a new batch, which an outer completion must never clear.
function __compactTakePendingDOMState(includeCanvases,includeLogs,force){
 if(includeCanvases)for(const key of __pendingKeys(__canvases)){
  const canvas=__canvases[key];
  if(canvas.context&&canvas.kind==="2d")canvas.state.canvasNative=true;
 }
 const pending=__pendingElementStates(includeCanvases);
 if(!force&&!__state.operations.length&&!__pendingKeys(pending).length&&!__state.bodyHTMLDirty&&!__state.bodyTextDirty)return null;
 const snapshot=__pendingAssign({},__state,{elements:pending,logs:includeLogs?__state.logs:[]});
 // Decoded video data is an input to the facade, never a DOM mutation.
 delete snapshot.videoSources;
 const encoded=__pendingStringify(snapshot);
 __state.operations=[];__state.bodyHTMLDirty=false;__state.bodyTextDirty=false;
 for(const key of __pendingKeys(pending)){
  const state=pending[key];
  state.innerHTMLDirty=false;state.textContentDirty=false;state.attributesDirty=false;state.checkedDirty=false;state.indeterminateDirty=false;
  __dirtyElementStates.delete(state);
 }
 if(includeLogs)__state.logs=[];
 return encoded;
}
function __compactFlushDOMMutations(){
 return __queryElements("","flushDOM","",true);
}
function __compactTakeTaskOutput(){
 const output=__pendingStringify({logs:__state.logs,navigate:__state.navigate||""});
 // The shell consumes a script navigation once. Reporting it again from every
 // later task restarted the pending load on each timer tick, so it never finished.
 __state.logs=[];__state.navigate="";
 return output;
}'
}
