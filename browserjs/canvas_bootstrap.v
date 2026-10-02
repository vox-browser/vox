// Compact JavaScript IDL transport for HTML canvas. The HTML records own all
// validation, geometry, drawing state, raster operations and pixel readback.
module browserjs

pub fn canvas_bootstrap() string {
	return r'
const __canvasObjects = Object.create(null);
function __canvasCall(s, method, args, extra) {
 const request = Object.assign({key:s.bridgeKey||s.id,width:__canvasDimension(s,"width"),height:__canvasDimension(s,"height"),method:method,args:args||[]},extra||{});
 try { return JSON.parse(__ladybirdCanvas(JSON.stringify(request))); }
 catch(error) { const match=/^([A-Za-z]+Error):\s*(.*)/.exec(error.message); if(match){error.name=match[1];error.message=match[2];} throw error; }
}
function __canvasFor(s) {
 const key=s.bridgeKey||s.id;
 return __canvases[key] || (__canvases[key]={state:s});
}
function __canvasResize(s) {
 const key=s.bridgeKey||s.id;
 const canvas=__canvases[key];if(canvas){if(canvas.kind==="webgl"||canvas.kind==="webgl2")__webglCall(s,"resize");else __canvasCall(s,"resize");}
}
function __canvasSource(source) {
 if(!source||!source.__state)throw new TypeError("Expected a CanvasImageSource");
 const state=source.__state,result={source:state.bridgeKey||state.id};
 if(state.tagName==="video" && state.videoPixels)result.image={width:+state.videoWidth,height:+state.videoHeight,pixels:state.videoPixels};
 return result;
}
function __canvasMatrix(matrix) {
 matrix=matrix||{};
 const values=[matrix.a===undefined?(matrix.m11===undefined?1:+matrix.m11):+matrix.a,matrix.b===undefined?(matrix.m12===undefined?0:+matrix.m12):+matrix.b,matrix.c===undefined?(matrix.m21===undefined?0:+matrix.m21):+matrix.c,matrix.d===undefined?(matrix.m22===undefined?1:+matrix.m22):+matrix.d,matrix.e===undefined?(matrix.m41===undefined?0:+matrix.m41):+matrix.e,matrix.f===undefined?(matrix.m42===undefined?0:+matrix.m42):+matrix.f];
 for(const entry of [["a","m11"],["b","m12"],["c","m21"],["d","m22"],["e","m41"],["f","m42"]])if(matrix[entry[0]]!==undefined&&matrix[entry[1]]!==undefined&&!Object.is(+matrix[entry[0]],+matrix[entry[1]]))throw new TypeError("DOMMatrix aliases disagree");
 if(matrix.is2D===false || (matrix.m13!==undefined&&+matrix.m13!==0) || (matrix.m14!==undefined&&+matrix.m14!==0) || (matrix.m23!==undefined&&+matrix.m23!==0) || (matrix.m24!==undefined&&+matrix.m24!==0) || (matrix.m31!==undefined&&+matrix.m31!==0) || (matrix.m32!==undefined&&+matrix.m32!==0) || (matrix.m33!==undefined&&+matrix.m33!==1) || (matrix.m34!==undefined&&+matrix.m34!==0) || (matrix.m43!==undefined&&+matrix.m43!==0) || (matrix.m44!==undefined&&+matrix.m44!==1))throw new TypeError("Expected a two-dimensional matrix");
 return values;
}
function __canvasPaintObject(s, result, pattern) {
 if(result===null)return null;
 const object={__canvasHandle:result.handle};
 if(pattern)object.setTransform=function(matrix){__canvasCall(s,"patternSetTransform",__canvasMatrix(matrix),{handle:result.handle});};
 else object.addColorStop=function(offset,color){if(arguments.length<2)throw new TypeError("addColorStop requires two arguments");__canvasCall(s,"addColorStop",[+offset,String(color)],{handle:result.handle});};
 __canvasObjects[result.handle]=object;
 return object;
}
function __canvasImageData(image) {
 image.data=new Uint8ClampedArray(image.data);
 return image;
}
function __canvasGetContext(s,kind,options){kind=String(kind);if(kind==="2d")return __canvasContext(s,options);if(kind==="webgl"||kind==="webgl2"||kind==="experimental-webgl")return typeof __webglContext==="function"?__webglContext(s,kind,options):null;return null;}
function __canvasContext(s,options) {
 const canvas=__canvasFor(s);
 if(canvas.kind&&canvas.kind!=="2d")return null;if(canvas.context)return canvas.context;
 if(__canvasCall(s,"getContext",[],{options:options||null})===null)return null;canvas.kind="2d";
 const context={canvas:__element(s),getContextAttributes:function(){return __canvasCall(s,"getContextAttributes");}};
 const properties=["fillStyle","strokeStyle","font","globalAlpha","globalCompositeOperation","shadowOffsetX","shadowOffsetY","shadowBlur","shadowColor","filter","lineWidth","lineCap","lineJoin","miterLimit","lineDashOffset","textAlign","textBaseline","direction","letterSpacing","imageSmoothingEnabled","imageSmoothingQuality"];
 const numeric=["globalAlpha","shadowOffsetX","shadowOffsetY","shadowBlur","lineWidth","miterLimit","lineDashOffset"];
 for(const property of properties)Object.defineProperty(context,property,{enumerable:true,get:function(){const result=__canvasCall(s,"get",[],{property:property});return result&&result.handle?__canvasObjects[result.handle]:result;},set:function(value){if(property==="fillStyle"||property==="strokeStyle")value=value&&value.__canvasHandle?{handle:value.__canvasHandle}:String(value);else if(numeric.includes(property))value=+value;else if(property==="imageSmoothingEnabled")value=!!value;else value=String(value);__canvasCall(s,"set",[],{property:property,value:value});}});
 const methods={save:0,restore:0,reset:0,fillRect:4,strokeRect:4,clearRect:4,beginPath:0,closePath:0,moveTo:2,lineTo:2,rect:4,quadraticCurveTo:4,bezierCurveTo:6,arc:5,arcTo:5,ellipse:7,translate:2,scale:2,rotate:1,transform:6,resetTransform:0};
 for(const method of Object.keys(methods))context[method]=function(){if(arguments.length<methods[method])throw new TypeError(method+" has too few arguments");const args=Array.from(arguments,Number);if(method==="arc"&&arguments.length>5)args[5]=!!arguments[5];if(method==="ellipse"&&arguments.length>7)args[7]=!!arguments[7];return __canvasCall(s,method,args);};
 context.fill=function(rule){__canvasCall(s,"fill",[rule===undefined?"nonzero":String(rule)]);};
 context.stroke=function(){__canvasCall(s,"stroke");};
 context.clip=function(rule){__canvasCall(s,"clip",[rule===undefined?"nonzero":String(rule)]);};
 context.isPointInPath=function(x,y,rule){if(arguments.length<2)throw new TypeError("isPointInPath requires two arguments");return __canvasCall(s,"isPointInPath",[+x,+y,rule===undefined?"nonzero":String(rule)]);};
 context.setLineDash=function(sequence){if(arguments.length<1)throw new TypeError("setLineDash requires a sequence");__canvasCall(s,"setLineDash",Array.from(sequence,Number));};
 context.getLineDash=function(){return __canvasCall(s,"getLineDash");};
 context.setTransform=function(){const dictionary=arguments.length<=1;if(!dictionary&&arguments.length<6)throw new TypeError("setTransform requires six numbers or a matrix");__canvasCall(s,"setTransform",dictionary?__canvasMatrix(arguments[0]):Array.from(arguments,Number),{dictionary:dictionary});};
 context.getTransform=function(){const result=__canvasCall(s,"getTransform");result.is2D=true;return result;};
 for(const entry of [["createLinearGradient",4],["createRadialGradient",6],["createConicGradient",3]])context[entry[0]]=function(){if(arguments.length<entry[1])throw new TypeError("Too few gradient arguments");const args=Array.from(arguments,Number);if(args.some(function(value){return !Number.isFinite(value);}))throw new TypeError("Gradient coordinates must be finite");return __canvasPaintObject(s,__canvasCall(s,entry[0],args),false);};
 context.createPattern=function(source,repetition){if(arguments.length<2)throw new TypeError("createPattern requires two arguments");return __canvasPaintObject(s,__canvasCall(s,"createPattern",[],Object.assign(__canvasSource(source),{repetition:repetition===null?"":String(repetition)})),true);};
 context.drawImage=function(source){const args=Array.prototype.slice.call(arguments,1).map(Number);if(![2,4,8].includes(args.length))throw new TypeError("Invalid drawImage arguments");__canvasCall(s,"drawImage",args,__canvasSource(source));};
 context.getImageData=function(x,y,width,height){if(arguments.length<4)throw new TypeError("getImageData requires four arguments");return __canvasImageData(__canvasCall(s,"getImageData",[Math.trunc(+x),Math.trunc(+y),Math.trunc(+width),Math.trunc(+height)]));};
 context.createImageData=function(width,height){if(width&&width.data)return __canvasImageData(__canvasCall(s,"createImageData",[width.width,width.height]));if(arguments.length<2)throw new TypeError("createImageData requires dimensions");return __canvasImageData(__canvasCall(s,"createImageData",[Math.trunc(+width),Math.trunc(+height)]));};
 context.putImageData=function(image){if(!image||!image.data)throw new TypeError("Expected ImageData");const args=Array.prototype.slice.call(arguments,1).map(function(value){return Math.trunc(+value);});if(args.length!==2&&args.length!==6)throw new TypeError("Invalid putImageData arguments");__canvasCall(s,"putImageData",args,{imageData:{width:image.width,height:image.height,data:Array.from(image.data)}});};
 for(const method of ["fillText","strokeText"])context[method]=function(text,x,y,maxWidth){if(arguments.length<3)throw new TypeError("Too few text arguments");const args=[String(text),+x,+y];if(maxWidth!==undefined)args.push(+maxWidth);__canvasCall(s,method,args);};
 context.measureText=function(text){if(arguments.length<1)throw new TypeError("measureText requires text");return __canvasCall(s,"measureText",[String(text)]);};
 canvas.context=context;
 return context;
}
'
}
