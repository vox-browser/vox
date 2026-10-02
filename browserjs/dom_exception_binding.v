// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// DOMException.{h,cpp,idl} and generated constructor/prototype binding.
// The translated WebIDL record owns the exception fields and legacy code.
module browserjs

import webidl
import x.json2

pub fn (mut runtime Runtime) install_dom_exception_binding() ! {
	runtime.define_host_function('__ladybirdDOMException', fn (input string) !string {
		request := canvas_host_object(json2.decode[json2.Any](input)!)!
		exception := webidl.DOMException.construct(canvas_host_string(request['message'] or {
			json2.Any('')
		}), canvas_host_string(request['name'] or { json2.Any('Error') }))
		return json2.encode({
			'name':    json2.Any(exception.name())
			'message': json2.Any(exception.message())
			'code':    json2.Any(int(exception.code()))
		})
	})!
}

pub fn dom_exception_bootstrap() string {
	return r'
if(typeof globalThis.DOMException!=="function"){
 const __domExceptions=new WeakMap();
 const DOMException=function DOMException(message="",name="Error"){
  if(!new.target)throw new TypeError("DOMException constructor requires new");
  // WebIDL DOMString conversion rejects Symbol instead of using the String
  // special Symbol formatting behavior.
  if(typeof message==="symbol"||typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
  __domExceptions.set(this,JSON.parse(__ladybirdDOMException(JSON.stringify({message:String(message),name:String(name)}))));
 };
 Object.setPrototypeOf(DOMException.prototype,Error.prototype);
 Object.defineProperty(DOMException,"prototype",{writable:false});
 for(const property of ["name","message","code"])Object.defineProperty(DOMException.prototype,property,{get:function(){
  const exception=__domExceptions.get(this);if(!exception)throw new TypeError("Illegal invocation");return exception[property];
 },enumerable:true,configurable:true});
 Object.defineProperty(DOMException.prototype,Symbol.toStringTag,{value:"DOMException",configurable:true});
 const names=["INDEX_SIZE_ERR","DOMSTRING_SIZE_ERR","HIERARCHY_REQUEST_ERR","WRONG_DOCUMENT_ERR","INVALID_CHARACTER_ERR","NO_DATA_ALLOWED_ERR","NO_MODIFICATION_ALLOWED_ERR","NOT_FOUND_ERR","NOT_SUPPORTED_ERR","INUSE_ATTRIBUTE_ERR","INVALID_STATE_ERR","SYNTAX_ERR","INVALID_MODIFICATION_ERR","NAMESPACE_ERR","INVALID_ACCESS_ERR","VALIDATION_ERR","TYPE_MISMATCH_ERR","SECURITY_ERR","NETWORK_ERR","ABORT_ERR","URL_MISMATCH_ERR","QUOTA_EXCEEDED_ERR","TIMEOUT_ERR","INVALID_NODE_TYPE_ERR","DATA_CLONE_ERR"];
 names.forEach(function(name,index){for(const target of [DOMException,DOMException.prototype])Object.defineProperty(target,name,{value:index+1,enumerable:true});});
 Object.defineProperty(globalThis,"DOMException",{value:DOMException,writable:true,configurable:true});
}
'
}
