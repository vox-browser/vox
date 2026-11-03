module main

// Preserve the HTML interface hierarchy when compact wrappers replace native
// element objects. React's focused-element traversal tests HTMLIFrameElement.
fn compact_html_interfaces_bootstrap() string {
	return r'
const __nativeHTMLConstructor=globalThis.__ladybirdHTMLConstructor,__HTMLConstructorTypeError=TypeError,__HTMLConstructorProxy=Proxy,__compactSetElementPrototype=Object.setPrototypeOf;
delete globalThis.__ladybirdHTMLConstructor;
function __makeHTMLConstructor(name){
 const target=({[name]:function(){throw new __HTMLConstructorTypeError("Illegal "+name+" constructor");}})[name];
 const constructor=new __HTMLConstructorProxy(target,{construct(target,args,newTarget){if(newTarget===constructor)throw new __HTMLConstructorTypeError("Illegal "+name+" constructor");return __nativeHTMLConstructor(newTarget,name,target.prototype);}});
 Object.defineProperty(target.prototype,"constructor",{value:constructor,writable:true,configurable:true});
 return constructor;
}
const HTMLElement=__makeHTMLConstructor("HTMLElement");
const HTMLIFrameElement=__makeHTMLConstructor("HTMLIFrameElement");
const HTMLInputElement=__makeHTMLConstructor("HTMLInputElement");
const HTMLTemplateElement=__makeHTMLConstructor("HTMLTemplateElement");
const HTMLLinkElement=__makeHTMLConstructor("HTMLLinkElement");
const HTMLScriptElement=__makeHTMLConstructor("HTMLScriptElement");
const HTMLButtonElement=__makeHTMLConstructor("HTMLButtonElement");
const HTMLFormElement=__makeHTMLConstructor("HTMLFormElement");
const HTMLDialogElement=__makeHTMLConstructor("HTMLDialogElement");
const HTMLTextAreaElement=__makeHTMLConstructor("HTMLTextAreaElement");
const HTMLSelectElement=__makeHTMLConstructor("HTMLSelectElement");
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
