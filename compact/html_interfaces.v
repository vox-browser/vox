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
const HTMLMetaElement=__makeHTMLConstructor("HTMLMetaElement");
function SVGElement(){throw new TypeError("Illegal SVGElement constructor");}
function MathMLElement(){throw new __HTMLConstructorTypeError("Illegal MathMLElement constructor");}
for(const [constructor,parent,name] of [[HTMLElement,Element,"HTMLElement"],[HTMLIFrameElement,HTMLElement,"HTMLIFrameElement"],[HTMLInputElement,HTMLElement,"HTMLInputElement"],[HTMLTemplateElement,HTMLElement,"HTMLTemplateElement"],[HTMLLinkElement,HTMLElement,"HTMLLinkElement"],[HTMLScriptElement,HTMLElement,"HTMLScriptElement"],[HTMLButtonElement,HTMLElement,"HTMLButtonElement"],[HTMLFormElement,HTMLElement,"HTMLFormElement"],[HTMLDialogElement,HTMLElement,"HTMLDialogElement"],[HTMLTextAreaElement,HTMLElement,"HTMLTextAreaElement"],[HTMLSelectElement,HTMLElement,"HTMLSelectElement"],[HTMLMetaElement,HTMLElement,"HTMLMetaElement"],[SVGElement,Element,"SVGElement"],[MathMLElement,Element,"MathMLElement"]]){
 Object.setPrototypeOf(constructor,parent);
 Object.setPrototypeOf(constructor.prototype,parent.prototype);
 Object.defineProperty(constructor,"prototype",{writable:false});
 Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
 Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
}
// The remaining interfaces of the HTML element index. React and its routers
// test elements against them, for example HTMLAnchorElement and
// HTMLHeadingElement while hydrating the GitHub repository view.
const __compactHTMLInterfaces=Object.create(null);
for(const [constructor,tags] of [[HTMLIFrameElement,"iframe"],[HTMLInputElement,"input"],[HTMLTemplateElement,"template"],[HTMLLinkElement,"link"],[HTMLScriptElement,"script"],[HTMLButtonElement,"button"],[HTMLFormElement,"form"],[HTMLDialogElement,"dialog"],[HTMLTextAreaElement,"textarea"],[HTMLSelectElement,"select"],[HTMLMetaElement,"meta"]])for(const tag of tags.split(" "))__compactHTMLInterfaces[tag]=constructor;
for(const [name,tags] of [["HTMLAnchorElement","a"],["HTMLAreaElement","area"],["HTMLBaseElement","base"],["HTMLBodyElement","body"],["HTMLBRElement","br"],["HTMLCanvasElement","canvas"],["HTMLDataElement","data"],["HTMLDataListElement","datalist"],["HTMLDetailsElement","details"],["HTMLDirectoryElement","dir"],["HTMLDivElement","div"],["HTMLDListElement","dl"],["HTMLEmbedElement","embed"],["HTMLFieldSetElement","fieldset"],["HTMLFontElement","font"],["HTMLFrameElement","frame"],["HTMLFrameSetElement","frameset"],["HTMLHeadElement","head"],["HTMLHeadingElement","h1 h2 h3 h4 h5 h6"],["HTMLHRElement","hr"],["HTMLHtmlElement","html"],["HTMLLabelElement","label"],["HTMLLegendElement","legend"],["HTMLLIElement","li"],["HTMLMapElement","map"],["HTMLMarqueeElement","marquee"],["HTMLMenuElement","menu"],["HTMLMeterElement","meter"],["HTMLModElement","del ins"],["HTMLObjectElement","object"],["HTMLOListElement","ol"],["HTMLOptGroupElement","optgroup"],["HTMLOptionElement","option"],["HTMLOutputElement","output"],["HTMLParagraphElement","p"],["HTMLParamElement","param"],["HTMLPictureElement","picture"],["HTMLPreElement","pre listing xmp"],["HTMLProgressElement","progress"],["HTMLQuoteElement","blockquote q"],["HTMLSlotElement","slot"],["HTMLSourceElement","source"],["HTMLSpanElement","span"],["HTMLStyleElement","style"],["HTMLTableCaptionElement","caption"],["HTMLTableCellElement","td th"],["HTMLTableColElement","col colgroup"],["HTMLTableElement","table"],["HTMLTableRowElement","tr"],["HTMLTableSectionElement","tbody thead tfoot"],["HTMLTimeElement","time"],["HTMLTitleElement","title"],["HTMLUListElement","ul"],["HTMLUnknownElement","applet bgsound blink isindex keygen multicol nextid spacer"]]){
 if(Object.prototype.hasOwnProperty.call(globalThis,name))continue;
 const constructor=__makeHTMLConstructor(name);
 Object.setPrototypeOf(constructor,HTMLElement);
 Object.setPrototypeOf(constructor.prototype,HTMLElement.prototype);
 Object.defineProperty(constructor,"prototype",{writable:false});
 Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
 Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 for(const tag of tags.split(" "))__compactHTMLInterfaces[tag]=constructor;
}
__compactInstallObjectData();
function __compactElementPrototype(state){
 if(state.namespaceURI==="http://www.w3.org/2000/svg"){
  const name=String(state.tagName),constructor=__compactSVGInterfaces[name.slice(name.indexOf(":")+1)];
  return constructor?constructor.prototype:SVGElement.prototype;
 }
 if(state.namespaceURI==="http://www.w3.org/1998/Math/MathML")return MathMLElement.prototype;
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml")return Element.prototype;
 const name=String(state.tagName),local=name.slice(name.indexOf(":")+1);
 const constructor=__compactHTMLInterfaces[local];
 return constructor?constructor.prototype:HTMLElement.prototype;
}
' + compact_svg_interfaces_bootstrap() + compact_svg_animated_bootstrap() + compact_template_bootstrap() + compact_iframe_reflection_bootstrap() + compact_toggle_attribute_bootstrap() + compact_html_language_bootstrap() + compact_native_state_bootstrap()
}
