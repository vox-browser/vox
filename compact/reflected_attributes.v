module main

// IDL attributes that reflect content attributes, defined over the elements'
// own getAttribute/setAttribute so mutation records and custom element
// reactions follow the attribute change:
// https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflecting-content-attributes-in-idl-attributes
// ARIAMixin (https://w3c.github.io/aria/#ARIAMixin) and the HTMLElement
// attributes that were missing.
fn compact_reflected_attributes_bootstrap() string {
	return r'
(function(){
 function string(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);}
 function define(prototype,name,get,set){
  if(!prototype||Object.prototype.hasOwnProperty.call(prototype,name))return;
  Object.defineProperty(prototype,name,{get,set,enumerable:true,configurable:true});
 }
 // Nullable DOMString reflection: a missing attribute is null, null removes it.
 function nullableString(prototype,name,attribute){
  define(prototype,name,function(){return this.getAttribute(attribute);},function(value){if(value===null||value===undefined)this.removeAttribute(attribute);else this.setAttribute(attribute,string(value));});
 }
 function plainString(prototype,name,attribute){
  define(prototype,name,function(){const value=this.getAttribute(attribute);return value===null?"":value;},function(value){this.setAttribute(attribute,string(value));});
 }
 function boolean(prototype,name,attribute){
  define(prototype,name,function(){return this.hasAttribute(attribute);},function(value){if(value)this.setAttribute(attribute,"");else this.removeAttribute(attribute);});
 }
 // Enumerated reflection limited to known values: the canonical keyword, or
 // the missing/invalid default.
 function enumerated(prototype,name,attribute,keywords,missing,invalid,empty){
  define(prototype,name,function(){
   const value=this.getAttribute(attribute);
   if(value===null)return missing;
   const lower=value.toLowerCase();
   if(lower===""&&empty!==undefined)return empty;
   return Object.prototype.hasOwnProperty.call(keywords,lower)?keywords[lower]:invalid;
  },function(value){
   if(value===null&&missing===null){this.removeAttribute(attribute);return;}
   this.setAttribute(attribute,string(value));
  });
 }
 const aria=["role","ariaAtomic","ariaAutoComplete","ariaBrailleLabel","ariaBrailleRoleDescription","ariaBusy","ariaChecked","ariaColCount","ariaColIndex","ariaColIndexText","ariaColSpan","ariaCurrent","ariaDescription","ariaDisabled","ariaExpanded","ariaHasPopup","ariaHidden","ariaInvalid","ariaKeyShortcuts","ariaLabel","ariaLevel","ariaLive","ariaModal","ariaMultiLine","ariaMultiSelectable","ariaOrientation","ariaPlaceholder","ariaPosInSet","ariaPressed","ariaReadOnly","ariaRelevant","ariaRequired","ariaRoleDescription","ariaRowCount","ariaRowIndex","ariaRowIndexText","ariaRowSpan","ariaSelected","ariaSetSize","ariaSort","ariaValueMax","ariaValueMin","ariaValueNow","ariaValueText"];
 for(const name of aria)nullableString(Element.prototype,name,name==="role"?"role":"aria-"+name.slice(4).toLowerCase());
 plainString(Element.prototype,"slot","slot");
 const element=typeof HTMLElement==="function"?HTMLElement.prototype:null;
 if(!element)return;
 plainString(element,"accessKey","accesskey");
 boolean(element,"autofocus","autofocus");
 boolean(element,"inert","inert");
 enumerated(element,"dir","dir",{ltr:"ltr",rtl:"rtl",auto:"auto"},"","");
 enumerated(element,"enterKeyHint","enterkeyhint",{enter:"enter",done:"done",go:"go",next:"next",previous:"previous",search:"search",send:"send"},"","");
 enumerated(element,"inputMode","inputmode",{none:"none",text:"text",tel:"tel",url:"url",email:"email",numeric:"numeric",decimal:"decimal",search:"search"},"","");
 enumerated(element,"popover","popover",{auto:"auto",manual:"manual",hint:"hint"},null,"manual","auto");
 // translate inherits the yes/no state of the nearest ancestor; the default is yes.
 define(element,"translate",function(){
  for(let current=this;current&&current.nodeType===1;current=current.parentNode){
   const value=current.getAttribute("translate");
   if(value===null)continue;
   const lower=value.toLowerCase();
   if(lower===""||lower==="yes")return true;
   if(lower==="no")return false;
  }
  return true;
 },function(value){this.setAttribute("translate",value?"yes":"no");});
 // draggable: true/false, else images and links with an href drag by default.
 define(element,"draggable",function(){
  const value=(this.getAttribute("draggable")||"").toLowerCase();
  if(value==="true")return true;
  if(value==="false")return false;
  return this.localName==="img"||(this.localName==="a"&&this.hasAttribute("href"));
 },function(value){this.setAttribute("draggable",value?"true":"false");});
 // tabIndex: a valid integer, else 0 for focusable areas and -1 otherwise.
 define(element,"tabIndex",function(){
  const value=this.getAttribute("tabindex");
  if(value!==null){
   const match=/^[\t\n\f\r ]*([+-]?[0-9]+)/.exec(value);
   if(match){const parsed=parseInt(match[1],10);if(parsed>=-2147483648&&parsed<=2147483647)return parsed;}
  }
  const name=this.localName;
  if((name==="a"||name==="area")&&this.hasAttribute("href"))return 0;
  if(["button","input","select","textarea","iframe","object","embed","summary"].includes(name))return 0;
  if(this.hasAttribute("contenteditable")&&(this.getAttribute("contenteditable")||"").toLowerCase()!=="false")return 0;
  return -1;
 },function(value){this.setAttribute("tabindex",String(Number(value)|0));});
 define(element,"contentEditable",function(){
  const value=this.getAttribute("contenteditable");
  if(value===null)return "inherit";
  const lower=value.toLowerCase();
  if(lower===""||lower==="true")return "true";
  if(lower==="false")return "false";
  if(lower==="plaintext-only")return "plaintext-only";
  return "inherit";
 },function(value){
  const lower=string(value).toLowerCase();
  if(lower==="inherit")this.removeAttribute("contenteditable");
  else if(lower==="true"||lower==="false"||lower==="plaintext-only")this.setAttribute("contenteditable",lower);
  else throw new DOMException("The value must be true, false, plaintext-only or inherit","SyntaxError");
 });
})();
'
}

