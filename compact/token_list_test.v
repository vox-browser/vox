module main

import browserjs
import dom
import html

fn run_native_token_list_check(source string) {
	url := dom.URL{value: 'https://token-lists.test/'}
	mut document := html.create_navigation_document(url, url.origin(), none) or { panic(err) }
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><body><div id="target" class=" a  a\tb "></div><svg><g id="drawing"></g></svg></body>')
	allocation.finish()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.destroy_a_document_and_its_descendants(); document.finalize(); document.release_native_storage() }
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [source], runtime, mut messages)
	assert messages == ['token list passed'], messages.join('\n')
}

fn test_native_class_list_is_live_same_object_indexed_and_iterable() {
	run_native_token_list_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const list=target.classList;
check(list,target.classList);check(list instanceof DOMTokenList,true);check(Object.prototype.toString.call(list),"[object DOMTokenList]");
check(list.length,2);check(list.item(0),"a");check(list[1],"b");check(list[2],undefined);check(list.item(2),null);check(list.item(-1),null);check(String(list)," a  a\tb ");
check(JSON.stringify(Object.keys(list)),"[\"0\",\"1\"]");check(Object.getOwnPropertyDescriptor(list,"0").writable,false);check(Reflect.set(list,"0","x"),false);
Object.defineProperty(DOMTokenList.prototype,"9",{value:"inherited",configurable:true});try{check(list[9],"inherited");check(Object.prototype.hasOwnProperty.call(list,"9"),false);}finally{delete DOMTokenList.prototype[9];}
check(JSON.stringify([...list]),"[\"a\",\"b\"]");check(JSON.stringify([...list.entries()]),"[[0,\"a\"],[1,\"b\"]]");check(JSON.stringify([...list.keys()]),"[0,1]");
target.setAttribute("class","changed changed last");check(list.length,2);check(list[0],"changed");check(list.value,"changed changed last");
list.add("last","new");check(target.className,"changed last new");check(list.toggle("last"),false);check(list.toggle("last",false),false);check(list.toggle("last",true),true);
check(list.replace("changed","new"),true);check(String(list),"new last");check(list.replace("missing","other"),false);
target.classList="first second";check(list.value,"first second");
const seen=[],receiver={};list.forEach(function(value,index,actual){check(this,receiver);check(actual,list);seen.push(value+index);if(index===0)list.add("third");},receiver);check(seen.join(","),"first0,second1");check(list.value,"first second third");
for(const method of ["values","keys","entries","forEach"])check(DOMTokenList.prototype[method],Array.prototype[method]);check(list[Symbol.iterator],Array.prototype.values);check([...DOMTokenList.prototype.values.call({0:"generic",length:1})].join(","),"generic");
const created=document.createElement("div");const fresh=created.classList;check(fresh,created.classList);fresh.add();check(created.hasAttribute("class"),false);fresh.value=" x x ";fresh.remove();check(fresh.value,"x");
console.log("token list passed");
')
}

fn test_native_class_list_rejects_invalid_tokens_without_partial_mutations() {
	run_native_token_list_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const list=target.classList;list.value="seed second";
for(const [operation,name] of [[()=>list.add("added",""),"SyntaxError"],[()=>list.add("added","bad token"),"InvalidCharacterError"],[()=>list.remove("seed","bad\ntoken"),"InvalidCharacterError"],[()=>list.replace("seed",""),"SyntaxError"],[()=>list.toggle(" "),"InvalidCharacterError"]]){
 let caught;try{operation();}catch(error){caught=error;}check(caught instanceof DOMException,true);check(caught.name,name);check(list.value,"seed second");check([...list].join(","),"seed,second");
}
check(list.contains(""),false);check(list.contains("bad token"),false);list.add("non\u00a0breaking");check(list.contains("non\u00a0breaking"),true);
let conversions=0;const value={toString(){conversions++;return "valid";}};
for(const receiver of [null,{},Object.create(list)]){let rejected=false;try{DOMTokenList.prototype.add.call(receiver,value);}catch(error){rejected=error instanceof TypeError;}check(rejected,true);}check(conversions,0);
for(const operation of [()=>list.item(),()=>list.contains(),()=>list.toggle(),()=>list.replace("seed"),()=>list.supports(),()=>list.item(1n),()=>list.add(Symbol())]){let rejected=false;try{operation();}catch(error){rejected=error instanceof TypeError;}check(rejected,true);}
const reason={original:true};let caught;try{list.add("valid",{[Symbol.toPrimitive](hint){check(hint,"string");throw reason;}});}catch(error){caught=error;}check(caught,reason);check(list.contains("valid"),false);
let unsupported=false;try{list.supports("seed");}catch(error){unsupported=error instanceof TypeError;}check(unsupported,true);
console.log("token list passed");
')
}

