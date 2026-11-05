// CacheStorage and Cache (Service Workers, "Cache Objects") for window
// realms. Upstream LibWeb has no Cache API; this realm-local implementation
// keeps request/response pairs in memory for the lifetime of the document.
// Pages such as Discord read their configuration through caches.open() and
// stall without it; nothing here persists across navigations.
module browserjs

pub fn (runtime &Runtime) install_cache_storage_binding(secure_context bool) ! {
	if !secure_context { return }
	runtime.evaluate_host(cache_storage_bootstrap)!
}

const cache_storage_bootstrap = r'(function(){
 "use strict";
 const global=globalThis,define=Object.defineProperty,TypeError=global.TypeError;
 if(typeof global.caches!=="undefined"||typeof global.Request!=="function"||typeof global.Response!=="function")return;
 const RequestType=global.Request,ResponseType=global.Response,fetchFunction=global.fetch;
 const entries=new WeakMap,storages=new WeakMap;
 function illegal(){throw new TypeError("Illegal constructor")}
 function brand(map,value,name){const state=map.get(value);if(!state)throw new TypeError("Illegal invocation: not a "+name);return state}
 function method(prototype,name,implementation){define(prototype,name,{value:{[name](...args){return implementation.apply(this,args)}}[name],writable:true,enumerable:true,configurable:true})}
 function promise(action){try{return Promise.resolve(action())}catch(error){return Promise.reject(error)}}
 function toRequest(value){return value instanceof RequestType?value:new RequestType(value)}
 function withoutFragment(url){const index=url.indexOf("#");return index<0?url:url.slice(0,index)}
 function withoutSearch(url){const plain=withoutFragment(url),index=plain.indexOf("?");return index<0?plain:plain.slice(0,index)}
 function scheme(url){return url.slice(0,url.indexOf(":")+1).toLowerCase()}
 // https://w3c.github.io/ServiceWorker/#request-matches-cached-item-algorithm
 function matches(request,stored,options){
  const ignoreSearch=!!(options&&options.ignoreSearch),ignoreMethod=!!(options&&options.ignoreMethod);
  if(!ignoreMethod&&request.method!=="GET")return false;
  const left=ignoreSearch?withoutSearch(request.url):withoutFragment(request.url);
  const right=ignoreSearch?withoutSearch(stored.request.url):withoutFragment(stored.request.url);
  return left===right;
 }
 function query(state,request,options){
  if(request===undefined)return state.items.slice();
  const actual=toRequest(request);
  if(actual.method!=="GET"&&!(options&&options.ignoreMethod))return [];
  return state.items.filter(item=>matches(actual,item,options));
 }
 function Cache(){illegal()}
 function CacheStorage(){illegal()}
 method(Cache.prototype,"match",function(request,options){const state=brand(entries,this,"Cache");return promise(()=>{const found=query(state,request,options)[0];return found?found.response.clone():undefined})});
 method(Cache.prototype,"matchAll",function(request,options){const state=brand(entries,this,"Cache");return promise(()=>query(state,request,options).map(item=>item.response.clone()))});
 method(Cache.prototype,"keys",function(request,options){const state=brand(entries,this,"Cache");return promise(()=>query(state,request,options).map(item=>item.request.clone()))});
 method(Cache.prototype,"delete",function(request,options){const state=brand(entries,this,"Cache");return promise(()=>{const remove=new Set(query(state,request,options));if(remove.size===0)return false;state.items=state.items.filter(item=>!remove.has(item));return true})});
 function store(state,request,response){
  const actual=toRequest(request);
  const protocol=scheme(actual.url);
  if(protocol!=="http:"&&protocol!=="https:")throw new TypeError("Cache.put() requires an http(s) request");
  if(actual.method!=="GET")throw new TypeError("Cache.put() requires a GET request");
  if(!(response instanceof ResponseType))throw new TypeError("Cache.put() requires a Response");
  if(response.status===206)throw new TypeError("Cache.put() cannot store a partial response");
  const vary=response.headers.get("Vary");
  if(vary&&vary.split(",").some(value=>value.trim()==="*"))throw new TypeError("Cache.put() cannot store Vary: *");
  if(response.bodyUsed)throw new TypeError("Cache.put() requires an unused response body");
  const item={request:actual.clone(),response:response.clone()};
  state.items=state.items.filter(existing=>!matches(actual,existing,undefined));
  state.items.push(item);
 }
 method(Cache.prototype,"put",function(request,response){const state=brand(entries,this,"Cache");return promise(()=>{store(state,request,response)})});
 method(Cache.prototype,"addAll",function(requests){const state=brand(entries,this,"Cache");return promise(()=>{
  const list=Array.from(requests,toRequest);
  for(const request of list){const protocol=scheme(request.url);if((protocol!=="http:"&&protocol!=="https:")||request.method!=="GET")throw new TypeError("Cache.addAll() requires http(s) GET requests")}
  return Promise.all(list.map(request=>fetchFunction(request))).then(responses=>{for(const response of responses)if(!response.ok)throw new TypeError("Cache.addAll() received a failed response");list.forEach((request,index)=>store(state,request,responses[index]))});
 })});
 method(Cache.prototype,"add",function(request){brand(entries,this,"Cache");return this.addAll([request])});
 define(Cache.prototype,Symbol.toStringTag,{value:"Cache",configurable:true});
 function storage(value){return brand(storages,value,"CacheStorage")}
 method(CacheStorage.prototype,"open",function(name){const named=storage(this);return promise(()=>{const key=String(name);let cache=named.get(key);if(!cache){cache=Object.create(Cache.prototype);entries.set(cache,{items:[]});named.set(key,cache)}return cache})});
 method(CacheStorage.prototype,"has",function(name){const named=storage(this);return promise(()=>named.has(String(name)))});
 method(CacheStorage.prototype,"delete",function(name){const named=storage(this);return promise(()=>named.delete(String(name)))});
 method(CacheStorage.prototype,"keys",function(){const named=storage(this);return promise(()=>Array.from(named.keys()))});
 method(CacheStorage.prototype,"match",function(request,options){const named=storage(this);return promise(()=>{
  const names=options&&options.cacheName!==undefined?[String(options.cacheName)]:Array.from(named.keys());
  for(const name of names){const cache=named.get(name);if(!cache)continue;const found=query(entries.get(cache),request,options)[0];if(found)return found.response.clone()}
  return undefined;
 })});
 define(CacheStorage.prototype,Symbol.toStringTag,{value:"CacheStorage",configurable:true});
 const instance=Object.create(CacheStorage.prototype);storages.set(instance,new Map);
 define(global,"Cache",{value:Cache,writable:true,configurable:true});
 define(global,"CacheStorage",{value:CacheStorage,writable:true,configurable:true});
 define(global,"caches",{get:function caches(){return instance},enumerable:true,configurable:true});
})()'
