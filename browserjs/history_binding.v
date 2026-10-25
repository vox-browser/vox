module browserjs

// The synchronous state/URL portion of History.idl. Traversal remains a
// separate browser scheduling boundary.
fn history_binding_factory() string {
	return r'(function(operate,global){
 const define=Object.defineProperty,getOwn=Object.getOwnPropertyDescriptor,brand=new WeakSet(),S=String,wellFormed=String.prototype.toWellFormed,apply=Reflect.apply;
 let observer=null;
 function check(value){if(!brand.has(value))throw new TypeError("Illegal History receiver");}
 function text(value){if(typeof value==="symbol")throw new TypeError("Cannot convert Symbol to string");return S(value);}
 function write(receiver,method,args){
  check(receiver);if(args.length<2)throw new TypeError(method+" requires two arguments");
  const unused=text(args[1]),url=args[2]==null?null:apply(wellFormed,text(args[2]),[]);
  const result=operate(method,args[0],unused,url);
  if(observer)observer(operate("url"));return result;
 }
 function History(){throw new TypeError("Illegal History constructor");}
 define(History,"prototype",{writable:false});
 define(History.prototype,Symbol.toStringTag,{value:"History",configurable:true});
 const methods={pushState(data,unused){return write(this,"pushState",arguments);},replaceState(data,unused){return write(this,"replaceState",arguments);}};
 for(const name of ["pushState","replaceState"])define(History.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 for(const name of ["length","state","scrollRestoration"]){
  const accessors={get [name](){check(this);return operate(name);},set [name](value){check(this);const mode=text(value);if(mode!=="auto"&&mode!=="manual")throw new TypeError("Invalid ScrollRestoration");operate("setScrollRestoration",mode);}};
  const attribute=getOwn(accessors,name);if(name!=="scrollRestoration")delete attribute.set;
  define(History.prototype,name,attribute);
 }
 const history=Object.create(History.prototype);brand.add(history);
 const attribute={get history(){operate("windowBrand",this);return history;}};
 define(global,"history",getOwn(attribute,"history"));
 define(global,"History",{value:History,writable:true,configurable:true});
 define(global,"__ladybirdObserveHistoryURL",{value:function(callback){observer=callback;},configurable:true});
})'
}
