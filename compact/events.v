module main

// Compact listeners use the same stable element identity as DOM mutation replay.
// Capture the path before callbacks can remove or move the control.
fn compact_event_dispatch_bootstrap() string {
	return r'
function __compactEventPath(s, bubbles) {
 const path = [s];
 if (s && bubbles) {
  if(s.nativeParent){
   const ancestors=__queryElements(s.bridgeKey,"eventAncestors","");
   for(let index=0;index<ancestors.length;index++){
    const element=__queryElement(ancestors[index]);
    path.push(__elementApply(__elementRecordGet,__elementRecords,[element]));
   }
  }else{
   let parent=s.parentKey&&__state.elements[s.parentKey];
   while(parent){path.push(parent);parent=parent.parentKey&&__state.elements[parent.parentKey];}
  }
  path.push(null);
 }
 return path;
}
// Compact listeners and inline handlers (content attributes and on* properties).
function __compactRunEventHandlers(s, name, event, path, replay) {
 for (const current of path) {
  const receiver = current ? __element(current) : document;
  event.currentTarget = receiver;
  for (const listener of (__listeners[__listenerKey(current, name)] || []).slice()) {
   if (event.immediateStopped) break;
   try { listener.call(receiver, event); } catch (error) { console.error(error); }
  }
  const nativeMedia = current && current.namespaceURI === "http://www.w3.org/1999/xhtml" &&
   (current.tagName === "audio" || current.tagName === "video");
  const raw = current === s && replay && Object.prototype.hasOwnProperty.call(replay, "raw") ? replay.raw :
   (current && !nativeMedia ? (current.attributes["on" + name] || "") : "");
  if (!event.immediateStopped) {
   try {
    if (current) {
     const handler = !nativeMedia && receiver["on" + name];
     if (typeof handler === "function") {
      if (handler.call(receiver, event) === false) event.preventDefault();
     } else if (raw && (nativeMedia || !Object.prototype.hasOwnProperty.call(receiver, "on" + name)) &&
      Function("event", raw).call(receiver, event) === false) event.preventDefault();
    }
    // Native click dispatch already owns Window handlers and propagation.
    // Replaying a global onclick here can undo a delegated toggle even when
    // the document listener stopped the original event before Window.
    if (!current && name !== "click" && typeof window["on" + name] === "function" && window["on" + name].call(window, event) === false)
     event.preventDefault();
   } catch (error) { console.error(error); }
  }
  if (event.cancelBubble) break;
 }
 event.currentTarget = null;
}
window.__ladybirdDispatch = function (name, id, replay) {
 const s = replay ? __resolveElementState(replay.key) :
  (String(id) === "" ? null : (__elementStates().find(item => item.id === String(id)) || null));
 if (replay && !s) return window.__ladybirdFinalize();
 const target = s ? __element(s) : document;
 const bubbles = name === "click" || name === "input" || name === "change";
 const path = __compactEventPath(s, bubbles);
 let nativePrevented=false;
 if(name==="click"){
  if(replay&&replay.nativeDispatched)nativePrevented=!!replay.nativeDefaultPrevented;
  else nativePrevented=!EventTarget.prototype.dispatchEvent.call(target,new MouseEvent("click",{bubbles:true,cancelable:true,view:window}));
 }
 const event = {type:name, target:target, currentTarget:null, bubbles:bubbles,
  cancelable:name !== "input" && name !== "change", defaultPrevented:nativePrevented, button:0, which:1,
  preventDefault(){if(this.cancelable)this.defaultPrevented = true;},
  stopPropagation(){this.cancelBubble = true;},
  stopImmediatePropagation(){this.cancelBubble = true; this.immediateStopped = true;}};
 __compactRunEventHandlers(s, name, event, path, replay);
 __state.defaultPrevented = event.defaultPrevented && !(replay && replay.nativeDispatched && nativePrevented);
 return window.__ladybirdFinalize();
};
' +
		compact_element_click_bootstrap()
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-click
// The synthetic click is dispatched natively, so native listeners and activation
// behavior (following links, toggling checkboxes, opening details) run as for
// html_element_click(). Inline handlers live in the compact layer: a relay on
// each element of the event path runs that element's handlers after its native
// listeners, so stopPropagation() and `return false` keep their meaning and a
// canceled click skips the activation behavior.
fn compact_element_click_bootstrap() string {
	return r'
(function(){
 const apply=Reflect.apply,matches=Element.prototype.matches,nativeAdd=EventTarget.prototype.addEventListener,
  nativeRemove=EventTarget.prototype.removeEventListener,nativeDispatch=EventTarget.prototype.dispatchEvent,
  ClickEvent=typeof PointerEvent==="function"?PointerEvent:MouseEvent,
  clicking=new WeakSet(),clickingHas=WeakSet.prototype.has,clickingAdd=WeakSet.prototype.add,clickingDelete=WeakSet.prototype.delete;
 function disabled(element){
  // Also commits pending compact mutations, such as a new href, before dispatch.
  try{return apply(matches,element,[":disabled"]);}catch(error){return false;}
 }
 function refreshActivationState(s){
  if(s.tagName!=="input")return;
  const request={op:"activationState"};if(s.created)request.state=s;
  try{const state=__queryElements(s.bridgeKey,"formControls",JSON.stringify(request));s.checked=state.checked;s.indeterminate=state.indeterminate;s.checkedDirty=false;s.indeterminateDirty=false;}catch(error){}
 }
 Object.defineProperty(HTMLElement.prototype,"click",{value:function click(){
  const s=__elementApply(__elementRecordGet,__elementRecords,[this]);
  if(!s||s.namespaceURI!=="http://www.w3.org/1999/xhtml")throw new TypeError("Illegal HTMLElement receiver");
  // 1. A disabled form control does nothing. 2-3. Nor does a nested click() of the same element.
  if(disabled(this)||apply(clickingHas,clicking,[s]))return;
  apply(clickingAdd,clicking,[s]);
  const target=this,event=new ClickEvent("click",{bubbles:true,cancelable:true,composed:true,view:window});
  const compact={type:"click",target:target,currentTarget:null,bubbles:true,cancelable:true,isTrusted:false,button:0,which:1,cancelBubble:false,
   get defaultPrevented(){return event.defaultPrevented;},
   preventDefault(){event.preventDefault();},
   stopPropagation(){this.cancelBubble=true;event.stopPropagation();},
   stopImmediatePropagation(){this.cancelBubble=true;this.immediateStopped=true;event.stopImmediatePropagation();}};
  const relays=[];
  for(const current of __compactEventPath(s,true)){
   const receiver=current?__element(current):document,relay=function(){
    compact.immediateStopped=false;__compactRunEventHandlers(s,"click",compact,[current],null);
   };
   try{apply(nativeAdd,receiver,["click",relay]);relays.push([receiver,relay]);}catch(error){}
  }
  try{
   apply(nativeDispatch,target,[event]);
  }finally{
   for(const [receiver,relay] of relays)apply(nativeRemove,receiver,["click",relay]);
   apply(clickingDelete,clicking,[s]);
   refreshActivationState(s);
  }
 },writable:true,enumerable:true,configurable:true});
})();
'
}
