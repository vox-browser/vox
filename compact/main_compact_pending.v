module main

// Native reads must replay every pending edit, but an unchanged indexed
// collection read should not enumerate every facade in the document.
fn compact_pending_elements_bootstrap() string {
	return r'
const __dirtyElementStates=new Set(),__trackedElementStates=new WeakSet();
function __trackElementEdits(state){
 if(__trackedElementStates.has(state))return state;
 __trackedElementStates.add(state);
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
  if(state.attributesDirty||state.textContentDirty||state.innerHTMLDirty||state.checkedDirty||state.indeterminateDirty)pending[state.bridgeKey]=state;
  else __dirtyElementStates.delete(state);
 }
 if(includeCanvases)for(const key of Object.keys(__canvases)){
  const state=__canvases[key].state;
  if(state.canvasNative&&__state.elements[state.bridgeKey]===state)pending[state.bridgeKey]=state;
 }
 return pending;
}
function __clearPendingElementEdits(){
 for(const state of __dirtyElementStates){
  state.innerHTMLDirty=false;state.textContentDirty=false;state.attributesDirty=false;state.checkedDirty=false;state.indeterminateDirty=false;
  __dirtyElementStates.delete(state);
 }
}'
}
