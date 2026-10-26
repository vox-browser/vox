module main

// Preserve the HTML interface hierarchy when compact wrappers replace native
// element objects. React's focused-element traversal tests HTMLIFrameElement.
fn compact_html_interfaces_bootstrap() string {
	return r'
function HTMLElement(){throw new TypeError("Illegal HTMLElement constructor");}
function HTMLIFrameElement(){throw new TypeError("Illegal HTMLIFrameElement constructor");}
function HTMLInputElement(){throw new TypeError("Illegal HTMLInputElement constructor");}
for(const [constructor,parent,name] of [[HTMLElement,Element,"HTMLElement"],[HTMLIFrameElement,HTMLElement,"HTMLIFrameElement"],[HTMLInputElement,HTMLElement,"HTMLInputElement"]]){
 Object.setPrototypeOf(constructor,parent);
 Object.setPrototypeOf(constructor.prototype,parent.prototype);
 Object.defineProperty(constructor,"prototype",{writable:false});
 Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
 Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
}
function __compactElementPrototype(state){
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml")return Element.prototype;
 const name=String(state.tagName),local=name.slice(name.indexOf(":")+1);
 return local==="iframe"?HTMLIFrameElement.prototype:local==="input"?HTMLInputElement.prototype:HTMLElement.prototype;
}
'
}
