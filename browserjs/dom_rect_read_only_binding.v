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
 return function make(){return create(prototype)};
})'
}
