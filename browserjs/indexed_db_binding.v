module browserjs

fn indexed_db_binding_factory() string {
	return r'(function(operate,global){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,T=global.TypeError;
 const constructors={},names=["IDBFactory","IDBRequest","IDBOpenDBRequest","IDBDatabase","IDBTransaction","IDBObjectStore","IDBIndex","IDBCursor"];
 for(const name of names){
  const constructor={[name]:function(){throw new T("Illegal constructor")}}[name];
  const parent=name==="IDBOpenDBRequest"?constructors.IDBRequest:["IDBRequest","IDBDatabase","IDBTransaction"].includes(name)?global.EventTarget:null;
  if(parent){Object.setPrototypeOf(constructor,parent);Object.setPrototypeOf(constructor.prototype,parent.prototype)}
  define(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});define(constructor,"prototype",{writable:false});
  define(global,name,{value:constructor,writable:true,configurable:true});constructors[name]=constructor;
 }
 function method(type,name,length){
  const value=({[name](...args){operate("brand",this,type);if(args.length<length)throw new T(name+" requires "+length+" argument(s)");return operate(name,this,...args)}})[name];
  define(value,"length",{value:length,configurable:true});define(constructors[type].prototype,name,{value,writable:true,enumerable:true,configurable:true});
 }
 function getter(type,name){const get=descriptor({get [name](){operate("brand",this,type);return operate(name,this)}},name).get;define(constructors[type].prototype,name,{get,enumerable:true,configurable:true})}
 for(const [type,properties] of [["IDBRequest",["result","error","source","transaction","readyState"]],["IDBDatabase",["name","version","objectStoreNames"]],["IDBTransaction",["db","mode","durability","error","objectStoreNames"]],["IDBObjectStore",["name","keyPath","autoIncrement","indexNames","transaction"]],["IDBIndex",["name","objectStore","keyPath","multiEntry","unique"]]])for(const name of properties)getter(type,name);
 const indexName=descriptor(constructors.IDBIndex.prototype,"name");
 define(constructors.IDBIndex.prototype,"name",{...indexName,set(value){operate("brand",this,"IDBIndex");operate("setName",this,value)}});
 for(const [type,methods] of [["IDBFactory",[["open",1],["deleteDatabase",1],["cmp",2]]],["IDBDatabase",[["createObjectStore",1],["deleteObjectStore",1],["transaction",1],["close",0]]],["IDBTransaction",[["objectStore",1],["abort",0],["commit",0]]],["IDBObjectStore",[["get",1],["put",1],["add",1],["createIndex",2]]]])for(const [name,length] of methods)method(type,name,length);
 // Promise-returning WebIDL operations reject receiver errors. Capture the
 // intrinsic constructor before author code can replace the global property.
 const Promise=global.Promise;
 const databases=({databases(){return new Promise((resolve,reject)=>{try{operate("brand",this,"IDBFactory");resolve(operate("databases",this))}catch(error){reject(error)}})}}).databases;
 define(constructors.IDBFactory.prototype,"databases",{value:databases,writable:true,enumerable:true,configurable:true});
 for(const [type,events] of [["IDBRequest",["success","error"]],["IDBOpenDBRequest",["blocked","upgradeneeded"]],["IDBDatabase",["abort","error","close","versionchange"]],["IDBTransaction",["abort","error","complete"]]])for(const event of events){
  const name="on"+event;
  const handler=descriptor({get [name](){operate("brand",this,type);return operate("getHandler",this,event)},set [name](value){operate("brand",this,type);operate("setHandler",this,event,value)}},name);
  define(constructors[type].prototype,name,{...handler,enumerable:true,configurable:true});
 }
 const Parent=global.Event,versionPrototype=create(Parent.prototype);
 const IDBVersionChangeEvent=new Proxy(function IDBVersionChangeEvent(type){throw new T("IDBVersionChangeEvent requires new")},{construct(target,args,newTarget){
  if(args.length<1)throw new T("IDBVersionChangeEvent requires one argument");
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:versionPrototype);
  operate("constructVersionEvent",receiver,args[0],args[1]);return receiver;
 }});
 Object.setPrototypeOf(IDBVersionChangeEvent,Parent);define(IDBVersionChangeEvent,"prototype",{value:versionPrototype,writable:false});
 define(versionPrototype,"constructor",{value:IDBVersionChangeEvent,writable:true,configurable:true});
 define(versionPrototype,Symbol.toStringTag,{value:"IDBVersionChangeEvent",configurable:true});
 for(const name of ["oldVersion","newVersion"]){const get=descriptor({get [name](){return operate(name,this)}},name).get;define(versionPrototype,name,{get,enumerable:true,configurable:true})}
 define(global,"IDBVersionChangeEvent",{value:IDBVersionChangeEvent,writable:true,configurable:true});
 // DOMStringList reads its owning native list on every access, including
 // previously obtained lists after createObjectStore/deleteObjectStore.
 const lists=new WeakMap(),listOwners=new WeakMap();
 function DOMStringList(){throw new T("Illegal constructor")}
 define(DOMStringList.prototype,Symbol.toStringTag,{value:"DOMStringList",configurable:true});
 function listInfo(receiver){const info=listOwners.get(receiver);if(!info)throw new T("Illegal DOMStringList receiver");return info}
 const listMethods={item(index){const [owner,kind]=listInfo(this);if(arguments.length<1)throw new T("item requires one argument");return operate("listItem",owner,kind,index>>>0)},contains(value){const [owner,kind]=listInfo(this);if(arguments.length<1)throw new T("contains requires one argument");return operate("listContains",owner,kind,value)}};
 for(const name of ["item","contains"])define(DOMStringList.prototype,name,{value:listMethods[name],writable:true,enumerable:true,configurable:true});
 define(DOMStringList.prototype,"length",{get(){const [owner,kind]=listInfo(this);return operate("listLength",owner,kind)},enumerable:true,configurable:true});
 define(DOMStringList.prototype,Symbol.iterator,{value:function*(){listInfo(this);for(let i=0;i<this.length;i++)yield this.item(i)},writable:true,configurable:true});
 define(DOMStringList,"prototype",{writable:false});define(global,"DOMStringList",{value:DOMStringList,writable:true,configurable:true});
 function makeList(owner,kind){
  let cache=lists.get(owner);if(!cache)lists.set(owner,cache=new Map());if(cache.has(kind))return cache.get(kind);
  const target=create(DOMStringList.prototype),isIndex=key=>typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key)&&Number(key)<4294967295;
  const proxy=new Proxy(target,{
   get(target,key,receiver){if(isIndex(key)){const result=operate("listItem",owner,kind,Number(key));return result===null?void 0:result}return Reflect.get(target,key,receiver)},
   has(target,key){return isIndex(key)&&Number(key)<operate("listLength",owner,kind)||Reflect.has(target,key)},
   ownKeys(target){return Array.from({length:operate("listLength",owner,kind)},(_,i)=>String(i)).concat(Reflect.ownKeys(target))},
   getOwnPropertyDescriptor(target,key){if(isIndex(key)&&Number(key)<operate("listLength",owner,kind))return {value:operate("listItem",owner,kind,Number(key)),writable:false,enumerable:true,configurable:true};return Reflect.getOwnPropertyDescriptor(target,key)},
   set(target,key,value,receiver){return isIndex(key)?false:Reflect.set(target,key,value,receiver)},
   defineProperty(target,key,value){return isIndex(key)?false:Reflect.defineProperty(target,key,value)},
   deleteProperty(target,key){return isIndex(key)&&Number(key)<operate("listLength",owner,kind)?false:Reflect.deleteProperty(target,key)}
  });
  listOwners.set(proxy,[owner,kind]);cache.set(kind,proxy);return proxy;
 }
 let factory;define(global,"indexedDB",{get(){operate("globalBrand",this);if(!factory)factory=operate("factory",this);return factory},enumerable:true,configurable:true});
 // Convert the key-path union in one pass: read @@iterator once, convert each
 // member before advancing, and let for-of close the iterator on failure.
 const string=global.String,iterator=global.Symbol.iterator,apply=global.Reflect.apply;
 function domString(value){if(typeof value==="symbol")throw new T("Cannot convert a Symbol to DOMString");return string(value)}
 function keyPath(value){
  if(value!==null&&(typeof value==="object"||typeof value==="function")){
   const method=value[iterator];
   if(method!==null&&method!==void 0){
    if(typeof method!=="function")throw new T("Expected a callable iterator");
    const input={[iterator](){return apply(method,value,[])}},result=[];
    for(const item of input)define(result,result.length,{value:domString(item),writable:true,enumerable:true,configurable:true});
    return result;
   }
  }
  return domString(value);
 }
 return [...names.map(name=>constructors[name].prototype),versionPrototype,makeList,value=>{if(value===null||(typeof value!=="object"&&typeof value!=="function")||typeof value[Symbol.iterator]!=="function")throw new T("Expected a sequence");return Array.from(value)},keyPath];
})'
}
