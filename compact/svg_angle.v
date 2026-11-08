module main

// Inserted in the SVG animated-attribute closure so angles use the same private
// receiver records and SameObject wrappers as the other SVG value interfaces.
fn compact_svg_angle_bootstrap() string {
	return r'
 defineInterface("SVGAngle",null,{SVG_ANGLETYPE_UNKNOWN:0,SVG_ANGLETYPE_UNSPECIFIED:1,SVG_ANGLETYPE_DEG:2,SVG_ANGLETYPE_RAD:3,SVG_ANGLETYPE_GRAD:4});
 const angleUnits=[null,"","deg","rad","grad"];
 const angleFactors={"":1,deg:1,rad:180/Math.PI,grad:0.9,turn:360};
 function svgReceiver(receiver,localName){
  const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!state||state.namespaceURI!=="http://www.w3.org/2000/svg"||(localName&&String(state.tagName).split(":").pop()!==localName))throw new TypeError("Illegal SVG receiver");
  return receiver;
 }
 function angleFloat(input){const value=Math.fround(+input);if(!Number.isFinite(value))throw new TypeError("Angle must be a finite float");return value;}
 function parseAngle(text){
  if(text===null)return null;
  const match=/^[\x20\t\n\f\r]*([+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)(deg|rad|grad|turn)?[\x20\t\n\f\r]*$/i.exec(text);
  if(!match)return null;
  const number=Math.fround(Number(match[1]));return Number.isFinite(number)?[match[2]?match[2].toLowerCase():"",number]:null;
 }
 function angleValue(own){return own.element?(parseAngle(own.element.getAttribute("orient"))||["",0]):own.value;}
 function serializeAngle(value){return floatString(value[1])+value[0];}
 function storeAngle(own,value){
  if(own.readOnly)throw readOnlyError();
  if(own.element)own.element.setAttribute("orient",serializeAngle(value));else own.value=value;
 }
 function angleUnit(input){const unit=(+input)&0xffff;if(unit<1||unit>4)throw new DOMException("Unsupported angle unit type","NotSupportedError");return angleUnits[unit];}
 accessor(SVGAngle.prototype,"unitType",function(){const index=angleUnits.indexOf(angleValue(record(this,"SVGAngle"))[0]);return index<0?0:index;});
 accessor(SVGAngle.prototype,"value",function(){const value=angleValue(record(this,"SVGAngle"));return Math.fround(value[1]*angleFactors[value[0]]);},function(input){
  const own=record(this,"SVGAngle"),value=angleFloat(input);storeAngle(own,["",value]);
 });
 accessor(SVGAngle.prototype,"valueInSpecifiedUnits",function(){return angleValue(record(this,"SVGAngle"))[1];},function(input){
  const own=record(this,"SVGAngle"),value=angleFloat(input);storeAngle(own,[angleValue(own)[0],value]);
 });
 accessor(SVGAngle.prototype,"valueAsString",function(){return serializeAngle(angleValue(record(this,"SVGAngle")));},function(input){
  const own=record(this,"SVGAngle"),text=""+input;if(own.readOnly)throw readOnlyError();
  const value=parseAngle(text);if(!value)throw new DOMException("Invalid angle","SyntaxError");storeAngle(own,value);
 });
 method(SVGAngle.prototype,"newValueSpecifiedUnits",function(unitType,valueInSpecifiedUnits){
  const own=record(this,"SVGAngle");if(arguments.length<2)throw new TypeError("newValueSpecifiedUnits requires two arguments");
  const converted=(+unitType)&0xffff,value=angleFloat(valueInSpecifiedUnits);if(own.readOnly)throw readOnlyError();
  storeAngle(own,[angleUnit(converted),value]);
 },2);
 method(SVGAngle.prototype,"convertToSpecifiedUnits",function(unitType){
  const own=record(this,"SVGAngle");if(arguments.length<1)throw new TypeError("convertToSpecifiedUnits requires a unit type");
  const converted=(+unitType)&0xffff;if(own.readOnly)throw readOnlyError();const unit=angleUnit(converted),value=angleValue(own);
  storeAngle(own,[unit,Math.fround(value[1]*angleFactors[value[0]]/angleFactors[unit])]);
 },1);
 function createAngle(fields){return wrap(SVGAngle.prototype,"SVGAngle",fields);}
 function animatedAngle(element){return wrap(SVGAnimatedAngle.prototype,"SVGAnimatedAngle",{base:createAngle({element,readOnly:false}),anim:createAngle({element,readOnly:true})});}
 accessor(SVGAnimatedAngle.prototype,"baseVal",function(){return record(this,"SVGAnimatedAngle").base;});
 accessor(SVGAnimatedAngle.prototype,"animVal",function(){return record(this,"SVGAnimatedAngle").anim;});
 function markerOrientationEnumeration(element){
  return {read:()=>{const text=element.getAttribute("orient");return text==="auto"?1:text==="auto-start-reverse"?3:2;},write:input=>{
   const value=(+input)&0xffff;if(value<1||value>3)throw new TypeError("Invalid marker orientation type");
   element.setAttribute("orient",value===1?"auto":value===3?"auto-start-reverse":"0");
  }};
 }
 accessor(SVGMarkerElement.prototype,"orient",function(){return svgReceiver(this,"marker").getAttribute("orient")||"";},function(value){svgReceiver(this,"marker").setAttribute("orient",""+value);});
 method(SVGMarkerElement.prototype,"setOrientToAuto",function(){svgReceiver(this,"marker").setAttribute("orient","auto");},0);
 method(SVGMarkerElement.prototype,"setOrientToAngle",function(angle){
  svgReceiver(this,"marker");if(arguments.length<1)throw new TypeError("setOrientToAngle requires an angle");
  this.setAttribute("orient",serializeAngle(angleValue(record(angle,"SVGAngle"))));
 },1);
 if(typeof SVGSVGElement==="function")method(SVGSVGElement.prototype,"createSVGAngle",function(){svgReceiver(this,"svg");return createAngle({element:null,readOnly:false,value:["",0]});},0);
'
}
