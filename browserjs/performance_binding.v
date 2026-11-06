module browserjs

// HighResolutionTime/Performance.idl: the native clock and timeline queries.
fn performance_binding_factory() string {
	return r'(function(operate,global,makeTimeline){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,T=global.TypeError;
 function Performance(){throw new T("Illegal constructor")}
 Object.setPrototypeOf(Performance,global.EventTarget);
 const prototype=Object.create(global.EventTarget.prototype);
 define(Performance,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:Performance,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"Performance",configurable:true});
 const methods={now(){return operate("now",this)},toJSON(){return {timeOrigin:operate("timeOrigin",this)}},
  mark:makeTimeline(5),
  measure:makeTimeline(7),
  getEntries(){return operate("getEntries",this)},
  getEntriesByType(type){operate("brand",this);if(arguments.length===0)throw new T("getEntriesByType requires a type");return operate("getEntriesByType",this,operate("string",this,type))},
  getEntriesByName(name,type){operate("brand",this);if(arguments.length===0)throw new T("getEntriesByName requires a name");return operate("getEntriesByName",this,operate("string",this,name),type===undefined?undefined:operate("string",this,type))},
  clearMarks(name){operate("brand",this);return operate("clearMarks",this,name===undefined?undefined:operate("string",this,name))},
  clearMeasures(name){operate("brand",this);return operate("clearMeasures",this,name===undefined?undefined:operate("string",this,name))},
  clearResourceTimings(){return operate("clearResourceTimings",this)},
  setResourceTimingBufferSize(size){operate("brand",this);if(arguments.length===0)throw new T("setResourceTimingBufferSize requires a size");return operate("setResourceTimingBufferSize",this,size)}
 };
 for(const name of Object.keys(methods))define(prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 define(prototype,"timeOrigin",{get:descriptor({get timeOrigin(){return operate("timeOrigin",this)}},"timeOrigin").get,enumerable:true,configurable:true});
 define(prototype,"onresourcetimingbufferfull",{get:descriptor({get onresourcetimingbufferfull(){return operate("getHandler",this)}},"onresourcetimingbufferfull").get,set:descriptor({set onresourcetimingbufferfull(value){operate("setHandler",this,value)}},"onresourcetimingbufferfull").set,enumerable:true,configurable:true});
 const performance=Object.create(prototype);
 define(global,"Performance",{value:Performance,writable:true,configurable:true});
 define(global,"performance",{get(){return performance},set(value){define(this,"performance",{value,writable:true,enumerable:true,configurable:true})},enumerable:true,configurable:true});
 return performance;
})'
}
