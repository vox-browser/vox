// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// DOMException.{h,cpp,idl} and generated constructor/prototype binding.
// The translated WebIDL record owns the exception fields and legacy code.
module browserjs

pub fn dom_exception_bootstrap() string {
	return r'
if(typeof globalThis.DOMException!=="function"){
 const __domExceptionApply=Reflect.apply;
 const DOMException=function DOMException(message="",name="Error"){
  if(!new.target)throw new TypeError("DOMException constructor requires new");
  __domExceptionApply(__ladybirdDOMExceptionConstruct,this,[message,name]);
 };
 Object.setPrototypeOf(DOMException.prototype,Error.prototype);
 Object.defineProperty(DOMException,"prototype",{writable:false});
 for(const property of ["name","message","code"])Object.defineProperty(DOMException.prototype,property,{get:function(){
  return __domExceptionApply(__ladybirdDOMExceptionGet,this,[property]);
 },enumerable:true,configurable:true});
 Object.defineProperty(DOMException.prototype,Symbol.toStringTag,{value:"DOMException",configurable:true});
 const names=["INDEX_SIZE_ERR","DOMSTRING_SIZE_ERR","HIERARCHY_REQUEST_ERR","WRONG_DOCUMENT_ERR","INVALID_CHARACTER_ERR","NO_DATA_ALLOWED_ERR","NO_MODIFICATION_ALLOWED_ERR","NOT_FOUND_ERR","NOT_SUPPORTED_ERR","INUSE_ATTRIBUTE_ERR","INVALID_STATE_ERR","SYNTAX_ERR","INVALID_MODIFICATION_ERR","NAMESPACE_ERR","INVALID_ACCESS_ERR","VALIDATION_ERR","TYPE_MISMATCH_ERR","SECURITY_ERR","NETWORK_ERR","ABORT_ERR","URL_MISMATCH_ERR","QUOTA_EXCEEDED_ERR","TIMEOUT_ERR","INVALID_NODE_TYPE_ERR","DATA_CLONE_ERR"];
 names.forEach(function(name,index){for(const target of [DOMException,DOMException.prototype])Object.defineProperty(target,name,{value:index+1,enumerable:true});});
 Object.defineProperty(globalThis,"DOMException",{value:DOMException,writable:true,configurable:true});
}
'
}
