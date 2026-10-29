(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,222009,e=>{"use strict";var t=e.i(760814);e.s(["applyZIndex",0,(e,a=!0,n=!1)=>t.css`
  ${({theme:r})=>t.css`
    z-index: ${r.zIndex[e]} ${n?"!important":""};

    ${a&&t.css`
      * {
        z-index: ${r.zIndex[e]} ${n?"!important":""};
      }
    `};
  `}
`])},179286,e=>{"use strict";var t=e.i(391398),a=e.i(191788),n=e.i(876278),r=e.i(450228),i=e.i(120012);e.s(["default",0,({model:e,isFullHeight:s,testId:o,isPlaceholder:l,cardType:u,isInverse:c,isDefaultAspectRatio:d=!0})=>{let{src:p,altText:m=""}=e?.blocks||{},[h,g]=(0,a.useState)(l?n.INDEX_CARD_IMAGE_FALLBACK:p);return(0,a.useEffect)(()=>{l||g(p)},[p,l]),(0,t.jsx)(i.ImageCardStyled,{"data-testid":o,$isFullHeight:!!s,children:(0,t.jsx)(r.default,{imageUrlTemplate:h,alt:m,cardType:u,isFullHeight:s,isInverse:c,isDefaultAspectRatio:d})})}])},303854,699213,623886,736641,871944,67708,799306,421510,913122,e=>{"use strict";function t(e){return(t="function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?function(e){return typeof e}:function(e){return e&&"function"==typeof Symbol&&e.constructor===Symbol&&e!==Symbol.prototype?"symbol":typeof e})(e)}function a(e,t){if(t.length<e)throw TypeError(e+" argument"+(e>1?"s":"")+" required, but only "+t.length+" present")}function n(e){a(1,arguments);var n=Object.prototype.toString.call(e);return e instanceof Date||"object"===t(e)&&"[object Date]"===n?new Date(e.getTime()):"number"==typeof e||"[object Number]"===n?new Date(e):(("string"==typeof e||"[object String]"===n)&&"u">typeof console&&(console.warn("Starting with v2.0.0-beta.1 date-fns doesn't accept strings as date arguments. Please use `parseISO` to parse strings. See: https://github.com/date-fns/date-fns/blob/master/docs/upgradeGuide.md#string-arguments"),console.warn(Error().stack)),new Date(NaN))}function r(e){var t=new Date(Date.UTC(e.getFullYear(),e.getMonth(),e.getDate(),e.getHours(),e.getMinutes(),e.getSeconds(),e.getMilliseconds()));return t.setUTCFullYear(e.getFullYear()),e.getTime()-t.getTime()}function i(e){a(1,arguments);var t=n(e);return t.setHours(0,0,0,0),t}function s(e,t){var a=e.getFullYear()-t.getFullYear()||e.getMonth()-t.getMonth()||e.getDate()-t.getDate()||e.getHours()-t.getHours()||e.getMinutes()-t.getMinutes()||e.getSeconds()-t.getSeconds()||e.getMilliseconds()-t.getMilliseconds();return a<0?-1:a>0?1:a}e.s(["default",0,a],699213),e.s(["default",0,n],623886),e.s(["default",0,r],736641);var o,l={};function u(){return l}function c(e,t){a(2,arguments);var r=n(e),i=n(t),s=r.getTime()-i.getTime();return s<0?-1:s>0?1:s}function d(e,t){if(null==e)throw TypeError("assign requires that input parameter not be null or undefined");for(var a in t)Object.prototype.hasOwnProperty.call(t,a)&&(e[a]=t[a]);return e}e.s(["getDefaultOptions",0,u],871944);var p={lessThanXSeconds:{one:"less than a second",other:"less than {{count}} seconds"},xSeconds:{one:"1 second",other:"{{count}} seconds"},halfAMinute:"half a minute",lessThanXMinutes:{one:"less than a minute",other:"less than {{count}} minutes"},xMinutes:{one:"1 minute",other:"{{count}} minutes"},aboutXHours:{one:"about 1 hour",other:"about {{count}} hours"},xHours:{one:"1 hour",other:"{{count}} hours"},xDays:{one:"1 day",other:"{{count}} days"},aboutXWeeks:{one:"about 1 week",other:"about {{count}} weeks"},xWeeks:{one:"1 week",other:"{{count}} weeks"},aboutXMonths:{one:"about 1 month",other:"about {{count}} months"},xMonths:{one:"1 month",other:"{{count}} months"},aboutXYears:{one:"about 1 year",other:"about {{count}} years"},xYears:{one:"1 year",other:"{{count}} years"},overXYears:{one:"over 1 year",other:"over {{count}} years"},almostXYears:{one:"almost 1 year",other:"almost {{count}} years"}};function m(e){return function(){var t=arguments.length>0&&void 0!==arguments[0]?arguments[0]:{},a=t.width?String(t.width):e.defaultWidth;return e.formats[a]||e.formats[e.defaultWidth]}}var h={date:m({formats:{full:"EEEE, MMMM do, y",long:"MMMM do, y",medium:"MMM d, y",short:"MM/dd/yyyy"},defaultWidth:"full"}),time:m({formats:{full:"h:mm:ss a zzzz",long:"h:mm:ss a z",medium:"h:mm:ss a",short:"h:mm a"},defaultWidth:"full"}),dateTime:m({formats:{full:"{{date}} 'at' {{time}}",long:"{{date}} 'at' {{time}}",medium:"{{date}}, {{time}}",short:"{{date}}, {{time}}"},defaultWidth:"full"})},g={lastWeek:"'last' eeee 'at' p",yesterday:"'yesterday at' p",today:"'today at' p",tomorrow:"'tomorrow at' p",nextWeek:"eeee 'at' p",other:"P"};function f(e){return function(t,a){var n;if("formatting"===(null!=a&&a.context?String(a.context):"standalone")&&e.formattingValues){var r=e.defaultFormattingWidth||e.defaultWidth,i=null!=a&&a.width?String(a.width):r;n=e.formattingValues[i]||e.formattingValues[r]}else{var s=e.defaultWidth,o=null!=a&&a.width?String(a.width):e.defaultWidth;n=e.values[o]||e.values[s]}return n[e.argumentCallback?e.argumentCallback(t):t]}}function v(e){return function(t){var a,n=arguments.length>1&&void 0!==arguments[1]?arguments[1]:{},r=n.width,i=r&&e.matchPatterns[r]||e.matchPatterns[e.defaultMatchWidth],s=t.match(i);if(!s)return null;var o=s[0],l=r&&e.parsePatterns[r]||e.parsePatterns[e.defaultParseWidth],u=Array.isArray(l)?function(e,t){for(var a=0;a<e.length;a++)if(t(e[a]))return a}(l,function(e){return e.test(o)}):function(e,t){for(var a in e)if(e.hasOwnProperty(a)&&t(e[a]))return a}(l,function(e){return e.test(o)});return a=e.valueCallback?e.valueCallback(u):u,{value:a=n.valueCallback?n.valueCallback(a):a,rest:t.slice(o.length)}}}let y={code:"en-US",formatDistance:function(e,t,a){var n,r=p[e];if(n="string"==typeof r?r:1===t?r.one:r.other.replace("{{count}}",t.toString()),null!=a&&a.addSuffix)if(a.comparison&&a.comparison>0)return"in "+n;else return n+" ago";return n},formatLong:h,formatRelative:function(e,t,a,n){return g[e]},localize:{ordinalNumber:function(e,t){var a=Number(e),n=a%100;if(n>20||n<10)switch(n%10){case 1:return a+"st";case 2:return a+"nd";case 3:return a+"rd"}return a+"th"},era:f({values:{narrow:["B","A"],abbreviated:["BC","AD"],wide:["Before Christ","Anno Domini"]},defaultWidth:"wide"}),quarter:f({values:{narrow:["1","2","3","4"],abbreviated:["Q1","Q2","Q3","Q4"],wide:["1st quarter","2nd quarter","3rd quarter","4th quarter"]},defaultWidth:"wide",argumentCallback:function(e){return e-1}}),month:f({values:{narrow:["J","F","M","A","M","J","J","A","S","O","N","D"],abbreviated:["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],wide:["January","February","March","April","May","June","July","August","September","October","November","December"]},defaultWidth:"wide"}),day:f({values:{narrow:["S","M","T","W","T","F","S"],short:["Su","Mo","Tu","We","Th","Fr","Sa"],abbreviated:["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],wide:["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]},defaultWidth:"wide"}),dayPeriod:f({values:{narrow:{am:"a",pm:"p",midnight:"mi",noon:"n",morning:"morning",afternoon:"afternoon",evening:"evening",night:"night"},abbreviated:{am:"AM",pm:"PM",midnight:"midnight",noon:"noon",morning:"morning",afternoon:"afternoon",evening:"evening",night:"night"},wide:{am:"a.m.",pm:"p.m.",midnight:"midnight",noon:"noon",morning:"morning",afternoon:"afternoon",evening:"evening",night:"night"}},defaultWidth:"wide",formattingValues:{narrow:{am:"a",pm:"p",midnight:"mi",noon:"n",morning:"in the morning",afternoon:"in the afternoon",evening:"in the evening",night:"at night"},abbreviated:{am:"AM",pm:"PM",midnight:"midnight",noon:"noon",morning:"in the morning",afternoon:"in the afternoon",evening:"in the evening",night:"at night"},wide:{am:"a.m.",pm:"p.m.",midnight:"midnight",noon:"noon",morning:"in the morning",afternoon:"in the afternoon",evening:"in the evening",night:"at night"}},defaultFormattingWidth:"wide"})},match:{ordinalNumber:(o={matchPattern:/^(\d+)(th|st|nd|rd)?/i,parsePattern:/\d+/i,valueCallback:function(e){return parseInt(e,10)}},function(e){var t=arguments.length>1&&void 0!==arguments[1]?arguments[1]:{},a=e.match(o.matchPattern);if(!a)return null;var n=a[0],r=e.match(o.parsePattern);if(!r)return null;var i=o.valueCallback?o.valueCallback(r[0]):r[0];return{value:i=t.valueCallback?t.valueCallback(i):i,rest:e.slice(n.length)}}),era:v({matchPatterns:{narrow:/^(b|a)/i,abbreviated:/^(b\.?\s?c\.?|b\.?\s?c\.?\s?e\.?|a\.?\s?d\.?|c\.?\s?e\.?)/i,wide:/^(before christ|before common era|anno domini|common era)/i},defaultMatchWidth:"wide",parsePatterns:{any:[/^b/i,/^(a|c)/i]},defaultParseWidth:"any"}),quarter:v({matchPatterns:{narrow:/^[1234]/i,abbreviated:/^q[1234]/i,wide:/^[1234](th|st|nd|rd)? quarter/i},defaultMatchWidth:"wide",parsePatterns:{any:[/1/i,/2/i,/3/i,/4/i]},defaultParseWidth:"any",valueCallback:function(e){return e+1}}),month:v({matchPatterns:{narrow:/^[jfmasond]/i,abbreviated:/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i,wide:/^(january|february|march|april|may|june|july|august|september|october|november|december)/i},defaultMatchWidth:"wide",parsePatterns:{narrow:[/^j/i,/^f/i,/^m/i,/^a/i,/^m/i,/^j/i,/^j/i,/^a/i,/^s/i,/^o/i,/^n/i,/^d/i],any:[/^ja/i,/^f/i,/^mar/i,/^ap/i,/^may/i,/^jun/i,/^jul/i,/^au/i,/^s/i,/^o/i,/^n/i,/^d/i]},defaultParseWidth:"any"}),day:v({matchPatterns:{narrow:/^[smtwf]/i,short:/^(su|mo|tu|we|th|fr|sa)/i,abbreviated:/^(sun|mon|tue|wed|thu|fri|sat)/i,wide:/^(sunday|monday|tuesday|wednesday|thursday|friday|saturday)/i},defaultMatchWidth:"wide",parsePatterns:{narrow:[/^s/i,/^m/i,/^t/i,/^w/i,/^t/i,/^f/i,/^s/i],any:[/^su/i,/^m/i,/^tu/i,/^w/i,/^th/i,/^f/i,/^sa/i]},defaultParseWidth:"any"}),dayPeriod:v({matchPatterns:{narrow:/^(a|p|mi|n|(in the|at) (morning|afternoon|evening|night))/i,any:/^([ap]\.?\s?m\.?|midnight|noon|(in the|at) (morning|afternoon|evening|night))/i},defaultMatchWidth:"any",parsePatterns:{any:{am:/^a/i,pm:/^p/i,midnight:/^mi/i,noon:/^no/i,morning:/morning/i,afternoon:/afternoon/i,evening:/evening/i,night:/night/i}},defaultParseWidth:"any"})},options:{weekStartsOn:0,firstWeekContainsDate:1}};e.s(["default",0,y],67708);function b(e){if(null===e||!0===e||!1===e)return NaN;var t=Number(e);return isNaN(t)?t:t<0?Math.ceil(t):Math.floor(t)}function k(e,t){a(2,arguments);var r=n(e),i=b(t);return isNaN(i)?new Date(NaN):(i&&r.setDate(r.getDate()+i),r)}function S(e,r){if(a(2,arguments),!r||"object"!==t(r))return new Date(NaN);var i=r.years?b(r.years):0,s=r.months?b(r.months):0,o=r.weeks?b(r.weeks):0,l=r.days?b(r.days):0,u=r.hours?b(r.hours):0,c=r.minutes?b(r.minutes):0,d=r.seconds?b(r.seconds):0,p=n(e),m=s||i?function(e,t){a(2,arguments);var r=n(e),i=b(t);if(isNaN(i))return new Date(NaN);if(!i)return r;var s=r.getDate(),o=new Date(r.getTime());return(o.setMonth(r.getMonth()+i+1,0),s>=o.getDate())?o:(r.setFullYear(o.getFullYear(),o.getMonth(),s),r)}(p,s+12*i):p;return new Date((l||o?k(m,l+7*o):m).getTime()+1e3*(d+60*(c+60*u)))}function w(e,t){return a(2,arguments),n(e).getTime()-n(t).getTime()}e.s(["default",0,b],799306);var x={ceil:Math.ceil,round:Math.round,floor:Math.floor,trunc:function(e){return e<0?Math.ceil(e):Math.floor(e)}};function $(e){return e?x[e]:x.trunc}function j(e,t){a(2,arguments);var r=n(e),i=n(t);return r.getTime()>i.getTime()}function P(e){return a(1,arguments),(!!function(e){return a(1,arguments),e instanceof Date||"object"===t(e)&&"[object Date]"===Object.prototype.toString.call(e)}(e)||"number"==typeof e)&&!isNaN(Number(n(e)))}function C(e,t){return a(2,arguments),new Date(n(e).getTime()+b(t))}e.s(["default",0,P],421510),e.s(["default",0,C],913122);var _=["years","months","weeks","days","hours","minutes","seconds"];e.s(["formatDate",0,e=>{let t=10===Math.abs(e).toString().length?1e3*e:e;return P(t)?new Date(t).toLocaleDateString("en-GB",{day:"numeric",month:"short",year:"numeric",timeZone:"UTC"}):""},"formatDuration",0,e=>(function(e,t){if(arguments.length<1)throw TypeError("1 argument required, but only ".concat(arguments.length," present"));var a,n,r,i,s,o=u(),l=null!=(a=null!=(n=null==t?void 0:t.locale)?n:o.locale)?a:y,c=null!=(r=null==t?void 0:t.format)?r:_,d=null!=(i=null==t?void 0:t.zero)&&i,p=null!=(s=null==t?void 0:t.delimiter)?s:" ";return l.formatDistance?c.reduce(function(t,a){var n="x".concat(a.replace(/(^.)/,function(e){return e.toUpperCase()})),r=e[a];return"number"==typeof r&&(d||e[a])?t.concat(l.formatDistance(n,r)):t},[]).join(p):""})(function(e){a(1,arguments);var t=n(e.start),o=n(e.end);if(isNaN(t.getTime()))throw RangeError("Start Date is invalid");if(isNaN(o.getTime()))throw RangeError("End Date is invalid");var l={};l.years=Math.abs(function(e,t){a(2,arguments);var r=n(e),i=n(t),s=c(r,i),o=Math.abs(function(e,t){a(2,arguments);var r=n(e),i=n(t);return r.getFullYear()-i.getFullYear()}(r,i));r.setFullYear(1584),i.setFullYear(1584);var l=c(r,i)===-s,u=s*(o-Number(l));return 0===u?0:u}(o,t));var u=c(o,t),d=S(t,{years:u*l.years});l.months=Math.abs(function(e,t){a(2,arguments);var r,i=n(e),s=n(t),o=c(i,s),l=Math.abs(function(e,t){a(2,arguments);var r=n(e),i=n(t);return 12*(r.getFullYear()-i.getFullYear())+(r.getMonth()-i.getMonth())}(i,s));if(l<1)r=0;else{1===i.getMonth()&&i.getDate()>27&&i.setDate(30),i.setMonth(i.getMonth()-o*l);var u=c(i,s)===-o;(function(e){a(1,arguments);var t=n(e);return(function(e){a(1,arguments);var t=n(e);return t.setHours(23,59,59,999),t})(t).getTime()===(function(e){a(1,arguments);var t=n(e),r=t.getMonth();return t.setFullYear(t.getFullYear(),r+1,0),t.setHours(23,59,59,999),t})(t).getTime()})(n(e))&&1===l&&1===c(e,s)&&(u=!1),r=o*(l-Number(u))}return 0===r?0:r}(o,d));var p=S(d,{months:u*l.months});l.days=Math.abs(function(e,t){a(2,arguments);var o=n(e),l=n(t),u=s(o,l),c=Math.abs(function(e,t){a(2,arguments);var n=i(e),s=i(t);return Math.round((n.getTime()-r(n)-(s.getTime()-r(s)))/864e5)}(o,l));o.setDate(o.getDate()-u*c);var d=Number(s(o,l)===-u),p=u*(c-d);return 0===p?0:p}(o,p));var m=S(p,{days:u*l.days});l.hours=Math.abs(function(e,t,n){a(2,arguments);var r=w(e,t)/36e5;return $(null==n?void 0:n.roundingMethod)(r)}(o,m));var h=S(m,{hours:u*l.hours});l.minutes=Math.abs(function(e,t,n){a(2,arguments);var r=w(e,t)/6e4;return $(null==n?void 0:n.roundingMethod)(r)}(o,h));var g=S(h,{minutes:u*l.minutes});return l.seconds=Math.abs(function(e,t,n){a(2,arguments);var r=w(e,t)/1e3;return $(null==n?void 0:n.roundingMethod)(r)}(o,g)),l}({start:0,end:6e4*e}),{format:["hours","minutes"]}).replace(/hours?/,e=>"hour"===e?"hr":"hrs").replace(/minutes?/,e=>"minute"===e?"min":"mins"),"formatTimestamp",0,(e,t)=>{let i,s=new Date;if(isNaN((i=new Date("number"==typeof e?e*(e<1e12?1e3:1):e)).getTime()))return"";{let e=function(e,t){return a(1,arguments),function(e,t,i){a(2,arguments);var s,o,l,p,m,h,g,f=u(),v=null!=(s=null!=(o=null==i?void 0:i.locale)?o:f.locale)?s:y;if(!v.formatDistance)throw RangeError("locale must contain localize.formatDistance property");var b=c(e,t);if(isNaN(b))throw RangeError("Invalid time value");var k=d(d({},i),{addSuffix:!!(null==i?void 0:i.addSuffix),comparison:b});b>0?(p=n(t),m=n(e)):(p=n(e),m=n(t));var S=String(null!=(l=null==i?void 0:i.roundingMethod)?l:"round");if("floor"===S)h=Math.floor;else if("ceil"===S)h=Math.ceil;else if("round"===S)h=Math.round;else throw RangeError("roundingMethod must be 'floor', 'ceil' or 'round'");var w=m.getTime()-p.getTime(),x=w/6e4,$=(w-(r(m)-r(p)))/6e4,j=null==i?void 0:i.unit;if("second"===(g=j?String(j):x<1?"second":x<60?"minute":x<1440?"hour":$<43200?"day":$<525600?"month":"year")){var P=h(w/1e3);return v.formatDistance("xSeconds",P,k)}if("minute"===g){var C=h(x);return v.formatDistance("xMinutes",C,k)}if("hour"===g){var _=h(x/60);return v.formatDistance("xHours",_,k)}if("day"===g){var M=h($/1440);return v.formatDistance("xDays",M,k)}if("month"===g){var D=h($/43200);return 12===D&&"month"!==j?v.formatDistance("xYears",1,k):v.formatDistance("xMonths",D,k)}else if("year"===g){var I=h($/525600);return v.formatDistance("xYears",I,k)}throw RangeError("unit must be 'second', 'minute', 'hour', 'day', 'month' or 'year'")}(e,Date.now(),t)}(i),o=j(i,function(e,t){return a(2,arguments),function(e,t){return a(2,arguments),C(e,6e4*b(t))}(e,-b(t))}(s,5)),l=j(i,function(e,t){return a(2,arguments),k(e,-b(t))}(s,8)),p=(e,t)=>e.toLocaleDateString("en-GB",{day:"numeric",month:t,year:"numeric",timeZone:"UTC"});switch(t){case"live":return`${e} ago`;case"recent":return`Last updated on ${p(i,"short")}`;case"long":if(o)return"Just now";if(l)return`${e} ago`;return p(i,"long");case"seo":return i.toISOString();case"seo-archive":return p(i,"short");default:if(!o&&!l)return p(i,"short");{let t=e.replace("minutes","mins").replace("hour","hr");return o?"Just now":`${t} ago`}}}},"formatTimestampToTime",0,(e,t=!0,a)=>new Date(e).toLocaleTimeString("en-GB",{hour:"numeric",minute:"2-digit",hour12:t,...a&&{timeZone:a,timeZoneName:"short"}}),"getTimeZone",0,()=>Intl.DateTimeFormat().resolvedOptions().timeZone],303854)},973471,e=>{"use strict";e.s(["getFr",0,e=>"number"==typeof e?`repeat(${e}, 1fr)`:e])},913777,e=>{"use strict";var t=e.i(760814),a=e.i(339228),n=e.i(973471);let r=[6,5,4,3,2,1],i=t.default.div.withConfig({displayName:"Grid.styles__GridStyled",componentId:"sc-772acff9-0"})`
  ${({$justifyContent:e,$justifyItems:i,$alignContent:s,$justifySelf:o,$alignItems:l,$alignSelf:u,$columns:c,$padding:d,$gridAutoFlow:p,$gridGap:m,$height:h,$margin:g,$width:f,$rows:v,$left:y,$top:b,$gap:k,$maxWidth:S})=>t.css`
    display: grid;
    box-sizing: border-box;
    ${s&&t.css`
      align-content: ${s};
    `};
    ${u&&t.css`
      align-self: ${u};
    `};
    ${l&&t.css`
      align-items: ${l};
    `};
    ${e&&t.css`
      justify-content: ${e};
    `};
    ${o&&t.css`
      justify-self: ${o};
    `};
    ${i&&t.css`
      justify-items: ${i};
    `};
    ${k&&t.css`
      gap: ${k};
    `};
    ${p&&t.css`
      grid-auto-flow: ${p};
    `};
    ${(({$padding:e,$gridGap:r,$columns:i,$margin:s,$height:o,$width:l,$left:u,$rows:c,$top:d,$maxWidth:p,groups:m})=>t.css`
  ${m.map(m=>(0,a.applyStylesForBreakpoints)(t.css`
        ${!!i?.length&&!!i[m-1]&&t.css`
          grid-template-columns: ${(0,n.getFr)(i?.[m-1])};
        `}
        ${!!c?.length&&!!c[m-1]&&t.css`
          grid-template-rows: ${(0,n.getFr)(c[m-1])};
        `}
        ${!!e?.length&&!!e[m-1]&&t.css`
          /* stylelint-disable-next-line declaration-property-value-disallowed-list -- Dynamic value from props */
          padding: ${e[m-1]};
        `}
        ${!!r?.length&&!!r[m-1]&&t.css`
          gap: ${r[m-1]};
        `}
        ${!!p?.length&&!!p[m-1]&&t.css`
          max-width: ${p[m-1]};
        `}
        ${!!s?.length&&!!s[m-1]&&t.css`
          /* stylelint-disable-next-line declaration-property-value-disallowed-list -- Dynamic value from props */
          margin: ${s[m-1]};
        `}
        ${!!d?.length&&!!o?.length&&!!d[m-1]&&!!o[m-1]&&t.css`
          grid-row: ${d[m-1]} / span ${o[m-1]};
        `}
        ${!!u?.length&&!!l?.length&&!!u[m-1]&&!!l[m-1]&&t.css`
          grid-column: ${u[m-1]} / span ${l[m-1]};
        `}
      `,`group${m}`))}
`)({$padding:d,$gridGap:m,$columns:c,$margin:g,$height:h,$width:f,$rows:v,$left:y,$top:b,$maxWidth:S,groups:r})}
  `}
`;e.s(["GridStyled",0,i])},240911,e=>{"use strict";let t="home",a=e=>Array.isArray(e)?e.map(e=>e.replace(".app","")):e.replace(".app","");e.s(["BASE_SLUG",0,t,"getArrayFromSlug",0,(e=t)=>{let n=a(e);return Array.isArray(n)?n:[n]},"getStringFromSlug",0,(e=t,n=!1,r=!1)=>{let i=a(e),s=Array.isArray(i)?i.join("/"):i;return`${n?"/":""}${s}${r?"/":""}`}])},57988,e=>{"use strict";var t=e.i(746857),a=e.i(240911);function n(e){return e.replace(/<\/?[^>]+(>|$)/g,"")}let r=function(e){let[t]=e.split(/[?#]/),r=t.split("/").filter(Boolean).map(e=>{try{let t=decodeURIComponent(e);return n(t)}catch{return n(e)}});return 0===r.length?[a.BASE_SLUG]:r};e.s(["useCurrentSlug",0,function(){let{asPath:e}=(0,t.useAppRouter)();return r(e)}],57988)},927119,326790,e=>{"use strict";var t=e.i(746857),a=e.i(704570);function n(){let e=(0,t.useAppRouter)(),{rolexPlaylistPath:n,rolexSponsorClipId:r,rolexSponsorClipIdSummary:i}=(0,a.usePageData)(),s=e.asPath.split("?")[0]===n;return{rolexPath:n||"",isRolexPage:s,rolexClipPid:r||"UNDEFINED-ROLEX-CLIP-PID",rolexSponsorSummary:i||""}}e.s(["default",0,n],326790),e.s(["useRolexData",0,n],927119)},895270,e=>{"use strict";var t=e.i(184919),a=e.i(57988),n=e.i(704570),r=e.i(927119);let i=[t.ContentSubtype.ClipsNews,t.ContentSubtype.ClipsSport,t.ContentSubtype.Reels,t.ContentSubtype.VerticalClipsNews,t.ContentSubtype.VerticalClipsSport,t.ContentSubtype.VerticalReels];e.s(["useDarkMode",0,function(){let{subtype:e}=(0,n.usePageData)(),{isRolexPage:t}=(0,r.useRolexData)(),[s]=(0,a.useCurrentSlug)(),o=i.includes(e);return"video"===s||o||t}],895270)},939648,e=>{"use strict";e.s(["HEADER_COLLAPSED_HEIGHT",0,64,"HEADER_DEFAULT_HEIGHT",0,80,"HEADER_HEIGHT_MOBILE",0,48])},854300,e=>{"use strict";var t=e.i(391398),a=e.i(868783),n=e.i(895270),r=e.i(548817),i=e.i(409614),s=e.i(760814),o=e.i(939648),l=e.i(339228),u=e.i(222009),c=e.i(879214);let d=s.default.section.withConfig({displayName:"Container.styles__ContainerStyled",componentId:"sc-8b855a6c-0"})`
  ${({theme:e,$isInverse:t,$isDarkMode:a,$marginTop:n,$marginBottom:d,$withScrollMargin:p=!1,$withBackground:m=!0,$zIndex:h,$variant:g})=>s.css`
    display: grid;
    justify-items: center;
    position: relative;

    ${h&&(0,u.applyZIndex)(h)};

    ${(0,c.getSortedEntries)(n).map(([e,t])=>(0,r.default)(t)?"group6"===e?s.css`
            margin-block-start: ${t}px;
          `:(0,l.applyStylesForBreakpoints)(s.css`
              margin-block-start: ${t}px;
            `,e):s.css``)};

    ${(0,c.getSortedEntries)(d).map(([e,t])=>(0,r.default)(t)?"group6"===e?s.css`
            margin-block-end: ${t}px;
          `:(0,l.applyStylesForBreakpoints)(s.css`
              margin-block-end: ${t}px;
            `,e):s.css``)};

    ${(t||a)&&m&&s.css`
      background-color: ${e.container.onInverseBG2.value};

      ${function(e,t,a=!1){let n=a?1:.5,r={};return(0,i.default)(r,e,t,(e=[],t=0)=>e.concat(t)),s.css`
    ${({theme:e})=>Object.entries(r).map(([t,[a,r]])=>{let i=r*n,o=-a*n,u=e.container.onInverseBG2.value;return"group6"===t?s.css`
            box-shadow:
              0 ${i}px 0 0 ${u},
              0 ${o}px 0 0 ${u};
          `:(0,l.applyStylesForBreakpoints)(s.css`
              box-shadow:
                0 ${i}px 0 0 ${u},
                0 ${o}px 0 0 ${u};
            `,t)})};
  `}(n,d,a)};
    `};

    ${p&&s.css`
      scroll-margin-top: ${o.HEADER_DEFAULT_HEIGHT}px;

      ${(0,l.applyStylesForBreakpoints)(s.css`
          scroll-margin-top: ${o.HEADER_HEIGHT_MOBILE}px;
        `,"group2")};
    `};

    ${("advertisement"===g||"advertisement-placeholder"===g)&&s.css`
      padding-top: 15px;
      padding-bottom: 5px;

      ${a?s.css`
            background-color: ${e.advert.onInverse.container.value} !important;
          `:s.css`
            background-color: ${e.advert.container.value} !important;
          `};
    `};

    ${(()=>{switch(g){case"advertisement":return a?s.css`
                border-top: 1px solid ${e.advert.onInverse.border.value} !important;
                border-bottom: 1px solid ${e.advert.onInverse.border.value} !important;
              `:s.css`
                border-top: 1px solid ${e.advert.border.value} !important;
                border-bottom: 1px solid ${e.advert.border.value} !important;
              `;case"advertisement-placeholder":return s.css`
            min-height: 293px;
          `;default:return s.css``}})()};
  `};
`,p=(0,a.withCMSFallback)(({testId:e,id:a,as:r="div",children:i,marginTop:s,marginBottom:o,dataComponent:l,variant:u="content",withBackground:p,zIndex:m,inlineStyles:h,isInverse:g=!1,...f})=>{let v=(0,n.useDarkMode)(),y={group6:s,...(0,c.getCombinedProps)(f,"marginTop")},b={group6:o,...(0,c.getCombinedProps)(f,"marginBottom")};return(0,t.jsx)(d,{id:a,"data-testid":e,"data-component":l,as:r,style:h,$isInverse:g,$isDarkMode:v,$marginTop:y,$marginBottom:b,$withScrollMargin:!!a,$variant:u,$withBackground:p,$zIndex:m,children:i})},({testId:e,id:a,as:n="div",children:r,marginTop:i,marginBottom:s,dataComponent:o,variant:l="content",withBackground:u,zIndex:p,inlineStyles:m,isInverse:h=!1,...g})=>{let f={group6:i,...(0,c.getCombinedProps)(g,"marginTop")},v={group6:s,...(0,c.getCombinedProps)(g,"marginBottom")};return(0,t.jsx)(d,{id:a,"data-testid":e,"data-component":o,as:n,style:m,$isInverse:h,$isDarkMode:h,$marginTop:f,$marginBottom:v,$withScrollMargin:!!a,$variant:l,$withBackground:u,$zIndex:p,children:r})});e.s(["default",0,p],854300)},449492,e=>{"use strict";e.s(["AUDIO_SLUG",0,"audio","EARLY_PROGRESS",0,10,"FULL_PROGRESS",0,100,"LATE_PROGRESS",0,90,"SOUNDS_SLUG",0,"sounds"])},16234,e=>{"use strict";var t=e.i(391398);let a={audio:"Finished",video:"Finished","subscribers-only":"Subscriber only"};var n=e.i(760814),r=e.i(570549);let i=n.css`
  padding: 4px 10px;
  border-radius: 12px;
  display: inline-block;
  white-space: nowrap;
  /* stylelint-disable-next-line plugin/no-unsupported-browser-features */
  max-width: max-content;
`,s=n.default.span.withConfig({displayName:"MediaTag.styles__MediaTagStyled",componentId:"sc-39e7b2ce-0"})(({theme:e,$variant:t,$isInverse:a})=>"subscribers-only"===t?n.css`
          background-color: ${e.subscription.button.default.normal.background.value};
          color: ${e.tabs.selected.inverse.content.value};

          ${i};
          ${(0,r.applyTypography)(e.metaData.emphasised)};
        `:n.css`
          background-color: ${a?e.container.onInverseBG.value:e.playExperience.finishedLabel.value};
          color: ${a?e.text.onInverseBG.default.value:e.text.default.value};

          ${i};
          ${(0,r.applyTypography)(e.metaData.regular)};
        `);e.s(["default",0,({variant:e,isInverse:n=!1,testId:r="media-tag"})=>(0,t.jsx)(s,{$isInverse:n,$variant:e,"data-testid":r,children:a[e]})],16234)},291246,e=>{"use strict";var t=e.i(391398),a=e.i(191788),n=e.i(746857),r=e.i(396866);let i=(0,a.createContext)([!1]),{Provider:s}=i;e.s(["AdsServiceContext",0,i,"default",0,({children:e,value:a})=>{let[,i]=a,{query:o}=(0,n.useAppRouter)(),l="true"===o["ads-test"]?"adsServiceTest":"adsService",u=async()=>{i(await window.dotcom.ads.enabled())};return(0,t.jsxs)(s,{value:a,children:[(0,t.jsx)(r.default,{strategy:"beforeInteractive",source:l,onReady:u}),e]})}])},232854,e=>{"use strict";var t=e.i(191788),a=e.i(291246);e.s(["useIsAdsServiceEnabled",0,function(){let[e=!1]=(0,t.useContext)(a.AdsServiceContext);return e}],232854)},833223,506098,e=>{"use strict";var t=e.i(191788),a=e.i(391398);let n=(0,t.createContext)(()=>null),{Provider:r}=n;e.s(["NestedSectionsContext",0,n,"default",0,({children:e,value:t})=>(0,a.jsx)(r,{value:t,children:e})],506098),e.s(["useNestedSections",0,function(){return(0,t.useContext)(n)}],833223)},160709,e=>{"use strict";var t=e.i(391398),a=e.i(868783),n=e.i(519894),r=e.i(317166),i=e.i(79934),s=e.i(84541),o=e.i(721854);let l={save:i.SaveButtonInner,follow:i.FollowButtonInner},u=(0,a.withCMSFallback)(({action:e="save",...a})=>{let{isSignedIn:s}=(0,r.useUser)(),o=(0,n.useFeatureFlag)("authentication"),u=(0,n.useFeatureFlag)("bookmarking"),c=(0,n.useFeatureFlag)("follow-brand-function"),d="save"===e&&u,p="follow"===e&&c,m=s?l[e]:i.SaveButtonPopover;return o&&(d||p)?(0,t.jsx)(m,{action:e,...a}):null},({action:e="save",variant:a="news",text:n="Save",...r})=>{let i=(0,o.getButtonIcon)(e,!1);return(0,t.jsx)(s.default,{withoutPaddingBlock:!0,withoutPaddingInline:!0,type:"news"===a?"unboxed-share":"round",icon:i,"data-action":e,isSelected:!1,text:n,...r})});e.s(["default",0,u],160709)},593521,77694,e=>{"use strict";var t=e.i(391398),a=e.i(519894),n=e.i(704570),r=e.i(65739),i=e.i(160709),s=e.i(490602),o=e.i(760814),l=e.i(339228);let u=o.default.button.withConfig({displayName:"ArticlePageButtons.styles__ArticlePageButtonsButtonStyled",componentId:"sc-46edd6b5-0"})`
  cursor: pointer;
`,c=o.default.div.withConfig({displayName:"ArticlePageButtons.styles__SaveButtonWrapper",componentId:"sc-46edd6b5-1"})`
  display: inline-flex;

  button[data-action] {
    span[data-testid='button-text'] {
      margin-right: 2px;

      ${(0,l.applyStylesForBreakpoints)(o.css`
          margin-right: 4px;
        `,"group1")};
    }
  }
`;e.s(["ArticlePageButtonsButtonStyled",0,u,"SaveButtonWrapper",0,c],77694),e.s(["default",0,({onCommentClick:e})=>{let o=(0,a.useFeatureFlag)("comments"),{pageTitle:l}=(0,n.usePageData)();return(0,t.jsxs)(t.Fragment,{children:[o&&(0,t.jsx)(u,{"data-testid":"article-page-comment-button",disabled:!e,type:"button",onClick:e,children:(0,t.jsx)(r.default,{name:"participate:comments"})}),(0,t.jsx)(s.default,{trigger:"click",title:l||"",iconPosition:"right"}),(0,t.jsx)(c,{"data-article-page-buttons":!0,children:(0,t.jsx)(i.default,{isInverse:!1,iconPosition:"right",size:"small"})})]})}],593521)},151155,e=>{"use strict";var t=e.i(391398),a=e.i(191788),n=e.i(324951),r=e.i(760814),i=e.i(339228),s=e.i(570549),o=e.i(222009);let l=r.default.div.withConfig({displayName:"Dropdown.styles__DropdownContainerStyled",componentId:"sc-1c05475d-0"})`
  ${({$type:e})=>r.css`
    ${"nestedNav"===e&&r.css`
      display: flex;
      justify-content: flex-end;
      align-content: center;
    `};

    ${"subNav"===e&&r.css`
      position: relative;
      display: inline-block;
    `};
  `};
`,u=r.default.div.withConfig({displayName:"Dropdown.styles__DropdownOverlayStyled",componentId:"sc-1c05475d-1"})`
  ${({theme:e,$type:t})=>r.css`
    position: absolute;
    ${(0,o.applyZIndex)("level3")};

    ${"nestedNav"===t&&r.css`
      display: grid;
      row-gap: 6px;
      top: 28px;
      background-color: ${e.nav.content.value};
      padding: 24px 0;

      li {
        color: #ffffff;

        &:hover {
          background-color: ${e.divider.highEmphasis.value};
        }
      }

      ${(0,i.applyStylesForBreakpoints)(r.css`
          top: 54px;
          left: 0;
          right: 0;
          padding: 24px 16px;
        `,"group2")};
    `};

    ${"subNav"===t&&r.css`
      right: 0;
      padding: 24px 16px;
      background-color: ${e.nav.level2.bgHover.value};

      ${(0,i.applyStylesForBreakpoints)(r.css`
          top: 54px;
          left: 0;
          right: 0;
          padding: 24px 16px;
        `,"group2")};
    `};
  `}
`,c=r.css`
  cursor: pointer;
  display: flex;
  column-gap: 4px;
  align-items: center;
  padding-left: 8px;
  padding-right: 8px;
  position: relative;
`,d=r.default.button.withConfig({displayName:"Dropdown.styles__NestedNavButtonStyled",componentId:"sc-1c05475d-2"})`
  ${({theme:e,$isInverse:t,$isMenuOpen:a})=>r.css`
    ${c};

    svg {
      pointer-events: none;
    }

    &::before {
      position: absolute;
      content: '';
      background-color: ${e.divider.lowEmphasis.value};
      height: 30px;
      width: 1px;
      left: -6px;
    }

    ${a&&r.css`
      background-color: ${e.nav.content.value};
      color: #ffffff;
    `};

    ${t&&r.css`
      color: ${e.text.onInverseBG.default.value};
    `};

    ${(0,s.applyTypography)(e.nav.topbar.level3.default)};
  `};
`,p=r.default.button.withConfig({displayName:"Dropdown.styles__SubNavButtonStyled",componentId:"sc-1c05475d-3"})`
  ${({theme:e,$isMenuOpen:t})=>r.css`
    height: 32px;
    ${c};

    svg {
      pointer-events: none;
    }

    ${t&&r.css`
      background-color: ${e.nav.level2.bgHover.value};
    `};

    ${(0,s.applyTypography)(e.nav.topbar.level2.default)};
  `};
`,m={nestedNav:({children:e,isInverse:a,isMenuOpen:n,...r})=>(0,t.jsx)(d,{$isInverse:a,$isMenuOpen:n,...r,children:e}),subNav:({children:e,isMenuOpen:a,...n})=>(0,t.jsx)(p,{$isInverse:!1,$isMenuOpen:a,...n,children:e})};e.s(["default",0,({children:e,overlay:r,type:i,isOpen:s,onDropdownToggle:o,onDropdownClose:c,isInverse:d})=>{let[p,h]=(0,a.useState)(!1),g=(0,a.useRef)(null),f=void 0===s?p:s,v=m[i];return(0,n.useOutsideClicker)(g,()=>c?c():h(!1)),(0,t.jsxs)(l,{ref:g,$type:i,children:[(0,t.jsx)(v,{isInverse:d,isMenuOpen:f,onClick:()=>o?o():h(e=>!e),children:e}),f&&(0,t.jsx)(u,{$type:i,children:r})]})}],151155)},215812,e=>{"use strict";var t=e.i(760814),a=e.i(913777),n=e.i(339228),r=e.i(570549);let i=t.css`
  display: none;
  ${(0,n.applyStylesForBreakpoints)(t.css`
      display: block;
    `,"group2")};
`,s=t.css`
  display: block;

  ${(0,n.applyStylesForBreakpoints)(t.css`
      display: none;
    `,"group2")};
`,o=t.default.p.withConfig({displayName:"Bradford.styles__TitleStyled",componentId:"sc-f26957a7-0"})`
  ${({theme:e})=>t.css`
    color: #202224;
    display: -webkit-box;
    text-overflow: ellipsis;
    overflow: hidden;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;

    ${(0,r.applyTypography)(e.promoHeadline.xSmall.default.bpLarge)};
  `}
`,l=t.default.div.withConfig({displayName:"Bradford.styles__AnchorInnerStyled",componentId:"sc-f26957a7-1"})`
  ${({$isLive:e,$isOnDemand:a})=>(e||a)&&t.css`
      cursor: pointer;

      &:hover {
        ${o} {
          text-decoration: underline;
        }
      }
    `}
`,u=(0,t.default)(a.GridStyled).withConfig({displayName:"Bradford.styles__CardStyled",componentId:"sc-f26957a7-2"})`
  ${({$isLive:e,$isFirst:a,theme:r})=>t.css`
    width: 100%;
    border-bottom: 1px solid #e6e8ea;
    padding: 20px 16px 16px 16px;

    ${e&&t.css`
      margin-bottom: 12px;
      padding-top: 16px;
      border-bottom: none;
      background-color: ${r.container.onDefaultBG2.value};

      ${(0,n.applyStylesForBreakpoints)(t.css`
          margin-bottom: 4px;
        `,"group2")};
    `}

    ${!e&&a&&t.css`
      padding-top: 0;
    `}
  `}
`,c=t.default.span.withConfig({displayName:"Bradford.styles__TimeStyled",componentId:"sc-f26957a7-3"})`
  ${({theme:e})=>t.css`
    color: #545658;
    ${(0,r.applyTypography)(e.audio.listCard.timestamp.bpSmall)};
    font-family: 'BBC Reith Sans';
    font-size: 14px;
    font-weight: 400;
    line-height: 18px;
    text-align: left;
  `}
`,d=(0,t.default)(a.GridStyled).withConfig({displayName:"Bradford.styles__TextGridStyled",componentId:"sc-f26957a7-4"})`
  gap: 2px;
  max-height: unset;
  align-content: baseline;

  ${(0,n.applyStylesForBreakpoints)(t.css`
      max-height: 80px;
    `,"group2")};
`,p=t.default.div.withConfig({displayName:"Bradford.styles__ArtworkStyled",componentId:"sc-f26957a7-5"})`
  img {
    aspect-ratio: 1 / 1;
    object-fit: cover;
  }

  ${({$isLive:e})=>e&&t.css`
      img {
        border-radius: 50%;
      }
    `}

  ${(0,n.applyStylesForBreakpoints)(t.css`
      margin: auto;
    `,"group2")};
`,m=t.default.p.withConfig({displayName:"Bradford.styles__BrandNameStyled",componentId:"sc-f26957a7-6"})`
  ${({theme:e})=>t.css`
    color: #545658;
    ${(0,r.applyTypography)(e.metaData.large)};

    ${(0,n.applyStylesForBreakpoints)(t.css`
        ${(0,r.applyTypography)(e.audio.listCard.brandName.bpSmall)};
      `,"group2")};
  `}
`,h=t.default.p.withConfig({displayName:"Bradford.styles__DescriptionStyled",componentId:"sc-f26957a7-7"})`
  ${({$isLive:e})=>t.css`
    color: #545658;
    margin-top: 8px;
    ${e&&t.css`
      margin-bottom: 12px;
    `}
    /* applyTypography(theme.promoDescription.bpLarge)}; TODO missing token */
    /* styleName: promoDescription.bpLarge; */
    font-family: "BBC Reith Serif";
    font-size: 14px;
    font-weight: 400;
    line-height: 18px;
    text-align: left;
  `}
`,g=(0,t.default)(h).withConfig({displayName:"Bradford.styles__DescriptionMobileStyled",componentId:"sc-f26957a7-8"})`
  ${i};
`,f=(0,t.default)(h).withConfig({displayName:"Bradford.styles__DescriptionDesktopStyled",componentId:"sc-f26957a7-9"})`
  ${s};
`,v=t.default.div.withConfig({displayName:"Bradford.styles__LiveIndicatorStyled",componentId:"sc-f26957a7-10"})`
  ${({theme:e})=>t.css`
    display: flex;
    column-gap: 2px;
    color: #eb0000;
    ${(0,r.applyTypography)(e.kicker.indexcardHeadlinexSmall.bpLarge)};

    svg {
      height: 20px;
      width: 20px;
    }
  `}
`,y=t.default.div.withConfig({displayName:"Bradford.styles__MetadataStyled",componentId:"sc-f26957a7-11"})`
  display: flex;
  flex-direction: column;
  row-gap: 8px;
`,b=t.default.div.withConfig({displayName:"Bradford.styles__ProgressBarDesktopStyled",componentId:"sc-f26957a7-12"})`
  ${s};
`,k=t.default.div.withConfig({displayName:"Bradford.styles__ProgressBarMobileStyled",componentId:"sc-f26957a7-13"})`
  ${i};
`,S=t.default.div.withConfig({displayName:"Bradford.styles__DescriptionDesktopWrapperStyled",componentId:"sc-f26957a7-14"})`
  display: flex;
  align-items: flex-end;
  justify-content: space-between;

  ${(0,n.applyStylesForBreakpoints)(t.css`
      display: none;
    `,"group2")};

  ${({theme:e})=>t.css`
    button[data-action='play'] {
      min-width: unset;
      margin-left: 8px;
      background: ${e.contentIndicator.large.onInverse.background.value};
      color: ${e.contentIndicator.large.onInverse.content.value};
      border-radius: 50%;
    }
  `}
`,w=t.default.div.withConfig({displayName:"Bradford.styles__DescriptionMobileWrapperStyled",componentId:"sc-f26957a7-15"})`
  display: none;

  ${(0,n.applyStylesForBreakpoints)(t.css`
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
    `,"group2")};

  ${({theme:e})=>t.css`
    button[data-action='play'] {
      min-width: unset;
      margin-left: 8px;
      background: ${e.contentIndicator.large.onInverse.background.value};
      color: ${e.contentIndicator.large.onInverse.content.value};
      border-radius: 50%;
    }
  `}
`;e.s(["AnchorInnerStyled",0,l,"ArtworkStyled",0,p,"BrandNameStyled",0,m,"CardStyled",0,u,"DescriptionDesktopStyled",0,f,"DescriptionDesktopWrapperStyled",0,S,"DescriptionMobileStyled",0,g,"DescriptionMobileWrapperStyled",0,w,"LiveIndicatorStyled",0,v,"MetadataStyled",0,y,"ProgressBarDesktopStyled",0,b,"ProgressBarMobileStyled",0,k,"TextGridStyled",0,d,"TimeStyled",0,c,"TitleStyled",0,o])},506811,e=>{"use strict";var t=e.i(732299);e.s(["processNetworkError",0,function(e){if(e instanceof t.HTTPError){let t=Error(e.message);return t.name=e.name,t.stack=e.stack,t.statusCode=e.statusCode,t}return e instanceof Error&&"statusCode"in e||e instanceof Error?e:Error(String(e))}])},458810,346455,e=>{"use strict";var t=e.i(191788),a=e.i(959560),n=e.i(746857),r=e.i(704570),i=e.i(240911),s=e.i(258069),o=e.i(898229),l=e.i(506811),u=e.i(993297);async function c(e,t){try{let{data:a}=await (0,o.fetchClient)(e,t);return function(e){let{data:t,page:a,pageSize:n,total:r}=e;return{page:a,pageSize:n,total:r,results:t.map(u.transformContent)}}(a)}catch(e){throw(0,l.processNetworkError)(e)}}let d=function(e,a){let{query:{slug:o}}=(0,n.useAppRouter)(),{country:l}=(0,r.usePageData)(),u=e.includes("content-collection"),d=u?{...a,params:{country:l||"xx"}}:a;return(0,t.useCallback)((t,a)=>c(e,(0,s.buildFetchInit)(d,{page:String(t),size:String(a),...u?{path:(0,i.getStringFromSlug)(o,!0)}:{}})),[e,u,l,o,a])};e.s(["useCollectionRequest",0,d],346455),e.s(["useCollectionPagination",0,function(e,n,r){let{pageSize:i=20,collectionRef:s,scrollOffset:o=160}=r,[l,u]=(0,t.useState)(0),[c,p]=(0,t.useState)(!1),m=d(e,n),{data:{results:h}={},isLoading:g}=(0,a.default)(c?`${e}?page=${l}&size=${i}`:null,()=>m(l,i)),f=(0,t.useCallback)(e=>{if(u(e),s?.current){let{scrollY:e,scrollTo:t}=window,{top:a}=s.current.getBoundingClientRect();t({top:e+a-o,behavior:"smooth"})}},[s,o]);return(0,t.useEffect)(()=>{c||0===l||p(!0)},[l,c]),{results:h,isLoading:g,currentPage:l,handlePageChange:f}}],458810)},453784,145707,e=>{"use strict";var t=e.i(391398),a=e.i(191788);let n=function(e){return({layout:t,asideIndex:a,...n})=>e(n,t,a)};e.s(["forwardLayout",0,n],145707);var r=e.i(704570),i=e.i(854300),s=e.i(217256),o=e.i(485768),l=e.i(117191);let u=({children:e,adHeight:a})=>(0,t.jsx)(i.default,{dataComponent:"advertisement-block",variant:null===a?"advertisement-placeholder":"advertisement",marginTop:48,marginBottom:48,group2:{marginTop:32,marginBottom:32},...0===a?{inlineStyles:{display:"none"}}:{},children:(0,t.jsx)(s.default,{columns:24,group2:{columns:12},children:(0,t.jsx)(o.default,{colStart:1,colSpan:24,group2:{colStart:1,colSpan:12},children:e})})}),c=({children:e,adHeight:a})=>(0,t.jsx)(i.default,{dataComponent:"advertisement-block",variant:null===a?"advertisement-placeholder":"advertisement",marginTop:48,marginBottom:48,group2:{marginTop:32,marginBottom:32},...0===a?{inlineStyles:{display:"none"}}:{},children:(0,t.jsx)(s.default,{columns:24,group2:{columns:12},children:(0,t.jsx)(o.default,{colStart:1,colSpan:22,group5:{colStart:1,colSpan:19},group4:{colStart:1,colSpan:14},group3:{colStart:1,colSpan:24},group2:{colStart:1,colSpan:12},children:e})})}),d=({incrementedType:e,...a})=>e?(0,t.jsx)(l.AdSlot,{...a,type:e}):null,p=n((e,n)=>{let{allowAdvertising:i=!0}=(0,r.usePageData)(),[s,o]=(0,a.useState)(null),p=e.incrementedType?d:l.AdSlot,m=e=>o(e);if(!i)return null;switch(n){case"single-column":return(0,t.jsx)(u,{adHeight:s,children:(0,t.jsx)(p,{showContainer:!1,showPlaceholder:!1,onAdvertRendered:m,...e})});case"double-column":return(0,t.jsx)(c,{adHeight:s,children:(0,t.jsx)(p,{showContainer:!1,showPlaceholder:!1,onAdvertRendered:m,...e})})}});e.s(["default",0,p],453784)},344065,e=>{"use strict";var t=e.i(391398),a=e.i(65739),n=e.i(760814),r=e.i(339228),i=e.i(570549);let s=n.default.div.withConfig({displayName:"LoadingSpinner.styles__SpinnerContainerStyled",componentId:"sc-1c23711c-0"})`
  display: flex;
  justify-content: center;
`,o=(0,n.default)(s).withConfig({displayName:"LoadingSpinner.styles__SpinnerWrapperStyled",componentId:"sc-1c23711c-1"})`
  ${({theme:e,$isInverse:t})=>n.css`
    flex-direction: column;
    color: ${t?e.interactive2.onInverseBG.pressed.value:e.interactive2.onDefaultBG.pressed.value};
  `}
`,l=(0,n.default)(s).withConfig({displayName:"LoadingSpinner.styles__SpinnerTextStyled",componentId:"sc-1c23711c-2"})`
  ${({theme:e})=>n.css`
    margin-bottom: 16px;
    ${(0,i.applyTypography)(e.generic.headline.xSmall.bpLarge)};
    ${(0,r.applyStylesForBreakpoints)(n.css`
        ${(0,i.applyTypography)(e.generic.headline.xSmall.bpSmall)};
      `,"group1","group2")}
  `}
`;e.s(["default",0,({text:e="Fetching results",isInverse:n=!1})=>(0,t.jsxs)(o,{"data-testid":"loading-spinner",$isInverse:n,children:[(0,t.jsx)(l,{children:e}),(0,t.jsx)(s,{children:(0,t.jsx)(a.default,{"data-testid":"spinner-icon",name:"playback-avkx:loading",width:30,height:30})})]})],344065)},363402,e=>{"use strict";var t=e.i(191788),a=e.i(959560),n=e.i(116240),r=e.i(890979);let i=Promise.resolve(),s=(0,n.withMiddleware)(a.default,e=>(a,s,o)=>{let l,u=(0,t.useRef)(!1),{cache:c,initialSize:d=1,revalidateAll:p=!1,persistSize:m=!1,revalidateFirstPage:h=!0,revalidateOnMount:g=!1,parallel:f=!1}=o;try{(l=(0,n.serialize)(a?a(0,null):null)[0])&&(l="$inf$"+l)}catch(e){}let[v,y,b]=(0,n.createCacheHelper)(c,l),k=(0,t.useCallback)(()=>(0,n.isUndefined)(v()._l)?d:v()._l,[c,l,d]);(0,r.useSyncExternalStore)((0,t.useCallback)(e=>l?b(l,()=>{e()}):()=>{},[c,l]),k,k);let S=(0,t.useCallback)(()=>{let e=v()._l;return(0,n.isUndefined)(e)?d:e},[l,d]),w=(0,t.useRef)(S());(0,n.useIsomorphicLayoutEffect)(()=>{if(!u.current){u.current=!0;return}l&&y({_l:m?w.current:S()})},[l,c]);let x=g&&!u.current,$=e(l,async e=>{let t=v()._i,r=[],i=S(),[l]=(0,n.createCacheHelper)(c,e),u=l().data,d=[],m=null;for(let e=0;e<i;++e){let[i,l]=(0,n.serialize)(a(e,f?null:m));if(!i)break;let[g,v]=(0,n.createCacheHelper)(c,i),y=g().data,b=p||t||(0,n.isUndefined)(y)||h&&!e&&!(0,n.isUndefined)(u)||x||u&&!(0,n.isUndefined)(u[e])&&!o.compare(u[e],y);if(s&&b){let t=async()=>{v({data:y=await s(l),_k:l}),r[e]=y};f?d.push(t):await t()}else r[e]=y;f||(m=y)}return f&&await Promise.all(d.map(e=>e())),y({_i:n.UNDEFINED}),r},o),j=(0,t.useCallback)(function(e,t){let a="boolean"==typeof t?{revalidate:t}:t||{},r=!1!==a.revalidate;return l?(r&&((0,n.isUndefined)(e)?y({_i:!0}):y({_i:!1})),arguments.length?$.mutate(e,{...a,revalidate:r}):$.mutate()):i},[l,c]),P=(0,t.useCallback)(e=>{let t;if(!l)return i;let[,r]=(0,n.createCacheHelper)(c,l);if((0,n.isFunction)(e)?t=e(S()):"number"==typeof e&&(t=e),"number"!=typeof t)return i;r({_l:t}),w.current=t;let s=[],[o]=(0,n.createCacheHelper)(c,l),u=null;for(let e=0;e<t;++e){let[t]=(0,n.serialize)(a(e,u)),[r]=(0,n.createCacheHelper)(c,t),i=t?r().data:n.UNDEFINED;if((0,n.isUndefined)(i))return j(o().data);s.push(i),u=i}return j(s)},[l,c,j,S]);return{size:S(),setSize:P,mutate:j,get data(){return $.data},get error(){return $.error},get isValidating(){return $.isValidating},get isLoading(){return $.isLoading}}});e.s(["default",0,s])},521670,588299,e=>{"use strict";var t=e.i(760814);let a=t.keyframes`
  0% {
    background-color: rgb(58, 60, 62);
  }

  100% {
    background-color: rgb(82, 84, 86);
  }
`,n=t.keyframes`
  0% {
    background-color: #e6e8ea;
  }

  100% {
    background-color: #d2d4d6;
  }
`,r=t.default.div.withConfig({displayName:"CardSkeleton.styles__SkeletonBlockStyled",componentId:"sc-597e70be-0"})`
  ${({$height:e="1em",$width:r="100%",$isInverse:i=!1})=>t.css`
    width: ${r};
    height: ${e};
    background-color: ${i?"rgb(58, 60, 62)":"#e6e8ea"};
    animation: ${i?a:n} 1.2s ease-in-out infinite alternate;

    @media (prefers-reduced-motion: reduce) {
      animation: none;
    }
  `}
`,i=t.default.div.withConfig({displayName:"CardSkeleton.styles__SkeletonCardStyled",componentId:"sc-597e70be-1"})`
  position: relative;
  display: grid;
  row-gap: 8px;
  min-width: 100%;
`;e.s(["SkeletonBlockStyled",0,r,"SkeletonCardStyled",0,i],521670);var s=e.i(391398),o=e.i(191788);let l=t.default.div.withConfig({displayName:"SkeletonReveal.styles__SkeletonRevealStyled",componentId:"sc-fa1626a7-0"})`
  position: relative;
`,u="300ms",c=t.default.div.withConfig({displayName:"SkeletonReveal.styles__SkeletonRevealContentStyled",componentId:"sc-fa1626a7-1"})`
  visibility: ${({$isRevealed:e})=>e?"visible":"hidden"};
  pointer-events: ${({$isRevealed:e})=>e?"auto":"none"};
  opacity: ${({$isRevealed:e})=>+!!e};
  transition: opacity ${u} ease-out;

  @media (prefers-reduced-motion: reduce) {
    transition: none;
  }
`,d=t.default.div.withConfig({displayName:"SkeletonReveal.styles__SkeletonRevealFallbackStyled",componentId:"sc-fa1626a7-2"})`
  position: absolute;
  inset: 0;
  pointer-events: none;
  opacity: ${({$isRevealed:e})=>+!e};
  transition: opacity ${u} ease-out;

  @media (prefers-reduced-motion: reduce) {
    transition: none;
  }
`,p=e=>Array.from(e?.querySelectorAll("img:not(.hide-when-no-script)")??[]);e.s(["default",0,({children:e,fallback:t,hasImage:a=!0,isRevealed:n,revealKey:r,onReady:i})=>{let u=(0,o.useRef)(null),[m,h]=(0,o.useState)(!a),[g,f]=(0,o.useState)(!n);(0,o.useEffect)(()=>{if(!n)return void f(!0);let e=window.setTimeout(()=>f(!1),300);return()=>window.clearTimeout(e)},[n]);let v=(0,o.useCallback)(()=>{let e=p(u.current);(!e.length||e.every(e=>e.complete))&&h(!0)},[]);(0,o.useEffect)(()=>{h(!a)},[a,r]),(0,o.useEffect)(()=>{m&&i?.(r)},[m,r,i]),(0,o.useEffect)(()=>{a&&!m&&p(u.current).forEach(e=>{"lazy"===e.getAttribute("loading")&&e.setAttribute("loading","eager")})},[a,m,r]),(0,o.useEffect)(()=>{if(!a||m)return;let e=window.requestAnimationFrame(v);return()=>window.cancelAnimationFrame(e)},[a,m,v]);let y=e=>{if(e.target instanceof HTMLImageElement&&!e.target.classList.contains("hide-when-no-script")){if("error"===e.type)return void h(!0);v()}};return(0,s.jsxs)(l,{onLoadCapture:y,onErrorCapture:y,children:[(0,s.jsx)(c,{ref:u,$isRevealed:n,children:e}),g&&(0,s.jsx)(d,{$isRevealed:n,children:t({isContentRevealing:n})})]})}],588299)},440695,e=>{"use strict";var t=e.i(391398),a=e.i(191788),n=e.i(519894);e.i(959560);var r=e.i(116240),i=e.i(363402),s=e.i(346455);let o=function(e,t,n,o){let l=n.length,{mutate:u}=(0,r.useSWRConfig)(),c=(0,s.useCollectionRequest)(e,t),{data:d=[],isValidating:p,size:m,setSize:h}=(0,i.default)((t,a)=>a&&0===a.results.length?null:[e,t+1,l],([,e,t])=>c(e,t),{initialSize:0,fallbackData:[],revalidateFirstPage:!1,revalidateIfStale:!1,revalidateOnFocus:!1,revalidateOnReconnect:!1}),g=[...n,...d.flatMap(e=>e.results)],f=d[d.length-1],v=!f||f.results.length>=l,y=g.length<o&&v,b=(0,a.useCallback)(()=>{if(!y)return;let t=m+1;u([e,t,l],c(t,l),{revalidate:!1}).catch(()=>void 0)},[y,m,e,l,u,c]);return{items:g,isLoading:p,hasMore:y,onLoadMore:(0,a.useCallback)(()=>h(e=>e+1),[h]),pagesLoaded:m+1,prefetchNext:b}},l=function(e,{enabled:t=!0,rootMargin:n="0px 0px 400px 0px"}={}){let r=(0,a.useRef)(null),i=(0,a.useRef)(e);return i.current=e,(0,a.useEffect)(()=>{let e=r.current;if(!e||!t)return;let a=new IntersectionObserver(([e])=>{e.isIntersecting&&i.current()},{rootMargin:n});return a.observe(e),()=>a.disconnect()},[t,n]),r},u=new Set,c=e=>`card-${e}`;function d(e,t){let{status:a}=e;switch(t.type){case"REQUEST_MORE":return"idle"===a||"paused"===a?{...e,status:"fetching"}:e;case"PAGE_RECEIVED":return"fetching"===a?{...e,status:"revealing"}:e;case"BATCH_REVEALED":if("revealing"!==a)return e;if(!t.hasMore)return{status:"exhausted",revealedCount:t.revealedCount};return{status:t.atPause?"paused":"idle",revealedCount:t.revealedCount};case"EXHAUSTED":return"idle"===a||"paused"===a||"fetching"===a?{...e,status:"exhausted"}:e;default:return e}}let p=function(e,t,r,i={}){let{loadsPerPause:s=8,prefetchDistance:p=1e3,footerStopDistance:m=300}=i,{items:h,isLoading:g,hasMore:f,onLoadMore:v,pagesLoaded:y,prefetchNext:b}=o(`content-collection/${e}`,{isLegacyApiEnabled:(0,n.useFeatureFlag)("legacy-api")},t,r.total),k=t.length,[S,w]=(0,a.useReducer)(d,{status:"idle",revealedCount:k}),{status:x,revealedCount:$}=S,j=(0,a.useRef)({status:x,itemCount:h.length,hasMore:f,pagesLoaded:y,onLoadMore:v});j.current={status:x,itemCount:h.length,hasMore:f,pagesLoaded:y,onLoadMore:v};let P="revealing"===x?Math.max(h.length-$,0):0,C=(0,a.useMemo)(()=>Array.from({length:P},(e,t)=>c($+t)),[P,$]),[_,M]=(0,a.useState)({start:-1,keys:new Set}),D=_.start===$?_.keys:u,I=(0,a.useCallback)(e=>{M(t=>{let a=new Set(t.start===$?t.keys:[]);return a.add(e),{start:$,keys:a}})},[$]),E=0===C.length||C.every(e=>D.has(e)),T=(0,a.useCallback)(()=>{let e=j.current.pagesLoaded-1,t=e>0&&e%s==0;w({type:"BATCH_REVEALED",revealedCount:j.current.itemCount,atPause:t,hasMore:j.current.hasMore})},[s]);(0,a.useEffect)(()=>{"fetching"===x&&!g&&(h.length>$?w({type:"PAGE_RECEIVED"}):f||w({type:"EXHAUSTED"}))},[x,$,g,h.length,f]),(0,a.useEffect)(()=>{f||"idle"!==x&&"paused"!==x||w({type:"EXHAUSTED"})},[f,x]),(0,a.useEffect)(()=>{"revealing"===x&&E&&T()},[x,E,T]);let[N,A]=(0,a.useState)(!1),B=(0,a.useRef)(N);B.current=N;let F=(0,a.useCallback)(()=>{("idle"===j.current.status||"paused"===j.current.status)&&(B.current&&A(!1),w({type:"REQUEST_MORE"}),j.current.onLoadMore())},[]);(0,a.useEffect)(()=>{"paused"===x&&b()},[x]),(0,a.useEffect)(()=>{N&&b()},[N]);let R=l(F,{enabled:"idle"===x&&f&&!N,rootMargin:`0px 0px ${p}px 0px`}),z=l(()=>A(!0),{enabled:f&&!N,rootMargin:`0px 0px -${m}px 0px`}),L="fetching"===x||"revealing"===x,H=r.total,W=r.pageSize||k,O=Number.isFinite(H)?Math.max(H-$,0):W,U="fetching"===x?Math.min(W,O):0;return{isLoading:L,totalItems:H,controls:{hasMore:f,isLoading:L,isAutoScrollEnabled:"paused"!==x&&!N,sentinelRef:R,footerStopRef:z,onLoadMore:F},cards:(0,a.useMemo)(()=>[...h.slice(0,$).map((e,t)=>({type:"card",key:c(t),item:e,index:t,isIncoming:!1})),...h.slice($,$+P).map((e,t)=>({type:"card",key:c($+t),item:e,index:$+t,isIncoming:!0})),...Array.from({length:U},(e,t)=>({type:"skeleton",key:`skeleton-${$+t}`}))],[h,$,P,U]),visibleItemCount:$+P,isRevealed:E,markReady:I}};var m=e.i(760814),h=e.i(84541);let g=({hasMore:e,isLoading:a,isAutoScrollEnabled:n,sentinelRef:r,footerStopRef:i,onLoadMore:s,isInverse:o=!1,testId:l="infinite-scroll"})=>(0,t.jsxs)(t.Fragment,{children:[e&&(0,t.jsx)("div",{ref:r,"data-testid":`${l}-sentinel`}),e&&(0,t.jsx)("div",{ref:i,"data-testid":`${l}-footer-stop`}),e&&!a&&!n&&(0,t.jsx)(h.default,{type:"general",text:"Show More",onClick:s,testId:`${l}-load-more-button`,isInverse:o})]}),f=m.default.div.withConfig({displayName:"InfiniteScrollShell__FooterStyled",componentId:"sc-6574a340-0"})`
  display: flex;
  justify-content: center;
  margin-top: 48px;
  margin-bottom: 48px;
`,v=m.default.div.withConfig({displayName:"InfiniteScrollShell__StatusStyled",componentId:"sc-6574a340-1"})`
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden; /* stylelint-disable-line plugin/no-unsupported-browser-features */
  clip: rect(0, 0, 0, 0);
  border: 0;
`,y=({children:e,controls:a,itemCount:n,totalItems:r,isLoading:i,isInverse:s=!1,testId:o="infinite-scroll"})=>(0,t.jsxs)("section",{"aria-label":"Results","data-testid":o,children:[(0,t.jsx)(v,{role:"status","aria-live":"polite","aria-atomic":"true",children:i?"Loading more results":`Showing ${n} of ${r} results`}),(0,t.jsx)("div",{"aria-busy":i,children:e}),(0,t.jsx)(f,{"data-testid":`${o}-load-more`,children:(0,t.jsx)(g,{...a,isInverse:s})})]});var b=e.i(588299);e.s(["default",0,({collectionId:e,content:a,paginationData:n,grid:r,renderItem:i,renderSkeleton:s,isInverse:o=!1,testId:l="infinite-scroll",prefetchDistance:u,footerStopDistance:c,loadsPerPause:d,dataset:m})=>{let{cards:h,isLoading:g,totalItems:f,controls:v,isRevealed:k,markReady:S,visibleItemCount:w}=p(e,a,n,{prefetchDistance:u,footerStopDistance:c,loadsPerPause:d});return(0,t.jsx)(y,{controls:v,itemCount:w,totalItems:f,isLoading:g,isInverse:o,testId:l,children:(0,t.jsx)(r,{"data-testid":`${l}-grid`,...m,children:h.map((e,a)=>(0,t.jsx)("li",{"aria-hidden":"skeleton"===e.type?"true":void 0,"data-testid":"skeleton"===e.type?`${l}-loading-card-${a}`:void 0,children:"card"===e.type?(0,t.jsx)(b.default,{revealKey:e.key,hasImage:!!e.item.image,isRevealed:!e.isIncoming||k,onReady:e.isIncoming?S:void 0,fallback:s,children:i(e.item,e.index)}):s({isContentRevealing:!1})},e.key))})})}],440695)},94476,316908,e=>{"use strict";var t=e.i(391398),a=e.i(270340),n=e.i(704570),r=e.i(808824),i=e.i(120012);e.s(["default",0,({imageUrlTemplate:e,cardType:s="",sizes:o,loading:l,fetchPriority:u,...c})=>{let{os:d={},browser:p={}}=(0,n.usePageData)(),{getIsEager:m}=(0,a.useEagerImages)(),h=(0,r.supportsWebP)({os:d,browser:p}),g=o??(0,r.getSizesByCardType)(s,"96vw",""),{srcSet:f,mainImageSource:v}=(0,r.getSrcAndSrcSet)(e,!1,h),y=l??(m(v)?"eager":"lazy");return(0,t.jsx)(i.ImageStyled,{sizes:g,srcSet:f,src:v,loading:y,fetchpriority:u,...c})}],94476),e.s(["getHexWithTransparency",0,function(e,t){let a=Math.round(t/100*255).toString(16).padStart(2,"0");return`${e}${a}`}],316908)},287988,e=>{"use strict";e.s(["BOOKMARKS_SLUG",0,"saved"])},232489,e=>{"use strict";var t=e.i(606919),a=e.i(287988),n=e.i(147097),r=e.i(318438);e.s(["getHref",0,(e,i,s="")=>{if(!(0,n.getIsClient)())return"";let o=window.location.origin,l="https://www.bbc.com"===o?r.siteLabel.production:r.siteLabel.test,u=`${o}${s}`;switch(i){case"saved_items":return`${o}/${a.BOOKMARKS_SLUG}`;case"manage_subscription":return`${o}/managesubscription`;case"subscribe":return`${o}/subscribe`;case"sign_out":return(0,t.getAuthUrl)(e,{userOrigin:l});case"settings":return(0,t.getAuthUrl)(e,{userOrigin:l,ptrt:u,web:"true"});default:return(0,t.getAuthUrl)(e,{userOrigin:l,ptrt:u})}}])},276045,e=>{"use strict";var t=e.i(191788),a=e.i(879677),n=e.i(788664),r=e.i(494373),i=e.i(519894),s=e.i(704570),o=e.i(898229);e.s(["useWorldNewsData",0,function(){let{country:e="",worldNewsTvPath:l,worldNewsTvScheduleId:u,worldNewsFullScheduleUrl:c=""}=(0,s.usePageData)(),d=(0,r.getWntvRegion)(e),p=(0,r.isWntvCountry)(e),m=(0,i.useFeatureFlag)("legacy-api"),h=(0,i.useFeatureFlag)(`wntv-${d}`),g=(0,i.useFeatureFlag)(`wntv-${d}-preroll-ad`),f=p&&h,v=(0,t.useCallback)(async t=>{let{data:a}=await (0,o.fetchClient)(t,{isLegacyApiEnabled:m,...m?{headers:new Headers({country:e})}:{params:new URLSearchParams({country:e})}});return a},[e,m]),y=(0,n.default)(f?"schedule":null,v,{refreshInterval:3e5});return{isWntvEnabled:f,isWntvPrerollAdEnabled:p&&g,worldNewsData:y,worldNewsTvPath:(0,a.default)(l,""),worldNewsServiceId:(0,a.default)(u,""),worldNewsFullScheduleUrl:c}}],276045)},848e3,e=>{"use strict";var t=e.i(395497);let a=e.i(227162).appConfig.getValue(t.ConfigSettings.SeoArchiveStartDate)||"2017-06-01";e.s(["SEO_ARCHIVE_INDEX_SLUG",0,"pages/content-index","SEO_ARCHIVE_ITEMS_PER_RESULTS_PAGE",0,9,"SEO_ARCHIVE_START_DATE",0,a],848e3)},612097,e=>{"use strict";var t=e.i(191788),a=e.i(746857),n=e.i(240911);e.s(["useThrottledPagination",0,function(e,r=9,i=0,s){let{query:o,replace:l}=(0,a.useAppRouter)(),{page:u="1",slug:c,...d}=o,p=(0,n.getStringFromSlug)(c,!0),m=parseInt(u,10),h=s??Math.ceil(i/r),g=Math.min(m,h),f=s?Math.min(r*s,i):i;return(0,t.useEffect)(()=>{if(m>h){let t=new URLSearchParams({...d,page:h.toString()});l(`${p}?${t.toString()}`,void 0,{shallow:e}).then()}},[l,m,d,e,p,h]),{page:g,pageSize:r,total:f}}],612097)},51086,633430,e=>{"use strict";var t=e.i(391398),a=e.i(459949),n=e.i(868783),r=e.i(191788),i=e.i(184919),s=e.i(823575),o=e.i(746857),l=e.i(704570);let u=(0,r.createContext)({}),{Provider:c}=u;e.s(["SearchAnalyticsContext",0,u,"default",0,({children:e,value:a})=>(0,t.jsx)(c,{value:a,children:e})],633430);let d=function(e){let{query:t}=(0,o.useAppRouter)(),{type:a}=(0,l.usePageData)(),n=(0,r.useRef)(!1),c=a===i.ContentType.SearchPage,{results:d,page:p}=e,{submittedSearchText:m="",inputRef:h}=(0,r.useContext)(u),g=(0,r.useCallback)(({title:e="",href:t,type:a="newport",metadata:n,id:r,brandName:i,seriesName:o},l)=>{let{contentType:u,subtype:d}=n,h=["episode","series","brand"].find(e=>d===e)?(0,s.getAvProperties)({contentType:u,subtype:d,title:e,brandName:i,seriesName:o,id:r}):null;c&&window.analytics.sendEvent({eventGrouping:"internal_search_result_click",eventProperties:{ise_page:p,ise_keyword:m,ise_click_rank:l,item_name:e,item_link:t,item_type:a,...h||{}}})},[c,p,m]);return(0,r.useEffect)(()=>{let e=()=>{d.length&&(window.analytics.sendEvent({eventGrouping:"internal_search_result_display",eventProperties:{ise_keyword:h?.current?.value||t?.q?.toString()||"",ise_page:p}}),n.current=!0)};return c&&(n.current?e():window.addEventListener("echo_initialize_success",e)),()=>{c&&window.removeEventListener("echo_initialize_success",e)}},[c,t,h,p,d]),{onResultItemClick:g}};var p=e.i(612097),m=e.i(554692),h=e.i(581620),g=e.i(760814);let f=g.default.div.withConfig({displayName:"NewJersey.styles__NewJerseyContainerStyled",componentId:"sc-189bb7d3-0"})`
  display: grid;
  row-gap: 24px;
`,v=g.default.div.withConfig({displayName:"NewJersey.styles__NewJerseyPaginationStyled",componentId:"sc-189bb7d3-1"})`
  display: flex;
  justify-content: center;
  margin-top: 48px;
  margin-bottom: 120px;
`,y=({paginationData:e={},testId:n="new-jersey",collectionAnalytics:r,controlButtonsPortalRef:i,content:s=[]})=>{let{pageSize:o,total:l,page:u}=(0,p.useThrottledPagination)(!0,e.pageSize,e.total,h.SEARCH_RESULTS_MAX_PAGES),{onResultItemClick:c}=d({page:u,pageSize:o,total:l,results:s}),g=s.slice(0,o);return(0,t.jsxs)(f,{"data-testid":`${n}-grid`,children:[g.length?g.map((e,a)=>(0,t.jsx)(m.default,{...e,hideBottomBorder:a===g.length-1,type:"newport",collectionAnalytics:r,itemPosition:a,onClick:()=>c({...e,type:"newport"},a),isOverrideAnalytics:!0,hideMetadata:!0},a)):(0,t.jsx)("div",{ref:i}),(0,t.jsx)(v,{children:(0,t.jsx)(a.Pagination,{currentPage:u,itemsTotalCount:l,itemsPerPage:o,pageRangeDisplayed:6})})]})},b=(0,n.withCMSFallback)(y,({content:e=[],paginationData:a={},testId:n,...r})=>{let{pageSize:i}=a,s=e.slice(0,i);return(0,t.jsx)(f,{children:s.map((e,a)=>(0,t.jsx)(m.default,{...e,type:"newport",...r,hideMetadata:!0},a))})});e.s(["NewJersey",0,y,"default",0,b],51086)},648761,e=>{e.v(t=>Promise.all(["static/chunks/0n..hexfw6r85.js"].map(t=>e.l(t))).then(()=>t(493594)))},828805,e=>{e.v(t=>Promise.all(["static/chunks/18bztvpdorkth.js"].map(t=>e.l(t))).then(()=>t(879466)))},812937,e=>{e.v(t=>Promise.all(["static/chunks/0ffxuwm49oix0.js"].map(t=>e.l(t))).then(()=>t(485683)))},515824,e=>{e.v(t=>Promise.all(["static/chunks/05u0ya7obj7ro.js"].map(t=>e.l(t))).then(()=>t(411236)))},525705,e=>{e.v(t=>Promise.all(["static/chunks/0z2.8gdngrkuk.js"].map(t=>e.l(t))).then(()=>t(113847)))},771284,e=>{e.v(t=>Promise.all(["static/chunks/14vww2ci_89nf.js"].map(t=>e.l(t))).then(()=>t(504127)))},64214,e=>{e.v(t=>Promise.all(["static/chunks/0ytibk9~7yifn.js"].map(t=>e.l(t))).then(()=>t(945578)))},991855,e=>{e.v(t=>Promise.all(["static/chunks/0j7~yotk97jxc.js"].map(t=>e.l(t))).then(()=>t(405067)))},582626,e=>{e.v(t=>Promise.all(["static/chunks/1368-yf-me439.js"].map(t=>e.l(t))).then(()=>t(482608)))},34479,e=>{e.v(t=>Promise.all(["static/chunks/0yuh-~t-ppktm.js"].map(t=>e.l(t))).then(()=>t(742862)))},253584,e=>{e.v(t=>Promise.all(["static/chunks/0oeiln2dry2bs.js"].map(t=>e.l(t))).then(()=>t(83621)))},179938,e=>{e.v(t=>Promise.all(["static/chunks/0pr885e78gdj8.js"].map(t=>e.l(t))).then(()=>t(935664)))},29455,e=>{e.v(t=>Promise.all(["static/chunks/05e-_rwyri0gi.js"].map(t=>e.l(t))).then(()=>t(416090)))},209509,e=>{e.v(t=>Promise.all(["static/chunks/13xfzm66q5x.7.js"].map(t=>e.l(t))).then(()=>t(556831)))},881178,e=>{e.v(t=>Promise.all(["static/chunks/0s_kjwmep8yf2.js"].map(t=>e.l(t))).then(()=>t(541099)))},935046,e=>{e.v(t=>Promise.all(["static/chunks/0lzefd_ptqlce.js"].map(t=>e.l(t))).then(()=>t(376411)))},423182,e=>{e.v(t=>Promise.all(["static/chunks/02w2j6a0szhem.js"].map(t=>e.l(t))).then(()=>t(46385)))},156025,e=>{e.v(t=>Promise.all(["static/chunks/0p0vkh91e4914.js"].map(t=>e.l(t))).then(()=>t(714830)))},963281,e=>{e.v(t=>Promise.all(["static/chunks/0l7g7f4dyv0f-.js"].map(t=>e.l(t))).then(()=>t(233061)))},171427,e=>{e.v(t=>Promise.all(["static/chunks/0ec517i~_6min.js"].map(t=>e.l(t))).then(()=>t(622702)))},855479,e=>{e.v(t=>Promise.all(["static/chunks/004vauwu48azs.js"].map(t=>e.l(t))).then(()=>t(398144)))},517492,e=>{e.v(t=>Promise.all(["static/chunks/0r8yqy9~18zbm.js"].map(t=>e.l(t))).then(()=>t(593624)))},106835,e=>{e.v(t=>Promise.all(["static/chunks/0g~mh0z17hs0e.js"].map(t=>e.l(t))).then(()=>t(617864)))},239272,e=>{e.v(t=>Promise.all(["static/chunks/0dfhw76.7mxqo.js"].map(t=>e.l(t))).then(()=>t(502341)))},48292,e=>{e.v(t=>Promise.all(["static/chunks/04h172kkt~xm-.js"].map(t=>e.l(t))).then(()=>t(282676)))},748588,e=>{e.v(t=>Promise.all(["static/chunks/0zpz-874su9ks.js"].map(t=>e.l(t))).then(()=>t(140108)))},965517,e=>{e.v(t=>Promise.all(["static/chunks/0_682v_tmycqh.js"].map(t=>e.l(t))).then(()=>t(299514)))},952340,e=>{e.v(t=>Promise.all(["static/chunks/17d-3bben9tkw.js"].map(t=>e.l(t))).then(()=>t(417473)))},412203,e=>{e.v(t=>Promise.all(["static/chunks/0-a6nanpwqpag.js"].map(t=>e.l(t))).then(()=>t(461239)))},791844,e=>{e.v(t=>Promise.all(["static/chunks/1566agutxknpz.js"].map(t=>e.l(t))).then(()=>t(926404)))},423501,e=>{e.v(t=>Promise.all(["static/chunks/0ahzv8e.qitwx.js"].map(t=>e.l(t))).then(()=>t(231311)))},544130,e=>{e.v(t=>Promise.all(["static/chunks/0x4zv0liim9tb.js"].map(t=>e.l(t))).then(()=>t(484112)))},631060,e=>{e.v(t=>Promise.all(["static/chunks/0cm_f~9t.nb1u.js"].map(t=>e.l(t))).then(()=>t(685098)))},612575,e=>{e.v(t=>Promise.all(["static/chunks/0olmr9xx2irp_.js"].map(t=>e.l(t))).then(()=>t(257203)))},112905,e=>{e.v(t=>Promise.all(["static/chunks/02gz1-ocnq62g.js"].map(t=>e.l(t))).then(()=>t(325461)))},139296,e=>{e.v(t=>Promise.all(["static/chunks/04s4vnlpbigoe.js"].map(t=>e.l(t))).then(()=>t(710853)))},497333,e=>{e.v(t=>Promise.all(["static/chunks/0mgn9gis09369.js"].map(t=>e.l(t))).then(()=>t(993518)))},19108,e=>{e.v(t=>Promise.all(["static/chunks/0ib_j80741bgy.js"].map(t=>e.l(t))).then(()=>t(757795)))},559958,e=>{e.v(t=>Promise.all(["static/chunks/05j89a5dl50x1.js"].map(t=>e.l(t))).then(()=>t(58795)))},925136,e=>{e.v(t=>Promise.all(["static/chunks/0baun3z.hlze~.js"].map(t=>e.l(t))).then(()=>t(68882)))},989792,e=>{e.v(t=>Promise.all(["static/chunks/07710kwr~_0.e.js"].map(t=>e.l(t))).then(()=>t(916507)))},629479,e=>{e.v(t=>Promise.all(["static/chunks/0v.rn646nuqs7.js"].map(t=>e.l(t))).then(()=>t(307488)))},587329,e=>{e.v(t=>Promise.all(["static/chunks/0d9awe5d081.2.js"].map(t=>e.l(t))).then(()=>t(878642)))},576337,e=>{e.v(t=>Promise.all(["static/chunks/0ogvtm3jmac~r.js"].map(t=>e.l(t))).then(()=>t(580134)))},524769,e=>{e.v(t=>Promise.all(["static/chunks/0ws4zt1qv5-55.js"].map(t=>e.l(t))).then(()=>t(731360)))},233880,e=>{e.v(t=>Promise.all(["static/chunks/12m63s1_cjg0~.js"].map(t=>e.l(t))).then(()=>t(723966)))},580778,e=>{e.v(t=>Promise.all(["static/chunks/0bumfg62.s.g..js"].map(t=>e.l(t))).then(()=>t(177170)))},176096,e=>{e.v(t=>Promise.all(["static/chunks/0yoghfwkswxeg.js"].map(t=>e.l(t))).then(()=>t(964284)))},684958,e=>{e.v(t=>Promise.all(["static/chunks/0gcq24lt2b72g.js"].map(t=>e.l(t))).then(()=>t(208405)))},646790,e=>{e.v(t=>Promise.all(["static/chunks/0gv8vfh~i9pse.js"].map(t=>e.l(t))).then(()=>t(621743)))},704815,e=>{e.v(t=>Promise.all(["static/chunks/0zixabptje-40.js"].map(t=>e.l(t))).then(()=>t(340986)))},98934,e=>{e.v(t=>Promise.all(["static/chunks/09rk~ly2q1buz.js"].map(t=>e.l(t))).then(()=>t(700930)))},762970,e=>{e.v(t=>Promise.all(["static/chunks/1115fwe9_44~8.js","static/chunks/10.~qslroat7t.js"].map(t=>e.l(t))).then(()=>t(343854)))},593201,e=>{e.v(t=>Promise.all(["static/chunks/0uhpbvd40ldiy.js"].map(t=>e.l(t))).then(()=>t(846310)))},211169,e=>{e.v(t=>Promise.all(["static/chunks/0rcd3t2i3-4oi.js"].map(t=>e.l(t))).then(()=>t(230230)))},445290,e=>{e.v(t=>Promise.all(["static/chunks/0.8qg9z5thaeh.js"].map(t=>e.l(t))).then(()=>t(924189)))},871926,e=>{e.v(t=>Promise.all(["static/chunks/07tq4no73cok6.js"].map(t=>e.l(t))).then(()=>t(995919)))},439890,e=>{e.v(t=>Promise.all(["static/chunks/12sshwfi~3pg4.js"].map(t=>e.l(t))).then(()=>t(511310)))},922605,e=>{e.v(t=>Promise.all(["static/chunks/0qc7ilezzs-aa.js"].map(t=>e.l(t))).then(()=>t(748558)))},260421,e=>{e.v(t=>Promise.all(["static/chunks/04k.r0ygqabhh.js"].map(t=>e.l(t))).then(()=>t(47375)))},967106,e=>{e.v(t=>Promise.all(["static/chunks/0i4yw6faulc.d.js"].map(t=>e.l(t))).then(()=>t(766583)))},272637,e=>{e.v(t=>Promise.all(["static/chunks/07np970eqbo60.js"].map(t=>e.l(t))).then(()=>t(329301)))},717929,e=>{e.v(t=>Promise.all(["static/chunks/0fm4br.pqse_v.js"].map(t=>e.l(t))).then(()=>t(701066)))},739128,e=>{e.v(t=>Promise.all(["static/chunks/0clu0h0nakxl0.js"].map(t=>e.l(t))).then(()=>t(91973)))},611005,e=>{e.v(t=>Promise.all(["static/chunks/0u6b.un4cj2d~.js"].map(t=>e.l(t))).then(()=>t(549362)))},506839,e=>{e.v(t=>Promise.all(["static/chunks/087~h7u0q296x.js"].map(t=>e.l(t))).then(()=>t(713866)))},650607,e=>{e.v(t=>Promise.all(["static/chunks/0guiobcf~7~h3.js"].map(t=>e.l(t))).then(()=>t(986513)))},48593,e=>{e.v(t=>Promise.all(["static/chunks/0ctdjfoxevtbb.js"].map(t=>e.l(t))).then(()=>t(418214)))},370277,e=>{e.v(t=>Promise.all(["static/chunks/03e2ajh12t-~6.js"].map(t=>e.l(t))).then(()=>t(858488)))},90278,e=>{e.v(t=>Promise.all(["static/chunks/0cdr~a0kac4v9.js"].map(t=>e.l(t))).then(()=>t(941820)))},10662,e=>{e.v(t=>Promise.all(["static/chunks/17c58ez67.yz_.js"].map(t=>e.l(t))).then(()=>t(126133)))},242924,e=>{e.v(t=>Promise.all(["static/chunks/16std1e9uygen.js"].map(t=>e.l(t))).then(()=>t(789046)))},413120,e=>{e.v(t=>Promise.all(["static/chunks/11~jh~aed1od..js"].map(t=>e.l(t))).then(()=>t(629472)))},252838,e=>{e.v(t=>Promise.all(["static/chunks/0f_gffw58o_dm.js"].map(t=>e.l(t))).then(()=>t(826615)))},788686,e=>{e.v(t=>Promise.all(["static/chunks/0l92d6kzfu8jg.js"].map(t=>e.l(t))).then(()=>t(759759)))},87758,e=>{e.v(t=>Promise.all(["static/chunks/0hfk_v5kflss2.js"].map(t=>e.l(t))).then(()=>t(624948)))},786799,e=>{e.v(t=>Promise.all(["static/chunks/0-kefdrf6ih5s.js"].map(t=>e.l(t))).then(()=>t(978156)))},784525,e=>{e.v(t=>Promise.all(["static/chunks/178~uy1pz6ka4.js"].map(t=>e.l(t))).then(()=>t(848913)))},277576,e=>{e.v(t=>Promise.all(["static/chunks/01ahds4cdfgmx.js"].map(t=>e.l(t))).then(()=>t(793012)))},768052,e=>{e.v(t=>Promise.all(["static/chunks/0d87nviml8v4v.js"].map(t=>e.l(t))).then(()=>t(313037)))},300810,e=>{e.v(t=>Promise.all(["static/chunks/0~830zvx2d6~-.js"].map(t=>e.l(t))).then(()=>t(448768)))},250904,e=>{e.v(t=>Promise.all(["static/chunks/0gmos.wajd.qx.js"].map(t=>e.l(t))).then(()=>t(781027)))},886105,e=>{e.v(t=>Promise.all(["static/chunks/0wb82s55d9~ye.js"].map(t=>e.l(t))).then(()=>t(630410)))},995184,e=>{e.v(t=>Promise.all(["static/chunks/0u17oyz1d609w.js"].map(t=>e.l(t))).then(()=>t(913839)))},373788,e=>{e.v(t=>Promise.all(["static/chunks/0r2n2_xlr0d38.js"].map(t=>e.l(t))).then(()=>t(948275)))},837652,e=>{e.v(t=>Promise.all(["static/chunks/0jl4bpoiy-t_p.js"].map(t=>e.l(t))).then(()=>t(320925)))},747401,e=>{e.v(t=>Promise.all(["static/chunks/0cg2.e5~fk5js.js"].map(t=>e.l(t))).then(()=>t(843760)))},918987,e=>{e.v(t=>Promise.all(["static/chunks/01dqogk35w.vs.js"].map(t=>e.l(t))).then(()=>t(419297)))},338140,e=>{e.v(t=>Promise.all(["static/chunks/1841t-k25y5iw.js"].map(t=>e.l(t))).then(()=>t(70045)))},834577,e=>{e.v(t=>Promise.all(["static/chunks/1452dyf5ry7n_.css","static/chunks/0-zghtc59y~6r.js","static/chunks/05x98j802~24f.js"].map(t=>e.l(t))).then(()=>t(79980)))},649857,e=>{e.v(t=>Promise.all(["static/chunks/17y-vwlw.bfs8.js"].map(t=>e.l(t))).then(()=>t(402966)))},758068,e=>{e.v(t=>Promise.all(["static/chunks/0~~24znpk8vc1.js"].map(t=>e.l(t))).then(()=>t(963698)))},273528,e=>{e.v(t=>Promise.all(["static/chunks/0n~94fkip2t8l.js"].map(t=>e.l(t))).then(()=>t(302001)))},554740,e=>{e.v(t=>Promise.all(["static/chunks/14wvgtevp151f.js"].map(t=>e.l(t))).then(()=>t(859411)))},884690,e=>{e.v(t=>Promise.all(["static/chunks/15evlvb3umxnn.js"].map(t=>e.l(t))).then(()=>t(689304)))},64898,e=>{e.v(t=>Promise.all(["static/chunks/1452dyf5ry7n_.css","static/chunks/0lzv.-11q~la_.js","static/chunks/05x98j802~24f.js"].map(t=>e.l(t))).then(()=>t(948269)))},63325,e=>{e.v(t=>Promise.all(["static/chunks/0zj59obk44-qh.js"].map(t=>e.l(t))).then(()=>t(299169)))},813116,e=>{e.v(t=>Promise.all(["static/chunks/0jcf7ay9pl-s0.js"].map(t=>e.l(t))).then(()=>t(419303)))},756465,e=>{e.v(t=>Promise.all(["static/chunks/0b-tgv1_m1uo9.js"].map(t=>e.l(t))).then(()=>t(990734)))},778933,e=>{e.v(t=>Promise.all(["static/chunks/0k530rgixl5kt.js"].map(t=>e.l(t))).then(()=>t(830740)))},33632,e=>{e.v(t=>Promise.all(["static/chunks/0fi49hn5~2abh.js"].map(t=>e.l(t))).then(()=>t(462292)))},332619,e=>{e.v(t=>Promise.all(["static/chunks/0eocendwectqa.js"].map(t=>e.l(t))).then(()=>t(142080)))},155649,e=>{e.v(t=>Promise.all(["static/chunks/0cr_6f10ae_q~.js"].map(t=>e.l(t))).then(()=>t(925278)))},220252,e=>{e.v(t=>Promise.all(["static/chunks/0na6onp8uomzi.js"].map(t=>e.l(t))).then(()=>t(81272)))}]);