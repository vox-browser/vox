module main

// Compact listeners use the same stable element identity as DOM mutation replay.
// Capture the path before callbacks can remove or move the control.
fn compact_event_dispatch_bootstrap() string {
	return r'
window.__ladybirdDispatch = function (name, id, replay) {
 const s = replay ? __resolveElementState(replay.key) :
  (String(id) === "" ? null : (__elementStates().find(item => item.id === String(id)) || null));
 if (replay && !s) return window.__ladybirdFinalize();
 const target = s ? __element(s) : document;
 const path = [s];
 const bubbles = name === "click" || name === "input" || name === "change";
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
 __state.defaultPrevented = event.defaultPrevented && !(replay && replay.nativeDispatched && nativePrevented);
 return window.__ladybirdFinalize();
};'
}
