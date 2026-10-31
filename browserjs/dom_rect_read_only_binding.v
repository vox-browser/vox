module browserjs

fn dom_rect_read_only_binding_factory() string {
	return r'(function(operate,global){
 "use strict";
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,T=global.TypeError;
 const object=v=>v!==null&&(typeof v==="object"||typeof v==="function");
 const prototype={};
 const number=v=>operate("number",null,v);
 const DOMRectReadOnly=new Proxy(function DOMRectReadOnly(){throw new T("DOMRectReadOnly requires new")},{construct(target,args,newTarget){
  const values=[];for(let i=0;i<4;i++)values.push(args[i]===undefined?0:number(args[i]));
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:prototype);
  operate("construct",receiver,...values);return receiver;
 }});
 define(DOMRectReadOnly,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:DOMRectReadOnly,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"DOMRectReadOnly",configurable:true});
 const methods={toJSON(){
  operate("brand",this);const result={};for(const name of ["x","y","width","height","top","right","bottom","left"])result[name]=operate(name,this);return result;
 }};
 define(prototype,"toJSON",{value:methods.toJSON,writable:true,enumerable:true,configurable:true});
 for(const name of ["x","y","width","height","top","right","bottom","left"]){
  const get=descriptor({get [name](){return operate(name,this)}},name).get;
  define(prototype,name,{get,enumerable:true,configurable:true});
 }
 const statics={fromRect(other={}){
  if(other!=null&&!object(other))throw new T("DOMRectInit must be a dictionary");
  other=other==null?{}:other;const values={};
  for(const name of ["height","width","x","y"]){const value=other[name];values[name]=value===undefined?0:number(value)}
  const receiver=create(prototype);operate("construct",receiver,values.x,values.y,values.width,values.height);return receiver;
 }};
 define(DOMRectReadOnly,"fromRect",{value:statics.fromRect,writable:true,enumerable:true,configurable:true});
 define(global,"DOMRectReadOnly",{value:DOMRectReadOnly,writable:true,configurable:true});
 const mutablePrototype=create(prototype);
 const DOMRect=new Proxy(function DOMRect(){throw new T("DOMRect requires new")},{construct(target,args,newTarget){
  const values=[];for(let i=0;i<4;i++)values.push(args[i]===undefined?0:number(args[i]));
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:mutablePrototype);
  operate("constructMutable",receiver,...values);return receiver;
 }});
 Object.setPrototypeOf(DOMRect,DOMRectReadOnly);
 define(DOMRect,"prototype",{value:mutablePrototype,writable:false});
 define(mutablePrototype,"constructor",{value:DOMRect,writable:true,configurable:true});
 define(mutablePrototype,Symbol.toStringTag,{value:"DOMRect",configurable:true});
 for(const name of ["x","y","width","height"]){
  const get=descriptor(prototype,name).get;
  const set=descriptor({set [name](value){operate("set:"+name,this,value)}},name).set;
  define(mutablePrototype,name,{get,set,enumerable:true,configurable:true});
 }
 const mutableStatics={fromRect(other={}){
  if(other!=null&&!object(other))throw new T("DOMRectInit must be a dictionary");
  other=other==null?{}:other;const values={};
  for(const name of ["height","width","x","y"]){const value=other[name];values[name]=value===undefined?0:number(value)}
  const receiver=create(mutablePrototype);operate("constructMutable",receiver,values.x,values.y,values.width,values.height);return receiver;
 }};
 define(DOMRect,"fromRect",{value:mutableStatics.fromRect,writable:true,enumerable:true,configurable:true});
 define(global,"DOMRect",{value:DOMRect,writable:true,configurable:true});
 return function make(){return create(prototype)};
})'
}
