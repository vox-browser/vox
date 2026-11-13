module browserjs

// PerformanceObserver is backed by the owning global's native timeline.
fn performance_observer_binding_factory() string {
	return r'(function(operate,global){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,T=global.TypeError;
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 const types=Object.freeze(operate("supported",null));
 const prototypes=[{}, {}, {}];
 function PerformanceObserverEntryList(){throw new T("Illegal constructor")}
 function PerformanceEntry(){throw new T("Illegal constructor")}
 const markPrototype=Object.create(prototypes[2]),measurePrototype=Object.create(prototypes[2]);
 prototypes[4]=markPrototype;prototypes[6]=measurePrototype;
 function markArguments(name,options){
  name=operate("string",null,name);
  if(options!=null&&!object(options))throw new T("markOptions must be a dictionary");
  options=options==null?{}:options;
  const detail=options.detail,rawStart=options.startTime;
  const start=rawStart===undefined?undefined:operate("markDouble",null,rawStart);
  return [name,start,detail];
 }
 const PerformanceMark=new Proxy(function PerformanceMark(markName){throw new T("PerformanceMark constructor requires new")},{construct(target,args,newTarget){
  if(args.length===0)throw new T("PerformanceMark requires a name");
  const values=markArguments(args[0],args[1]),requested=newTarget.prototype;
  const receiver=create(object(requested)?requested:markPrototype);
  return operate("constructMark",receiver,...values);
 }});
 Object.setPrototypeOf(PerformanceMark,PerformanceEntry);
 const markMethod={mark(name,options=undefined){
  operate("performanceMarkBrand",this);if(arguments.length===0)throw new T("mark requires a name");
  return operate("mark",this,...markArguments(name,options));
 }}.mark;
 function PerformanceMeasure(){throw new T("Illegal constructor")}
 Object.setPrototypeOf(PerformanceMeasure,PerformanceEntry);
 function VisibilityStateEntry(){throw new T("Illegal constructor")}
 Object.setPrototypeOf(VisibilityStateEntry,PerformanceEntry);
 prototypes[8]=Object.create(prototypes[2]);
 // (DOMString or DOMHighResTimeStamp): Numbers convert as finite doubles.
 function measureTime(value){return value===undefined?undefined:typeof value==="number"?operate("markDouble",null,value):operate("string",null,value)}
 const measureMethod={measure(measureName,startOrMeasureOptions={},endMark=undefined){
  operate("performanceMarkBrand",this);if(arguments.length===0)throw new T("measure requires a name");
  measureName=operate("string",null,measureName);
  let startName,options=false,detail,duration,end,start;
  if(startOrMeasureOptions==null||object(startOrMeasureOptions)){
   const source=startOrMeasureOptions==null?{}:startOrMeasureOptions;
   options=true;detail=source.detail;
   const rawDuration=source.duration;duration=rawDuration===undefined?undefined:operate("markDouble",null,rawDuration);
   end=measureTime(source.end);start=measureTime(source.start);
  }else startName=operate("string",null,startOrMeasureOptions);
  endMark=endMark===undefined?undefined:operate("string",null,endMark);
  return operate("measure",this,measureName,startName,options,detail,duration,end,start,endMark);
 }}.measure;
 const PerformanceObserver=new Proxy(function PerformanceObserver(callback){throw new T("PerformanceObserver constructor requires new")},{construct(target,args,newTarget){
  if(args.length===0||typeof args[0]!=="function")throw new T("PerformanceObserver requires a callback function");
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:prototypes[0]);
  operate("construct",receiver,args[0]);return receiver;
 }});
 const interfaces=[[0,PerformanceObserver,"PerformanceObserver"],[1,PerformanceObserverEntryList,"PerformanceObserverEntryList"],[2,PerformanceEntry,"PerformanceEntry"],[4,PerformanceMark,"PerformanceMark"],[6,PerformanceMeasure,"PerformanceMeasure"]];
 if(types.includes("visibility-state"))interfaces.push([8,VisibilityStateEntry,"VisibilityStateEntry"]);
 for(const [index,constructor,name] of interfaces){
  define(constructor,"prototype",{value:prototypes[index],writable:false});
  define(prototypes[index],"constructor",{value:constructor,writable:true,configurable:true});
  define(prototypes[index],Symbol.toStringTag,{value:name,configurable:true});
  define(global,name,{value:constructor,writable:true,configurable:true});
 }
 define(PerformanceObserver,"supportedEntryTypes",{get:descriptor({get supportedEntryTypes(){return types}},"supportedEntryTypes").get,enumerable:true,configurable:true});
 const observerMethods={observe(options){
  operate("observerBrand",this);if(arguments.length===0)throw new T("observe requires options");
  if(options!=null&&!object(options))throw new T("options must be a dictionary");
  options=options==null?{}:options;
  const buffered=options.buffered,rawThreshold=options.durationThreshold;
  const threshold=rawThreshold===undefined?undefined:operate("unsigned",this,rawThreshold),entries=options.entryTypes;
  let entryTypes;
  if(entries!==undefined){if(!object(entries))throw new T("entryTypes must be iterable");entryTypes=[];for(const entry of entries)entryTypes.push(operate("string",this,entry))}
  const type=options.type;
  return operate("observe",this,buffered===undefined?undefined:!!buffered,threshold,entryTypes,type===undefined?undefined:operate("string",this,type));
 },disconnect(){return operate("disconnect",this)},takeRecords(){return operate("takeRecords",this)}};
 const listMethods={getEntries(){return operate("getEntries",this)},getEntriesByType(type){
  operate("listBrand",this);if(arguments.length===0)throw new T("getEntriesByType requires a type");return operate("getEntriesByType",this,operate("string",this,type));
 },getEntriesByName(name,type){
  operate("listBrand",this);if(arguments.length===0)throw new T("getEntriesByName requires a name");return operate("getEntriesByName",this,operate("string",this,name),type===undefined?undefined:operate("string",this,type));
 }};
 for(const [prototype,methods] of [[prototypes[0],observerMethods],[prototypes[1],listMethods],[prototypes[2],{toJSON(){return {name:operate("name",this),entryType:operate("entryType",this),startTime:operate("startTime",this),duration:operate("duration",this)}}}]])
  for(const name of Object.keys(methods))define(prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 define(prototypes[8],"toJSON",{value:({toJSON(){operate("visibilityBrand",this);return {name:operate("name",this),entryType:operate("entryType",this),startTime:operate("startTime",this),duration:operate("duration",this)}}}).toJSON,writable:true,enumerable:true,configurable:true});
 for(const name of ["name","entryType","startTime","duration"]){
  const get=descriptor({get [name](){return operate(name,this)}},name).get;
  define(prototypes[2],name,{get,enumerable:true,configurable:true});
 }
 define(markPrototype,"detail",{get:descriptor({get detail(){return operate("markDetail",this)}},"detail").get,enumerable:true,configurable:true});
 define(measurePrototype,"detail",{get:descriptor({get detail(){return operate("measureDetail",this)}},"detail").get,enumerable:true,configurable:true});
 return function make(index,dropped){return index===7?measureMethod:index===5?markMethod:index===3?(dropped===undefined?{}:{droppedEntriesCount:dropped}):create(prototypes[index])};
})'
}
