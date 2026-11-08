module main

import dom
import html

// HTMLSelectElement.selectedIndex for a script. Like compact_select_value(), a
// single-line select without a selected option reports the option the
// selectedness setting algorithm would select, without changing the document.
fn compact_select_selected_index(select_element &dom.HTMLSelectElement) i32 {
	selected := html.html_select_element_selected_index(select_element)
	element := unsafe { &dom.Element(select_element) }
	if selected >= 0 || element.has_attribute('multiple')
		|| html.html_select_element_display_size(select_element) != 1 {
		return selected
	}
	for index, option in html.html_select_element_list_of_options(select_element) {
		if !html.html_option_element_disabled(option) {
			return i32(index)
		}
	}
	return -1
}

// HTMLSelectElement.selectedIndex and options on compact select facades. The
// live select's options own the selection; 4chan's catalog shows its saved
// settings by assigning selectedIndex.
fn compact_select_bootstrap() string {
	return r'
function __compactSelect(o,s){
 Object.defineProperty(o,"value",{configurable:true,enumerable:true,get:function(){
  return __queryElements(s.bridgeKey,"selectValue","");
 },set:function(value){
  if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
  __queryElements(s.bridgeKey,"setSelectValue",String(value));
 }});
 Object.defineProperty(o,"selectedIndex",{configurable:true,enumerable:true,get:function(){
  if(s.created&&!s.parentKey)return -1;
  return __queryElements(s.bridgeKey,"selectedIndex","");
 },set:function(value){
  if(s.created&&!s.parentKey)return;
  __queryElements(s.bridgeKey,"setSelectedIndex",String(value|0));
 }});
 let options=null;
 Object.defineProperty(o,"options",{configurable:true,enumerable:true,get:function(){
  if(!options)options=__compactOptionsCollection(o,__classCollection(s.bridgeKey,"",function(){
   if(s.created&&!s.parentKey)return [];
   return __queryElements(s.bridgeKey,"querySelectorAll","option");
  }));
  return options;
 }});
 __compactSelectMembers(o,s);
}
// https://html.spec.whatwg.org/multipage/form-elements.html#the-htmloptionscollection-interface
// The options of a select, with the HTMLOptionsCollection members over the
// live HTMLCollection.
function __compactOptionsCollection(select,collection){
 const members={
  add(element,before){if(arguments.length===0)throw new TypeError("add requires an element");return select.add(element,before);},
  remove(index){select.remove(index);}
 };
 for(const name of Object.keys(members))Object.defineProperty(members[name],"name",{value:name});
 return new Proxy(collection,{
  get(target,property,receiver){
   if(property==="selectedIndex")return select.selectedIndex;
   if(Object.prototype.hasOwnProperty.call(members,property))return members[property];
   return Reflect.get(target,property,receiver);
  },
  set(target,property,value,receiver){
   if(property==="length"){select.length=value;return true;}
   if(property==="selectedIndex"){select.selectedIndex=value;return true;}
   if(typeof property==="string"&&/^(0|[1-9][0-9]*)$/.test(property)){__compactSetOptionAt(select,Number(property),value);return true;}
   return Reflect.set(target,property,value,receiver);
  },
  has(target,property){return property==="selectedIndex"||Object.prototype.hasOwnProperty.call(members,property)||Reflect.has(target,property);}
 });
}
// https://html.spec.whatwg.org/multipage/form-elements.html#dom-htmloptionscollection-setter
function __compactSetOptionAt(select,index,option){
 const options=select.options,length=options.length;
 if(option===null){if(index<length)options[index].remove();return;}
 if(!(option instanceof HTMLOptionElement))throw new TypeError("Value is not an HTMLOptionElement");
 if(index>=length){for(let count=index-length;count>0;count--)select.appendChild(document.createElement("option"));select.appendChild(option);return;}
 const old=options[index];old.parentNode.replaceChild(option,old);
}
// HTMLSelectElement.add(), remove(), length, item(), namedItem(), type and
// selectedOptions over the list of options of the select.
function __compactSelectMembers(o,s){
 const define=(name,descriptor)=>Object.defineProperty(o,name,Object.assign({configurable:true,enumerable:true},descriptor));
 define("type",{get(){return this.hasAttribute("multiple")?"select-multiple":"select-one";}});
 define("length",{get(){return this.options.length;},set(value){
  const target=Number(value)>>>0,options=this.options;let length=options.length;
  if(target>100000)return;
  for(;length<target;length++)this.appendChild(document.createElement("option"));
  for(;length>target;length--)options[length-1].remove();
 }});
 define("item",{value:function item(index){if(arguments.length===0)throw new TypeError("item requires an index");return this.options.item(index);},writable:true});
 define("namedItem",{value:function namedItem(name){if(arguments.length===0)throw new TypeError("namedItem requires a name");return this.options.namedItem(name);},writable:true});
 define("add",{value:function add(element,before){
  if(arguments.length===0)throw new TypeError("add requires an element");
  if(!(element instanceof HTMLOptionElement)&&!(element instanceof HTMLOptGroupElement))throw new TypeError("add requires an option or optgroup element");
  for(let ancestor=this;ancestor;ancestor=ancestor.parentNode)if(ancestor===element)throw new DOMException("The element is an ancestor of the select","HierarchyRequestError");
  let reference=null;
  if(typeof before==="number"||(before!==null&&before!==undefined&&typeof before!=="object"))reference=this.options[Number(before)|0]||null;
  else if(before!==null&&before!==undefined){
   if(!(before instanceof HTMLElement))throw new TypeError("before must be an element or an index");
   let inside=false;for(let ancestor=before;ancestor;ancestor=ancestor.parentNode)if(ancestor===this){inside=true;break;}
   if(!inside)throw new DOMException("The reference element is not in the select","NotFoundError");
   reference=before;
  }
  if(element===reference)return;
  (reference?reference.parentNode:this).insertBefore(element,reference);
 },writable:true});
 define("remove",{value:function remove(index){
  if(arguments.length===0){return Element.prototype.remove.call(this);}
  const option=this.options[Number(index)|0];if(option&&Number(index)>=0)option.remove();
 },writable:true});
 let selected=null;
 define("selectedOptions",{get(){
  if(!selected)selected=__classCollection(s.bridgeKey,"",()=>Array.from(this.options).filter(option=>option.selected));
  return selected;
 }});
}
const __optionScriptNamespaces=["http://www.w3.org/1999/xhtml","http://www.w3.org/2000/svg"];
function __compactOptionText(node){
 let text="";
 for(let child=node.firstChild;child;child=child.nextSibling){
  if(child.nodeType===3||child.nodeType===4)text+=child.data;
  else if(child.nodeType===1&&!(child.localName==="script"&&__optionScriptNamespaces.includes(child.namespaceURI)))text+=__compactOptionText(child);
 }
 return text;
}
// https://infra.spec.whatwg.org/#strip-and-collapse-ascii-whitespace
function __compactStripAndCollapse(value){return value.replace(/[\t\n\f\r ]+/g," ").replace(/^ /,"").replace(/ $/,"");}
function __compactOptionSelect(option){
 const parent=option.parentNode;
 if(!parent||parent.nodeType!==1||parent.namespaceURI!=="http://www.w3.org/1999/xhtml")return null;
 if(parent.localName==="select")return parent;
 if(parent.localName==="optgroup"){const grand=parent.parentNode;if(grand&&grand.nodeType===1&&grand.localName==="select"&&grand.namespaceURI==="http://www.w3.org/1999/xhtml")return grand;}
 return null;
}
// https://html.spec.whatwg.org/multipage/form-elements.html#dom-option
function Option(text,value,defaultSelected,selected){
 if(!new.target)throw new TypeError("Option constructor requires new");
 const option=document.createElement("option");
 const data=text===undefined?"":String(text);
 if(data!=="")option.appendChild(document.createTextNode(data));
 if(value!==undefined)option.setAttribute("value",String(value));
 if(defaultSelected)option.setAttribute("selected","");
 option.selected=!!selected;
 return option;
}
if(typeof HTMLOptionElement==="function"){
 Object.defineProperty(Option,"prototype",{value:HTMLOptionElement.prototype,writable:false,enumerable:false,configurable:false});
 Object.defineProperty(globalThis,"Option",{value:Option,writable:true,enumerable:false,configurable:true});
}
// HTMLOptionElement.selected sets the option selectedness and runs the
// selectedness algorithm of its select; jQuery val() on a select assigns it on
// every option. A detached script-created option keeps a local value.
const __detachedOptionSelected=new WeakMap();
function __compactOption(o,s){
 const define=(name,descriptor)=>Object.defineProperty(o,name,Object.assign({configurable:true,enumerable:true},descriptor));
 define("text",{get(){return __compactStripAndCollapse(__compactOptionText(this));},set(value){this.textContent=String(value);}});
 define("label",{get(){const label=this.getAttributeNS(null,"label");return label===null?this.text:label;},set(value){this.setAttribute("label",String(value));}});
 define("value",{get(){const value=this.getAttributeNS(null,"value");return value===null?this.text:value;},set(value){this.setAttribute("value",String(value));}});
 define("defaultSelected",{get(){return this.hasAttribute("selected");},set(value){if(value)this.setAttribute("selected","");else this.removeAttribute("selected");}});
 define("index",{get(){const select=__compactOptionSelect(this);if(!select)return 0;const index=Array.prototype.indexOf.call(Array.from(select.options),this);return index<0?0:index;}});
 define("form",{get(){const select=__compactOptionSelect(this);const form=select?select.form:null;return form===undefined?null:form;}});
 Object.defineProperty(o,"selected",{configurable:true,enumerable:true,get:function(){
  if(s.created&&!s.parentKey)return __detachedOptionSelected.get(s)===true;
  return __queryElements(s.bridgeKey,"optionSelected","",true);
 },set:function(value){
  if(s.created&&!s.parentKey){__detachedOptionSelected.set(s,!!value);return;}
  __queryElements(s.bridgeKey,"setOptionSelected",value?"true":"false",true);
 }});
}
'
}
