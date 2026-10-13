// Generated indexed DataTransferItemList platform object and Window interfaces.
module browserjs

fn data_transfer_items_identity_factory() string {
	return r'(function(operate){
 "use strict";
 const create=Object.create,define=Object.defineProperty,P=Proxy,T=TypeError;
 const get=Reflect.get,set=Reflect.set,has=Reflect.has,getOwn=Reflect.getOwnPropertyDescriptor,defineOwn=Reflect.defineProperty,remove=Reflect.deleteProperty,ownKeys=Reflect.ownKeys;
 const itemPrototype=create(Object.prototype),listPrototype=create(Object.prototype);
 define(itemPrototype,Symbol.toStringTag,{value:"DataTransferItem",configurable:true});
 define(listPrototype,Symbol.toStringTag,{value:"DataTransferItemList",configurable:true});
 define(listPrototype,Symbol.iterator,{value:Array.prototype.values,writable:true,configurable:true});
 function wrapItem(){return create(itemPrototype)}
 function arrayIndex(key){return typeof key==="string"?operate("arrayIndex",key):undefined}
 function wrapList(){
  const target=create(listPrototype);let wrapper;
  function indexed(key){const index=arrayIndex(key);if(index===undefined)return undefined;const value=operate("indexed",wrapper,index);if(value===undefined)return undefined;return {value,writable:false,enumerable:true,configurable:true}}
  wrapper=new P(target,{
   getOwnPropertyDescriptor(target,key){return indexed(key)||getOwn(target,key)},
   get(target,key,receiver){const property=indexed(key);return property?property.value:get(target,key,receiver)},
   has(target,key){return indexed(key)!==undefined||has(target,key)},
   set(target,key,value,receiver){if(indexed(key)!==undefined)return false;return set(target,key,value,receiver)},
   defineProperty(target,key,property){if(arrayIndex(key)!==undefined)return false;return defineOwn(target,key,property)},
   deleteProperty(target,key){if(arrayIndex(key)!==undefined)return indexed(key)===undefined;return remove(target,key)},
   preventExtensions(){return false},
   ownKeys(target){const keys=[];function append(key){define(keys,keys.length,{value:key,writable:true,enumerable:true,configurable:true})}for(let index=0;index<4294967295;++index){if(operate("indexed",wrapper,index)===undefined)break;append(`${index}`)}const ordinary=ownKeys(target);for(let index=0;index<ordinary.length;++index){const key=ordinary[index];if(typeof key==="string")append(key)}for(let index=0;index<ordinary.length;++index){const key=ordinary[index];if(typeof key==="symbol")append(key)}return keys}
  });return wrapper;
 }
 function install(global,getKind,getType,getAsFile,getLength,remove,clear){
 const DataTransferItem=new P(function DataTransferItem(){throw new T("DataTransferItem constructor must be called with \u0027new\u0027")},{construct(){throw new T("DataTransferItem is not a constructor")}});
 const DataTransferItemList=new P(function DataTransferItemList(){throw new T("DataTransferItemList constructor must be called with \u0027new\u0027")},{construct(){throw new T("DataTransferItemList is not a constructor")}});
 const interfaces=[[DataTransferItem,itemPrototype,"DataTransferItem"],[DataTransferItemList,listPrototype,"DataTransferItemList"]];
 for(let index=0;index<interfaces.length;++index){const constructor=interfaces[index][0],prototype=interfaces[index][1],name=interfaces[index][2];
  define(constructor,"prototype",{value:prototype,writable:false});
  define(prototype,"constructor",{value:constructor,writable:true,configurable:true});
  define(global,name,{value:constructor,writable:true,configurable:true});
 }
 define(itemPrototype,"kind",{get:getKind,enumerable:true,configurable:true});
 define(itemPrototype,"type",{get:getType,enumerable:true,configurable:true});
 define(itemPrototype,"getAsFile",{value:getAsFile,writable:true,enumerable:true,configurable:true});
 define(listPrototype,"length",{get:getLength,enumerable:true,configurable:true});
 define(listPrototype,"remove",{value:remove,writable:true,enumerable:true,configurable:true});
 define(listPrototype,"clear",{value:clear,writable:true,enumerable:true,configurable:true});
 return {DataTransferItem,DataTransferItemList};
 }
 return {itemPrototype,listPrototype,wrapItem,wrapList,install};
})'
}