// classList objects are built per element; give them the DOMTokenList
// interface so they brand, stringify and iterate as one.
fn compact_dom_token_list_bootstrap() string {
	return r'
(function(){
 if(typeof globalThis.DOMTokenList!=="function"){
  const DOMTokenList=function DOMTokenList(){throw new TypeError("Illegal constructor");};
  Object.defineProperty(DOMTokenList.prototype,Symbol.toStringTag,{value:"DOMTokenList",configurable:true});
  Object.defineProperty(globalThis,"DOMTokenList",{value:DOMTokenList,writable:true,configurable:true});
 }
 const prototype=globalThis.DOMTokenList.prototype;
 if(!(Symbol.iterator in prototype)){
  Object.defineProperty(prototype,Symbol.iterator,{value:function*(){for(let index=0;index<this.length;index++)yield this.item(index);},writable:true,configurable:true});
 }
 const brand=list=>{if(list&&typeof list==="object"&&Object.getPrototypeOf(list)===Object.prototype)Object.setPrototypeOf(list,prototype);return list;};
 // The element factories call the __classList binding of this script.
 if(typeof __classList==="function"){const original=__classList;__classList=function(state){return brand(original(state));};}
 for(const element of [document.documentElement,document.head,document.body])if(element)brand(element.classList);
})();
'
}

// Element-reflecting IDL attributes:
// https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflecting-content-attributes-in-idl-attributes
// An explicitly set element is returned while it is in a shadow-including
// ancestor tree scope; otherwise the content attribute holds IDs resolved
// in the element tree scope.
fn compact_element_reflection_bootstrap() string {
	return r'
(function(){
 const explicit=new WeakMap();
 function own(element){let values=explicit.get(element);if(!values){values={};explicit.set(element,values);}return values;}
 function inScope(element,candidate){
  const root=candidate.getRootNode();
  for(let current=element.getRootNode();current;){
   if(current===root)return true;
   if(current.nodeType===11&&current.host)current=current.host.getRootNode();else break;
  }
  return false;
 }
 function lookup(element,id){const root=element.getRootNode();return typeof root.getElementById==="function"?root.getElementById(id):null;}
 function single(prototype,name,attribute){
  if(!prototype||Object.prototype.hasOwnProperty.call(prototype,name))return;
  Object.defineProperty(prototype,name,{enumerable:true,configurable:true,
   get(){
    const set=explicit.get(this);
    if(set&&Object.prototype.hasOwnProperty.call(set,name)){const value=set[name];return value&&inScope(this,value)?value:null;}
    const id=this.getAttribute(attribute);
    return id===null?null:lookup(this,id);
   },
   set(value){
    if(value===null||value===undefined){if(explicit.get(this))delete own(this)[name];this.removeAttribute(attribute);return;}
    if(!(value instanceof Element))throw new TypeError("The value must be an Element or null");
    own(this)[name]=value;this.setAttribute(attribute,"");
   }});
 }
 function list(prototype,name,attribute){
  if(!prototype||Object.prototype.hasOwnProperty.call(prototype,name))return;
  Object.defineProperty(prototype,name,{enumerable:true,configurable:true,
   get(){
    const set=explicit.get(this);
    if(set&&Object.prototype.hasOwnProperty.call(set,name))return Object.freeze(set[name].filter(element=>inScope(this,element)));
    const value=this.getAttribute(attribute);
    if(value===null)return null;
    const elements=[];
    for(const id of value.split(/[\t\n\f\r ]+/))if(id){const element=lookup(this,id);if(element)elements.push(element);}
    return Object.freeze(elements);
   },
   set(value){
    if(value===null||value===undefined){if(explicit.get(this))delete own(this)[name];this.removeAttribute(attribute);return;}
    const elements=Array.from(value);
    for(const element of elements)if(!(element instanceof Element))throw new TypeError("The values must be Elements");
    own(this)[name]=elements;this.setAttribute(attribute,"");
   }});
 }
 single(Element.prototype,"ariaActiveDescendantElement","aria-activedescendant");
 for(const [name,attribute] of [["ariaControlsElements","aria-controls"],["ariaDescribedByElements","aria-describedby"],["ariaDetailsElements","aria-details"],["ariaErrorMessageElements","aria-errormessage"],["ariaFlowToElements","aria-flowto"],["ariaLabelledByElements","aria-labelledby"],["ariaOwnsElements","aria-owns"]])list(Element.prototype,name,attribute);
 for(const name of ["HTMLButtonElement","HTMLInputElement"])if(typeof globalThis[name]==="function")single(globalThis[name].prototype,"popoverTargetElement","popovertarget");
 if(typeof globalThis.HTMLButtonElement==="function")single(HTMLButtonElement.prototype,"commandForElement","commandfor");
})();
'
}

