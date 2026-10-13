// EntriesAPI/FileSystemEntry.idl and generated platform-object metadata.
module browserjs

fn file_system_entry_identity_factory() string {
	return r'(function(makeError){
 "use strict";
 const create=Object.create,define=Object.defineProperty,P=Proxy;
 const prototype=create(Object.prototype);
 define(prototype,Symbol.toStringTag,{value:"FileSystemEntry",configurable:true});
 function wrap(){return create(prototype)}
 function install(global,isFile,isDirectory,name){
  const FileSystemEntry=new P(function FileSystemEntry(){throw makeError("TypeError","FileSystemEntry constructor must be called with \u0027new\u0027")},{construct(){throw makeError("TypeError","FileSystemEntry is not a constructor")}});
  define(FileSystemEntry,"prototype",{value:prototype,writable:false});
  define(prototype,"constructor",{value:FileSystemEntry,writable:true,configurable:true});
  define(global,"FileSystemEntry",{value:FileSystemEntry,writable:true,configurable:true});
  define(prototype,"isFile",{get:isFile,enumerable:true,configurable:true});
  define(prototype,"isDirectory",{get:isDirectory,enumerable:true,configurable:true});
  define(prototype,"name",{get:name,enumerable:true,configurable:true});
  return FileSystemEntry;
 }
 return {prototype,wrap,install};
})'
}