fn test_native_class_list_updates_svg_and_delivers_attribute_reactions_once() {
	run_native_token_list_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
drawing.classList.add("svg");check(drawing.className.baseVal,"svg");drawing.className.baseVal="animated";check(drawing.classList[0],"animated");
const events=[];class Observed extends HTMLElement{static get observedAttributes(){return ["class"];}attributeChangedCallback(name,old,value){events.push([old,value,this.className].join("|"));}}
customElements.define("x-token-observed",Observed);const element=new Observed(),list=element.classList;
const observer=new MutationObserver(()=>{});observer.observe(element,{attributes:true,attributeOldValue:true});
list.add("one","two");check(events.join(","),"|one two|one two");const records=observer.takeRecords();check(records.length,1);check(records[0].attributeName,"class");check(records[0].oldValue,null);
try{list.remove("one","");}catch(error){}check(observer.takeRecords().length,0);check(events.length,1);check(list.value,"one two");
const descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"classList");check(descriptor.get.name,"get classList");check(descriptor.set.name,"set classList");
console.log("token list passed");
')
}

fn test_native_token_list_attributes_are_limited_to_their_declared_elements() {
	run_native_token_list_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const html="http://www.w3.org/1999/xhtml",svg="http://www.w3.org/2000/svg";
for(const namespace of [html,svg,"http://www.w3.org/1998/Math/MathML","urn:custom",""]){
 for(const tag of ["a","area","link","iframe","output","td","th"]){
  const element=document.createElementNS(namespace,tag);
  for(const [property,tags] of [["classList",null],["relList",["a","area","link"]],["htmlFor",["output"]],["sandbox",["iframe"]],["sizes",["link"]]]){
   const expected=property==="classList"||namespace===html&&tags.includes(tag)||namespace===svg&&tag==="a"&&property==="relList";
   check(Object.prototype.toString.call(element[property]),expected?"[object DOMTokenList]":"[object Undefined]");
  }
 }
}


for(const [tag,property,attribute] of [["a","relList","rel"],["area","relList","rel"],["link","relList","rel"],["form","relList","rel"],["iframe","sandbox","sandbox"],["output","htmlFor","for"],["link","sizes","sizes"]]){
 const element=document.createElement(tag),list=element[property];check(list,element[property]);element[property]="one two";check(element.getAttribute(attribute),"one two");list.add("three");check(element.getAttribute(attribute),"one two three");
 const get=Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element),property)?.get;
 if(get){let rejected=false;try{get.call(target);}catch(error){rejected=error instanceof TypeError;}check(rejected,true);}
}
const anchor=document.createElementNS(svg,"a");anchor.relList="noopener";check(anchor.relList.supports("NOOPENER"),true);check(anchor.relList.supports("not-supported"),false);
const frame=document.createElement("iframe");check(frame.sandbox.supports("allow-scripts"),true);
console.log("token list passed");
')
}

fn test_token_list_forwarding_uses_the_public_getter_and_preserves_assignment_values() {
	run_native_token_list_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
for(const [element,prototype,property] of [[target,Element.prototype,"classList"],[document.createElement("a"),HTMLAnchorElement.prototype,"relList"]]){
 const setter=Object.getOwnPropertyDescriptor(prototype,property).set,forwarded={};let conversions=0;
 const value={toString(){conversions++;return "converted";}};
 Object.defineProperty(element,property,{get(){return forwarded;},configurable:true});setter.call(element,value);check(forwarded.value,value);check(conversions,0);
 const frozen=Object.freeze({value:"unchanged"});Object.defineProperty(element,property,{get(){return frozen;},configurable:true});check(setter.call(element,"ignored"),undefined);check(frozen.value,"unchanged");
 const reason={original:true};Object.defineProperty(element,property,{get(){throw reason;},configurable:true});let caught;try{setter.call(element,value);}catch(error){caught=error;}check(caught,reason);check(conversions,0);
 Object.defineProperty(element,property,{get(){return null;},configurable:true});let rejected=false;try{setter.call(element,value);}catch(error){rejected=error instanceof TypeError;}check(rejected,true);check(conversions,0);
 let reads=0;const fake={get [property](){reads++;return forwarded;}};rejected=false;try{setter.call(fake,value);}catch(error){rejected=error instanceof TypeError;}check(rejected,true);check(reads,0);
}
console.log("token list passed");
')
}
