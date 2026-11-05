(function(){'use strict';var n,aa=typeof Object.create=="function"?Object.create:function(a){function b(){}
b.prototype=a;return new b},p=typeof Object.defineProperties=="function"?Object.defineProperty:function(a,b,c){if(a==Array.prototype||a==Object.prototype)return a;
a[b]=c.value;return a};
function ba(a){a=["object"==typeof globalThis&&globalThis,a,"object"==typeof window&&window,"object"==typeof self&&self,"object"==typeof global&&global];for(var b=0;b<a.length;++b){var c=a[b];if(c&&c.Math==Math)return c}throw Error("Cannot find global object");}
var q=ba(this);function r(a,b){if(b)a:{var c=q;a=a.split(".");for(var d=0;d<a.length-1;d++){var h=a[d];if(!(h in c))break a;c=c[h]}a=a[a.length-1];d=c[a];b=b(d);b!=d&&b!=null&&p(c,a,{configurable:!0,writable:!0,value:b})}}
var t;if(typeof Object.setPrototypeOf=="function")t=Object.setPrototypeOf;else{var v;a:{var ca={a:!0},da={};try{da.__proto__=ca;v=da.a;break a}catch(a){}v=!1}t=v?function(a,b){a.__proto__=b;if(a.__proto__!==b)throw new TypeError(a+" is not extensible");return a}:null}var ea=t;
function fa(a){var b=0;return function(){return b<a.length?{done:!1,value:a[b++]}:{done:!0}}}
function x(a){var b=typeof Symbol!="undefined"&&Symbol.iterator&&a[Symbol.iterator];if(b)return b.call(a);if(typeof a.length=="number")return{next:fa(a)};throw Error(String(a)+" is not an iterable or ArrayLike");}
function ha(a,b){var c;b&&!b.done&&(c=a["return"])&&c.call(a)}
r("Symbol",function(a){function b(k){if(this instanceof b)throw new TypeError("Symbol is not a constructor");return new c(d+(k||"")+"_"+h++,k)}
function c(k,f){this.h=k;p(this,"description",{configurable:!0,writable:!0,value:f})}
if(a)return a;c.prototype.toString=function(){return this.h};
var d="jscomp_symbol_"+(Math.random()*1E9>>>0)+"_",h=0;return b});
r("Symbol.iterator",function(a){if(a)return a;a=Symbol("Symbol.iterator");p(Array.prototype,a,{configurable:!0,writable:!0,value:function(){return ia(fa(this))}});
return a});
function ia(a){var b=(typeof Iterator!="undefined"&&Iterator.prototype&&!Iterator.prototype.next?Iterator.prototype:null)||Object.prototype,c=aa(b);c.next=a;b[Symbol.iterator]||(c[Symbol.iterator]=function(){return this});
return c}
r("Promise",function(a){function b(f){this.i=0;this.j=void 0;this.h=[];this.A=!1;var e=this.l();try{f(e.resolve,e.reject)}catch(g){e.reject(g)}}
function c(){this.h=null}
function d(f){return f instanceof b?f:new b(function(e){e(f)})}
if(a)return a;c.prototype.i=function(f){if(this.h==null){this.h=[];var e=this;this.j(function(){e.m()})}this.h.push(f)};
var h=q.setTimeout;c.prototype.j=function(f){h(f,0)};
c.prototype.m=function(){for(;this.h&&this.h.length;){var f=this.h;this.h=[];for(var e=0;e<f.length;++e){var g=f[e];f[e]=null;try{g()}catch(l){this.l(l)}}}this.h=null};
c.prototype.l=function(f){this.j(function(){throw f;})};
b.prototype.l=function(){function f(l){return function(m){g||(g=!0,l.call(e,m))}}
var e=this,g=!1;return{resolve:f(this.L),reject:f(this.m)}};
b.prototype.L=function(f){if(f===this)this.m(new TypeError("A Promise cannot resolve to itself"));else if(f instanceof b)this.N(f);else{a:switch(typeof f){case "object":var e=f!=null;break a;case "function":e=!0;break a;default:e=!1}e?this.K(f):this.u(f)}};
b.prototype.K=function(f){var e=void 0;try{e=f.then}catch(g){this.m(g);return}typeof e=="function"?this.O(e,f):this.u(f)};
b.prototype.m=function(f){this.B(2,f)};
b.prototype.u=function(f){this.B(1,f)};
b.prototype.B=function(f,e){if(this.i!=0)throw Error("Cannot settle("+f+", "+e+"): Promise already settled in state"+this.i);this.i=f;this.j=e;this.i===2&&this.M();this.C()};
b.prototype.M=function(){var f=this;h(function(){if(f.J()){var e=q.console;typeof e!=="undefined"&&e.error(f.j)}},1)};
b.prototype.J=function(){if(this.A)return!1;var f=q.CustomEvent,e=q.Event,g=q.dispatchEvent;if(typeof g==="undefined")return!0;typeof f==="function"?f=new f("unhandledrejection",{cancelable:!0}):typeof e==="function"?f=new e("unhandledrejection",{cancelable:!0}):(f=q.document.createEvent("CustomEvent"),f.initCustomEvent("unhandledrejection",!1,!0,f));f.promise=this;f.reason=this.j;return g(f)};
b.prototype.C=function(){if(this.h!=null){for(var f=0;f<this.h.length;++f)k.i(this.h[f]);this.h=null}};
var k=new c;b.prototype.N=function(f){var e=this.l();f.D(e.resolve,e.reject)};
b.prototype.O=function(f,e){var g=this.l();try{f.call(e,g.resolve,g.reject)}catch(l){g.reject(l)}};
b.prototype.then=function(f,e){function g(w,z){return typeof w=="function"?function(P){try{l(w(P))}catch(Q){m(Q)}}:z}
var l,m,u=new b(function(w,z){l=w;m=z});
this.D(g(f,l),g(e,m));return u};
b.prototype.catch=function(f){return this.then(void 0,f)};
b.prototype.D=function(f,e){function g(){switch(l.i){case 1:f(l.j);break;case 2:e(l.j);break;default:throw Error("Unexpected state: "+l.i);}}
var l=this;this.h==null?k.i(g):this.h.push(g);this.A=!0};
b.resolve=d;b.reject=function(f){return new b(function(e,g){g(f)})};
b.race=function(f){return new b(function(e,g){for(var l=x(f),m=l.next();!m.done;m=l.next())d(m.value).D(e,g)})};
b.all=function(f){var e=x(f),g=e.next();return g.done?d([]):new b(function(l,m){function u(P){return function(Q){w[P]=Q;z--;z==0&&l(w)}}
var w=[],z=0;do w.push(void 0),z++,d(g.value).D(u(w.length-1),m),g=e.next();while(!g.done)})};
return b});
function y(a,b){return Object.prototype.hasOwnProperty.call(a,b)}
var ja=typeof Object.assign=="function"?Object.assign:function(a,b){if(a==null)throw new TypeError("No nullish arg");a=Object(a);for(var c=1;c<arguments.length;c++){var d=arguments[c];if(d)for(var h in d)y(d,h)&&(a[h]=d[h])}return a};
r("Object.assign",function(a){return a||ja});
r("Symbol.dispose",function(a){return a?a:Symbol("Symbol.dispose")});
r("WeakMap",function(a){function b(g){this.h=(e+=Math.random()+1).toString();if(g){g=x(g);for(var l;!(l=g.next()).done;)l=l.value,this.set(l[0],l[1])}}
function c(){}
function d(g){var l=typeof g;return l==="object"&&g!==null||l==="function"}
function h(g){if(!y(g,f)){var l=new c;p(g,f,{value:l})}}
function k(g){var l=Object[g];l&&(Object[g]=function(m){if(m instanceof c)return m;Object.isExtensible(m)&&h(m);return l(m)})}
if(function(){if(!a||!Object.seal)return!1;try{var g=Object.seal({}),l=Object.seal({}),m=new a([[g,2],[l,3]]);if(m.get(g)!=2||m.get(l)!=3)return!1;m.delete(g);m.set(l,4);return!m.has(g)&&m.get(l)==4}catch(u){return!1}}())return a;
var f="$jscomp_hidden_"+Math.random();k("freeze");k("preventExtensions");k("seal");var e=0;b.prototype.set=function(g,l){if(!d(g))throw Error("Invalid WeakMap key");h(g);if(!y(g,f))throw Error("WeakMap key fail: "+g);g[f][this.h]=l;return this};
b.prototype.get=function(g){return d(g)&&y(g,f)?g[f][this.h]:void 0};
b.prototype.has=function(g){return d(g)&&y(g,f)&&y(g[f],this.h)};
b.prototype.delete=function(g){return d(g)&&y(g,f)&&y(g[f],this.h)?delete g[f][this.h]:!1};
return b});
r("Map",function(a){function b(){var e={};return e.previous=e.next=e.head=e}
function c(e,g){var l=e[1];return ia(function(){if(l){for(;l.head!=e[1];)l=l.previous;for(;l.next!=l.head;)return l=l.next,{done:!1,value:g(l)};l=null}return{done:!0,value:void 0}})}
function d(e,g){var l=g&&typeof g;l=="object"||l=="function"?k.has(g)?l=k.get(g):(l=""+ ++f,k.set(g,l)):l="p_"+g;var m=e[0][l];if(m&&y(e[0],l))for(e=0;e<m.length;e++){var u=m[e];if(g!==g&&u.key!==u.key||g===u.key)return{id:l,list:m,index:e,entry:u}}return{id:l,list:m,index:-1,entry:void 0}}
function h(e){this[0]={};this[1]=b();this.size=0;if(e){e=x(e);for(var g;!(g=e.next()).done;)g=g.value,this.set(g[0],g[1])}}
if(function(){if(!a||typeof a!="function"||!a.prototype.entries||typeof Object.seal!="function")return!1;try{var e=Object.seal({x:4}),g=new a(x([[e,"s"]]));if(g.get(e)!="s"||g.size!=1||g.get({x:4})||g.set({x:4},"t")!=g||g.size!=2)return!1;var l=g.entries(),m=l.next();if(m.done||m.value[0]!=e||m.value[1]!="s")return!1;m=l.next();return!(m.done||m.value[0].x!=4||m.value[1]!="t"||!l.next().done)}catch(u){return!1}}())return a;
var k=new WeakMap;h.prototype.set=function(e,g){e=e===0?0:e;var l=d(this,e);l.list||(l.list=this[0][l.id]=[]);l.entry?l.entry.value=g:(l.entry={next:this[1],previous:this[1].previous,head:this[1],key:e,value:g},l.list.push(l.entry),this[1].previous.next=l.entry,this[1].previous=l.entry,this.size++);return this};
h.prototype.delete=function(e){e=d(this,e);return e.entry&&e.list?(e.list.splice(e.index,1),e.list.length||delete this[0][e.id],e.entry.previous.next=e.entry.next,e.entry.next.previous=e.entry.previous,e.entry.head=null,this.size--,!0):!1};
h.prototype.clear=function(){this[0]={};this[1]=this[1].previous=b();this.size=0};
h.prototype.has=function(e){return!!d(this,e).entry};
h.prototype.get=function(e){return(e=d(this,e).entry)&&e.value};
h.prototype.entries=function(){return c(this,function(e){return[e.key,e.value]})};
h.prototype.keys=function(){return c(this,function(e){return e.key})};
h.prototype.values=function(){return c(this,function(e){return e.value})};
h.prototype.forEach=function(e,g){for(var l=this.entries(),m;!(m=l.next()).done;)m=m.value,e.call(g,m[1],m[0],this)};
h.prototype[Symbol.iterator]=h.prototype.entries;var f=0;return h});
r("Set",function(a){function b(c){this.h=new Map;if(c){c=x(c);for(var d;!(d=c.next()).done;)this.add(d.value)}this.size=this.h.size}
if(function(){if(!a||typeof a!="function"||!a.prototype.entries||typeof Object.seal!="function")return!1;try{var c=Object.seal({x:4}),d=new a(x([c]));if(!d.has(c)||d.size!=1||d.add(c)!=d||d.size!=1||d.add({x:4})!=d||d.size!=2)return!1;var h=d.entries(),k=h.next();if(k.done||k.value[0]!=c||k.value[1]!=c)return!1;k=h.next();return k.done||k.value[0]==c||k.value[0].x!=4||k.value[1]!=k.value[0]?!1:h.next().done}catch(f){return!1}}())return a;
b.prototype.add=function(c){c=c===0?0:c;this.h.set(c,c);this.size=this.h.size;return this};
b.prototype.delete=function(c){c=this.h.delete(c);this.size=this.h.size;return c};
b.prototype.clear=function(){this.h.clear();this.size=0};
b.prototype.has=function(c){return this.h.has(c)};
b.prototype.entries=function(){return this.h.entries()};
b.prototype.values=function(){return this.h.values()};
b.prototype.keys=b.prototype.values;b.prototype[Symbol.iterator]=b.prototype.values;b.prototype.forEach=function(c,d){var h=this;this.h.forEach(function(k){return c.call(d,k,k,h)})};
return b});
r("Array.from",function(a){return a?a:function(b,c,d){c=c!=null?c:function(e){return e};
var h=[],k=typeof Symbol!="undefined"&&Symbol.iterator&&b[Symbol.iterator];if(typeof k=="function"){b=k.call(b);for(var f=0;!(k=b.next()).done;)h.push(c.call(d,k.value,f++))}else for(k=b.length,f=0;f<k;f++)h.push(c.call(d,b[f],f));return h}});
r("Array.prototype.find",function(a){return a?a:function(b,c){a:{var d=this;d instanceof String&&(d=String(d));for(var h=d.length,k=0;k<h;k++){var f=d[k];if(b.call(c,f,k,d)){b=f;break a}}b=void 0}return b}});/*

 Copyright The Closure Library Authors.
 SPDX-License-Identifier: Apache-2.0
*/
var A=this||self;function B(a){var b=typeof a;return b=="object"&&a!=null||b=="function"}
function ka(a){return Object.prototype.hasOwnProperty.call(a,C)&&a[C]||(a[C]=++la)}
var C="closure_uid_"+(Math.random()*1E9>>>0),la=0;function D(a,b){a=a.split(".");for(var c=A,d;a.length&&(d=a.shift());)a.length||b===void 0?c[d]&&c[d]!==Object.prototype[d]?c=c[d]:c=c[d]={}:c[d]=b}
function ma(a,b){function c(){}
c.prototype=b.prototype;a.I=b.prototype;a.prototype=new c;a.prototype.constructor=a;a.X=function(d,h,k){for(var f=Array(arguments.length-2),e=2;e<arguments.length;e++)f[e-2]=arguments[e];return b.prototype[h].apply(d,f)}}
;var na=Array.prototype.indexOf?function(a,b){return Array.prototype.indexOf.call(a,b,void 0)}:function(a,b){if(typeof a==="string")return typeof b!=="string"||b.length!=1?-1:a.indexOf(b,0);
for(var c=0;c<a.length;c++)if(c in a&&a[c]===b)return c;return-1},E=Array.prototype.forEach?function(a,b,c){Array.prototype.forEach.call(a,b,c)}:function(a,b,c){for(var d=a.length,h=typeof a==="string"?a.split(""):a,k=0;k<d;k++)k in h&&b.call(c,h[k],k,a)};
function oa(a,b){b=na(a,b);b>=0&&Array.prototype.splice.call(a,b,1)}
function pa(a){return Array.prototype.concat.apply([],arguments)}
function qa(a){var b=a.length;if(b>0){for(var c=Array(b),d=0;d<b;d++)c[d]=a[d];return c}return[]}
;function ra(a,b){this.j=a;this.l=b;this.i=0;this.h=null}
ra.prototype.get=function(){if(this.i>0){this.i--;var a=this.h;this.h=a.next;a.next=null}else a=this.j();return a};function sa(a){A.setTimeout(function(){throw a;},0)}
;function F(){this.i=this.h=null}
F.prototype.add=function(a,b){var c=ta.get();c.set(a,b);this.i?this.i.next=c:this.h=c;this.i=c};
F.prototype.remove=function(){var a=null;this.h&&(a=this.h,this.h=this.h.next,this.h||(this.i=null),a.next=null);return a};
var ta=new ra(function(){return new G},function(a){return a.reset()});
function G(){this.next=this.scope=this.h=null}
G.prototype.set=function(a,b){this.h=a;this.scope=b;this.next=null};
G.prototype.reset=function(){this.next=this.scope=this.h=null};var H,I=!1,ua=new F;function va(a){H||wa();I||(H(),I=!0);ua.add(a,void 0)}
function wa(){var a=Promise.resolve(void 0);H=function(){a.then(xa)}}
function xa(){for(var a;a=ua.remove();){try{a.h.call(a.scope)}catch(c){sa(c)}var b=ta;b.l(a);b.i<100&&(b.i++,a.next=b.h,b.h=a)}I=!1}
;function J(){this.j=this.j;this.l=this.l}
J.prototype.j=!1;J.prototype.dispose=function(){this.j||(this.j=!0,this.F())};
J.prototype[Symbol.dispose]=function(){this.dispose()};
J.prototype.addOnDisposeCallback=function(a,b){this.j?b!==void 0?a.call(b):a():(this.l||(this.l=[]),b&&(a=a.bind(b)),this.l.push(a))};
J.prototype.F=function(){if(this.l)for(;this.l.length;)this.l.shift()()};function ya(a){var b={},c;for(c in a)b[c]=a[c];return b}
;var za=/&/g,Aa=/</g,Ba=/>/g,Ca=/"/g,Da=/'/g,Ea=/\x00/g,Fa=/[\x00&<>"']/;/*

 Copyright Google LLC
 SPDX-License-Identifier: Apache-2.0
*/
function K(a){this.h=a}
K.prototype.toString=function(){return this.h};
var Ga=new K("about:invalid#zClosurez");function L(a){this.R=a}
function M(a){return new L(function(b){return b.substr(0,a.length+1).toLowerCase()===a+":"})}
var Ha=[M("data"),M("http"),M("https"),M("mailto"),M("ftp"),new L(function(a){return/^[^:]*([/?#]|$)/.test(a)})],Ia=/^\s*(?!javascript:)(?:[\w+.-]+:|[^:/?#]*(?:[/?#]|$))/i;var Ja={W:0,U:1,V:2,0:"FORMATTED_HTML_CONTENT",1:"EMBEDDED_INTERNAL_CONTENT",2:"EMBEDDED_TRUSTED_EXTERNAL_CONTENT"};function N(a,b){b=Error.call(this,a+" cannot be used with intent "+Ja[b]);this.message=b.message;"stack"in b&&(this.stack=b.stack);this.type=a;this.name="TypeCannotBeUsedWithIframeIntentError"}
var O=Error;N.prototype=aa(O.prototype);N.prototype.constructor=N;if(ea)ea(N,O);else for(var R in O)if(R!="prototype")if(Object.defineProperties){var Ka=Object.getOwnPropertyDescriptor(O,R);Ka&&Object.defineProperty(N,R,Ka)}else N[R]=O[R];N.I=O.prototype;function La(a){Fa.test(a)&&(a.indexOf("&")!=-1&&(a=a.replace(za,"&amp;")),a.indexOf("<")!=-1&&(a=a.replace(Aa,"&lt;")),a.indexOf(">")!=-1&&(a=a.replace(Ba,"&gt;")),a.indexOf('"')!=-1&&(a=a.replace(Ca,"&quot;")),a.indexOf("'")!=-1&&(a=a.replace(Da,"&#39;")),a.indexOf("\x00")!=-1&&(a=a.replace(Ea,"&#0;")));return a}
;function S(a){J.call(this);this.A=1;this.m=[];this.u=0;this.h=[];this.i={};this.B=!!a}
ma(S,J);n=S.prototype;n.subscribe=function(a,b,c){var d=this.i[a];d||(d=this.i[a]=[]);var h=this.A;this.h[h]=a;this.h[h+1]=b;this.h[h+2]=c;this.A=h+3;d.push(h);return h};
n.unsubscribe=function(a,b,c){if(a=this.i[a]){var d=this.h;if(a=a.find(function(h){return d[h+1]==b&&d[h+2]==c}))return this.G(a)}return!1};
n.G=function(a){var b=this.h[a];if(b){var c=this.i[b];this.u!=0?(this.m.push(a),this.h[a+1]=function(){}):(c&&oa(c,a),delete this.h[a],delete this.h[a+1],delete this.h[a+2])}return!!b};
n.H=function(a,b){var c=this.i[a];if(c){var d=Array(arguments.length-1),h=arguments.length,k;for(k=1;k<h;k++)d[k-1]=arguments[k];if(this.B)for(k=0;k<c.length;k++)h=c[k],Ma(this.h[h+1],this.h[h+2],d);else{this.u++;try{for(k=0,h=c.length;k<h&&!this.j;k++){var f=c[k];this.h[f+1].apply(this.h[f+2],d)}}finally{if(this.u--,this.m.length>0&&this.u==0)for(;c=this.m.pop();)this.G(c)}}return k!=0}return!1};
function Ma(a,b,c){va(function(){a.apply(b,c)})}
n.clear=function(a){if(a){var b=this.i[a];b&&(b.forEach(this.G,this),delete this.i[a])}else this.h.length=0,this.i={}};
n.F=function(){S.I.F.call(this);this.clear();this.m.length=0};var Na=RegExp("^(?:([^:/?#.]+):)?(?://(?:([^\\\\/?#]*)@)?([^\\\\/?#]*?)(?::([0-9]+))?(?=[\\\\/?#]|$))?([^?#]+)?(?:\\?([^#]*))?(?:#([\\s\\S]*))?$");function Oa(a){var b=a.match(Na);a=b[1];var c=b[2],d=b[3];b=b[4];var h="";a&&(h+=a+":");d&&(h+="//",c&&(h+=c+"@"),h+=d,b&&(h+=":"+b));return h}
function Pa(a,b,c){if(Array.isArray(b))for(var d=0;d<b.length;d++)Pa(a,String(b[d]),c);else b!=null&&c.push(a+(b===""?"":"="+encodeURIComponent(String(b))))}
var Qa=/#|$/;var T={},Ra=[],U=new S,V={};function Sa(){var a=x(Ra),b=a.next();try{for(;!b.done;b=a.next()){var c=b.value;c()}}finally{ha(a,b)}}
function W(a,b){return a.tagName.toLowerCase().substring(0,3)==="yt:"?a.getAttribute(b):a.dataset?a.dataset[b]:a.getAttribute("data-"+b)}
function Ta(a){U.H.apply(U,arguments)}
;function Ua(a){return(a.search("cue")===0||a.search("load")===0)&&a!=="loadModule"}
function Va(a){return a.search("get")===0||a.search("is")===0}
;var Wa=window;
function X(a,b){this.v={};this.playerInfo={};this.videoTitle="";this.l=this.h=null;this.i=0;this.u=!1;this.m=[];this.j=null;this.C={};this.options=null;this.B=this.S.bind(this);if(!a)throw Error("YouTube player element ID required.");this.id=ka(this);b=Object.assign({title:"video player",videoId:"",width:640,height:360},b||{});var c=document;if(a=typeof a==="string"?c.getElementById(a):a){c=a.tagName.toLowerCase()==="iframe";b.host||(b.host=c?Oa(a.src):"https://www.youtube.com");this.options=b||{};
b=[this.options,window.YTConfig||{}];for(var d=0;d<b.length;d++)b[d].host&&(b[d].host=b[d].host.toString().replace("http://","https://"));if(!c){b=document.createElement("iframe");c=a.attributes;d=0;for(var h=c.length;d<h;d++){var k=c[d].value;k!=null&&k!==""&&k!=="null"&&b.setAttribute(c[d].name,k)}b.setAttribute("frameBorder","0");b.setAttribute("allowfullscreen","");b.setAttribute("allow","accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share");b.setAttribute("referrerPolicy",
"strict-origin-when-cross-origin");b.setAttribute("title","YouTube "+Y(this,"title"));(c=Y(this,"width"))&&b.setAttribute("width",c.toString());(c=Y(this,"height"))&&b.setAttribute("height",c.toString());this.l=a;(c=a.parentNode)&&c.replaceChild(b,a);a=Xa(this,b);c=""+Y(this,"host")+Ya(this)+"?";d=[];for(var f in a)Pa(f,a[f],d);f=c+d.join("&");if(Wa.yt_embedsEnableIframeSrcWithIntent){var e=e===void 0?Ha:e;a:if(e=e===void 0?Ha:e,f instanceof K)e=f;else{for(a=0;a<e.length;++a)if(c=e[a],c instanceof
L&&c.R(f)){e=new K(f);break a}e=void 0}e=e||Ga;b.removeAttribute("srcdoc");f="allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-storage-access-by-user-activation".split(" ");b.setAttribute("sandbox","");for(a=0;a<f.length;a++)b.sandbox.supports&&!b.sandbox.supports(f[a])||b.sandbox.add(f[a]);if(e instanceof K)if(e instanceof K)e=e.h;else throw Error("");else e=Ia.test(e)?e:void 0;e!==void 0&&(b.src=e);b.sandbox.add("allow-presentation","allow-top-navigation")}else b.src=
f;a=b}this.h=a;this.h.id||(this.h.id="widget"+ka(this.h));T[this.h.id]=this;if(window.postMessage){this.j=new S;Za(this);b=Y(this,"events");for(var g in b)b.hasOwnProperty(g)&&this.addEventListener(g,b[g]);for(var l in V)V.hasOwnProperty(l)&&$a(this,l)}}}
n=X.prototype;n.setSize=function(a,b){this.h.width=a.toString();this.h.height=b.toString();return this};
n.getIframe=function(){return this.h};
n.addEventListener=function(a,b){var c=b;typeof b==="string"&&(c=function(){window[b].apply(window,arguments)});
if(!c)return this;this.j.subscribe(a,c);ab(this,a);return this};
function $a(a,b){b=b.split(".");if(b.length===2){var c=b[1];"player"===b[0]&&ab(a,c)}}
n.destroy=function(){this.h&&this.h.id&&(T[this.h.id]=null);var a=this.j;a&&typeof a.dispose=="function"&&a.dispose();if(this.l){a=this.l;var b=this.h,c=b.parentNode;c&&c.replaceChild(a,b)}else(a=this.h)&&a.parentNode&&a.parentNode.removeChild(a);Z&&(Z[this.id]=null);this.options=null;this.h&&this.A&&this.h.removeEventListener("load",this.A);this.l=this.h=null};
function bb(a,b,c){c=c||[];c=Array.prototype.slice.call(c);b={event:"command",func:b,args:c};a.u?a.sendMessage(b):a.m.push(b)}
n.S=function(){cb(this)||clearInterval(this.i)};
function cb(a){if(!a.h||!a.h.contentWindow)return!1;a.sendMessage({event:"listening"});return!0}
function Za(a){db(a,a.id,String(Y(a,"host")));var b=Number(Wa.yt_embedsWidgetPollIntervalMs)||250;a.i=setInterval(a.B,b);a.h&&(a.A=function(){clearInterval(a.i);a.i=setInterval(a.B,b)},a.h.addEventListener("load",a.A))}
function eb(a){var b=a.getBoundingClientRect();a=Math.max(0,Math.min(b.bottom,window.innerHeight||document.documentElement.clientHeight)-Math.max(b.top,0))*Math.max(0,Math.min(b.right,window.innerWidth||document.documentElement.clientWidth)-Math.max(b.left,0));a=(b=b.height*b.width)?a/b:0;return document.visibilityState==="hidden"||a<.5?1:a<.75?2:a<.85?3:a<.95?4:a<1?5:6}
function ab(a,b){a.C[b]||(a.C[b]=!0,bb(a,"addEventListener",[b]))}
n.sendMessage=function(a){a.id=this.id;a.channel="widget";a=JSON.stringify(a);var b=Oa(this.h.src||"").replace("http:","https:");if(this.h.contentWindow)try{this.h.contentWindow.postMessage(a,b)}catch(c){if(c.name&&c.name==="SyntaxError")c.message&&c.message.indexOf("target origin ''")>0||console&&console.warn&&console.warn(c);else throw c;}else console&&console.warn&&console.warn("The YouTube player is not attached to the DOM. API calls should be made after the onReady event. See more: https://developers.google.com/youtube/iframe_api_reference#Events")};
function Ya(a){if((a=String(Y(a,"videoId")))&&(a.length!==11||!a.match(/^[a-zA-Z0-9\-_]+$/)))throw Error("Invalid video id");return"/embed/"+a}
function Xa(a,b){var c=Y(a,"playerVars");c?c=ya(c):c={};window!==window.top&&document.referrer&&(c.widget_referrer=document.referrer.substring(0,256));var d=Y(a,"embedConfig");if(d){if(B(d))try{d=JSON.stringify(d)}catch(h){console.error("Invalid embed config JSON",h)}c.embed_config=d}c.enablejsapi=window.postMessage?1:0;window.location.host&&(c.origin=window.location.protocol+"//"+window.location.host);c.widgetid=a.id;window.location.href&&E(["debugjs","debugcss"],function(h){var k=window.location.href;
var f=k.search(Qa);b:{var e=0;for(var g=h.length;(e=k.indexOf(h,e))>=0&&e<f;){var l=k.charCodeAt(e-1);if(l==38||l==63)if(l=k.charCodeAt(e+g),!l||l==61||l==38||l==35)break b;e+=g+1}e=-1}if(e<0)k=null;else{g=k.indexOf("&",e);if(g<0||g>f)g=f;e+=h.length+1;k=decodeURIComponent(k.slice(e,g!==-1?g:0).replace(/\+/g," "))}k!==null&&(c[h]=k)});
window.location.href&&(c.forigin=window.location.href);a=window.location.ancestorOrigins;c.aoriginsup=a===void 0?0:1;a&&a.length>0&&(c.aorigins=Array.from(a).join(","));window.document.referrer&&(c.gporigin=window.document.referrer);b&&(c.vf=eb(b));return c}
function fb(a,b){if(B(b)){for(var c in b)b.hasOwnProperty(c)&&(a.playerInfo[c]=b[c]);a.playerInfo.hasOwnProperty("videoData")&&(b=a.playerInfo.videoData,b.hasOwnProperty("title")&&b.title?(b=b.title,b!==a.videoTitle&&(a.videoTitle=b,a.h.setAttribute("title",b))):(a.videoTitle="",a.h.setAttribute("title","YouTube "+Y(a,"title"))))}}
function gb(a,b){b=x(b);var c=b.next();try{for(var d={};!c.done;d={o:void 0},c=b.next())d.o=c.value,a[d.o]||(d.o==="getCurrentTime"?a[d.o]=function(){var h=this.playerInfo.currentTime;if(this.playerInfo.playerState===1){var k=(Date.now()/1E3-this.playerInfo.currentTimeLastUpdated_)*this.playerInfo.playbackRate;k>0&&(h+=Math.min(k,1))}return h}:Ua(d.o)?a[d.o]=function(h){return function(){this.playerInfo={};
this.v={};bb(this,h.o,arguments);return this}}(d):Va(d.o)?a[d.o]=function(h){return function(){var k=h.o,f=0;
k.search("get")===0?f=3:k.search("is")===0&&(f=2);return this.playerInfo[k.charAt(f).toLowerCase()+k.substring(f+1)]}}(d):a[d.o]=function(h){return function(){bb(this,h.o,arguments);
return this}}(d))}finally{ha(b,c)}}
n.getVideoEmbedCode=function(){var a=""+Y(this,"host")+Ya(this),b=Number(Y(this,"width")),c=Number(Y(this,"height"));if(isNaN(b)||isNaN(c))throw Error("Invalid width or height property");b=Math.floor(b);c=Math.floor(c);var d=this.videoTitle;a=La(a);d=La(d!=null?d:"YouTube video player");return'<iframe width="'+b+'" height="'+c+'" src="'+a+'" title="'+(d+'" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>')};
n.getOptions=function(a){return this.v.namespaces?a?this.v[a]?this.v[a].options||[]:[]:this.v.namespaces||[]:[]};
n.getOption=function(a,b){if(this.v.namespaces&&a&&b&&this.v[a])return this.v[a][b]};
function Y(a,b){a=[a.options,window.YTConfig||{}];for(var c=0;c<a.length;c++){var d=a[c][b];if(d!==void 0)return d}return null}
var Z=null,hb=null;function ib(a){if(a.tagName.toLowerCase()!=="iframe"){var b=W(a,"videoid");b&&(b={videoId:b,width:W(a,"width"),height:W(a,"height")},new X(a,b))}}
function db(a,b,c){Z||(Z={},hb=new Set,jb.addEventListener("message",function(d){a:if(hb.has(d.origin)){try{var h=JSON.parse(d.data)}catch(e){break a}var k=Z[h.id];if(k&&d.origin===k.P)switch(d=k.T,d.u=!0,d.u&&(E(d.m,d.sendMessage,d),d.m.length=0),k=h.event,h=h.info,k){case "apiInfoDelivery":if(B(h))for(var f in h)h.hasOwnProperty(f)&&(d.v[f]=h[f]);break;case "infoDelivery":fb(d,h);break;case "initialDelivery":B(h)&&(clearInterval(d.i),d.playerInfo={},d.v={},gb(d,h.apiInterface),fb(d,h));break;case "alreadyInitialized":clearInterval(d.i);
break;case "readyToListen":cb(d);break;default:d.j.j||(f={target:d,data:h},d.j.H(k,f),Ta("player."+k,f))}}}));
Z[b]={T:a,P:c};hb.add(c)}
var jb=window;D("YT.PlayerState.UNSTARTED",-1);D("YT.PlayerState.ENDED",0);D("YT.PlayerState.PLAYING",1);D("YT.PlayerState.PAUSED",2);D("YT.PlayerState.BUFFERING",3);D("YT.PlayerState.CUED",5);D("YT.get",function(a){return T[a]});
D("YT.scan",Sa);D("YT.subscribe",function(a,b,c){U.subscribe(a,b,c);V[a]=!0;for(var d in T)T.hasOwnProperty(d)&&$a(T[d],a)});
D("YT.unsubscribe",function(a,b,c){U.unsubscribe(a,b,c)});
D("YT.Player",X);X.prototype.destroy=X.prototype.destroy;X.prototype.setSize=X.prototype.setSize;X.prototype.getIframe=X.prototype.getIframe;X.prototype.addEventListener=X.prototype.addEventListener;X.prototype.getVideoEmbedCode=X.prototype.getVideoEmbedCode;X.prototype.getOptions=X.prototype.getOptions;X.prototype.getOption=X.prototype.getOption;Ra.push(function(a){var b=a;b||(b=document);a=qa(b.getElementsByTagName("yt:player"));b=qa((b||document).querySelectorAll(".yt-player"));E(pa(a,b),ib)});
typeof YTConfig!=="undefined"&&YTConfig.parsetags&&YTConfig.parsetags!=="onload"||Sa();var kb=A.onYTReady;kb&&kb();var lb=A.onYouTubeIframeAPIReady;lb&&lb();var mb=A.onYouTubePlayerAPIReady;mb&&mb();}).call(this);
