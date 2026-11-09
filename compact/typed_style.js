(function(){
 const records=new WeakMap(),maps=new WeakMap(),computedCache=new WeakMap(),inlineCache=new WeakMap(),ruleCache=new WeakMap();
 const get=(map,key)=>__elementApply(__elementRecordGet,map,[key]);
 const put=(map,key,value)=>__elementApply(__elementRecordSet,map,[key,value]);
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert Symbol to string");return String(value);};
 const record=value=>{const state=get(records,value);if(!state)throw new TypeError("Illegal CSSStyleValue receiver");return state;};
 const call=(key,request)=>{try{return __queryElements(key,"typedStyleMap",JSON.stringify(request),true);}catch(error){throw new TypeError(error.message);}};
 const serialize=value=>{
  const own=record(value);
  if(own.kind==="keyword")return own.value;
  if(own.kind==="unit")return own.value+(own.unit==="number"?"":own.unit==="percent"?"%":own.unit);
  if(own.kind==="unparsed")return own.segments.map(value=>typeof value==="string"?value:variableText(value)).join("");
  return own.text;
 };
 class CSSStyleValue{
  constructor(){throw new TypeError("Illegal CSSStyleValue constructor");}
  toString(){return serialize(this);}
  static parse(property,text){if(arguments.length<2)throw new TypeError("Missing property and value");return reify(call("",{op:"parse",name:string(property),text:string(text)})[0]);}
  static parseAll(property,text){if(arguments.length<2)throw new TypeError("Missing property and value");return call("",{op:"parseAll",name:string(property),text:string(text)}).map(reify);}
 }
 class CSSKeywordValue extends CSSStyleValue{
  constructor(value){if(!arguments.length)throw new TypeError("Missing keyword");const text=string(value);if(!text)throw new TypeError("Empty keyword");const object=Object.create(new.target.prototype);put(records,object,{kind:"keyword",value:text});return object;}
  get value(){return record(this).value;}
  set value(value){const own=record(this),text=string(value);if(!text)throw new TypeError("Empty keyword");own.value=text;}
 }
 class CSSNumericValue extends CSSStyleValue{
  constructor(){throw new TypeError("Illegal CSSNumericValue constructor");}
  static parse(text){if(!arguments.length)throw new TypeError("Missing value");return reify(call("",{op:"numeric",text:string(text)}));}
 }
 const units=["number","percent","px","cm","mm","q","in","pt","pc","em","ex","ch","rem","lh","rlh","cap","ic","rcap","rex","rch","ric","vw","vh","vi","vb","vmin","vmax","svw","svh","lvw","lvh","dvw","dvh","cqw","cqh","cqi","cqb","cqmin","cqmax","deg","grad","rad","turn","s","ms","hz","khz","dpi","dpcm","dppx","fr"];
 class CSSUnitValue extends CSSNumericValue{
  constructor(value,unit){if(arguments.length<2)throw new TypeError("Missing unit value");value=Number(value);unit=string(unit).toLowerCase();if(!Number.isFinite(value)||!units.includes(unit))throw new TypeError("Invalid unit value");const object=Object.create(new.target.prototype);put(records,object,{kind:"unit",value,unit});return object;}
  get value(){return record(this).value;}
  set value(value){const own=record(this);value=Number(value);if(!Number.isFinite(value))throw new TypeError("Invalid numeric value");own.value=value;}
  get unit(){return record(this).unit;}
 }
 const variableRecords=new WeakMap();
 const variable=value=>{const own=get(variableRecords,value);if(!own)throw new TypeError("Illegal CSSVariableReferenceValue receiver");return own;};
 const variableText=value=>{const own=variable(value);return "var("+own.variable+(own.fallback===null?"":", "+serialize(own.fallback))+")";};
 class CSSVariableReferenceValue{
  constructor(name,fallback=null){if(!arguments.length)throw new TypeError("Missing variable");name=string(name);if(!name.startsWith("--")||name.length<3)throw new TypeError("Invalid custom property");if(fallback!==null&&(!get(records,fallback)||record(fallback).kind!=="unparsed"))throw new TypeError("Expected CSSUnparsedValue");put(variableRecords,this,{variable:name,fallback});}
  get variable(){return variable(this).variable;}
  set variable(value){const own=variable(this);value=string(value);if(!value.startsWith("--")||value.length<3)throw new TypeError("Invalid custom property");own.variable=value;}
  get fallback(){return variable(this).fallback;}
 }
 const segment=value=>get(variableRecords,value)?value:string(value);
 class CSSUnparsedValue extends CSSStyleValue{
  constructor(values){if(!arguments.length)throw new TypeError("Missing segments");const own={kind:"unparsed",segments:Array.from(values,segment)},object=Object.create(new.target.prototype);put(records,object,own);
   const proxy=new Proxy(object,{
    get(target,key,receiver){if(typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key))return own.segments[Number(key)];return Reflect.get(target,key,receiver);},
    set(target,key,value,receiver){if(typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key)){const index=Number(key);if(index>own.segments.length)throw new RangeError("Invalid segment index");own.segments[index]=segment(value);return true;}return Reflect.set(target,key,value,receiver);},
    has(target,key){return typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key)?Number(key)<own.segments.length:Reflect.has(target,key);}
   });put(records,proxy,own);return proxy;
  }
  get length(){return record(this).segments.length;}
  *[Symbol.iterator](){yield* record(this).segments;}
 }
 class CSSImageValue extends CSSStyleValue{}
 class CSSTransformValue extends CSSStyleValue{}
 class CSSMathValue extends CSSNumericValue{get operator(){return record(this).kind;}}
 class CSSNumericArray{
  constructor(){throw new TypeError("Illegal CSSNumericArray constructor");}
  *[Symbol.iterator](){for(let i=0;i<this.length;i++)yield this[i];}
 }
 function numericArray(values){const object=Object.create(CSSNumericArray.prototype);Object.defineProperty(object,"length",{value:values.length});for(let i=0;i<values.length;i++)Object.defineProperty(object,i,{value:values[i],enumerable:true});return object;}
 function mathConstructor(kind,args,prototype){
  if(!args.length||(["negate","invert"].includes(kind)&&args.length!==1)||(kind==="clamp"&&args.length!==3))throw new TypeError("Invalid math arguments");
  const values=args.map(value=>typeof value==="number"?new CSSUnitValue(value,"number"):value);
  for(const value of values)if(!(value instanceof CSSNumericValue)||!get(records,value))throw new TypeError("Expected CSSNumericValue");
  const texts=values.map(serialize);
  const text=kind==="sum"?"calc("+texts.join(" + ")+")":kind==="product"?"calc("+texts.join(" * ")+")":kind==="negate"?"calc(-1 * "+texts[0]+")":kind==="invert"?"calc(1 / "+texts[0]+")":kind+"("+texts.join(", ")+")";
  const state=call("",{op:"numeric",text}),object=Object.create(prototype);state.kind=kind;state.values=values;state.text=text;put(records,object,state);return object;
 }
 class CSSMathSum extends CSSMathValue{constructor(...values){return mathConstructor("sum",values,new.target.prototype);}get values(){return numericArray(record(this).values);}}
 class CSSMathProduct extends CSSMathValue{constructor(...values){return mathConstructor("product",values,new.target.prototype);}get values(){return numericArray(record(this).values);}}
 class CSSMathMin extends CSSMathValue{constructor(...values){return mathConstructor("min",values,new.target.prototype);}get values(){return numericArray(record(this).values);}}
 class CSSMathMax extends CSSMathValue{constructor(...values){return mathConstructor("max",values,new.target.prototype);}get values(){return numericArray(record(this).values);}}
 class CSSMathNegate extends CSSMathValue{constructor(value){return mathConstructor("negate",Array.from(arguments),new.target.prototype);}get value(){return record(this).values[0];}}
 class CSSMathInvert extends CSSMathValue{constructor(value){return mathConstructor("invert",Array.from(arguments),new.target.prototype);}get value(){return record(this).values[0];}}
 class CSSMathClamp extends CSSMathValue{constructor(lower,value,upper){return mathConstructor("clamp",Array.from(arguments),new.target.prototype);}get lower(){return record(this).values[0];}get value(){return record(this).values[1];}get upper(){return record(this).values[2];}}
 const mathClasses={sum:CSSMathSum,product:CSSMathProduct,min:CSSMathMin,max:CSSMathMax,negate:CSSMathNegate,invert:CSSMathInvert,clamp:CSSMathClamp};
 function reify(value){
  if(value===null||value===undefined)return undefined;
  if(value.kind==="keyword")return new CSSKeywordValue(value.value);
  if(value.kind==="unit")return new CSSUnitValue(value.value,value.unit);
  if(value.kind==="unparsed")return new CSSUnparsedValue(value.segments.map(token=>typeof token==="string"?token:new CSSVariableReferenceValue(token.variable,token.fallback===undefined?null:new CSSUnparsedValue(token.fallback.map(reifySegment)))));
  if(mathClasses[value.kind])value.values=value.values.map(reify);
  const constructor=mathClasses[value.kind]||(value.kind==="image"?CSSImageValue:value.kind==="transform"?CSSTransformValue:CSSStyleValue);
  const object=Object.create(constructor.prototype);put(records,object,value);return object;
 }
 function reifySegment(token){return typeof token==="string"?token:new CSSVariableReferenceValue(token.variable,token.fallback===undefined?null:new CSSUnparsedValue(token.fallback.map(reifySegment)));}
 function encode(value){const state=get(records,value);if(!state)return {kind:"string",text:string(value)};return {kind:state.kind,text:serialize(value),keyword:state.kind==="keyword"?state.value:"",value:state.kind==="unit"?state.value:0,unit:state.unit||"",associated_property:state.associated_property};}
 const mapRecord=value=>{const own=get(maps,value);if(!own)throw new TypeError("Illegal StylePropertyMap receiver");return own;};
 function mapCall(map,op,name="",values=[]){const state=mapRecord(map),result=call(state.key,{op,name,values,rule:state.rule||"",computed:state.computed});if(state.owner&&result.attributes!==undefined){state.owner.styleText=result.styleText;state.owner.attributes=result.attributes;state.owner.attributeRecords=result.attributeRecords;}return result.value;}
 class StylePropertyMapReadOnly{
  constructor(){throw new TypeError("Illegal StylePropertyMapReadOnly constructor");}
  get(property){mapRecord(this);if(!arguments.length)throw new TypeError("Missing property");return reify(mapCall(this,"get",string(property))[0]);}
  getAll(property){mapRecord(this);if(!arguments.length)throw new TypeError("Missing property");return mapCall(this,"getAll",string(property)).map(reify);}
  has(property){mapRecord(this);if(!arguments.length)throw new TypeError("Missing property");return mapCall(this,"has",string(property));}
  get size(){return mapCall(this,"size");}
  *entries(){for(const [name,values] of mapCall(this,"entries"))yield [name,values.map(reify)];}
  *keys(){for(const [name] of mapCall(this,"entries"))yield name;}
  *values(){for(const [,values] of mapCall(this,"entries"))yield values.map(reify);}
  forEach(callback,thisArg){mapRecord(this);if(typeof callback!=="function")throw new TypeError("Expected callback");for(const [name,values] of this.entries())Reflect.apply(callback,thisArg,[values,name,this]);}
  [Symbol.iterator](){return this.entries();}
 }
 class StylePropertyMap extends StylePropertyMapReadOnly{
  set(property,...values){mapRecord(this);if(arguments.length<2)throw new TypeError("Missing property and value");mapCall(this,"set",string(property),values.map(encode));}
  append(property,...values){mapRecord(this);if(arguments.length<2)throw new TypeError("Missing property and value");mapCall(this,"append",string(property),values.map(encode));}
  delete(property){mapRecord(this);if(!arguments.length)throw new TypeError("Missing property");mapCall(this,"delete",string(property));}
  clear(){mapCall(this,"clear");}
 }
 for(const constructor of [CSSStyleValue,CSSKeywordValue,CSSNumericValue,CSSUnitValue,CSSUnparsedValue,CSSVariableReferenceValue,CSSImageValue,CSSTransformValue,CSSMathValue,CSSMathSum,CSSMathProduct,CSSMathMin,CSSMathMax,CSSMathNegate,CSSMathInvert,CSSMathClamp,CSSNumericArray,StylePropertyMapReadOnly,StylePropertyMap]){Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});Object.defineProperty(globalThis,constructor.name,{value:constructor,writable:true,configurable:true});}
 for(const unit of units)Object.defineProperty(CSS,unit,{value:function(value){if(!arguments.length)throw new TypeError("Missing value");return new CSSUnitValue(value,unit);},writable:true,configurable:true});
 function elementMap(element,computed){const owner=get(__elementRecords,element);if(!owner)throw new TypeError("Illegal Element receiver");const cache=computed?computedCache:inlineCache;let map=get(cache,element);if(!map){map=Object.create((computed?StylePropertyMapReadOnly:StylePropertyMap).prototype);put(maps,map,{key:owner.bridgeKey,owner,computed});put(cache,element,map);}return map;}
 Object.defineProperty(Element.prototype,"computedStyleMap",{value:function computedStyleMap(){return elementMap(this,true);},writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"attributeStyleMap",{get(){return elementMap(this,false);},enumerable:true,configurable:true});
 Object.defineProperty(CSSStyleRule.prototype,"styleMap",{get(){const rule=__cssRuleId(this);let map=get(ruleCache,this);if(!map){map=Object.create(StylePropertyMap.prototype);put(maps,map,{key:"",rule,computed:false});put(ruleCache,this,map);}return map;},enumerable:true,configurable:true});
})();
