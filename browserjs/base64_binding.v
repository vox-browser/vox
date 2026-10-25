module browserjs

fn base64_binding_factory() string {
	return r'(function(operate,global){
 const define=Object.defineProperty,TypeError=global.TypeError;
 function invoke(name,receiver,data){if(receiver!==global&&receiver!==undefined&&receiver!==null)throw new TypeError("Illegal invocation");return operate(name,data)}
 const methods={
  atob(data){if(arguments.length===0)throw new TypeError("atob requires an argument");return invoke("atob",this,data)},
  btoa(data){if(arguments.length===0)throw new TypeError("btoa requires an argument");return invoke("btoa",this,data)}
 };
 for(const name of ["atob","btoa"])define(global,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
})'
}
