module browserjs

// CSSOM View's replaceable Window.screen and the source Screen interfaces.
fn window_screen_binding_factory() string {
	return r'(function(operate,global,secure){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,TypeError=global.TypeError,Promise=global.Promise;
 function Screen(){throw new TypeError("Illegal constructor")}
 function ScreenOrientation(){throw new TypeError("Illegal constructor")}
 Object.setPrototypeOf(ScreenOrientation,EventTarget);
 Object.setPrototypeOf(ScreenOrientation.prototype,EventTarget.prototype);
 const screen=Object.create(Screen.prototype),orientation=Object.create(ScreenOrientation.prototype);
 function check(value,expected){if(value!==expected)throw new TypeError("Illegal Screen receiver")}
 function getter(prototype,name,object,read){const get=descriptor({get [name](){check(this,object);return read()}},name).get;define(prototype,name,{get,enumerable:true,configurable:true})}
 for(const name of ["availWidth","availHeight","width","height","colorDepth","pixelDepth"])
  getter(Screen.prototype,name,screen,()=>operate(name));
 getter(Screen.prototype,"orientation",screen,()=>orientation);
 if(secure)getter(Screen.prototype,"isExtended",screen,()=>operate("isExtended"));
 for(const name of ["type","angle"])getter(ScreenOrientation.prototype,name,orientation,()=>operate(name));
 for(const object of secure?[screen,orientation]:[orientation]){
  const prototype=Object.getPrototypeOf(object);
  const attribute=descriptor({get onchange(){check(this,object);return operate("getHandler",this)},set onchange(value){check(this,object);operate("setHandler",this,value)}},"onchange");
  define(prototype,"onchange",{...attribute,enumerable:true,configurable:true});
 }
 const methods={lock(orientationType){try{check(this,orientation);if(arguments.length===0)throw new TypeError("lock requires an orientation");if(typeof orientationType==="symbol")throw new TypeError("Invalid orientation");const value=String(orientationType);if(!["any","natural","landscape","portrait","portrait-primary","portrait-secondary","landscape-primary","landscape-secondary"].includes(value))throw new TypeError("Invalid orientation");operate("lock",value);return Promise.resolve()}catch(error){return Promise.reject(error)}},unlock(){check(this,orientation);operate("unlock")}};
 for(const name of ["lock","unlock"])define(ScreenOrientation.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 for(const [constructor,name] of [[Screen,"Screen"],[ScreenOrientation,"ScreenOrientation"]]){
  define(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});define(constructor,"prototype",{writable:false});define(global,name,{value:constructor,writable:true,configurable:true});
 }
 function checkWindow(value){if(value!==global&&value!==undefined&&value!==null)throw new TypeError("Not an object of type Window")}
 const attribute=descriptor({get screen(){checkWindow(this);return screen},set screen(value){checkWindow(this);define(global,"screen",{value,writable:true,enumerable:true,configurable:true})}},"screen");
 define(global,"screen",{...attribute,enumerable:true,configurable:true});
 return [screen,orientation];
})'
}
