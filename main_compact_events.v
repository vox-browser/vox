module main

// Compact listeners use the same stable element identity as DOM mutation replay.
// Capture the path before callbacks can remove or move the clicked control.
fn compact_event_dispatch_bootstrap() string {
	return r'
window.__ladybirdDispatch = function (name, id, replay) {
 const s = replay ? (__state.elements[replay.key] || null) :
  (String(id) === "" ? null : (__elementStates().find(item => item.id === String(id)) || null));
 if (replay && !s) return window.__ladybirdFinalize();
 const target = s ? __element(s) : document;
 const path = [s];
 if (s && name === "click") {
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
 const event = {type:name, target:target, currentTarget:null, bubbles:name === "click",
  cancelable:true, defaultPrevented:false, button:0, which:1,
  preventDefault(){this.defaultPrevented = true;},
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
   (current && !nativeMedia ? (current.attributes.onclick || "") : "");
  if (!event.immediateStopped) {
   try {
    if (current && name === "click" && raw && Function("event", raw).call(receiver, event) === false)
     event.preventDefault();
    if (!current && typeof window["on" + name] === "function" && window["on" + name].call(window, event) === false)
     event.preventDefault();
   } catch (error) { console.error(error); }
  }
  if (event.cancelBubble) break;
 }
 event.currentTarget = null;
 __state.defaultPrevented = event.defaultPrevented;
 return window.__ladybirdFinalize();
};'
}
