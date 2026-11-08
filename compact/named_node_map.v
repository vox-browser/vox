module main

// JavaScript owns the Attr wrapper identity and NamedNodeMap proxy shape.
// Attribute values, attachment, namespace matching and ordering are native.
// Each native Attr gets an opaque key, so removal/recreation and reattachment
// preserve the identities of both the removed and replacement attributes.
fn compact_named_node_map_bootstrap() string {
	return r'
const __compactAttributeNodes=(function(){
 "use strict";
 const nodes=new WeakMap(),wrappers=new Map(),maps=new WeakMap(),mapStates=new WeakMap();
 const native=__compactNativeAttributes,string=native.string;
 function Attr(){throw new TypeError("Illegal constructor");}
 function NamedNodeMap(){throw new TypeError("Illegal constructor");}
 Object.setPrototypeOf(Attr,Node);Object.setPrototypeOf(Attr.prototype,Node.prototype);
 for(const [name,constructor] of [["Attr",Attr],["NamedNodeMap",NamedNodeMap]]){
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 function own(receiver){const key=nodes.get(receiver);if(!key)throw new TypeError("Illegal Attr receiver");return key;}
 function info(receiver){return native.call(null,"attribute",{attribute:own(receiver)});}
 function wrap(value){
  if(value===null)return null;
  let object=wrappers.get(value.key);
  if(!object){object=Object.create(Attr.prototype);nodes.set(object,value.key);wrappers.set(value.key,object);}
  return object;
 }
 function accessor(name,get,set){Object.defineProperty(Attr.prototype,name,{get,set,enumerable:true,configurable:true});}
 for(const name of ["namespaceURI","prefix","localName","name"]){accessor(name,function(){return info(this)[name];});}
 accessor("nodeName",function(){return info(this).name;});
 accessor("nodeType",function(){own(this);return 2;});
 for(const name of ["value","nodeValue","textContent"]){
  accessor(name,function(){return info(this).value;},function(value){
   const key=own(this),converted=name!=="value"&&value===null?"":string(value);
   const result=native.call(null,"setValue",{attribute:key,value:converted});
   if(result.ownerElement){const element=__queryElement(result.ownerElement);__compactCustomElementFlush(native.state(element));}
  });
 }
 accessor("ownerElement",function(){return __queryElement(info(this).ownerElement);});
 accessor("ownerDocument",function(){return __queryElement(info(this).ownerDocument);});
 accessor("specified",function(){own(this);return true;});
 for(const name of ["parentNode","parentElement","firstChild","lastChild","previousSibling","nextSibling"])accessor(name,function(){own(this);return null;});
 Object.defineProperty(Attr.prototype,"hasChildNodes",{value:function hasChildNodes(){own(this);return false;},writable:true,enumerable:true,configurable:true});
 function mapOwner(receiver){const state=mapStates.get(receiver);if(!state)throw new TypeError("Illegal NamedNodeMap receiver");return state;}
 function nullable(value){return value===null||value===undefined?null:string(value);}
 function byName(state,name){return wrap(native.call(state,"getNode",{name}));}
 function byNamespace(state,namespace,name){return wrap(native.call(state,"getNodeNS",{namespace,name}));}
 function at(state,index){return wrap(native.call(state,"item",{index}));}
 function length(state){return native.call(state,"length");}
 function names(state){return native.call(state,"supportedNames");}
 function mutate(state,op,fields){const result=native.call(state,op,fields);__compactCustomElementFlush(state);return wrap(result);}
 function method(name,length,body){
  const value={[name](){return body.apply(this,arguments);}}[name];
  Object.defineProperty(value,"length",{value:length});
  Object.defineProperty(NamedNodeMap.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 }
 Object.defineProperty(NamedNodeMap.prototype,"length",{get:function(){return length(mapOwner(this));},enumerable:true,configurable:true});
 method("item",1,function(index){const state=mapOwner(this);if(arguments.length===0)throw new TypeError("item requires an index");return at(state,Number(index)>>>0);});
 method("getNamedItem",1,function(name){const state=mapOwner(this);if(arguments.length===0)throw new TypeError("getNamedItem requires a name");return byName(state,string(name));});
 method("getNamedItemNS",2,function(namespace,localName){const state=mapOwner(this);if(arguments.length<2)throw new TypeError("getNamedItemNS requires two arguments");return byNamespace(state,nullable(namespace),string(localName));});
 method("removeNamedItem",1,function(name){const state=mapOwner(this);if(arguments.length===0)throw new TypeError("removeNamedItem requires a name");return mutate(state,"removeNamed",{name:string(name)});});
 method("removeNamedItemNS",2,function(namespace,localName){const state=mapOwner(this);if(arguments.length<2)throw new TypeError("removeNamedItemNS requires two arguments");return mutate(state,"removeNamedNS",{namespace:nullable(namespace),name:string(localName)});});
 function setNode(attribute){const state=mapOwner(this);if(arguments.length===0)throw new TypeError("setNamedItem requires an Attr");return mutate(state,"setNode",{attribute:own(attribute)});}
 method("setNamedItem",1,setNode);method("setNamedItemNS",1,setNode);
 Object.defineProperty(NamedNodeMap.prototype,Symbol.iterator,{value:Array.prototype.values,writable:true,configurable:true});
 function isIndex(property){return typeof property==="string"&&/^(0|[1-9][0-9]*)$/.test(property)&&Number(property)<4294967295;}
 function named(state,target,property){
  if(typeof property!=="string"||isIndex(property)||Reflect.has(target,property))return null;
  return names(state).includes(property)?byName(state,property):null;
 }
 function map(state){
  const target=Object.create(NamedNodeMap.prototype);
  const proxy=new Proxy(target,{
   get(target,property,receiver){
    if(isIndex(property)){const attr=at(state,Number(property));if(attr)return attr;}
    else{const attr=named(state,target,property);if(attr)return attr;}
    return Reflect.get(target,property,receiver);
   },
   has(target,property){return isIndex(property)?Number(property)<length(state)||Reflect.has(target,property):!!named(state,target,property)||Reflect.has(target,property);},
   ownKeys(target){
    const result=[],count=length(state);for(let i=0;i<count;i++)result.push(String(i));
    for(const name of names(state))if(!isIndex(name)&&!Reflect.has(target,name))result.push(name);
    return result.concat(Reflect.ownKeys(target));
   },
   getOwnPropertyDescriptor(target,property){
    if(isIndex(property)){const attr=at(state,Number(property));if(attr)return{value:attr,writable:false,enumerable:true,configurable:true};}
    else{const attr=named(state,target,property);if(attr)return{value:attr,writable:false,enumerable:false,configurable:true};}
    return Reflect.getOwnPropertyDescriptor(target,property);
   },
   defineProperty(target,property,descriptor){if(isIndex(property)||named(state,target,property))return false;return Reflect.defineProperty(target,property,descriptor);},
   set(target,property,value,receiver){if(isIndex(property)&&Number(property)<length(state)||named(state,target,property))return false;return Reflect.set(target,property,value,receiver);},
   deleteProperty(target,property){if(isIndex(property))return !(Number(property)<length(state))&&Reflect.deleteProperty(target,property);if(named(state,target,property))return false;return Reflect.deleteProperty(target,property);},
   preventExtensions(){return false;}
  });
  mapStates.set(proxy,state);return proxy;
 }
 const attributes=Object.getOwnPropertyDescriptor({get attributes(){const state=native.state(this);let result=maps.get(state);if(!result){result=map(state);maps.set(state,result);}return result;}},"attributes").get;
 Object.defineProperty(Element.prototype,"attributes",{get:attributes,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"hasAttributes",{value:function hasAttributes(){return native.call(native.state(this),"hasAttributes");},writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"getAttributeNode",{value:function getAttributeNode(name){const state=native.state(this);if(arguments.length===0)throw new TypeError("getAttributeNode requires a name");return byName(state,string(name));},writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"getAttributeNodeNS",{value:function getAttributeNodeNS(namespace,localName){const state=native.state(this);if(arguments.length<2)throw new TypeError("getAttributeNodeNS requires two arguments");return byNamespace(state,nullable(namespace),string(localName));},writable:true,enumerable:true,configurable:true});
 for(const name of ["setAttributeNode","setAttributeNodeNS"])Object.defineProperty(Element.prototype,name,{value:{[name](attribute){const state=native.state(this);if(arguments.length===0)throw new TypeError(name+" requires an Attr");return mutate(state,"setNode",{attribute:own(attribute)});}}[name],writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"removeAttributeNode",{value:function removeAttributeNode(attribute){const state=native.state(this);if(arguments.length===0)throw new TypeError("removeAttributeNode requires an Attr");return mutate(state,"removeNode",{attribute:own(attribute)});},writable:true,enumerable:true,configurable:true});
 return {map};
})();
'
}
