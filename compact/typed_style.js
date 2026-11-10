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
  if(own.kind==="transform"&&own.values)return own.values.map(value=>componentText(value)).join(" ");
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
  type(){return numericType(this);}
  add(...values){return numericMethod(this,"add",values);}
  sub(...values){return numericMethod(this,"sub",values);}
  mul(...values){return numericMethod(this,"mul",values);}
  div(...values){return numericMethod(this,"div",values);}
  min(...values){return numericMethod(this,"min",values);}
  max(...values){return numericMethod(this,"max",values);}
  equals(...values){return numericMethod(this,"equals",values);}
  negate(){return numericMethod(this,"negate",[]);}
  invert(){return numericMethod(this,"invert",[]);}
  to(unit){if(!arguments.length)throw new TypeError("Missing unit");return numericMethod(this,"to",[],[string(unit)]);}
 }
 function numericOperand(value){if(typeof value==="number")return String(value);if(!(value instanceof CSSNumericValue)||!get(records,value))throw new TypeError("Expected CSSNumberish");return serialize(value);}
 function numericMethod(value,name,values,units=[]){record(value);const result=call("",{op:"numericMethod",name,text:serialize(value),args:values.map(numericOperand),units});return typeof result==="boolean"?result:reify(result);}
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
 class CSSTransformValue extends CSSStyleValue{
  constructor(transforms){if(!arguments.length)throw new TypeError("Missing transforms");const values=Array.from(transforms,transformItem);if(!values.length)throw new TypeError("CSSTransformValue's transforms list cannot be empty");return transformValue(new.target.prototype,values);}
  get length(){return record(this).values.length;}
  get is2D(){return record(this).values.every(value=>component(value).is2D);}
  toMatrix(){let result=new DOMMatrix();for(const value of record(this).values)result=result.multiply(componentMatrix(value));return result;}
  *[Symbol.iterator](){yield* record(this).values;}
 }
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
 const unitBase=unit=>unit==="number"?null:unit==="percent"?"percent":["deg","grad","rad","turn"].includes(unit)?"angle":["s","ms"].includes(unit)?"time":["hz","khz"].includes(unit)?"frequency":["dpi","dpcm","dppx"].includes(unit)?"resolution":unit==="fr"?"flex":"length";
 function numericType(value){const own=record(value);if(own.kind==="unit"){const base=unitBase(own.unit),result={};if(base)result[base]=1;return result;}return Object.assign({},own.type||{});}
 // Whether a CSSNumericValue matches one of the given base types (null: <number>).
 function matches(value,...bases){if(!(value instanceof CSSNumericValue)||!get(records,value))return false;const type=numericType(value),keys=Object.keys(type).filter(key=>key!=="percentHint"&&type[key]!==0);return bases.some(base=>base===null?keys.length===0:keys.length===1&&keys[0]===base&&type[base]===1);}
 const numberish=value=>typeof value==="number"?new CSSUnitValue(value,"number"):value;
 const components=new WeakMap();
 const component=value=>{const own=get(components,value);if(!own)throw new TypeError("Illegal CSSTransformComponent receiver");return own;};
 const check=(value,...bases)=>{if(!matches(value,...bases))throw new TypeError("Invalid transform component value");return value;};
 const px=value=>{const own=get(records,value);if(!own||own.kind!=="unit"||(own.unit!=="px"&&own.unit!=="number"))throw new TypeError("Cannot convert transform component to a matrix");return own.value;};
 const degrees=value=>{const own=get(records,value);if(!own||own.kind!=="unit")throw new TypeError("Cannot convert transform component to a matrix");return own.unit==="rad"?own.value*180/Math.PI:own.unit==="grad"?own.value*0.9:own.unit==="turn"?own.value*360:own.value;};
 const minimumZero=value=>{const own=get(records,value);return own&&own.kind==="unit"&&own.value<0?"calc("+serialize(value)+")":serialize(value);};
 function componentText(value){
  const own=component(value);
  switch(own.type){
   case "translate":return own.is2D?"translate("+serialize(own.x)+", "+serialize(own.y)+")":"translate3d("+serialize(own.x)+", "+serialize(own.y)+", "+serialize(own.z)+")";
   case "rotate":return own.is2D?"rotate("+serialize(own.angle)+")":"rotate3d("+serialize(own.x)+", "+serialize(own.y)+", "+serialize(own.z)+", "+serialize(own.angle)+")";
   case "scale":return own.is2D?"scale("+serialize(own.x)+", "+serialize(own.y)+")":"scale3d("+serialize(own.x)+", "+serialize(own.y)+", "+serialize(own.z)+")";
   case "skew":{const ay=get(records,own.ay);return ay&&ay.kind==="unit"&&ay.value===0?"skew("+serialize(own.ax)+")":"skew("+serialize(own.ax)+", "+serialize(own.ay)+")";}
   case "skewX":return "skewX("+serialize(own.ax)+")";
   case "skewY":return "skewY("+serialize(own.ay)+")";
   case "perspective":return "perspective("+(own.length instanceof CSSKeywordValue?own.length.value:minimumZero(own.length))+")";
   default:{const m=own.matrix;return own.is2D?"matrix("+[m.a,m.b,m.c,m.d,m.e,m.f].join(", ")+")":"matrix3d("+Array.from(m.toFloat64Array()).join(", ")+")";}
  }
 }
 function componentMatrix(value){
  const own=component(value),matrix=new DOMMatrix();
  switch(own.type){
   case "translate":return matrix.translateSelf(px(own.x),px(own.y),own.is2D?0:px(own.z));
   case "rotate":return own.is2D?matrix.rotateSelf(degrees(own.angle)):matrix.rotateAxisAngleSelf(px(own.x),px(own.y),px(own.z),degrees(own.angle));
   case "scale":return own.is2D?matrix.scaleSelf(px(own.x),px(own.y)):matrix.scaleSelf(px(own.x),px(own.y),px(own.z));
   case "skew":return new DOMMatrix([1,Math.tan(degrees(own.ay)*Math.PI/180),Math.tan(degrees(own.ax)*Math.PI/180),1,0,0]);
   case "skewX":return matrix.skewXSelf(degrees(own.ax));
   case "skewY":return matrix.skewYSelf(degrees(own.ay));
   case "perspective":{if(own.length instanceof CSSKeywordValue)return matrix;const length=px(own.length);matrix.m34=-1/Math.max(length,1);return matrix;}
   default:return DOMMatrix.fromMatrix(own.matrix);
  }
 }
 const newComponent=(prototype,own)=>{const object=Object.create(prototype);put(components,object,own);return object;};
 class CSSTransformComponent{
  constructor(){throw new TypeError("Illegal CSSTransformComponent constructor");}
  get is2D(){return component(this).is2D;}
  set is2D(value){const own=component(this);if(["translate","rotate","scale","matrix"].includes(own.type))own.is2D=!!value;}
  toMatrix(){return componentMatrix(this);}
  toString(){return componentText(this);}
 }
 class CSSTranslate extends CSSTransformComponent{
  constructor(x,y,z){if(arguments.length<2)throw new TypeError("Missing translate values");check(x,"length","percent");check(y,"length","percent");if(z!==undefined)check(z,"length");return newComponent(new.target.prototype,{type:"translate",x,y,z:z===undefined?new CSSUnitValue(0,"px"):z,is2D:z===undefined});}
  get x(){return component(this).x;} set x(value){component(this).x=check(value,"length","percent");}
  get y(){return component(this).y;} set y(value){component(this).y=check(value,"length","percent");}
  get z(){return component(this).z;} set z(value){component(this).z=check(value,"length");}
 }
 class CSSRotate extends CSSTransformComponent{
  constructor(...args){
   if(args.length===1)return newComponent(new.target.prototype,{type:"rotate",x:new CSSUnitValue(0,"number"),y:new CSSUnitValue(0,"number"),z:new CSSUnitValue(1,"number"),angle:check(args[0],"angle"),is2D:true});
   if(args.length!==4)throw new TypeError("Invalid rotate arguments");
   const [x,y,z]=args.slice(0,3).map(numberish);check(x,null);check(y,null);check(z,null);
   return newComponent(new.target.prototype,{type:"rotate",x,y,z,angle:check(args[3],"angle"),is2D:false});
  }
  get x(){return component(this).x;} set x(value){component(this).x=check(numberish(value),null);}
  get y(){return component(this).y;} set y(value){component(this).y=check(numberish(value),null);}
  get z(){return component(this).z;} set z(value){component(this).z=check(numberish(value),null);}
  get angle(){return component(this).angle;} set angle(value){component(this).angle=check(value,"angle");}
 }
 class CSSScale extends CSSTransformComponent{
  constructor(x,y,z){if(arguments.length<2)throw new TypeError("Missing scale values");x=check(numberish(x),null);y=check(numberish(y),null);const is2D=z===undefined;z=is2D?new CSSUnitValue(1,"number"):check(numberish(z),null);return newComponent(new.target.prototype,{type:"scale",x,y,z,is2D});}
  get x(){return component(this).x;} set x(value){component(this).x=check(numberish(value),null);}
  get y(){return component(this).y;} set y(value){component(this).y=check(numberish(value),null);}
  get z(){return component(this).z;} set z(value){component(this).z=check(numberish(value),null);}
 }
 class CSSSkew extends CSSTransformComponent{
  constructor(ax,ay){if(arguments.length<2)throw new TypeError("Missing skew values");return newComponent(new.target.prototype,{type:"skew",ax:check(ax,"angle"),ay:check(ay,"angle"),is2D:true});}
  get ax(){return component(this).ax;} set ax(value){component(this).ax=check(value,"angle");}
  get ay(){return component(this).ay;} set ay(value){component(this).ay=check(value,"angle");}
 }
 class CSSSkewX extends CSSTransformComponent{
  constructor(ax){if(!arguments.length)throw new TypeError("Missing skew value");return newComponent(new.target.prototype,{type:"skewX",ax:check(ax,"angle"),is2D:true});}
  get ax(){return component(this).ax;} set ax(value){component(this).ax=check(value,"angle");}
 }
 class CSSSkewY extends CSSTransformComponent{
  constructor(ay){if(!arguments.length)throw new TypeError("Missing skew value");return newComponent(new.target.prototype,{type:"skewY",ay:check(ay,"angle"),is2D:true});}
  get ay(){return component(this).ay;} set ay(value){component(this).ay=check(value,"angle");}
 }
 const perspectiveLength=value=>{if(typeof value==="string")return new CSSKeywordValue(value);if(value instanceof CSSKeywordValue)return value;return check(value,"length");};
 class CSSPerspective extends CSSTransformComponent{
  constructor(length){if(!arguments.length)throw new TypeError("Missing perspective length");return newComponent(new.target.prototype,{type:"perspective",length:perspectiveLength(length),is2D:false});}
  get length(){return component(this).length;} set length(value){component(this).length=perspectiveLength(value);}
 }
 class CSSMatrixComponent extends CSSTransformComponent{
  constructor(matrix,options){if(!(matrix instanceof DOMMatrixReadOnly))throw new TypeError("Expected DOMMatrixReadOnly");const is2D=options&&options.is2D!==undefined?!!options.is2D:matrix.is2D;return newComponent(new.target.prototype,{type:"matrix",matrix:DOMMatrix.fromMatrix(matrix),is2D});}
  get matrix(){return component(this).matrix;}
  set matrix(value){if(!(value instanceof DOMMatrixReadOnly))throw new TypeError("Expected DOMMatrixReadOnly");component(this).matrix=DOMMatrix.fromMatrix(value);}
 }
 const transformItem=value=>{if(!get(components,value))throw new TypeError("Expected CSSTransformComponent");return value;};
 function transformValue(prototype,values,text){
  const own={kind:"transform",values},object=Object.create(prototype);if(text!==undefined)own.text=text;put(records,object,own);
  const index=key=>typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key);
  const proxy=new Proxy(object,{
   get(target,key,receiver){if(index(key))return own.values[Number(key)];return Reflect.get(target,key,receiver);},
   set(target,key,value,receiver){if(index(key)){const n=Number(key);if(n>own.values.length)throw new RangeError("Invalid transform index");own.values[n]=transformItem(value);return true;}return Reflect.set(target,key,value,receiver);},
   has(target,key){return index(key)?Number(key)<own.values.length:Reflect.has(target,key);}
  });put(records,proxy,own);return proxy;
 }
 function componentFromRecord(value){
  const own={type:value.type,is2D:!!value.is2D};
  for(const key of ["x","y","z","angle","ax","ay"])if(value[key]!==undefined)own[key]=reify(value[key]);
  if(value.length!==undefined)own.length=value.length.kind==="keyword"?new CSSKeywordValue(value.length.value):reify(value.length);
  if(value.matrix!==undefined)own.matrix=new DOMMatrix(value.matrix);
  const prototype={translate:CSSTranslate,rotate:CSSRotate,scale:CSSScale,skew:CSSSkew,skewX:CSSSkewX,skewY:CSSSkewY,perspective:CSSPerspective,matrix:CSSMatrixComponent}[value.type].prototype;
  return newComponent(prototype,own);
 }
 const mathClasses={sum:CSSMathSum,product:CSSMathProduct,min:CSSMathMin,max:CSSMathMax,negate:CSSMathNegate,invert:CSSMathInvert,clamp:CSSMathClamp};
 function reify(value){
  if(value===null||value===undefined)return undefined;
  if(value.kind==="keyword")return new CSSKeywordValue(value.value);
  if(value.kind==="unit")return new CSSUnitValue(value.value,value.unit);
  if(value.kind==="unparsed")return new CSSUnparsedValue(value.segments.map(token=>typeof token==="string"?token:new CSSVariableReferenceValue(token.variable,token.fallback===undefined?null:new CSSUnparsedValue(token.fallback.map(reifySegment)))));
  if(value.kind==="transform"&&value.components){const result=transformValue(CSSTransformValue.prototype,value.components.map(componentFromRecord),value.text);if(value.associated_property!==undefined)record(result).associated_property=value.associated_property;return result;}
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
  append(property,...values){mapRecord(this);if(!arguments.length)throw new TypeError("Missing property");mapCall(this,"append",string(property),values.map(encode));}
  delete(property){mapRecord(this);if(!arguments.length)throw new TypeError("Missing property");mapCall(this,"delete",string(property));}
  clear(){mapCall(this,"clear");}
 }
 for(const constructor of [CSSStyleValue,CSSKeywordValue,CSSNumericValue,CSSUnitValue,CSSUnparsedValue,CSSVariableReferenceValue,CSSImageValue,CSSTransformValue,CSSTransformComponent,CSSTranslate,CSSRotate,CSSScale,CSSSkew,CSSSkewX,CSSSkewY,CSSPerspective,CSSMatrixComponent,CSSMathValue,CSSMathSum,CSSMathProduct,CSSMathMin,CSSMathMax,CSSMathNegate,CSSMathInvert,CSSMathClamp,CSSNumericArray,StylePropertyMapReadOnly,StylePropertyMap]){Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});Object.defineProperty(globalThis,constructor.name,{value:constructor,writable:true,configurable:true});}
 for(const unit of units)Object.defineProperty(CSS,unit,{value:function(value){if(!arguments.length)throw new TypeError("Missing value");return new CSSUnitValue(value,unit);},writable:true,configurable:true});
 function elementMap(element,computed){const owner=get(__elementRecords,element);if(!owner)throw new TypeError("Illegal Element receiver");const cache=computed?computedCache:inlineCache;let map=get(cache,element);if(!map){map=Object.create((computed?StylePropertyMapReadOnly:StylePropertyMap).prototype);put(maps,map,{key:owner.bridgeKey,owner,computed});put(cache,element,map);}return map;}
 Object.defineProperty(Element.prototype,"computedStyleMap",{value:function computedStyleMap(){return elementMap(this,true);},writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Element.prototype,"attributeStyleMap",{get(){return elementMap(this,false);},enumerable:true,configurable:true});
 Object.defineProperty(CSSStyleRule.prototype,"styleMap",{get(){const rule=__cssRuleId(this);let map=get(ruleCache,this);if(!map){map=Object.create(StylePropertyMap.prototype);put(maps,map,{key:"",rule,computed:false});put(ruleCache,this,map);}return map;},enumerable:true,configurable:true});
})();
