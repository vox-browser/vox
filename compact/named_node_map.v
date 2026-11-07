module main

// DOM Attr and NamedNodeMap over the compact facade's ordered attribute
// records. The map is [SameObject] and live: indexed and named properties read
// the element's current records on every access, so a map held across
// setAttribute()/removeAttribute() calls observes them. Attr nodes keep their
// identity per namespace/local name while attached; value writes go through
// the ordinary mutation path (journal, reflected state and native replay).
// jQuery's option/select value hooks read elem.attributes.value.specified.
fn compact_named_node_map_bootstrap() string {
	return r'
const __compactAttributeNodes=(function(){
 "use strict";
 const XHTML="http://www.w3.org/1999/xhtml";
 const nodes=new WeakMap(),caches=new WeakMap(),maps=new WeakMap(),mapStates=new WeakMap();
 function Attr(){throw new TypeError("Illegal constructor");}
 function NamedNodeMap(){throw new TypeError("Illegal constructor");}
 Object.setPrototypeOf(Attr,Node);Object.setPrototypeOf(Attr.prototype,Node.prototype);
 for(const [name,constructor] of [["Attr",Attr],["NamedNodeMap",NamedNodeMap]]){
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 function records(state){return state.attributeRecords||[];}
 function key(record){return (record.namespaceURI===null?"":record.namespaceURI)+"\u0000"+record.localName;}
 function lowerASCII(name){return name.replace(/[A-Z]/g,function(character){return String.fromCharCode(character.charCodeAt(0)+32);});}
 // Qualified-name lookups lowercase ASCII for HTML elements, as setAttribute does.
 function qualified(state,name){return state.namespaceURI===XHTML?lowerASCII(name):name;}
 function node(element,state,record){
  let cache=caches.get(state);
  if(!cache){cache=new Map();caches.set(state,cache);}
  const id=key(record);let attr=cache.get(id);
  if(attr){const info=nodes.get(attr);info.name=record.name;info.prefix=record.prefix;info.value=record.value;return attr;}
  attr=Object.create(Attr.prototype);
  nodes.set(attr,{element:element,state:state,key:id,namespaceURI:record.namespaceURI,prefix:record.prefix,localName:record.localName,name:record.name,value:record.value,detached:false});
  cache.set(id,attr);return attr;
 }
 // The current record of the attribute, or null once it left its element. A
 // detached Attr keeps its last value and a later attribute gets a new node.
 function current(info){
  if(info.detached)return null;
  const list=records(info.state);
  for(let i=0;i<list.length;i++)if(key(list[i])===info.key){const record=list[i];info.name=record.name;info.prefix=record.prefix;info.value=record.value;return record;}
  info.detached=true;const cache=caches.get(info.state);if(cache)cache.delete(info.key);
  return null;
 }
 function attrInfo(receiver){const info=nodes.get(receiver);if(!info)throw new TypeError("Illegal Attr receiver");current(info);return info;}
 function stringValue(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);}
 function write(info,value){
  if(!current(info)){info.value=value;return;}
  const state=info.state,name=info.name;
  if(info.namespaceURI===null&&name==="src")__setElementSource(state,value);
  else if(info.namespaceURI===null&&name==="data")__setElementData(state,value);
  else __setAttribute(state,name,value);
  current(info);
 }
 function accessor(target,name,get,set){Object.defineProperty(target,name,{get:get,set:set,enumerable:true,configurable:true});}
 accessor(Attr.prototype,"namespaceURI",function(){return attrInfo(this).namespaceURI;});
 accessor(Attr.prototype,"prefix",function(){return attrInfo(this).prefix;});
 accessor(Attr.prototype,"localName",function(){return attrInfo(this).localName;});
 accessor(Attr.prototype,"name",function(){return attrInfo(this).name;});
 accessor(Attr.prototype,"nodeName",function(){return attrInfo(this).name;});
 accessor(Attr.prototype,"nodeType",function(){attrInfo(this);return 2;});
 for(const name of ["value","nodeValue","textContent"]){
  accessor(Attr.prototype,name,function(){return attrInfo(this).value;},function(value){const info=attrInfo(this);write(info,name==="value"?stringValue(value):(value===null?"":stringValue(value)));});
 }
 accessor(Attr.prototype,"ownerElement",function(){const info=attrInfo(this);return info.detached?null:info.element;});
 accessor(Attr.prototype,"ownerDocument",function(){return attrInfo(this).element.ownerDocument;});
 accessor(Attr.prototype,"specified",function(){attrInfo(this);return true;});
 for(const name of ["parentNode","parentElement","firstChild","lastChild","previousSibling","nextSibling"])accessor(Attr.prototype,name,function(){attrInfo(this);return null;});
 Object.defineProperty(Attr.prototype,"hasChildNodes",{value:function hasChildNodes(){attrInfo(this);return false;},writable:true,enumerable:true,configurable:true});
 function mapOwner(receiver){const owner=mapStates.get(receiver);if(!owner)throw new TypeError("Illegal NamedNodeMap receiver");return owner;}
 function byName(owner,name){
  name=qualified(owner.state,name);const list=records(owner.state);
  for(let i=0;i<list.length;i++)if(list[i].name===name)return node(owner.element,owner.state,list[i]);
  return null;
 }
 function byNamespace(owner,namespace,localName){
  namespace=namespace===null||namespace===undefined||namespace===""?null:stringValue(namespace);const list=records(owner.state);
  for(let i=0;i<list.length;i++)if(list[i].namespaceURI===namespace&&list[i].localName===localName)return node(owner.element,owner.state,list[i]);
  return null;
 }
 function at(owner,index){const list=records(owner.state);return index<list.length?node(owner.element,owner.state,list[index]):null;}
 function method(name,length,body){
  const value={[name](){return body.apply(this,arguments);}}[name];
  Object.defineProperty(value,"length",{value:length});
  Object.defineProperty(NamedNodeMap.prototype,name,{value:value,writable:true,enumerable:true,configurable:true});
 }
 Object.defineProperty(NamedNodeMap.prototype,"length",{get:function(){return records(mapOwner(this).state).length;},enumerable:true,configurable:true});
 method("item",1,function(index){const owner=mapOwner(this);if(arguments.length===0)throw new TypeError("item requires an index");return at(owner,Number(index)>>>0);});
 method("getNamedItem",1,function(name){const owner=mapOwner(this);if(arguments.length===0)throw new TypeError("getNamedItem requires a name");return byName(owner,stringValue(name));});
 method("getNamedItemNS",2,function(namespace,localName){const owner=mapOwner(this);if(arguments.length<2)throw new TypeError("getNamedItemNS requires two arguments");return byNamespace(owner,namespace,stringValue(localName));});
 function removeNode(owner,attr){
  if(!attr)throw new DOMException("The attribute was not found","NotFoundError");
  const info=nodes.get(attr);__removeAttribute(owner.state,info.name);current(info);return attr;
 }
 method("removeNamedItem",1,function(name){const owner=mapOwner(this);if(arguments.length===0)throw new TypeError("removeNamedItem requires a name");return removeNode(owner,byName(owner,stringValue(name)));});
 method("removeNamedItemNS",2,function(namespace,localName){const owner=mapOwner(this);if(arguments.length<2)throw new TypeError("removeNamedItemNS requires two arguments");return removeNode(owner,byNamespace(owner,namespace,stringValue(localName)));});
 // Only Attr nodes this facade created exist; a detached one can be attached
 // to another element, replacing the same-named attribute there.
 // Without a namespaced setter a namespaced node is matched, not created.
 function setNode(attr){
  const owner=mapOwner(this);if(arguments.length===0)throw new TypeError("setNamedItem requires an Attr");
  const info=nodes.get(attr);if(!info)throw new TypeError("Expected an Attr");
  current(info);
  if(!info.detached){if(info.state===owner.state)return attr;throw new DOMException("The attribute is in use by another element","InUseAttributeError");}
  const previous=info.namespaceURI===null?byName(owner,info.name):byNamespace(owner,info.namespaceURI,info.localName);
  const value=info.value;
  if(previous){const old=nodes.get(previous);__setAttribute(owner.state,old.name,value);old.detached=true;caches.get(owner.state).delete(old.key);info.key=old.key;info.localName=old.localName;}
  else{__setAttribute(owner.state,info.name,value);if(info.namespaceURI===null){info.localName=qualified(owner.state,info.name);info.key=key(info);}}
  let cache=caches.get(owner.state);if(!cache){cache=new Map();caches.set(owner.state,cache);}
  info.element=owner.element;info.state=owner.state;info.detached=false;cache.set(info.key,attr);current(info);
  return previous;
 }
 method("setNamedItem",1,setNode);
 method("setNamedItemNS",1,setNode);
 Object.defineProperty(NamedNodeMap.prototype,Symbol.iterator,{value:Array.prototype.values,writable:true,configurable:true});
 function isIndex(property){return typeof property==="string"&&/^(0|[1-9][0-9]*)$/.test(property)&&Number(property)<4294967295;}
 // Supported property names: qualified names in order without duplicates;
 // an HTML element omits names containing ASCII uppercase.
 function names(owner){
  const list=records(owner.state),result=[],seen=new Set();
  for(let i=0;i<list.length;i++){const name=list[i].name;if(seen.has(name))continue;seen.add(name);if(owner.state.namespaceURI===XHTML&&/[A-Z]/.test(name))continue;result.push(name);}
  return result;
 }
 function named(owner,target,property){
  if(typeof property!=="string"||isIndex(property)||Reflect.has(target,property))return null;
  return names(owner).includes(property)?byName(owner,property):null;
 }
 function map(element,state){
  const target=Object.create(NamedNodeMap.prototype),owner={element:element,state:state};
  const proxy=new Proxy(target,{
   get(target,property,receiver){
    if(isIndex(property)){const attr=at(owner,Number(property));if(attr)return attr;}
    else{const attr=named(owner,target,property);if(attr)return attr;}
    return Reflect.get(target,property,receiver);
   },
   has(target,property){
    if(isIndex(property))return Number(property)<records(state).length||Reflect.has(target,property);
    return !!named(owner,target,property)||Reflect.has(target,property);
   },
   ownKeys(target){
    const result=[];for(let i=0;i<records(state).length;i++)result.push(String(i));
    for(const name of names(owner))if(!Object.prototype.hasOwnProperty.call(target,name))result.push(name);
    return result.concat(Reflect.ownKeys(target));
   },
   getOwnPropertyDescriptor(target,property){
    if(isIndex(property)){const attr=at(owner,Number(property));if(attr)return{value:attr,writable:false,enumerable:true,configurable:true};}
    else{const attr=named(owner,target,property);if(attr)return{value:attr,writable:false,enumerable:false,configurable:true};}
    return Reflect.getOwnPropertyDescriptor(target,property);
   },
   defineProperty(target,property,descriptor){
    if(isIndex(property)||named(owner,target,property))return false;
    return Reflect.defineProperty(target,property,descriptor);
   },
   set(target,property,value,receiver){
    if(isIndex(property)&&Number(property)<records(state).length||named(owner,target,property))return false;
    return Reflect.set(target,property,value,receiver);
   },
   deleteProperty(target,property){
    if(isIndex(property))return !(Number(property)<records(state).length)&&Reflect.deleteProperty(target,property);
    if(named(owner,target,property))return false;
    return Reflect.deleteProperty(target,property);
   },
   preventExtensions(){return false;}
  });
  mapStates.set(proxy,owner);
  return proxy;
 }
 function elementState(receiver){const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);if(!state)throw new TypeError("Illegal Element receiver");return state;}
 const attributes=Object.getOwnPropertyDescriptor({get attributes(){
  const state=elementState(this);let result=maps.get(state);
  if(!result){result=map(this,state);maps.set(state,result);}
  return result;
 }},"attributes").get;
 Object.defineProperty(Element.prototype,"attributes",{get:attributes,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"hasAttributes",{value:function hasAttributes(){return records(elementState(this)).length>0;},writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"getAttributeNode",{value:function getAttributeNode(qualifiedName){
  const state=elementState(this);if(arguments.length===0)throw new TypeError("getAttributeNode requires a name");
  return byName({element:this,state:state},stringValue(qualifiedName));
 },writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"getAttributeNodeNS",{value:function getAttributeNodeNS(namespace,localName){
  const state=elementState(this);if(arguments.length<2)throw new TypeError("getAttributeNodeNS requires two arguments");
  return byNamespace({element:this,state:state},namespace,stringValue(localName));
 },writable:true,enumerable:true,configurable:true});
 return {map:map};
})();
'
}
