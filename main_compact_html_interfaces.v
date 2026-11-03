module main

// Preserve the HTML interface hierarchy when compact wrappers replace native
// element objects. React's focused-element traversal tests HTMLIFrameElement.
fn compact_html_interfaces_bootstrap() string {
	return r'
function HTMLElement(){throw new TypeError("Illegal HTMLElement constructor");}
function HTMLIFrameElement(){throw new TypeError("Illegal HTMLIFrameElement constructor");}
function HTMLInputElement(){throw new TypeError("Illegal HTMLInputElement constructor");}
function HTMLTemplateElement(){throw new TypeError("Illegal HTMLTemplateElement constructor");}
function HTMLLinkElement(){throw new TypeError("Illegal HTMLLinkElement constructor");}
function HTMLScriptElement(){throw new TypeError("Illegal HTMLScriptElement constructor");}
function HTMLButtonElement(){throw new TypeError("Illegal HTMLButtonElement constructor");}
function HTMLFormElement(){throw new TypeError("Illegal HTMLFormElement constructor");}
function HTMLDialogElement(){throw new TypeError("Illegal HTMLDialogElement constructor");}
function HTMLTextAreaElement(){throw new TypeError("Illegal HTMLTextAreaElement constructor");}
function HTMLSelectElement(){throw new TypeError("Illegal HTMLSelectElement constructor");}
function SVGElement(){throw new TypeError("Illegal SVGElement constructor");}
for(const [constructor,parent,name] of [[HTMLElement,Element,"HTMLElement"],[HTMLIFrameElement,HTMLElement,"HTMLIFrameElement"],[HTMLInputElement,HTMLElement,"HTMLInputElement"],[HTMLTemplateElement,HTMLElement,"HTMLTemplateElement"],[HTMLLinkElement,HTMLElement,"HTMLLinkElement"],[HTMLScriptElement,HTMLElement,"HTMLScriptElement"],[HTMLButtonElement,HTMLElement,"HTMLButtonElement"],[HTMLFormElement,HTMLElement,"HTMLFormElement"],[HTMLDialogElement,HTMLElement,"HTMLDialogElement"],[HTMLTextAreaElement,HTMLElement,"HTMLTextAreaElement"],[HTMLSelectElement,HTMLElement,"HTMLSelectElement"],[SVGElement,Element,"SVGElement"]]){
 Object.setPrototypeOf(constructor,parent);
 Object.setPrototypeOf(constructor.prototype,parent.prototype);
 Object.defineProperty(constructor,"prototype",{writable:false});
 Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
 Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
}
function __compactElementPrototype(state){
 if(state.namespaceURI==="http://www.w3.org/2000/svg")return SVGElement.prototype;
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml")return Element.prototype;
 const name=String(state.tagName),local=name.slice(name.indexOf(":")+1);
 const interfaces={iframe:HTMLIFrameElement,input:HTMLInputElement,template:HTMLTemplateElement,link:HTMLLinkElement,script:HTMLScriptElement,button:HTMLButtonElement,form:HTMLFormElement,dialog:HTMLDialogElement,textarea:HTMLTextAreaElement,select:HTMLSelectElement};
 return Object.prototype.hasOwnProperty.call(interfaces,local)?interfaces[local].prototype:HTMLElement.prototype;
}
' + compact_template_bootstrap() + compact_toggle_attribute_bootstrap() + compact_html_language_bootstrap()
}
