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
  define(prototype,name,function(){return this.getAttribute(attribute);},function(value){if(value===null)this.removeAttribute(attribute);else this.setAttribute(attribute,string(value));});
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
