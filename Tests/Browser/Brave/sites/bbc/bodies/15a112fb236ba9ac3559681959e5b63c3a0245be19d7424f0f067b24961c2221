(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,251870,t=>{"use strict";var e=function(){if("u">typeof Map)return Map;function t(t,e){var o=-1;return t.some(function(t,n){return t[0]===e&&(o=n,!0)}),o}function e(){this.__entries__=[]}return Object.defineProperty(e.prototype,"size",{get:function(){return this.__entries__.length},enumerable:!0,configurable:!0}),e.prototype.get=function(e){var o=t(this.__entries__,e),n=this.__entries__[o];return n&&n[1]},e.prototype.set=function(e,o){var n=t(this.__entries__,e);~n?this.__entries__[n][1]=o:this.__entries__.push([e,o])},e.prototype.delete=function(e){var o=this.__entries__,n=t(o,e);~n&&o.splice(n,1)},e.prototype.has=function(e){return!!~t(this.__entries__,e)},e.prototype.clear=function(){this.__entries__.splice(0)},e.prototype.forEach=function(t,e){void 0===e&&(e=null);for(var o=0,n=this.__entries__;o<n.length;o++){var i=n[o];t.call(e,i[1],i[0])}},e}(),o="u">typeof window&&"u">typeof document&&window.document===document,n=t.g.Math===Math?t.g:"u">typeof self&&self.Math===Math?self:"u">typeof window&&window.Math===Math?window:Function("return this")(),i="function"==typeof requestAnimationFrame?requestAnimationFrame.bind(n):function(t){return setTimeout(function(){return t(Date.now())},1e3/60)},r=["top","right","bottom","left","width","height","size","weight"],s="u">typeof MutationObserver,a=function(){function t(){this.connected_=!1,this.mutationEventsAdded_=!1,this.mutationsObserver_=null,this.observers_=[],this.onTransitionEnd_=this.onTransitionEnd_.bind(this),this.refresh=function(t){var e=!1,o=!1,n=0;function r(){e&&(e=!1,t()),o&&a()}function s(){i(r)}function a(){var t=Date.now();if(e){if(t-n<2)return;o=!0}else e=!0,o=!1,setTimeout(s,20);n=t}return a}(this.refresh.bind(this))}return t.prototype.addObserver=function(t){~this.observers_.indexOf(t)||this.observers_.push(t),this.connected_||this.connect_()},t.prototype.removeObserver=function(t){var e=this.observers_,o=e.indexOf(t);~o&&e.splice(o,1),!e.length&&this.connected_&&this.disconnect_()},t.prototype.refresh=function(){this.updateObservers_()&&this.refresh()},t.prototype.updateObservers_=function(){var t=this.observers_.filter(function(t){return t.gatherActive(),t.hasActive()});return t.forEach(function(t){return t.broadcastActive()}),t.length>0},t.prototype.connect_=function(){o&&!this.connected_&&(document.addEventListener("transitionend",this.onTransitionEnd_),window.addEventListener("resize",this.refresh),s?(this.mutationsObserver_=new MutationObserver(this.refresh),this.mutationsObserver_.observe(document,{attributes:!0,childList:!0,characterData:!0,subtree:!0})):(document.addEventListener("DOMSubtreeModified",this.refresh),this.mutationEventsAdded_=!0),this.connected_=!0)},t.prototype.disconnect_=function(){o&&this.connected_&&(document.removeEventListener("transitionend",this.onTransitionEnd_),window.removeEventListener("resize",this.refresh),this.mutationsObserver_&&this.mutationsObserver_.disconnect(),this.mutationEventsAdded_&&document.removeEventListener("DOMSubtreeModified",this.refresh),this.mutationsObserver_=null,this.mutationEventsAdded_=!1,this.connected_=!1)},t.prototype.onTransitionEnd_=function(t){var e=t.propertyName,o=void 0===e?"":e;r.some(function(t){return!!~o.indexOf(t)})&&this.refresh()},t.getInstance=function(){return this.instance_||(this.instance_=new t),this.instance_},t.instance_=null,t}(),c=function(t,e){for(var o=0,n=Object.keys(e);o<n.length;o++){var i=n[o];Object.defineProperty(t,i,{value:e[i],enumerable:!1,writable:!1,configurable:!0})}return t},l=function(t){return t&&t.ownerDocument&&t.ownerDocument.defaultView||n},u=f(0,0,0,0);function p(t){return parseFloat(t)||0}function d(t){for(var e=[],o=1;o<arguments.length;o++)e[o-1]=arguments[o];return e.reduce(function(e,o){return e+p(t["border-"+o+"-width"])},0)}var h="u">typeof SVGGraphicsElement?function(t){return t instanceof l(t).SVGGraphicsElement}:function(t){return t instanceof l(t).SVGElement&&"function"==typeof t.getBBox};function f(t,e,o,n){return{x:t,y:e,width:o,height:n}}var v=function(){function t(t){this.broadcastWidth=0,this.broadcastHeight=0,this.contentRect_=f(0,0,0,0),this.target=t}return t.prototype.isActive=function(){var t=function(t){if(!o)return u;if(h(t)){var e;return f(0,0,(e=t.getBBox()).width,e.height)}return function(t){var e,o=t.clientWidth,n=t.clientHeight;if(!o&&!n)return u;var i=l(t).getComputedStyle(t),r=function(t){for(var e={},o=0,n=["top","right","bottom","left"];o<n.length;o++){var i=n[o],r=t["padding-"+i];e[i]=p(r)}return e}(i),s=r.left+r.right,a=r.top+r.bottom,c=p(i.width),h=p(i.height);if("border-box"===i.boxSizing&&(Math.round(c+s)!==o&&(c-=d(i,"left","right")+s),Math.round(h+a)!==n&&(h-=d(i,"top","bottom")+a)),(e=t)!==l(e).document.documentElement){var v=Math.round(c+s)-o,m=Math.round(h+a)-n;1!==Math.abs(v)&&(c-=v),1!==Math.abs(m)&&(h-=m)}return f(r.left,r.top,c,h)}(t)}(this.target);return this.contentRect_=t,t.width!==this.broadcastWidth||t.height!==this.broadcastHeight},t.prototype.broadcastRect=function(){var t=this.contentRect_;return this.broadcastWidth=t.width,this.broadcastHeight=t.height,t},t}(),m=function(t,e){var o,n,i,r,s,a=(o=e.x,n=e.y,i=e.width,r=e.height,c(s=Object.create(("u">typeof DOMRectReadOnly?DOMRectReadOnly:Object).prototype),{x:o,y:n,width:i,height:r,top:n,right:o+i,bottom:r+n,left:o}),s);c(this,{target:t,contentRect:a})},b=function(){function t(t,o,n){if(this.activeObservations_=[],this.observations_=new e,"function"!=typeof t)throw TypeError("The callback provided as parameter 1 is not a function.");this.callback_=t,this.controller_=o,this.callbackCtx_=n}return t.prototype.observe=function(t){if(!arguments.length)throw TypeError("1 argument required, but only 0 present.");if(!("u"<typeof Element)&&Element instanceof Object){if(!(t instanceof l(t).Element))throw TypeError('parameter 1 is not of type "Element".');var e=this.observations_;e.has(t)||(e.set(t,new v(t)),this.controller_.addObserver(this),this.controller_.refresh())}},t.prototype.unobserve=function(t){if(!arguments.length)throw TypeError("1 argument required, but only 0 present.");if(!("u"<typeof Element)&&Element instanceof Object){if(!(t instanceof l(t).Element))throw TypeError('parameter 1 is not of type "Element".');var e=this.observations_;e.has(t)&&(e.delete(t),e.size||this.controller_.removeObserver(this))}},t.prototype.disconnect=function(){this.clearActive(),this.observations_.clear(),this.controller_.removeObserver(this)},t.prototype.gatherActive=function(){var t=this;this.clearActive(),this.observations_.forEach(function(e){e.isActive()&&t.activeObservations_.push(e)})},t.prototype.broadcastActive=function(){if(this.hasActive()){var t=this.callbackCtx_,e=this.activeObservations_.map(function(t){return new m(t.target,t.broadcastRect())});this.callback_.call(t,e,t),this.clearActive()}},t.prototype.clearActive=function(){this.activeObservations_.splice(0)},t.prototype.hasActive=function(){return this.activeObservations_.length>0},t}(),g="u">typeof WeakMap?new WeakMap:new e,y=function t(e){if(!(this instanceof t))throw TypeError("Cannot call a class as a function.");if(!arguments.length)throw TypeError("1 argument required, but only 0 present.");var o=new b(e,a.getInstance(),this);g.set(this,o)};["observe","unobserve","disconnect"].forEach(function(t){y.prototype[t]=function(){var e;return(e=g.get(this))[t].apply(e,arguments)}});var w=void 0!==n.ResizeObserver?n.ResizeObserver:y;t.s(["default",0,w])},468364,426710,t=>{"use strict";var e=t.i(191788),o=t.i(610503),n=t.i(251870);function i(t,i,r){(0,e.useEffect)(()=>{let e=new("u"<typeof ResizeObserver?n.default:ResizeObserver)(r?(0,o.default)(i,r,{leading:!0,trailing:!0}):i),s="function"==typeof t?t().current:t?.current;return s&&e&&e.observe(s),()=>{s&&e&&e.unobserve(s)}},[t,i])}t.s(["default",0,i],426710),t.s(["useResizeObserver",0,i],468364)},901414,t=>{"use strict";var e=t.i(191788),o=t.i(996847);let n=Object.entries(t.i(195214).breakpoints),i=!1,r=new Map,s=!1;t.s(["useBreakpoints",0,function(t){let[a,c]=(0,e.useState)("not-set");r.set(t,c);let l=t=>n.reduce((e,[o,[n,i]])=>n<=t&&t<=i?o:e,"group5"),u=(0,o.default)(()=>{r.forEach(t=>{t(l(window.innerWidth))})},300);return(0,e.useEffect)(()=>(s=!0,c(l(window.innerWidth)),i||(i=!0,window.addEventListener("resize",u)),()=>{}),[]),[a,s]}],901414)},167971,253772,t=>{"use strict";var e=t.i(391398),o=t.i(191788),n=t.i(730943),i=t.i(901414),r=t.i(468364),s=t.i(65739),a=t.i(760814),c=t.i(339228);let l=a.css`
  clip-path: polygon(50% 0%, 100% 50%, 50% 100%, 0% 50%);
  width: 16px;
  height: 12px;
`,u=(t,e,o)=>o?t.container.onDefaultBG4.value:e?t.container.onInverseBG3.value:t.container.onDefaultBG3.value,p=a.default.div.withConfig({displayName:"Popover.styles__PopoverOverlayBgStyled",componentId:"sc-a280de2f-0"})`
  display: none;

  ${(0,c.applyStylesForBreakpoints)(a.css`
      display: block;
      position: fixed;
      top: 0;
      left: 0;
      z-index: 0;
      opacity: 0.2;
      width: 100%;
      height: 100%;
      background-color: #000000;
    `,"group1","group2")};
`,d=a.default.div.withConfig({displayName:"Popover.styles__PopoverWrapperStyled",componentId:"sc-a280de2f-1"})`
  position: relative;
  display: flex;
  align-items: center;
`,h=a.default.div.withConfig({displayName:"Popover.styles__PopoverStyled",componentId:"sc-a280de2f-2"})`
  ${({theme:t,$isOpen:e,$animate:o,$alignment:n,$widthDiff:i,$withTransition:r,$isInverse:s,$isLight:p,$isOnLeftEdge:d})=>a.css`
    position: absolute;
    min-width: 140px;
    background-color: ${u(t,s,p)};
    width: fit-content;
    display: ${e?"grid":"none"};
    justify-items: start;
    padding: 16px;
    top: 50%;
    opacity: ${+!!o};
    z-index: 10000;

    ${r&&a.css`
      transition: opacity 0.2s linear;
    `}

    &::before {
      display: block;
      content: '';
      background-color: ${u(t,s,p)};
      ${l};
      position: absolute;
    }

    /* !important is needed to beat parent layouts that force a colour on all descendants, e.g. the listicle layout */
    ${p&&a.css`
      button {
        color: ${t.interactive5.onDefaultBG.default.value} !important;

        &:hover,
        &:focus,
        &:active {
          color: ${t.interactive5.onDefaultBG.default.value} !important;
        }

        &:focus {
          outline-color: ${t.interactive5.onDefaultBG.pressed.value};
        }

        &:disabled {
          color: ${t.interactive5.onDefaultBG.disabled.value} !important;
        }

        * {
          color: inherit !important;
        }
      }
    `}

    /* top and bottom */

    ${"top"===n&&a.css`
      top: unset;
      bottom: calc(100% + 12px);
      left: ${`-${i}px`};

      &::before {
        top: unset;
        bottom: 0;
        left: calc(50% - 8px);
        transform: translateY(50%);
      }
    `}

    ${"bottom"===n&&a.css`
      left: ${`-${i}px`};
      top: calc(100% + 8px);
      bottom: unset;

      ${(0,c.applyStylesForBreakpoints)(a.css`
          max-height: calc(100vh - 32px);
          overflow-y: auto;
        `,"group2")}

      ${d&&a.css`
        @media screen and (max-width: 1366px) and (min-width: 1008px) {
          left: ${`calc(-${i}px + 60px)`};
        }
      `}

      &::before {
        transform: translateY(-50%);
        left: calc(50% - 8px);
        bottom: unset;
        top: 0;

        @media screen and (max-width: 1366px) and (min-width: 1008px) {
          left: calc(12% - 8px);
        }
      }
    `}

    /* top / bottom + right / left */

    ${"top-right"===n&&a.css`
      top: unset;
      right: 0;
      bottom: calc(100% + 12px);

      &::before {
        top: unset;
        bottom: 0;
        right: 8px;
        transform: translateY(50%);
      }
    `}

    ${"top-left"===n&&a.css`
      top: unset;
      bottom: calc(100% + 12px);

      &::before {
        top: unset;
        bottom: 0;
        left: 8px;
        transform: translateY(50%);
      }
    `}


    ${"bottom-right"===n&&a.css`
      bottom: unset;
      top: calc(100% + 8px);
      left: unset;
      right: 0;

      &::before {
        bottom: unset;
        top: 0;
        right: 8px;
        transform: translateY(-50%);
      }
    `}

    ${"bottom-left"===n&&a.css`
      bottom: unset;
      top: calc(100% + 8px);

      &::before {
        bottom: unset;
        top: 0;
        left: 8px;
        transform: translateY(-50%);
      }
    `} /* left and right */


    ${"left"===n&&a.css`
      transform: translateX(-100%) translateY(-50%);

      &::before {
        ${l};
        top: calc(50% - 8px);
        right: 0;
        transform: translateX(50%);
      }
    `}

    ${"right"===n&&a.css`
      left: unset;
      transform: translateX(100%) translateY(-50%);
      right: 0;

      &::before {
        ${l};
        top: calc(50% - 8px);
        left: 0;
        transform: translateX(-50%);
      }
    `} /* left / right + top / bottom */

    ${"left-top"===n&&a.css`
      bottom: unset;
      top: 0;
      transform: translateX(-100%);

      &::before {
        ${l};
        bottom: unset;
        right: 0;
        top: 8px;
        transform: translateX(50%);
      }
    `}


    ${"left-bottom"===n&&a.css`
      bottom: 0;
      top: unset;
      transform: translateX(-100%);

      &::before {
        ${l};
        bottom: 8px;
        right: 0;
        top: unset;
        transform: translateX(50%);
      }
    `}

    ${"right-top"===n&&a.css`
      bottom: unset;
      top: 0;
      right: 0;
      transform: translateX(100%);

      &::before {
        ${l};
        bottom: unset;
        left: 0;
        top: 8px;
        transform: translateX(-50%);
      }
    `}


    ${"right-bottom"===n&&a.css`
      bottom: 0;
      top: unset;
      transform: translateX(100%);
      right: 0;

      &::before {
        ${l};
        bottom: 8px;
        left: 0;
        top: unset;
        transform: translateX(-50%);
      }
    `}
  `}

  ${(0,c.applyStylesForBreakpoints)(a.css`
      margin-left: -16px;
      margin-right: -16px;
      width: calc(100vw - 32px);
      padding: 24px 16px;
      position: fixed;
      top: unset;
      bottom: 0;
      left: 16px;
      right: unset;
      display: grid;

      /* TODO
      this should come from the content property => the content should
      determine the gap between its components, not the Popover
      */
      gap: 16px;

      &::before {
        display: none;
      }
    `,"group1","group2")};
`,f=a.default.button.withConfig({displayName:"Popover.styles__CloseButton",componentId:"sc-a280de2f-3"})`
  display: none;
  ${(0,c.applyStylesForBreakpoints)(a.css`
      ${({theme:t,$isLight:e})=>a.css`
        display: block;
        position: absolute;
        transform: translateX(calc(-100%));
        right: 0;
        top: 24px;
        cursor: pointer;
        color: ${e?t.interactive5.onDefaultBG.default.value:t.interactive5.onInverseBG.default.value};
      `};
    `,"group1","group2")};
`;t.s(["CloseButton",0,f,"PopoverOverlayBgStyled",0,p,"PopoverStyled",0,h,"PopoverWrapperStyled",0,d],253772);let v=(0,o.memo)((0,o.forwardRef)(({content:t,trigger:o,isOpen:n,isInverse:i,isLight:r,isOnLeftEdge:a,withOverlayBackground:c,withTransition:l,animate:u,transition:d,alignment:v,widthDiff:m,togglePopover:b},g)=>(0,e.jsxs)(e.Fragment,{children:[c&&(0,e.jsx)(p,{"data-testid":"popoverOverlay"}),(0,e.jsx)(h,{ref:g,$isOnLeftEdge:a,$isInverse:i,$isLight:r,"data-testid":"popoverStyled",className:"popover",$isOpen:n,$withTransition:l,$animate:u,$transition:d,$alignment:v,$widthDiff:m??0,tabIndex:-1,children:(0,e.jsxs)(e.Fragment,{children:[t,"hover"!==o&&(0,e.jsx)(f,{"data-testid":"popoverCloseButton",$isLight:r,onClick:()=>b(!1),children:(0,e.jsx)(s.default,{name:"actions:close",width:20,height:20})})]})})]})));t.s(["default",0,({content:t,trigger:s="click",alignment:a="bottom",withTransition:c,transition:l,children:u,isInverse:p=!1,isLight:h=!1,isOnLeftEdge:f,withOverlayBackground:m=!1,onOpenChange:b})=>{let[g,y]=(0,o.useState)(!1),[w,x]=(0,o.useState)(null),[_,k]=(0,o.useState)(null),[S,$]=(0,o.useState)(!1),[C]=(0,i.useBreakpoints)("popover"),E=["group1","group2"].includes(C),O=(0,o.useRef)(null),B=(0,o.useRef)(null),I=(0,o.useRef)(null),R=(0,o.useCallback)(t=>{if(B.current=t,t){let{height:e,width:o}=t.getBoundingClientRect();k({height:e,width:o}),"click"===s&&requestAnimationFrame(()=>{t&&(t.focus(),"function"==typeof t.scrollIntoView&&t.scrollIntoView({behavior:"smooth",block:"nearest"}))})}},[s]),P=(0,o.useCallback)(t=>{if(I.current=t,t){let{height:e,width:o}=t.getBoundingClientRect();x({height:e,width:o})}},[]);(0,r.useResizeObserver)(B,t=>{let[{contentRect:e}]=t,{height:o,width:n}=e;(_?.height!==o||_?.width!==n)&&k({height:o,width:n})},100),(0,r.useResizeObserver)(I,t=>{let[{contentRect:e}]=t,{height:o,width:n}=e;(w?.height!==o||w?.width!==n)&&x({height:o,width:n})},100);let T=(0,o.useCallback)(t=>{let e=t?y:$,o=t?$:y,n=t?10:200;e(t),setTimeout(()=>{o(t)},n),b?.(t)},[b]),A=(0,o.useCallback)(()=>"hover"===s&&T(!g),[g,T,s]),j=(0,o.useCallback)(()=>"focus"===s&&T(!g),[g,T,s]),L=(0,o.useCallback)(()=>"click"===s?null:"hover"===s&&T(!1),[T,s]),M=(0,o.useCallback)(()=>"click"!==s&&T(!1),[T,s]),F=(0,o.useCallback)(t=>{O.current&&!O.current?.contains(t.target)&&T(!1)},[T]);(0,o.useEffect)(()=>(document.addEventListener("click",t=>F(t)),document.addEventListener("keydown",t=>{let{key:e,keyCode:o}=t;("Escape"===e||"Esc"===e||27===o)&&(T(!1),document.activeElement.blur())}),()=>document.removeEventListener("click",F)),[M,T,g,F]);let D=_&&w&&Math.abs(_?.width-w?.width)/2;return u?(0,e.jsxs)(d,{"data-testid":"popoverWrapper",ref:O,id:"popover-wrapper",onClick:t=>{let e=t.target;"click"===s&&e?.closest("#popover-trigger")&&T(!g)},onMouseEnter:A,onMouseLeave:L,onBlur:M,onFocus:j,children:[(0,e.jsx)("div",{"data-testid":"popoverTrigger",id:"popover-trigger",ref:P,children:u}),g&&(E?(0,n.createPortal)((0,e.jsx)(v,{ref:R,content:t,trigger:s,isOpen:g,isInverse:p,isLight:h,isOnLeftEdge:f,withOverlayBackground:m,withTransition:c,animate:S,transition:l,alignment:a,widthDiff:D,togglePopover:T}),document.body):(0,e.jsx)(v,{ref:R,content:t,trigger:s,isOpen:g,isInverse:p,isLight:h,isOnLeftEdge:f,withOverlayBackground:m,withTransition:c,animate:S,transition:l,alignment:a,widthDiff:D,togglePopover:T}))]}):null}],167971)},490602,t=>{"use strict";var e=t.i(391398),o=t.i(84541),n=t.i(868783),i=t.i(746857),r=t.i(704570),s=t.i(167971),a=t.i(191788);let c={facebook:{text:"Facebook",icon:"social:facebook",onClick:t=>{let e=`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(t)}`;window.open(e,"_blank")}},twitter:{text:"X (Twitter)",icon:"social:x",onClick:t=>{let e=`https://twitter.com/intent/tweet?url=${encodeURIComponent(t)}`;window.open(e,"_blank")}},linkedin:{text:"LinkedIn",icon:"social:linkedin",onClick:t=>{let e=encodeURIComponent(t),o=`https://www.linkedin.com/shareArticle?mini=true&url=${e}`;window.open(o,"_blank")}},email:{text:"Email",icon:"social:email",onClick:(t,e)=>{let o=`Shared from BBC: ${e||t}`,n=`Check this out from the BBC: ${t}`,i=`mailto:?subject=${encodeURIComponent(o)}&body=${encodeURIComponent(n)}`;window.location.href=i}},copy:{text:"Copy",icon:"social:copy",onClick:async t=>{await navigator.clipboard.writeText(t)}}},l=({type:t,withoutPadding:n=!1,link:i,isInverse:r=!0,title:s,isAv:l,contentId:u,avProperties:p,contentTopic:d})=>{let h=c[t],[f,v]=(0,a.useState)(!1),{onClick:m,text:b,icon:g}=h;return(0,e.jsx)(o.default,{withoutPaddingInline:n,testId:`${t}ShareButton`,type:"social-unboxed-share",isInverse:r,icon:f?"actions:checkmark":g,onClick:()=>{"copy"===t&&v(!0),window.analytics.sendEvent({eventGrouping:l?"av_share":"article_share",eventProperties:{item_name:t,item_link:i,contentId:u,...p||{},...d?{content_topic:d}:{}}}),m(i,s)},text:f?"Link copied":b,disabled:f,isInPopover:!0})},u=(t,o,n,i,r,s,a)=>Object.keys(c).map((c,u)=>(0,e.jsx)(l,{isAv:i,type:c,...r&&{contentId:r},contentTopic:s,link:`https://bbc.com${t}`,isInverse:o,group_name:"share_menu",title:n,avProperties:a},u)),p=(0,n.withCMSFallback)(({trigger:t,isInverse:n=!1,isButtonInverse:a=!1,isPopoverLight:c=!1,iconPosition:l="left",withoutPaddingInline:p=!1,href:d,title:h,isOnLeftEdge:f,type:v="unboxed-share",size:m="small",alignment:b,withOverlayBackground:g=!1,avProperties:y,iconOnly:w=!1,isAvContent:x,onOpenChange:_})=>{let{asPath:k}=(0,i.useAppRouter)(),{type:S,id:$=""}=(0,r.usePageData)(),C=u(d||k,n,h,x??("audio"===S||"video"===S||"/video"===k),$,"",y);return(0,e.jsx)(s.default,{withOverlayBackground:g,alignment:b,isInverse:n,isLight:c,trigger:t,content:C,isOnLeftEdge:f,onOpenChange:_,children:(0,e.jsx)(o.default,{isInverse:a,withoutPaddingInline:p,size:m,iconPosition:l,testId:"socialShareTriggerButton",type:v,icon:"social:share",ariaLabel:w?"Share":void 0,...!w&&{text:"Share"}})})},({isInverse:t=!1,iconPosition:n="left",withoutPaddingInline:i=!1,trigger:r,isOnLeftEdge:a,href:u=window.location.pathname})=>(0,e.jsx)(s.default,{isInverse:t,trigger:r,content:Object.keys(c).map((o,n)=>(0,e.jsx)(l,{type:o,link:u,isInverse:t,isAv:!1,contentTopic:""},n)),isOnLeftEdge:a,children:(0,e.jsx)(o.default,{isInverse:t,withoutPaddingInline:i,size:"small",iconPosition:n,testId:"socialShareTriggerButton",type:"unboxed-share",icon:"social:share",text:"Share"})}));t.s(["default",0,p,"getSocialPopoverContent",0,u],490602)},542383,825893,t=>{"use strict";var e=t.i(191788),o=t.i(391398),n=t.i(480495),i=t.i(317166),r=t.i(830945);let s=(0,e.createContext)({dotcom:{isConsentReady:!1,hasFullSourcepointConsent:!1,hasTaboolaConsent:!1,hasChartbeatConsent:!1,hasOptimizelyConsent:!1},account:{hasPersonalizedContentConsent:!1}}),{Provider:a}=s;t.s(["UserConsentContext",0,s,"UserConsentProvider",0,({children:t})=>{let[s,c]=(0,e.useState)(!1),[l,u]=(0,e.useState)(!1),[p,d]=(0,e.useState)(!1),[h,f]=(0,e.useState)(!1),[v,m]=(0,e.useState)(!1),[b,g]=(0,e.useState)(!1),{isSignedIn:y}=(0,i.useUser)();return(0,e.useEffect)(()=>{let t=()=>{window.removeEventListener("ngas:consentReady",t),c(!0),u(window?.dotcom?.consent?.sp===2),f(window.dotcom.consent.gppApplies?2===window.dotcom.consent.sp:!!window.dotcom.consent.gdprApplies&&!!window.dotcom.consent.vendor.taboola),m(!window.dotcom.consent.gdprApplies||window.dotcom.consent?.vendorCustom?.chartbeat===!0),g(!window.dotcom.consent.gdprApplies||window.dotcom.consent?.vendorCustom?.optimizely===!0)};return window?.dotcom?.consent?.consentReady?t():window.addEventListener("ngas:consentReady",t),()=>window.removeEventListener("ngas:consentReady",t)},[]),(0,e.useEffect)(()=>{try{if(y&&l){let t=String((0,n.getCookie)(r.USER_ID)),{ep:e}=JSON.parse(atob(t));d(!!e)}else d(l)}catch{d(l)}},[l,y]),(0,o.jsx)(a,{value:{dotcom:{isConsentReady:s,hasFullSourcepointConsent:l,hasTaboolaConsent:h,hasChartbeatConsent:v,hasOptimizelyConsent:b},account:{hasPersonalizedContentConsent:p}},children:t})}],825893),t.s(["useConsent",0,function(){return(0,e.useContext)(s)}],542383)},524431,t=>{"use strict";var e=t.i(191788),o=t.i(520087),n=t.i(542383),i=t.i(519894),r=t.i(704570),s=t.i(227162),a=t.i(395497);let c={"Facebook.ActionSource":"website","Facebook.EventSourceUrl":"https://www.bbc.com"};t.s(["useLogMparticleEvent",0,function(){let t=(0,i.useFeatureFlag)("mparticle-sdk"),l=s.appConfig.getValue(a.ConfigSettings.MparticleKey),{country:u}=(0,r.usePageData)(),{dotcom:{hasFullSourcepointConsent:p}}=(0,n.useConsent)();return(0,e.useCallback)((e,n,i)=>{t&&l&&"us"===u&&p&&(o.default.logEvent(e,o.default.EventType.Other,{source:"piano",eventName:e,page:window.location.toString(),referrer:document.referrer,userAgent:navigator.userAgent,...n},c),i?.forceUpload&&o.default.upload())},[t,l,u,p])}],524431)},686764,t=>{"use strict";t.s(["default",0,({condition:t,wrapper:e,children:o})=>t?e(o):o])},162644,t=>{"use strict";var e=t.i(391398),o=t.i(746857),n=t.i(704570),i=t.i(167971),r=t.i(490602),s=t.i(760814),a=t.i(339228),c=t.i(84541),l=t.i(567290);let u=(0,s.default)(c.default).withConfig({displayName:"SocialSharePopover.styles__VideoSocialShareButtonStyled",componentId:"sc-4998b4eb-0"})`
  min-width: unset;

  ${l.ButtonText} {
    display: none;
  }
  ${(0,a.applyStylesForBreakpoints)(s.css`
      min-width: 126px;

      ${l.ButtonText} {
        display: inline-block;
      }
    `,"group2")};
`;t.s(["default",0,({title:t,avProperties:s,contentTopic:a})=>{let{asPath:c}=(0,o.useAppRouter)(),{id:l=""}=(0,n.usePageData)(),p=(0,r.getSocialPopoverContent)(c,!0,t,!0,l,a,s);return(0,e.jsx)(i.default,{content:p,alignment:"bottom-left",children:(0,e.jsx)(u,{isInverse:!0,size:"large",iconPosition:"left",testId:"socialShareTriggerButton",type:"round",icon:"social:share",text:"Share"})})}],162644)},818883,t=>{"use strict";var e=t.i(760814),o=t.i(339228),n=t.i(570549),i=t.i(84541);let r=e.default.div.withConfig({displayName:"SeriesCtas.styles__SeriesCtasStyled",componentId:"sc-bca9824d-0"})`
  display: flex;
  column-gap: 16px;

  ${(0,o.applyStylesForBreakpoints)(e.css`
      display: grid;
      row-gap: 12px;
    `,"group2")};
`,s=(0,e.default)(i.default).withConfig({displayName:"SeriesCtas.styles__SeriesCtasButtonStyled",componentId:"sc-bca9824d-1"})`
  width: 248px;
  height: 44px;

  ${(0,o.applyStylesForBreakpoints)(e.css`
      width: 203px;
    `,"group3")};

  ${(0,o.applyStylesForBreakpoints)(e.css`
      width: 100%;
    `,"group2")};
`,a=e.default.div.withConfig({displayName:"SeriesCtas.styles__SeriesCtasExtraActionsStyled",componentId:"sc-bca9824d-2"})`
  display: flex;
  column-gap: 8px;

  ${(0,o.applyStylesForBreakpoints)(e.css`
      padding-block: 4px 0;
      column-gap: 4px;
    `,"group2")};
`,c=e.default.span.withConfig({displayName:"SeriesCtas.styles__SeriesPrimaryCtaLoadingStateStyled",componentId:"sc-bca9824d-3"})`
  ${({theme:t})=>e.css`
    width: 248px;
    height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: ${t.container.onInverseBG3.value};
    color: ${t.interactiveInnner.onInverseBG.value};
    cursor: not-allowed;

    ${(0,o.applyStylesForBreakpoints)(e.css`
        width: 203px;
      `,"group3")};

    ${(0,o.applyStylesForBreakpoints)(e.css`
        width: unset;
      `,"group2")};
  `};
`,l=e.default.button.withConfig({displayName:"SeriesCtas.styles__SeriesSubscribeButtonStyled",componentId:"sc-bca9824d-4"})`
  ${({theme:t})=>e.css`
    background-color: ${t.subscription.button.default.normal.background.value};
    color: ${t.subscription.button.default.normal.content.value};
    cursor: pointer;
    border: 2px solid ${t.subscription.button.default.normal.background.value};
    ${(0,n.applyTypography)(t.button.regular)};
    width: 248px;
    display: flex;
    line-height: 28px;
    padding: 6px 36px;

    svg {
      width: 14px;
      height: 28px;
      margin-right: 8px;
    }
    ${(0,o.applyStylesForBreakpoints)(e.css`
        width: 203px;
        padding: 6px 16px;
      `,"group3")};
    ${(0,o.applyStylesForBreakpoints)(e.css`
        width: 100%;
        padding: 6px 24px;
        justify-content: center;
      `,"group2")};

    &:hover,
    &:focus {
      background-color: ${t.subscription.button.hover.normal.background.value};
      border: 2px solid ${t.subscription.button.hover.normal.background.value};
      outline: 2px solid ${t.subscription.button.hover.normal.background.value};
    }

    &:focus {
      outline: none;
      position: relative;
      border: 2px solid ${t.subscription.button.default.normal.content.value};

      &::before {
        content: '';
        inset: -3.5px;
        border: 2px solid ${t.subscription.button.focused.normal.stroke.value};
        position: absolute;
      }
    }
  `};
`;t.s(["SeriesCtasButtonStyled",0,s,"SeriesCtasExtraActionsStyled",0,a,"SeriesCtasStyled",0,r,"SeriesPrimaryCtaLoadingStateStyled",0,c,"SeriesSubscribeButtonStyled",0,l])}]);