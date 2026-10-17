module main

// Document.createEvent(): the legacy factory for an uninitialized event of the
// named interface, which scripts then set up with initEvent(). 4chan's catalog
// signals its own events this way.
fn compact_document_create_event_bootstrap() string {
	return r'
document.createEvent=function createEvent(interfaceName){
 "use strict";
 if(this!==document)throw new TypeError("Illegal Document receiver");
 if(arguments.length===0)throw new TypeError("createEvent requires an interface name");
 const name=String(interfaceName).toLowerCase();
 const interfaces={customevent:"CustomEvent",dragevent:"DragEvent",event:"Event",events:"Event",focusevent:"FocusEvent",htmlevents:"Event",keyboardevent:"KeyboardEvent",messageevent:"MessageEvent",mouseevent:"MouseEvent",mouseevents:"MouseEvent",pointerevent:"PointerEvent",svgevents:"Event",uievent:"UIEvent",uievents:"UIEvent",wheelevent:"WheelEvent"};
 const constructor=Object.prototype.hasOwnProperty.call(interfaces,name)?globalThis[interfaces[name]]:undefined;
 if(typeof constructor!=="function")throw new DOMException("The provided event type is not supported","NotSupportedError");
 return new constructor("");
};
'
}
