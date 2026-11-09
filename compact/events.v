module main

import browserjs

// Compact listeners use the same stable element identity as DOM mutation replay.
// Capture the path before callbacks can remove or move the control.
fn compact_event_dispatch_bootstrap() string {
	return compact_inline_handler_bootstrap() + r'
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
  // Native dispatch already ran the content attributes and on* properties of these elements.
  const nativeHandlers = current && !nativeMedia && __compactNativeInlineHandlers(receiver);
  const raw = current === s && replay && Object.prototype.hasOwnProperty.call(replay, "raw") ? replay.raw :
   (current && !nativeMedia && !nativeHandlers ? (__compactNativeAttributes.read(current,"on" + name,true) || "") : "");
  if (!event.immediateStopped) {
   try {
    if (current && !nativeHandlers) {
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
 const element = replay || String(id) === "" ? null : __queryElements("","getElementById",String(id));
 const s = replay ? __resolveElementState(replay.key) :
  (element ? __elementApply(__elementRecordGet,__elementRecords,[element]) : null);
 if (replay && !s) return window.__ladybirdFinalize();
 const target = s ? __element(s) : document;
 const bubbles = name === "click" || name === "input" || name === "change";
 const path = __compactEventPath(s, bubbles);
 let nativePrevented=false;
 if(name==="click"){
  if(replay&&replay.nativeDispatched)nativePrevented=!!replay.nativeDefaultPrevented;
  else nativePrevented=!EventTarget.prototype.dispatchEvent.call(target,new MouseEvent("click",{bubbles:true,cancelable:true,view:window}));
  // Activation may have toggled a checkbox or an ancestor <details>.
  __compactRefreshActivatedStates(path);
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

// HTML, SVG and MathML GlobalEventHandlers (on* IDL attributes). Native elements
// read and write their native handler slots, which also hold the compiled
// content attributes, so every native dispatch runs them. Elements whose inline
// handlers the compact layer still replays (image, object, media, ...) keep an
// own property, exactly like the expando these accessors replace.
fn compact_inline_handler_bootstrap() string {
	return r'
const __compactInlineHandler=globalThis.__ladybirdElementInlineHandler;delete globalThis.__ladybirdElementInlineHandler;
function __compactNativeInlineHandlers(receiver){
 return typeof __compactInlineHandler==="function"&&Reflect.apply(__compactInlineHandler,undefined,[2,receiver,""])===true;
}
(function(pairs){
 if(typeof __compactInlineHandler!=="function")return;
 const apply=Reflect.apply,define=Object.defineProperty,getOwn=Object.getOwnPropertyDescriptor,native=__compactInlineHandler;
 function check(receiver,namespace){
  const s=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!s||s.namespaceURI!==namespace)throw new TypeError("Illegal event handler receiver");
 }
 for(const [constructor,namespace] of [[HTMLElement,"http://www.w3.org/1999/xhtml"],
  [SVGElement,"http://www.w3.org/2000/svg"],[MathMLElement,"http://www.w3.org/1998/Math/MathML"]]){
 for(const [attribute,event] of pairs){
  const accessors={
   get [attribute](){check(this,namespace);const value=apply(native,undefined,[0,this,event]);return value===undefined?null:value;},
   set [attribute](value){check(this,namespace);if(apply(native,undefined,[1,this,event,value])!==true)define(this,attribute,{value:value,writable:true,enumerable:true,configurable:true});}
  };
  const descriptor=getOwn(accessors,attribute);
  define(constructor.prototype,attribute,{get:descriptor.get,set:descriptor.set,enumerable:true,configurable:true});
 }
 }
})(' + browserjs.element_inline_handler_pairs_json() + r');
'
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
 const markSynthetic=globalThis.__ladybirdSyntheticClickEvent;delete globalThis.__ladybirdSyntheticClickEvent;
 const apply=Reflect.apply,matches=Element.prototype.matches,nativeAdd=EventTarget.prototype.addEventListener,
  nativeRemove=EventTarget.prototype.removeEventListener,nativeDispatch=EventTarget.prototype.dispatchEvent,
  ClickEvent=typeof PointerEvent==="function"?PointerEvent:MouseEvent,
  clicking=new WeakSet(),clickingHas=WeakSet.prototype.has,clickingAdd=WeakSet.prototype.add,clickingDelete=WeakSet.prototype.delete;
 function disabled(element){
  // Also commits pending compact mutations, such as a new href, before dispatch.
  try{return apply(matches,element,[":disabled"]);}catch(error){return false;}
 }
 Object.defineProperty(HTMLElement.prototype,"click",{value:function click(){
  const s=__elementApply(__elementRecordGet,__elementRecords,[this]);
  if(!s||s.namespaceURI!=="http://www.w3.org/1999/xhtml")throw new TypeError("Illegal HTMLElement receiver");
  // 1. A disabled form control does nothing. 2-3. Nor does a nested click() of the same element.
  if(disabled(this)||apply(clickingHas,clicking,[s]))return;
  apply(clickingAdd,clicking,[s]);
  const target=this,event=new ClickEvent("click",{bubbles:true,cancelable:true,composed:true,view:window});
  markSynthetic(event);
  const compact={type:"click",target:target,currentTarget:null,bubbles:true,cancelable:true,isTrusted:false,button:0,which:1,cancelBubble:false,
   get defaultPrevented(){return event.defaultPrevented;},
   preventDefault(){event.preventDefault();},
   stopPropagation(){this.cancelBubble=true;event.stopPropagation();},
   stopImmediatePropagation(){this.cancelBubble=true;this.immediateStopped=true;event.stopImmediatePropagation();}};
  const relays=[],path=__compactEventPath(s,true);
  for(const current of path){
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
   __compactRefreshActivatedStates(path);
  }
 },writable:true,enumerable:true,configurable:true});
})();
'
}
