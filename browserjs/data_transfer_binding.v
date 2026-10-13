// HTML/DataTransfer.idl: constructor, effects, string store and frozen types.
module browserjs

fn data_transfer_bootstrap() string {
	return r'(function(prototype,global,construct,getDrop,setDrop,getEffect,setEffect,getTypes,getData,setData,clearData){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError;
 const DataTransfer=new Proxy(function DataTransfer(){throw new T("DataTransfer constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  apply(construct,receiver,[]);return receiver;
 }});
 define(DataTransfer,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:DataTransfer,writable:true,configurable:true});
 define(prototype,"dropEffect",{get:getDrop,set:setDrop,enumerable:true,configurable:true});
 define(prototype,"effectAllowed",{get:getEffect,set:setEffect,enumerable:true,configurable:true});
 define(prototype,"types",{get:getTypes,enumerable:true,configurable:true});
 for(const [name,value] of [["getData",getData],["setData",setData],["clearData",clearData]])define(prototype,name,{value,writable:true,enumerable:true,configurable:true});
 define(global,"DataTransfer",{value:DataTransfer,writable:true,configurable:true});return DataTransfer;
})'
}
