module main

// SVG animated attributes reflect their content attributes: each element
// interface gets the SVGAnimatedLength, SVGAnimatedNumber, ... members its
// IDL declares (tools/gen_svg_interfaces.py lists them), whose baseVal
// reads and writes the attribute and whose animVal is its read-only view.
// https://svgwg.org/svg2-draft/types.html
fn compact_svg_animated_bootstrap() string {
	return r'
(function(){
 if(typeof SVGElement!=="function")return;
 const XLINK="http://www.w3.org/1999/xlink";
 const get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const records=new WeakMap(),cache=new WeakMap();
 function record(receiver,name){const own=__elementApply(get,records,[receiver]);if(!own||own.kind!==name)throw new TypeError("Illegal "+name+" receiver");return own;}
 function wrap(prototype,kind,fields){const object=Object.create(prototype);__elementApply(set,records,[object,Object.assign({kind},fields)]);return object;}
 function cached(element,name,make){let map=__elementApply(get,cache,[element]);if(!map){map=new Map();__elementApply(set,cache,[element,map]);}let value=map.get(name);if(!value){value=make();map.set(name,value);}return value;}
 function readOnlyError(){return new DOMException("The object is read-only","NoModificationAllowedError");}
 function finite(value,what){const number=Number(value);if(!Number.isFinite(number))throw new TypeError(what+" must be a finite number");return number;}
 function defineInterface(name,parent,constants){
  if(typeof globalThis[name]==="function")return globalThis[name];
  const constructor=({[name]:function(){throw new TypeError("Illegal constructor");}})[name];
  if(parent){Object.setPrototypeOf(constructor,parent);Object.setPrototypeOf(constructor.prototype,parent.prototype);}
  for(const [constant,value] of Object.entries(constants||{})){Object.defineProperty(constructor,constant,{value,enumerable:true});Object.defineProperty(constructor.prototype,constant,{value,enumerable:true});}
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
  return constructor;
 }
 function accessor(prototype,name,getter,setter){
  const descriptor={get:Object.getOwnPropertyDescriptor({get [name](){return getter.call(this);}},name).get,enumerable:true,configurable:true};
  if(setter)descriptor.set=Object.getOwnPropertyDescriptor({set [name](value){setter.call(this,value);}},name).set;
  Object.defineProperty(prototype,name,descriptor);
 }
 function method(prototype,name,value,length){const named={[name]:function(){return value.apply(this,arguments);}}[name];Object.defineProperty(named,"length",{value:length});Object.defineProperty(prototype,name,{value:named,writable:true,enumerable:true,configurable:true});}
 defineInterface("SVGMarkerElement",SVGElement,{SVG_MARKERUNITS_UNKNOWN:0,SVG_MARKERUNITS_USERSPACEONUSE:1,SVG_MARKERUNITS_STROKEWIDTH:2,SVG_MARKER_ORIENT_UNKNOWN:0,SVG_MARKER_ORIENT_AUTO:1,SVG_MARKER_ORIENT_ANGLE:2});
 if(!__compactSVGInterfaces.marker)__compactSVGInterfaces.marker=SVGMarkerElement;
 defineInterface("SVGPreserveAspectRatio",null,{SVG_PRESERVEASPECTRATIO_UNKNOWN:0,SVG_PRESERVEASPECTRATIO_NONE:1,SVG_PRESERVEASPECTRATIO_XMINYMIN:2,SVG_PRESERVEASPECTRATIO_XMIDYMIN:3,SVG_PRESERVEASPECTRATIO_XMAXYMIN:4,SVG_PRESERVEASPECTRATIO_XMINYMID:5,SVG_PRESERVEASPECTRATIO_XMIDYMID:6,SVG_PRESERVEASPECTRATIO_XMAXYMID:7,SVG_PRESERVEASPECTRATIO_XMINYMAX:8,SVG_PRESERVEASPECTRATIO_XMIDYMAX:9,SVG_PRESERVEASPECTRATIO_XMAXYMAX:10,SVG_MEETORSLICE_UNKNOWN:0,SVG_MEETORSLICE_MEET:1,SVG_MEETORSLICE_SLICE:2});
 for(const name of ["SVGAnimatedPreserveAspectRatio","SVGAnimatedInteger","SVGAnimatedEnumeration","SVGAnimatedString","SVGAnimatedBoolean","SVGAnimatedAngle"])defineInterface(name,null,{});
 for(const name of ["SVGNumber","SVGLength","SVGLengthList","SVGNumberList","SVGAnimatedLength","SVGAnimatedNumber","SVGAnimatedRect","SVGAnimatedLengthList","SVGAnimatedNumberList","SVGAnimatedTransformList","SVGTransformList"])defineInterface(name,null,{});
 // SVGLength values: [unit type, number in that unit].
 const units=["","","%","em","ex","px","cm","mm","in","pt","pc"];
 const absolute={1:1,5:1,6:96/2.54,7:96/25.4,8:96,9:96/72,10:16};
 function parseLength(text){
  if(text===null||text===undefined)return null;
  const match=/^[\x20\t\n\f\r]*([+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)(%|em|ex|px|cm|mm|in|pt|pc)?[\x20\t\n\f\r]*$/i.exec(String(text));
  if(!match)return null;
  const number=Number(match[1]);if(!Number.isFinite(number))return null;
  return [match[2]?units.indexOf(match[2].toLowerCase()):1,number];
 }
 // Lengths hold single-precision floats; serialize the shortest such form.
 function floatString(number){const single=Math.fround(number);for(let precision=1;precision<=9;precision++){const text=Number(single.toPrecision(precision));if(Math.fround(text)===single)return String(text);}return String(single);}
 function serializeLength(value){return floatString(value[1])+units[value[0]];}
 function horizontal(name){return /^(x|x1|x2|cx|fx|dx|width|rx|refX|markerWidth)$/.test(name);}
 function vertical(name){return /^(y|y1|y2|cy|fy|dy|height|ry|refY|markerHeight)$/.test(name);}
 function viewportSize(element){
  for(let current=element&&element.parentNode;current&&current.nodeType===1;current=current.parentNode){
   if(current.localName==="svg"&&current.namespaceURI==="http://www.w3.org/2000/svg"){const box=current.getBoundingClientRect();return [box.width,box.height];}
  }
  return null;
 }
 function unitFactor(own,unit){
  if(absolute[unit]!==undefined)return absolute[unit];
  if(unit===3||unit===4){
   let size=16;
   if(own.element&&own.element.isConnected){const parsed=parseFloat(getComputedStyle(own.element).fontSize);if(Number.isFinite(parsed))size=parsed;}
   return unit===3?size:size/2;
  }
  if(unit===2){
   const viewport=viewportSize(own.element);
   if(!viewport)throw new DOMException("The length has no viewport to resolve a percentage against","NotSupportedError");
   const length=horizontal(own.attribute)?viewport[0]:vertical(own.attribute)?viewport[1]:Math.sqrt((viewport[0]*viewport[0]+viewport[1]*viewport[1])/2);
   return length/100;
  }
  return 1;
 }
 function lengthValue(own){
  if(!own.element)return own.value;
  return parseLength(own.element.getAttribute(own.content))||parseLength(own.initial)||[1,0];
 }
 function storeLength(own,value){
  if(own.readOnly)throw readOnlyError();
  if(own.element)own.element.setAttribute(own.content,serializeLength(value));else own.value=value;
 }
 function validUnit(unitType){const unit=Number(unitType)&0xffff;if(unit<1||unit>10)throw new DOMException("Unsupported length unit type","NotSupportedError");return unit;}
 const lengthPrototype=SVGLength.prototype;
 accessor(lengthPrototype,"unitType",function(){return lengthValue(record(this,"SVGLength"))[0];});
 accessor(lengthPrototype,"value",function(){const own=record(this,"SVGLength"),value=lengthValue(own);return value[1]*unitFactor(own,value[0]);},function(input){
  const own=record(this,"SVGLength");if(own.readOnly)throw readOnlyError();
  const number=finite(input,"value"),value=lengthValue(own);storeLength(own,[value[0],number/unitFactor(own,value[0])]);
 });
 accessor(lengthPrototype,"valueInSpecifiedUnits",function(){return lengthValue(record(this,"SVGLength"))[1];},function(input){
  const own=record(this,"SVGLength");if(own.readOnly)throw readOnlyError();
  const number=finite(input,"valueInSpecifiedUnits");storeLength(own,[lengthValue(own)[0],number]);
 });
 accessor(lengthPrototype,"valueAsString",function(){return serializeLength(lengthValue(record(this,"SVGLength")));},function(input){
  const own=record(this,"SVGLength");if(own.readOnly)throw readOnlyError();
  const parsed=parseLength(String(input));if(!parsed)throw new DOMException("Invalid length","SyntaxError");storeLength(own,parsed);
 });
 method(lengthPrototype,"newValueSpecifiedUnits",function(unitType,valueInSpecifiedUnits){
  const own=record(this,"SVGLength");if(arguments.length<2)throw new TypeError("newValueSpecifiedUnits requires two arguments");
  if(own.readOnly)throw readOnlyError();
  const number=finite(valueInSpecifiedUnits,"valueInSpecifiedUnits");storeLength(own,[validUnit(unitType),number]);
 },2);
 method(lengthPrototype,"convertToSpecifiedUnits",function(unitType){
  const own=record(this,"SVGLength");if(arguments.length<1)throw new TypeError("convertToSpecifiedUnits requires a unit type");
  if(own.readOnly)throw readOnlyError();
  const unit=validUnit(unitType),value=lengthValue(own),pixels=value[1]*unitFactor(own,value[0]);
  storeLength(own,[unit,pixels/unitFactor(own,unit)]);
 },1);
 function createLength(fields){return wrap(lengthPrototype,"SVGLength",fields);}
 // SVGNumber
 accessor(SVGNumber.prototype,"value",function(){const own=record(this,"SVGNumber");return own.read();},function(input){
  const own=record(this,"SVGNumber");if(own.readOnly)throw readOnlyError();own.write(finite(input,"value"));
 });
 // Default animated lengths retain their specified units, including zero percentages.
 const lengthDefaults={
  SVGFilterElement:{x:"-10%",y:"-10%",width:"120%",height:"120%"},
  SVGMaskElement:{x:"-10%",y:"-10%",width:"120%",height:"120%"},
  SVGLinearGradientElement:{x1:"0%",y1:"0%",x2:"100%",y2:"0%"},
  SVGRadialGradientElement:{cx:"50%",cy:"50%",r:"50%",fx:"50%",fy:"50%",fr:"0%"},
  SVGSVGElement:{width:"100%",height:"100%"},
  SVGMarkerElement:{markerWidth:"3",markerHeight:"3"},
  primitive:{x:"0%",y:"0%",width:"100%",height:"100%"}
 };
 const numberDefaults={amplitude:1,exponent:1,slope:1,numOctaves:1};
 const contentNames={className:"class",in1:"in"};
 const pairNames={stdDeviationX:["stdDeviation",0],stdDeviationY:["stdDeviation",1],radiusX:["radius",0],radiusY:["radius",1],baseFrequencyX:["baseFrequency",0],baseFrequencyY:["baseFrequency",1]};
 const units2={userSpaceOnUse:1,objectBoundingBox:2};
 const enumerations={
  clipPathUnits:[units2,1],gradientUnits:[units2,2],maskUnits:[units2,2],maskContentUnits:[units2,1],patternUnits:[units2,2],patternContentUnits:[units2,1],filterUnits:[units2,2],primitiveUnits:[units2,1],
  markerUnits:[{userSpaceOnUse:1,strokeWidth:2},2],spreadMethod:[{pad:1,reflect:2,repeat:3},1],
  "SVGFEBlendElement.mode":[{normal:1,multiply:2,screen:3,darken:4,lighten:5,overlay:6,"color-dodge":7,"color-burn":8,"hard-light":9,"soft-light":10,difference:11,exclusion:12,hue:13,saturation:14,color:15,luminosity:16},1],
  "SVGFEColorMatrixElement.type":[{matrix:1,saturate:2,hueRotate:3,luminanceToAlpha:4},1],
  "SVGFECompositeElement.operator":[{over:1,in:2,out:3,atop:4,xor:5,arithmetic:6},1],
  "SVGFEMorphologyElement.operator":[{erode:1,dilate:2},1],
  "SVGFETurbulenceElement.type":[{fractalNoise:1,turbulence:2},2],stitchTiles:[{stitch:1,noStitch:2},2],
  "SVGComponentTransferFunctionElement.type":[{identity:1,table:2,discrete:3,linear:4,gamma:5},1],
  xChannelSelector:[{R:1,G:2,B:3,A:4},4],yChannelSelector:[{R:1,G:2,B:3,A:4},4],
  edgeMode:[{duplicate:1,wrap:2,none:3},3],lengthAdjust:[{spacing:1,spacingAndGlyphs:2},1],
  method:[{align:1,stretch:2},1],spacing:[{auto:1,exact:2},2]
 };
 function parseNumber(text){if(text===null)return null;const match=/^[\x20\t\n\f\r]*([+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)[\x20\t\n\f\r]*$/.exec(text);return match?Number(match[1]):null;}
 function numberPair(text){if(text===null)return null;const parts=String(text).trim().split(/[\x20\t\n\f\r]*,[\x20\t\n\f\r]*|[\x20\t\n\f\r]+/).filter(Boolean);if(parts.length<1||parts.length>2)return null;const values=parts.map(part=>parseNumber(part));if(values.some(value=>value===null))return null;return values.length===1?[values[0],values[0]]:values;}
 function animatedNumber(element,attribute,defaultValue,integer){
  const pair=pairNames[attribute],content=pair?pair[0]:attribute;
  const read=()=>{
   if(pair){const values=numberPair(element.getAttribute(content));return values?values[pair[1]]:defaultValue;}
   const value=parseNumber(element.getAttribute(content));
   if(value===null)return defaultValue;
   return integer?(Number.isInteger(value)?value:defaultValue):value;
  };
  const write=value=>{
   if(integer)value=Math.trunc(value);
   if(pair){const values=numberPair(element.getAttribute(content))||[defaultValue,defaultValue];values[pair[1]]=value;element.setAttribute(content,values[0]===values[1]?String(values[0]):values.join(" "));}
   else element.setAttribute(content,String(value));
  };
  return wrap((integer?SVGAnimatedInteger:SVGAnimatedNumber).prototype,integer?"SVGAnimatedInteger":"SVGAnimatedNumber",{read,write});
 }
 for(const [type,name] of [[SVGAnimatedNumber,"SVGAnimatedNumber"],[SVGAnimatedInteger,"SVGAnimatedInteger"]]){
  accessor(type.prototype,"baseVal",function(){return record(this,name).read();},function(value){const own=record(this,name);own.write(name==="SVGAnimatedInteger"?Number(value)|0:finite(value,"baseVal"));});
  accessor(type.prototype,"animVal",function(){return record(this,name).read();});
 }
 accessor(SVGAnimatedLength.prototype,"baseVal",function(){return record(this,"SVGAnimatedLength").base;});
 accessor(SVGAnimatedLength.prototype,"animVal",function(){return record(this,"SVGAnimatedLength").anim;});
 function animatedLength(element,interfaceName,attribute){
  const primitive=/^SVGFE/.test(interfaceName)&&["x","y","width","height"].includes(attribute);
  const initial=((primitive?lengthDefaults.primitive:lengthDefaults[interfaceName])||{})[attribute]||"0";
  const fields={element,attribute,content:attribute,initial};
  return wrap(SVGAnimatedLength.prototype,"SVGAnimatedLength",{base:createLength(Object.assign({readOnly:false},fields)),anim:createLength(Object.assign({readOnly:true},fields))});
 }
 function stringContent(element,attribute){
  if(attribute==="href"){const plain=element.getAttribute("href");if(plain!==null)return plain;const linked=element.getAttributeNS(XLINK,"href");return linked===null?"":linked;}
  const value=element.getAttribute(contentNames[attribute]||attribute);return value===null?"":value;
 }
 accessor(SVGAnimatedString.prototype,"baseVal",function(){const own=record(this,"SVGAnimatedString");return stringContent(own.element,own.attribute);},function(value){
  const own=record(this,"SVGAnimatedString"),text=String(value);
  if(own.attribute==="href"&&!own.element.hasAttribute("href")&&own.element.hasAttributeNS(XLINK,"href"))own.element.setAttributeNS(XLINK,"xlink:href",text);
  else own.element.setAttribute(contentNames[own.attribute]||own.attribute,text);
 });
 accessor(SVGAnimatedString.prototype,"animVal",function(){const own=record(this,"SVGAnimatedString");return stringContent(own.element,own.attribute);});
 function enumeration(interfaceName,attribute){return enumerations[interfaceName+"."+attribute]||enumerations[attribute];}
 accessor(SVGAnimatedEnumeration.prototype,"baseVal",function(){const own=record(this,"SVGAnimatedEnumeration");return own.read();},function(value){const own=record(this,"SVGAnimatedEnumeration");own.write(value);});
 accessor(SVGAnimatedEnumeration.prototype,"animVal",function(){return record(this,"SVGAnimatedEnumeration").read();});
 function animatedEnumeration(element,interfaceName,attribute){
  const [table,defaultValue]=enumeration(interfaceName,attribute)||[{},0];
  const read=()=>{const value=element.getAttribute(attribute);return value!==null&&Object.prototype.hasOwnProperty.call(table,value)?table[value]:defaultValue;};
  const write=value=>{
   const number=Number(value)&0xffff,keyword=Object.keys(table).find(key=>table[key]===number);
   if(keyword===undefined)throw new TypeError("Invalid enumeration value");
   element.setAttribute(attribute,keyword);
  };
  return wrap(SVGAnimatedEnumeration.prototype,"SVGAnimatedEnumeration",{read,write});
 }
 // viewBox
 function parseRect(text){if(text===null)return null;const parts=String(text).trim().split(/[\x20\t\n\f\r]*,[\x20\t\n\f\r]*|[\x20\t\n\f\r]+/);if(parts.length!==4)return null;const values=parts.map(part=>parseNumber(part));if(values.some(value=>value===null)||values[2]<0||values[3]<0)return null;return values;}
 accessor(SVGAnimatedRect.prototype,"baseVal",function(){const own=record(this,"SVGAnimatedRect"),values=parseRect(own.element.getAttribute("viewBox"));return values?new DOMRect(values[0],values[1],values[2],values[3]):null;});
 accessor(SVGAnimatedRect.prototype,"animVal",function(){const own=record(this,"SVGAnimatedRect"),values=parseRect(own.element.getAttribute("viewBox"));return values?new DOMRectReadOnly(values[0],values[1],values[2],values[3]):null;});
 // preserveAspectRatio
 const aligns=["","none","xMinYMin","xMidYMin","xMaxYMin","xMinYMid","xMidYMid","xMaxYMid","xMinYMax","xMidYMax","xMaxYMax"];
 function parseAspect(text){
  if(text===null)return [6,1];
  const parts=String(text).trim().split(/[\x20\t\n\f\r]+/);
  const align=aligns.indexOf(parts[0]),meet=parts.length===1?1:parts[1]==="meet"?1:parts[1]==="slice"?2:0;
  if(align<1||meet===0||parts.length>2)return [6,1];
  return [align,meet];
 }
 for(const [name,index,length] of [["align",0,10],["meetOrSlice",1,2]])accessor(SVGPreserveAspectRatio.prototype,name,function(){const own=record(this,"SVGPreserveAspectRatio");return parseAspect(own.element.getAttribute("preserveAspectRatio"))[index];},function(value){
  const own=record(this,"SVGPreserveAspectRatio");if(own.readOnly)throw readOnlyError();
  const number=Number(value)&0xffff;if(number<1||number>length)throw new TypeError("Invalid preserveAspectRatio value");
  const current=parseAspect(own.element.getAttribute("preserveAspectRatio"));current[index]=number;
  own.element.setAttribute("preserveAspectRatio",aligns[current[0]]+(current[1]===2?" slice":""));
 });
 accessor(SVGAnimatedPreserveAspectRatio.prototype,"baseVal",function(){return record(this,"SVGAnimatedPreserveAspectRatio").base;});
 accessor(SVGAnimatedPreserveAspectRatio.prototype,"animVal",function(){return record(this,"SVGAnimatedPreserveAspectRatio").anim;});
 // Lists keep their items read-only views of the content attribute.
 function listOf(type,kind,items){
  const object=wrap(type.prototype,kind,{items});
  return object;
 }
 for(const [type,kind] of [[SVGNumberList,"SVGNumberList"],[SVGLengthList,"SVGLengthList"],[SVGTransformList,"SVGTransformList"]]){
  accessor(type.prototype,"numberOfItems",function(){return record(this,kind).items().length;});
  accessor(type.prototype,"length",function(){return record(this,kind).items().length;});
  method(type.prototype,"getItem",function(index){const items=record(this,kind).items(),position=Number(index)>>>0;if(position>=items.length)throw new DOMException("Index out of range","IndexSizeError");return items[position];},1);
 }
 for(const [type,kind] of [[SVGAnimatedNumberList,"SVGAnimatedNumberList"],[SVGAnimatedLengthList,"SVGAnimatedLengthList"],[SVGAnimatedTransformList,"SVGAnimatedTransformList"]]){
  accessor(type.prototype,"baseVal",function(){return record(this,kind).base;});
  accessor(type.prototype,"animVal",function(){return record(this,kind).base;});
 }
 function animatedList(element,type,attribute){
  const text=()=>{const value=element.getAttribute(attribute);return value===null?[]:String(value).trim().split(/[\x20\t\n\f\r]*,[\x20\t\n\f\r]*|[\x20\t\n\f\r]+/).filter(Boolean);};
  if(type==="SVGAnimatedNumberList")return wrap(SVGAnimatedNumberList.prototype,type,{base:listOf(SVGNumberList,"SVGNumberList",()=>text().map(part=>{const value=parseNumber(part);return wrap(SVGNumber.prototype,"SVGNumber",{readOnly:true,read:()=>value===null?0:value});}))});
  if(type==="SVGAnimatedLengthList")return wrap(SVGAnimatedLengthList.prototype,type,{base:listOf(SVGLengthList,"SVGLengthList",()=>text().map(part=>createLength({element:null,readOnly:true,value:parseLength(part)||[1,0]})))});
  return wrap(SVGAnimatedTransformList.prototype,type,{base:listOf(SVGTransformList,"SVGTransformList",()=>[])});
 }
 function animated(element,interfaceName,attribute,type){
  switch(type){
   case "SVGAnimatedLength":return animatedLength(element,interfaceName,attribute);
   case "SVGAnimatedNumber":return animatedNumber(element,attribute,numberDefaults[attribute]!==undefined?numberDefaults[attribute]:interfaceName==="SVGFEDropShadowElement"&&/^(dx|dy|stdDeviationX|stdDeviationY)$/.test(attribute)?2:0,false);
   case "SVGAnimatedInteger":return animatedNumber(element,attribute,numberDefaults[attribute]!==undefined?numberDefaults[attribute]:0,true);
   case "SVGAnimatedString":return wrap(SVGAnimatedString.prototype,type,{element,attribute});
   case "SVGAnimatedEnumeration":return animatedEnumeration(element,interfaceName,attribute);
   case "SVGAnimatedRect":return wrap(SVGAnimatedRect.prototype,type,{element});
   case "SVGAnimatedPreserveAspectRatio":return wrap(SVGAnimatedPreserveAspectRatio.prototype,type,{base:wrap(SVGPreserveAspectRatio.prototype,"SVGPreserveAspectRatio",{element,readOnly:false}),anim:wrap(SVGPreserveAspectRatio.prototype,"SVGPreserveAspectRatio",{element,readOnly:true})});
   default:return animatedList(element,type,attribute);
  }
 }
 const members=Object.assign({},__compactSVGAnimatedMembers);
 members.SVGMarkerElement=[["refX","SVGAnimatedLength"],["refY","SVGAnimatedLength"],["markerWidth","SVGAnimatedLength"],["markerHeight","SVGAnimatedLength"],["markerUnits","SVGAnimatedEnumeration"],["viewBox","SVGAnimatedRect"],["preserveAspectRatio","SVGAnimatedPreserveAspectRatio"]];
 for(const [interfaceName,list] of Object.entries(members)){
  const constructor=globalThis[interfaceName];
  if(typeof constructor!=="function")continue;
  for(const [attribute,type] of list){
   if(Object.prototype.hasOwnProperty.call(constructor.prototype,attribute))continue;
   accessor(constructor.prototype,attribute,function(){
    if(!(this instanceof constructor)||!__elementApply(__elementRecordGet,__elementRecords,[this]))throw new TypeError("Illegal "+interfaceName+" receiver");
    return cached(this,interfaceName+"."+attribute,()=>animated(this,interfaceName,attribute,type));
   });
  }
 }
 function ownerSVG(element){
  for(let current=element.parentNode;current&&current.nodeType===1;current=current.parentNode)
   if(current.localName==="svg"&&current.namespaceURI==="http://www.w3.org/2000/svg")return current;
  return null;
 }
 accessor(SVGElement.prototype,"ownerSVGElement",function(){return ownerSVG(this);});
 accessor(SVGElement.prototype,"viewportElement",function(){return ownerSVG(this);});
 if(typeof SVGSVGElement==="function"){
  method(SVGSVGElement.prototype,"createSVGLength",function(){return createLength({element:null,readOnly:false,value:[1,0],attribute:"",content:""});},0);
  method(SVGSVGElement.prototype,"createSVGNumber",function(){let value=0;return wrap(SVGNumber.prototype,"SVGNumber",{readOnly:false,read:()=>value,write:number=>{value=number;}});},0);
  method(SVGSVGElement.prototype,"createSVGPoint",function(){return new DOMPoint();},0);
  method(SVGSVGElement.prototype,"createSVGMatrix",function(){return new DOMMatrix();},0);
  method(SVGSVGElement.prototype,"createSVGRect",function(){return new DOMRect();},0);
 }
})();
'
}
