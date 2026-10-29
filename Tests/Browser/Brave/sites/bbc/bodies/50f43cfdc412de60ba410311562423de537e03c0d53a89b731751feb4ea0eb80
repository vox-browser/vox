(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,551068,e=>{"use strict";var t=e.i(760814),n=e.i(339228),a=e.i(570549),i=e.i(222009),o=e.i(680516);let r=t.default.section.withConfig({displayName:"Navigation.styles__NavigationSectionStyled",componentId:"sc-f1c1fa10-0"})`
  ${({theme:e,isFit:a})=>t.css`
    border-bottom: 1px solid ${e.nav.lines.value};
    position: relative;
    text-align: center;
    overflow: hidden;
    line-height: 0;
    max-width: 100vw;

    ${!a&&t.css`
      height: 0;
      border-bottom-color: transparent;
    `};

    ${(0,i.applyZIndex)("level3")};

    ${(0,n.applyStylesForBreakpoints)(t.css`
        border-bottom: none;
        display: none;
      `,"group4")};
  `};
`,s=t.default.nav.withConfig({displayName:"Navigation.styles__NavigationWrapper",componentId:"sc-f1c1fa10-1"})`
  display: inline-block;
  overflow-x: hidden;
  white-space: nowrap;
  margin-bottom: -1px;
`,l=t.default.ul.withConfig({displayName:"Navigation.styles__MainNavigationWrapper",componentId:"sc-f1c1fa10-2"})`
  list-style-type: none;
  display: flex;
  padding: 0;
  margin: 0;
  align-self: center;

  ${(0,n.applyStylesForBreakpoints)(t.css`
      display: none;
    `,"group4")};
`,c=t.default.li.withConfig({displayName:"Navigation.styles__MainNavigationItemStyled",componentId:"sc-f1c1fa10-3"})`
  ${({isActive:e,isSpecial:n,isNews:a,theme:i})=>t.css`
    position: relative;

    ${e&&t.css`
      &::after {
        content: '';
        width: 100%;
        height: 4px;
        background-color: ${a?i.bbcNewsLogo.onDefaultBG.default.value:"#000000"};
        position: absolute;
        left: 0;
        bottom: 0;
      }
    `}

    ${n&&t.css`
      &::before {
        content: '';
        position: absolute;
        width: 1px;
        height: 30px;
        background: ${i.nav.lines.value};
        left: 0;
        top: 50%;
        transform: translateY(-50%);
      }
    `}
  `};
`,d=t.default.a.withConfig({displayName:"Navigation.styles__MainNavigationLink",componentId:"sc-f1c1fa10-4"})`
  ${({theme:e,$isActive:n})=>t.css`
    position: relative;
    display: block;
    color: ${e.nav.content.value};
    cursor: pointer;
    padding: 12px 8px;

    &:hover {
      background-color: ${({theme:e})=>e.nav.level1.bgHover.value};
    }

    ${(0,a.applyTypography)(e.nav.topbar.level1[n?"selected":"default"])};
  `}
`,p=t.default.li.withConfig({displayName:"Navigation.styles__SubNavigationItemStyled",componentId:"sc-f1c1fa10-5"})`
  ${({isSpecial:e,theme:n})=>t.css`
    position: relative;
    display: inline-block;
    border-left: 1px solid ${e?n.nav.lines.value:"transparent"};

    &[data-hidden='true'] {
      display: none;
    }
  `}
`,u=(0,t.default)(d).withConfig({displayName:"Navigation.styles__SubNavigationLink",componentId:"sc-f1c1fa10-6"})`
  ${({theme:e,$isInverse:n,$isActive:i})=>t.css`
    ${n&&t.css`
      color: ${e.text.onInverseBG.default.value};
    `}

    padding: 8px;
    ${(0,a.applyTypography)(e.nav.topbar.level2[i?"selected":"default"])};

    &:hover {
      ${n&&t.css`
        color: ${e.text.default.value};
      `}
      background-color: ${({theme:e})=>e.nav.level2.bgHover.value};
    }
  `};
`,g=t.default.li.withConfig({displayName:"Navigation.styles__DropDownNavigationItemStyled",componentId:"sc-f1c1fa10-7"})`
  text-align: left;

  & + & {
    margin-top: 16px;
  }
`,f=t.default.a.withConfig({displayName:"Navigation.styles__DropDownNavigationLinkStyled",componentId:"sc-f1c1fa10-8"})`
  ${({theme:e,$isActive:n})=>t.css`
    display: block;
    text-decoration: none;
    color: ${e.nav.content.value};
    ${(0,a.applyTypography)(e.nav.topbar.level2.default)};

    ${n&&t.css`
      font-weight: bold;
    `}
  `};
`,h=t.default.nav.withConfig({displayName:"Navigation.styles__NavigationContainerStyled",componentId:"sc-f1c1fa10-9"})`
  ${({theme:e,$priority:a,$top:r,$showNavOnScroll:s})=>t.css`
    ${(0,i.applyZIndex)(a?"level3":"level2")};
    position: sticky;
    background-color: ${e.nav.background.value};
    top: ${Math.max(r,o.DEFAULT_HEADER_HEIGHT)}px;
    left: 0;
    right: 0;
    transform: ${s?"translateY(0)":"translateY(-150%)"};
    transition: transform 0.5s ease;

    ${(0,n.applyStylesForBreakpoints)(t.css`
        height: 0;
      `,"group4")};
  `};
`,m=t.default.div.withConfig({displayName:"Navigation.styles__NestedNavItemLinkStyled",componentId:"sc-f1c1fa10-10"})`
  ${({$isClicked:e})=>t.css`
    ${e&&t.css`
      pointer-events: none;
    `};
  `}

  width: 100%;
  height: 100%;

  a {
    padding: 0 8px;
    width: 100%;
    height: 100%;
    text-align: left;
    align-items: center;
    vertical-align: bottom;
    display: flex;
  }
`;e.s(["DropDownNavigationItemStyled",0,g,"DropDownNavigationLinkStyled",0,f,"MainNavigationItemStyled",0,c,"MainNavigationLink",0,d,"MainNavigationWrapper",0,l,"NavigationContainerStyled",0,h,"NavigationSectionStyled",0,r,"NavigationWrapper",0,s,"NestedNavItemLinkStyled",0,m,"SubNavigationItemStyled",0,p,"SubNavigationLink",0,u])},421237,e=>{"use strict";var t=e.i(391398),n=e.i(191788),a=e.i(939648);let i=(0,n.createContext)({showNav:!0,headerHeight:a.HEADER_DEFAULT_HEIGHT});e.s(["HeaderStateContext",0,i,"default",0,({children:e,value:n})=>(0,t.jsx)(i.Provider,{value:n,children:e})])},257539,149250,e=>{"use strict";var t=e.i(746857),n=e.i(519894),a=e.i(789799),i=e.i(232489);e.s(["useAuthAndBookmarkActions",0,e=>{let{asPath:o}=(0,t.useAppRouter)(),r=(0,n.useFeatureFlag)("authentication"),s=(0,n.useFeatureFlag)("bookmarking"),{isSignedIn:l,signInUrl:c,statusUrl:d,settingsUrl:p,registerUrl:u,signOutUrl:g}=e,{isSubscribed:f,isSubscriptionAllowed:h}=(0,a.useSubscriptionContext)(),m=[],v={saved_items:(0,i.getHref)("","saved_items"),your_account:(0,i.getHref)(d,"your_account",o),settings:(0,i.getHref)(p,"settings",o),sign_out:(0,i.getHref)(g,"sign_out",o),register:(0,i.getHref)(u,"register",o),sign_in:(0,i.getHref)(c,"sign_in",o),manage_subscription:(0,i.getHref)("","manage_subscription")},y={sign_in:{eventGrouping:"sign_in",eventProperties:{group_name:"account_option",item_link:v.sign_in}},register:{eventGrouping:"register",eventProperties:{group_name:"account_option",item_link:v.register}}},b={your_account:{eventGrouping:"account_option",eventProperties:{item_name:"your_account",item_link:v.your_account}},settings:{eventGrouping:"account_option",eventProperties:{item_name:"settings",item_link:v.settings}},saved_items:{eventGrouping:"account_option",eventProperties:{item_name:"saved_items",item_link:v.saved_items}},sign_out:{eventGrouping:"account_option",eventProperties:{item_name:"sign_out",item_link:v.sign_out}},manage_subscription:{eventGrouping:"account_option",eventProperties:{item_name:"manage_subscription",item_link:v.manage_subscription}}};return r&&s&&l&&m.push({actionName:"saved_items",analytics:b.saved_items,href:v.saved_items,icon:"account:saved-items-outlined",showInHeader:!0,text:"Saved",type:"unboxed"}),r&&(l?(m.push({actionName:"your_account",analytics:b.your_account,href:v.your_account,icon:"account:sign-in",showInHeader:!1,text:"Your Account",type:"unboxed"},{actionName:"settings",analytics:b.settings,href:v.settings,icon:"account:settings",showInHeader:!0,text:"Settings"}),f&&m.push({actionName:"manage_subscription",analytics:b.manage_subscription,href:v.manage_subscription,icon:"account:subscription",showInHeader:!0,text:"Subscription"}),m.push({actionName:"sign_out",analytics:b.sign_out,href:v.sign_out,icon:"account:sign-out",showInHeader:!0,text:"Sign Out"})):(h||m.push({actionName:"register",analytics:y.register,href:v.register,showInHeader:!0,text:"Register"}),m.push({actionName:"sign_in",analytics:y.sign_in,href:v.sign_in,showInHeader:!0,text:"Sign In",type:"unboxed"}))),m}],257539);var o=e.i(191788),r=e.i(610503);e.s(["useHeaderScroll",0,({headerRef:e})=>{let t=(0,o.useRef)(0),[n,a]=(0,o.useState)(!0),[i,s]=(0,o.useState)(!0),l=(0,o.useRef)(0),c=(0,o.useCallback)(e=>{n!==e&&a(e)},[n]),d=(0,o.useCallback)(e=>{i!==e&&s(e)},[i]);return(0,o.useEffect)(()=>{e.current&&(t.current=e.current.getBoundingClientRect().top)},[e]),(0,o.useEffect)(()=>{let e=t.current+80,n=(0,r.default)(()=>{let t=window.scrollY,n=l.current,a=t>=n,i=Math.abs(t-n);t<e?(c(!0),d(!0)):a&&n<e&&i>16?(c(!1),d(!1)):a?i>=150&&(c(!1),d(!1)):i>=150&&(c(!1),d(!0)),l.current=t},100,{leading:!0,trailing:!0});return window.addEventListener("scroll",n),()=>{window.removeEventListener("scroll",n),n.cancel()}},[n,i,c,d]),{isHeaderDefaultSize:n,showNav:i}}],149250)},333109,394527,871071,219717,967223,e=>{"use strict";var t,n,a,i,o,r=e.i(191788),s=e.i(480495),l=-1,c=function(e){addEventListener("pageshow",function(t){t.persisted&&(l=t.timeStamp,e(t))},!0)},d=function(){return window.performance&&performance.getEntriesByType&&performance.getEntriesByType("navigation")[0]},p=function(){var e=d();return e&&e.activationStart||0},u=function(e,t){var n=d(),a="navigate";return l>=0?a="back-forward-cache":n&&(document.prerendering||p()>0?a="prerender":document.wasDiscarded?a="restore":n.type&&(a=n.type.replace(/_/g,"-"))),{name:e,value:void 0===t?-1:t,rating:"good",delta:0,entries:[],id:"v3-".concat(Date.now(),"-").concat(Math.floor(0x82f79cd8fff*Math.random())+1e12),navigationType:a}},g=function(e,t,n){try{if(PerformanceObserver.supportedEntryTypes.includes(e)){var a=new PerformanceObserver(function(e){Promise.resolve().then(function(){t(e.getEntries())})});return a.observe(Object.assign({type:e,buffered:!0},n||{})),a}}catch(e){}},f=function(e,t,n,a){var i,o;return function(r){var s;t.value>=0&&(r||a)&&((o=t.value-(i||0))||void 0===i)&&(i=t.value,t.delta=o,s=t.value,t.rating=s>n[1]?"poor":s>n[0]?"needs-improvement":"good",e(t))}},h=function(e){requestAnimationFrame(function(){return requestAnimationFrame(function(){return e()})})},m=function(e){var t=function(t){"pagehide"!==t.type&&"hidden"!==document.visibilityState||e(t)};addEventListener("visibilitychange",t,!0),addEventListener("pagehide",t,!0)},v=function(e){var t=!1;return function(n){t||(e(n),t=!0)}},y=-1,b=function(){return"hidden"!==document.visibilityState||document.prerendering?1/0:0},w=function(e){"hidden"===document.visibilityState&&y>-1&&(y="visibilitychange"===e.type?e.timeStamp:0,_())},x=function(){addEventListener("visibilitychange",w,!0),addEventListener("prerenderingchange",w,!0)},_=function(){removeEventListener("visibilitychange",w,!0),removeEventListener("prerenderingchange",w,!0)},S=function(){return y<0&&(y=b(),x(),c(function(){setTimeout(function(){y=b(),x()},0)})),{get firstHiddenTime(){return y}}},$=function(e){document.prerendering?addEventListener("prerenderingchange",function(){return e()},!0):e()},k=[1800,3e3],N=function(e,t){t=t||{},$(function(){var n,a=S(),i=u("FCP"),o=g("paint",function(e){e.forEach(function(e){"first-contentful-paint"===e.name&&(o.disconnect(),e.startTime<a.firstHiddenTime&&(i.value=Math.max(e.startTime-p(),0),i.entries.push(e),n(!0)))})});o&&(n=f(e,i,k,t.reportAllChanges),c(function(a){n=f(e,i=u("FCP"),k,t.reportAllChanges),h(function(){i.value=performance.now()-a.timeStamp,n(!0)})}))})},I=[.1,.25],C=function(e,t){t=t||{},N(v(function(){var n,a=u("CLS",0),i=0,o=[],r=function(e){e.forEach(function(e){if(!e.hadRecentInput){var t=o[0],n=o[o.length-1];i&&e.startTime-n.startTime<1e3&&e.startTime-t.startTime<5e3?(i+=e.value,o.push(e)):(i=e.value,o=[e])}}),i>a.value&&(a.value=i,a.entries=o,n())},s=g("layout-shift",r);s&&(n=f(e,a,I,t.reportAllChanges),m(function(){r(s.takeRecords()),n(!0)}),c(function(){i=0,n=f(e,a=u("CLS",0),I,t.reportAllChanges),h(function(){return n()})}),setTimeout(n,0))}))},T={passive:!0,capture:!0},j=new Date,E=function(e,i){t||(t=i,n=e,a=new Date,D(removeEventListener),A())},A=function(){if(n>=0&&n<a-j){var e={entryType:"first-input",name:t.type,target:t.target,cancelable:t.cancelable,startTime:t.timeStamp,processingStart:t.timeStamp+n};i.forEach(function(t){t(e)}),i=[]}},L=function(e){if(e.cancelable){var t,n,a,i=(e.timeStamp>1e12?new Date:performance.now())-e.timeStamp;"pointerdown"==e.type?(t=function(){E(i,e),a()},n=function(){a()},a=function(){removeEventListener("pointerup",t,T),removeEventListener("pointercancel",n,T)},addEventListener("pointerup",t,T),addEventListener("pointercancel",n,T)):E(i,e)}},D=function(e){["mousedown","keydown","touchstart","pointerdown"].forEach(function(t){return e(t,L,T)})},B=[100,300],H=function(e,a){a=a||{},$(function(){var o,r=S(),s=u("FID"),l=function(e){e.startTime<r.firstHiddenTime&&(s.value=e.processingStart-e.startTime,s.entries.push(e),o(!0))},d=function(e){e.forEach(l)},p=g("first-input",d);o=f(e,s,B,a.reportAllChanges),p&&m(v(function(){d(p.takeRecords()),p.disconnect()})),p&&c(function(){o=f(e,s=u("FID"),B,a.reportAllChanges),i=[],n=-1,t=null,D(addEventListener),i.push(l),A()})})},F=0,O=1/0,P=0,M=function(e){e.forEach(function(e){e.interactionId&&(O=Math.min(O,e.interactionId),F=(P=Math.max(P,e.interactionId))?(P-O)/7+1:0)})},R=function(){return o?F:performance.interactionCount||0},G=function(){"interactionCount"in performance||o||(o=g("event",M,{type:"event",buffered:!0,durationThreshold:0}))},U=[200,500],W=0,V=function(){return R()-W},z=[],K={},Y=function(e){var t=z[z.length-1],n=K[e.interactionId];if(n||z.length<10||e.duration>t.latency){if(n)n.entries.push(e),n.latency=Math.max(n.latency,e.duration);else{var a={id:e.interactionId,latency:e.duration,entries:[e]};K[a.id]=a,z.push(a)}z.sort(function(e,t){return t.latency-e.latency}),z.splice(10).forEach(function(e){delete K[e.id]})}},J=function(e,t){t=t||{},$(function(){G();var n,a=u("INP"),i=function(e){e.forEach(function(e){e.interactionId&&Y(e),"first-input"!==e.entryType||z.some(function(t){return t.entries.some(function(t){return e.duration===t.duration&&e.startTime===t.startTime})})||Y(e)});var t,i=(t=Math.min(z.length-1,Math.floor(V()/50)),z[t]);i&&i.latency!==a.value&&(a.value=i.latency,a.entries=i.entries,n())},o=g("event",i,{durationThreshold:t.durationThreshold||40});n=f(e,a,U,t.reportAllChanges),o&&(o.observe({type:"first-input",buffered:!0}),m(function(){i(o.takeRecords()),a.value<0&&V()>0&&(a.value=0,a.entries=[]),n(!0)}),c(function(){z=[],W=R(),n=f(e,a=u("INP"),U,t.reportAllChanges)}))})},Q=[2500,4e3],Z={},q=function(e,t){t=t||{},$(function(){var n,a=S(),i=u("LCP"),o=function(e){var t=e[e.length-1];t&&t.startTime<a.firstHiddenTime&&(i.value=Math.max(t.startTime-p(),0),i.entries=[t],n())},r=g("largest-contentful-paint",o);if(r){n=f(e,i,Q,t.reportAllChanges);var s=v(function(){Z[i.id]||(o(r.takeRecords()),r.disconnect(),Z[i.id]=!0,n(!0))});["keydown","click"].forEach(function(e){addEventListener(e,s,!0)}),m(s),c(function(a){n=f(e,i=u("LCP"),Q,t.reportAllChanges),h(function(){i.value=performance.now()-a.timeStamp,Z[i.id]=!0,n(!0)})})}})},X=[800,1800],ee=function e(t){document.prerendering?$(function(){return e(t)}):"complete"!==document.readyState?addEventListener("load",function(){return e(t)},!0):setTimeout(t,0)},et=function(e,t){t=t||{};var n=u("TTFB"),a=f(e,n,X,t.reportAllChanges);ee(function(){var i=d();if(i){var o=i.responseStart;if(o<=0||o>performance.now())return;n.value=Math.max(o-p(),0),n.entries=[i],a(!0),c(function(){(a=f(e,n=u("TTFB",0),X,t.reportAllChanges))(!0)})}})},en=e.i(519894),ea=e.i(227162),ei=e.i(395497);e.s(["default",0,({pageType:e})=>{let t=(0,en.useFeatureFlag)("webvitals"),n=Math.floor(100*Math.random()),a=ea.appConfig.getValue(ei.ConfigSettings.WebVitalsSampleRate),i=!!a&&n<=parseInt(a);return(0,r.useEffect)(()=>{var n;let a,o,r,l,c,d=(0,s.getCookie)("ckns_policy");if(void 0===d){let e=new Date(Date.now()+31536e6);document.cookie=`ckns_policy=111; expires=${e.toUTCString()}; domain=.bbc.com; path=/`,d=(0,s.getCookie)("ckns_policy")}let p=null!=d&&"1"===d.toString()[2],u=Date.now();t&&i&&p&&"sendBeacon"in navigator&&(n=`dotcom-${e.toLowerCase()}`,a=!1,o={cls:null,fid:null,lcp:null,fcp:null,ttfb:null,inp:null},r={device_mem:null,device_cpu:null,device_effective_connection:null},l=()=>{if(a){a=!1,"hardwareConcurrency"in navigator&&(r.device_cpu=navigator.hardwareConcurrency),"connection"in navigator&&"effectiveType"in navigator.connection&&(r.device_effective_connection=navigator.connection.effectiveType),"deviceMemory"in navigator&&(r.device_mem=navigator.deviceMemory);let e=new Blob([JSON.stringify([{type:"web-vitals",url:window.location.href,body:{...o,...r},age:Date.now()-u}])],{type:"application/reports+json"}),t=ea.appConfig.getValue(ei.ConfigSettings.WebVitalsEndpoint);t=`${t}?pageType=${n}`,navigator.sendBeacon(t,e)}},C(c=e=>{a=!0,o[e.name.toLowerCase()]=e.value},{reportAllChanges:!0}),N(c),H(c),q(c,{reportAllChanges:!0}),et(c),J(c),window.addEventListener("visibilitychange",()=>{"hidden"===document.visibilityState&&l()}),window.addEventListener("pagehide",l))},[]),null}],333109);var eo=e.i(391398),er=e.i(893409),es=e.i(786025),el=e.i(102358),ec=e.i(760814),ed=e.i(339228),ep=e.i(570549);let eu=ec.default.section.withConfig({displayName:"ContentLinks.styles__ContentLinksSectionStyled",componentId:"sc-9a221ef-0"})`
  margin-top: 29px;

  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      margin-top: 24px;
    `,"group1","group2")}
`,eg=ec.default.ul.withConfig({displayName:"ContentLinks.styles__ContentLinksULStyled",componentId:"sc-9a221ef-1"})`
  display: flex;
  flex-direction: row;
  column-gap: 16px;
  row-gap: 18px;
  align-items: center;
  flex-wrap: wrap;

  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      align-items: flex-start;
      flex-direction: column;
      row-gap: 24px;
      column-gap: 0;
    `,"group1","group2")}
`,ef=ec.default.a.withConfig({displayName:"ContentLinks.styles__ContentLinkStyled",componentId:"sc-9a221ef-2"})`
  ${({theme:e,$isSpecial:t})=>ec.css`
    text-decoration: none;
    position: relative;
    color: ${e.nav.content.value};
    ${(0,ep.applyTypography)(e.footer.linksitem.primary.default)}

    &:hover {
      text-decoration: underline;
    }

    ${t&&ec.css`
      margin-left: 16px;

      &::before {
        content: '';
        position: absolute;
        left: -16px;
        top: 50%;
        transform: translateY(-50%);
        display: block;
        width: 1px;
        height: 28px;
        background-color: ${e.nav.lines.value};
      }

      ${(0,ed.applyStylesForBreakpoints)(ec.css`
          margin-left: 0;

          &::before {
            display: none;
          }
        `,"group1","group2")}
    `}
  `}
`,eh=({externalUrl:e,externalTarget:t,slug:n,path:a,title:i,isSpecial:o})=>{let r=a||n||e||"/",s=(0,el.getNavigationAnalytics)("footer",`ContentLink - ${i}`,e,r,"content_links");return(0,eo.jsx)("li",{"data-testid":"contentlink-li",children:(0,eo.jsx)(er.default,{analytics:s,href:r,target:t,styledAnchor:ef,styledAnchorProps:{$isSpecial:o},children:i})})},em=({contentLinks:e=[]})=>{let{length:t}=e;return t?(0,eo.jsx)(eu,{children:(0,eo.jsx)("nav",{role:"navigation","aria-label":"Footer navigation",children:(0,eo.jsx)(eg,{children:e.map((e,t)=>(0,eo.jsx)(eh,{...e},t))})})}):null};var ev=e.i(65739);let ey=ec.default.section.withConfig({displayName:"LanguageDropdown.styles__LanguageDropDownSectionStyled",componentId:"sc-bc6bb5-0"})`
  margin-top: 21px;
  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      margin-top: 24px;
    `,"group4")}
  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      margin-top: 40px;
    `,"group1","group2")}
`,eb=ec.default.div.withConfig({displayName:"LanguageDropdown.styles__LanguageDropdownWrapperStyled",componentId:"sc-bc6bb5-1"})`
  position: relative;
  margin-right: 16px;
`,ew=ec.default.button.withConfig({displayName:"LanguageDropdown.styles__DropdownButtonStyled",componentId:"sc-bc6bb5-2"})`
  cursor: pointer;
  height: 44px;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  padding: 6px 12px;
  background-color: ${({theme:e})=>e.container.onDefaultBG.value};
  color: ${({theme:e})=>e.text.default.value};
  ${({theme:e})=>ec.css`
    ${(0,ep.applyTypography)(e.footer.linksitem.primary.default)}
  `}

  // Hovered state
  &:hover {
    background-color: ${({theme:e})=>e.interactive1.onInverseBG.hovered.value};
  }

  // Disabled state
  &[disabled] {
    cursor: auto;
    color: ${({theme:e})=>e.interactive1.onDefaultBG.disabled2.value};
    background-color: ${({theme:e})=>e.interactive1.onDefaultBG.disabled1.value};
  }

  //Pressed state
  &:active {
    background-color: ${({theme:e,disabled:t})=>t?"none":e.container.onDefaultBG.value};
  }
`,ex=ec.default.div.withConfig({displayName:"LanguageDropdown.styles__DropdownButtonIconWrapperStyled",componentId:"sc-bc6bb5-3"})`
  width: 24px;
  height: 24px;
  margin-left: 4.5px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: ${({theme:e,$disabled:t})=>t?e.interactive1.onDefaultBG.disabled2.value:"#000000"};
`,e_=ec.default.div.withConfig({displayName:"LanguageDropdown.styles__DropdownContentWrapperStyled",componentId:"sc-bc6bb5-4"})`
  background-color: ${({theme:e})=>e.container.onDefaultBG.value};
  padding-bottom: 24px;
  padding-top: 48px;
  ${({$isHidden:e})=>e&&ec.css`
      visibility: hidden;
      position: absolute;
      width: 1px;
      height: 1px;
      overflow: hidden;
      pointer-events: none;
    `}
  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      padding-bottom: 8px;
    `,"group2")};
`,eS=ec.default.h3.withConfig({displayName:"LanguageDropdown.styles__DropdownContentHeadlineStyled",componentId:"sc-bc6bb5-5"})`
  text-align: center;
  color: ${({theme:e})=>e.text.default.value};
  ${({theme:e})=>ec.css`
    ${(0,ep.applyTypography)(e.generic.headline.tiny.bpLarge)}
    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        ${(0,ep.applyTypography)(e.generic.headline.tiny.bpSmall)}
        text-align: left;
        padding-left: 32px;
      `,"group2")};
  `}
`,e$=ec.default.h4.withConfig({displayName:"LanguageDropdown.styles__DropdownContentSubHeadlineStyled",componentId:"sc-bc6bb5-6"})`
  text-align: center;
  color: ${({theme:e})=>e.text.mediumEmphasis.value};
  margin-top: 24px;
  ${({theme:e})=>ec.css`
    ${(0,ep.applyTypography)(e.generic.description.Regular.bpLarge)}
  `}
  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      margin-top: 12px;
      text-align: left;
      padding-left: 32px;
    `,"group2")};
`,ek=ec.default.div.withConfig({displayName:"LanguageDropdown.styles__DropdownContentTableStyled",componentId:"sc-bc6bb5-7"})`
  ${({$itemsLength:e})=>ec.css`
    max-width: 616px;
    margin: 24px auto;
    display: grid;
    grid-template-rows: repeat(${Math.ceil(e/4)}, auto);
    grid-auto-flow: column;
    grid-auto-columns: minmax(188px, 188px);
    column-gap: 16px;
    row-gap: 8px;
    justify-content: center;
    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        grid-template-rows: repeat(${Math.ceil(e/2)}, auto);
        column-gap: 80px;
      `,"group4")};
    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        grid-template-rows: unset;
        grid-auto-flow: row;
        row-gap: 24px;
        margin: 32px auto;
        justify-content: left;
        padding-left: 32px;
      `,"group2")};
  `}
`,eN=ec.default.a.withConfig({displayName:"LanguageDropdown.styles__DropDownContentTableItemStyled",componentId:"sc-bc6bb5-8"})`
  ${({theme:e})=>ec.css`
    color: ${e.text.default.value};
    ${(0,ep.applyTypography)(e.footer.linksitem.secondary.default.bpLarge)}

    &:hover {
      text-decoration: underline;
    }
    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        font-size: 14px;
      `,"group2")};
  `}
`,eI=({text:e,disabled:t,onClick:n,isOpen:a})=>(0,eo.jsxs)(ew,{type:"button",disabled:t,onClick:n,children:[e,(0,eo.jsx)(ex,{$disabled:t,children:(0,eo.jsx)(ev.default,{name:t?"arrows:arrow-down":a?"arrows:arrow-up":"arrows:arrow-down"})})]}),eC=({title:e,externalUrl:t,externalTarget:n})=>{let a=(0,el.getNavigationAnalytics)("footer",`LanguageDropdownItem - ${e}`,t,t||"","language_dropdown");return t?(0,eo.jsx)(er.default,{analytics:a,href:t,target:n,styledAnchor:eN,children:e}):null},eT=({headline:e,subHeadline:t,languages:n=[],isHidden:a})=>{let{length:i}=n;return(0,eo.jsxs)(e_,{$isHidden:a,"aria-hidden":a,children:[e&&(0,eo.jsx)(eS,{children:e}),t&&(0,eo.jsx)(e$,{children:t}),!!i&&(0,eo.jsx)(ek,{$itemsLength:n.length,children:n.map((e,t)=>(0,eo.jsx)(eC,{...e},t))})]})},ej=({buttonText:e,isDisabled:t=!1,headline:n,subHeadline:a,languages:i=[]})=>{let{length:o}=i,[s,l]=(0,r.useState)(!1);return o?(0,eo.jsx)(ey,{children:(0,eo.jsxs)(eb,{children:[(0,eo.jsx)(eI,{text:e,disabled:t,onClick:()=>l(e=>!e),isOpen:s}),(0,eo.jsx)(eT,{headline:n,subHeadline:a,languages:i,isHidden:!s||t})]})}):null};var eE=e.i(147097);let eA=ec.default.section.withConfig({displayName:"LegalLinks.styles__LegalLinksSectionStyled",componentId:"sc-f9fd086a-0"})`
  margin-top: 16px;
`,eL=ec.default.ul.withConfig({displayName:"LegalLinks.styles__LegalLinksULStyled",componentId:"sc-f9fd086a-1"})`
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;
  column-gap: 16px;
  row-gap: 12px;
`,eD=ec.default.li.withConfig({displayName:"LegalLinks.styles__LegalLinksLIStyled",componentId:"sc-f9fd086a-2"})`
  flex: 0 0 auto;
`,eB=ec.default.a.withConfig({displayName:"LegalLinks.styles__LegalLinkItemStyled",componentId:"sc-f9fd086a-3"})`
  ${({theme:e})=>ec.css`
    cursor: pointer;
    text-decoration: none;
    color: ${e.nav.content.value};
    ${(0,ep.applyTypography)(e.footer.linksitem.secondary.default.bpLarge)}

    &:hover {
      text-decoration: underline;
    }
  `}
`,eH=({title:e,path:t,slug:n,externalUrl:a="",externalTarget:i,inOverlay:o})=>{let r=t||n,s=(0,el.getNavigationAnalytics)("footer",`LegalLink - ${e}`,a,r,"legal_links");return(0,eo.jsx)(eD,{children:r?(0,eo.jsx)(er.default,{analytics:s,href:r,styledAnchor:eB,children:e}):(0,eo.jsx)(er.default,{analytics:s,styledAnchor:eB,target:i,href:a,onClick:e=>{(0,eE.getIsClient)()&&o&&window.dotcom?.showSourcePointMessage&&(e.preventDefault(),window.dotcom.showSourcePointMessage())},children:e})})},eF=({links:e=[]})=>e.length?(0,eo.jsx)(eA,{children:(0,eo.jsx)("nav",{children:(0,eo.jsx)(eL,{children:e.map((e,t)=>(0,eo.jsx)(eH,{...e},t))})})}):null;var eO=e.i(761074),eP=e.i(417183);let eM={x:{icon:"social:x",urls:{news:"https://www.x.com/bbcworld",breaking:"https://www.x.com/bbcbreaking",sport:"https://www.x.com/bbcsport",earth:"https://www.x.com/bbcearth",travel:"https://www.x.com/bbc_travel",culture:"https://www.x.com/bbc_culture",audio:"https://x.com/bbcpodcasts?lang=en",select:"https://www.x.com/bbcselect"}},facebook:{icon:"social:facebook",urls:{news:"https://www.facebook.com/bbcnews",breaking:"https://www.facebook.com/bbcnews",sport:"https://www.facebook.com/bbcsport",earth:"https://www.facebook.com/bbcearth",travel:"https://www.facebook.com/bbctravel",culture:"https://www.facebook.com/bbcculture",audio:"https://www.facebook.com/BBCPodcasts",select:"https://www.facebook.com/bbcselect",global:"https://www.facebook.com/BBCGlobalFB"},keyOverrides:{global:"BBC Global"}},instagram:{icon:"social:instagram",urls:{news:"https://www.instagram.com/bbcnews",breaking:"https://www.instagram.com/bbcnews",sport:"https://www.instagram.com/bbcsport",earth:"https://www.instagram.com/bbcearth",travel:"https://www.instagram.com/bbc_travel",culture:"https://www.instagram.com/bbc_culture",audio:"https://www.instagram.com/bbcpodcasts",select:"https://www.instagram.com/bbcselect",global:"https://www.instagram.com/bbcglobal"},keyOverrides:{global:"BBC Global"}},tiktok:{icon:"social:tiktok",urls:{news:"https://www.tiktok.com/@bbcnews",breaking:"https://www.tiktok.com/@bbcnews",sport:"https://www.tiktok.com/@bbcsport",earth:"https://www.tiktok.com/@bbcearth"}},linkedin:{icon:"social:linkedin",urls:{news:"https://www.linkedin.com/company/bbc-news/",breaking:"https://www.linkedin.com/company/bbc-news/"}},youtube:{icon:"social:youtube",urls:{news:"https://www.youtube.com/bbcnews",breaking:"https://www.youtube.com/bbcnews",sport:"https://www.youtube.com/bbcsport",earth:"https://www.youtube.com/bbcearth",select:"https://www.youtube.com/bbcselect",global:"https://www.youtube.com/@bbc_global"},keyOverrides:{global:"BBC Global"}}},eR=e=>ec.css`
  transition: 0.2s linear opacity;
  ${e&&ec.css`
    opacity: ${+("out"!==e)};
  `};
`,eG=ec.default.div.withConfig({displayName:"SocialFollowUs.styles__SocialFollowUsContainerStyled",componentId:"sc-2bdeae3a-0"})`
  ${({theme:e,$hasTopDivider:t=!1,$hasBottomDivider:n=!1})=>ec.css`
    display: flex;
    flex-wrap: wrap;
    margin: 16px 0;

    ${t&&ec.css`
      border-top: ${`1px solid ${e.container.onDefaultBG.value}`};
      padding-top: 16px;
    `};

    ${n&&ec.css`
      border-bottom: ${`1px solid ${e.container.onDefaultBG.value}`};
      padding-bottom: 16px;
    `};

    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        flex-direction: column;
      `,"group2")};
  `}
`,eU=ec.default.div.withConfig({displayName:"SocialFollowUs.styles__SocialFollowUsHeaderStyled",componentId:"sc-2bdeae3a-1"})`
  /* token does not exist theme.generic.header.xSmall.bpLarge, => styles are the same anyway for all groups? */
  font-family: 'BBC Reith Sans';
  font-size: 16px;
  line-height: 20px;
  font-weight: 500;
  display: flex;
  align-items: center;
  margin-right: 40px;

  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      margin-bottom: 16px;
      margin-right: 0;

      /* token does not exist theme.generic.header.xSmall.bpSmall => styles are the same anyway for all groups? */
    `,"group2")};
`,eW=ec.default.div.withConfig({displayName:"SocialFollowUs.styles__SocialFollowUsFlexContainerStyled",componentId:"sc-2bdeae3a-2"})`
  display: flex;
  gap: 16px;
  align-items: center;

  button {
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  ${(0,ed.applyStylesForBreakpoints)(ec.css`
      button {
        width: 28px;
        height: 28px;
      }
    `,"group2")};
`,eV=ec.default.div.withConfig({displayName:"SocialFollowUs.styles__SocialContainerStyled",componentId:"sc-2bdeae3a-3"})`
  ${({$isActive:e,$transitionState:t})=>ec.css`
    position: relative;
    width: 100%;
    ${e&&ec.css`
      display: block;
    `}

    ${eR(t)};
  `}
`,ez=ec.default.div.withConfig({displayName:"SocialFollowUs.styles__SocialLinkContainerStyled",componentId:"sc-2bdeae3a-4"})`
  ${({theme:e})=>ec.css`
    background-color: ${e.container.onDefaultBG.value};
    flex-basis: 100%;
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    margin-top: 16px;

    a {
      ${(0,ep.applyTypography)(e.textLink.small.regular.bpLarge)};
      text-transform: capitalize;
    }

    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        margin-top: 14px;
      `,"group2")};
  `}
`,eK=ec.default.button.withConfig({displayName:"SocialFollowUs.styles__TriangleContainerStyled",componentId:"sc-2bdeae3a-5"})`
  ${({theme:e,$isActive:t,$transitionState:n})=>ec.css`
    position: relative;

    &:hover {
      outline: ${`1px solid ${e.interactive1.onDefaultBG.hovered.value}`};
    }

    &::after {
      content: '';
      width: 0;
      height: 0;
      border-left: 6px solid transparent;
      border-right: 6px solid transparent;
      border-bottom: 9px solid ${e.container.onDefaultBG.value};
      position: absolute;
      bottom: -20px;
      left: 50%;
      transform: translateX(-50%);
      ${eR(n)};

      ${!t&&ec.css`
        visibility: hidden;
      `}

      ${(0,ed.applyStylesForBreakpoints)(ec.css`
          bottom: -14px;
        `,"group2")};
    }
  `}
`,eY=ec.default.div.withConfig({displayName:"SocialFollowUs.styles__SocialLinkInnerItemStyled",componentId:"sc-2bdeae3a-6"})`
  padding: 15px 12px;
`,eJ=ec.default.a.withConfig({displayName:"SocialFollowUs.styles__SocialLinkItemStyled",componentId:"sc-2bdeae3a-7"})`
  ${({theme:e})=>ec.css`
    color: inherit;
    padding: 7px 5px;

    &:hover {
      text-decoration: underline;
    }

    &:active,
    &:focus {
      font-weight: 700;
      text-decoration: none;
      outline: ${`1px solid ${e.interactive1.onDefaultBG.hovered.value}`};
    }
  `}
`,eQ=({hasTopDivider:e,hasBottomDivider:t})=>{let n=(0,r.useRef)(null),[a,i]=(0,r.useState)(null),[o,s]=(0,r.useState)(null),{urls:l,keyOverrides:c}=(0,eO.default)(eM,a,{urls:{},keyOverrides:{}}),d=!!a&&!(0,eP.default)(l),p=Object.entries(eM);(0,r.useEffect)(()=>{if(d){let{current:e}=n;if(e){let[t]=Array.from(e.getElementsByTagName("a"));t?.focus()}}},[d,a]);let u=e=>{e.currentTarget.blur()};return(0,eo.jsxs)(eG,{"data-testid":"social-follow-us-container",$hasTopDivider:e,$hasBottomDivider:t,children:[(0,eo.jsx)(eU,{children:"Follow BBC on:"}),(0,eo.jsx)(eW,{"data-testid":"social-follow-us-icon-buttons",children:p.map(([e,{icon:t}],n)=>(0,eo.jsx)(eK,{$isActive:e===a,$transitionState:o,"aria-label":`Follow BBC on ${e}`,onClick:()=>{if(a===e){i(null),s(null);return}a?(s("out"),setTimeout(()=>{i(e),s("in")},200)):i(t=>t===e?null:e)},children:(0,eo.jsx)(ev.default,{name:t,testId:`social-button-${e}`})},`${e}-button-${n}`))}),d&&(0,eo.jsx)(eV,{$isActive:!!a,$transitionState:o,children:(0,eo.jsx)(ez,{ref:n,"data-testid":`social-follow-us-links-${a}`,children:Object.entries(l).map(([e,t])=>(0,eo.jsx)(er.default,{href:t,"data-testid":`${e}-anchor`,styledAnchor:eJ,styledAnchorInner:eY,onClick:u,children:(0,eO.default)(c,e,e)},e))})})]})};var eZ=e.i(24768);let eq=()=>(0,eo.jsx)("div",{id:eZ.SUBSCRIPTION_BANNER_ID,"data-testid":eZ.SUBSCRIPTION_BANNER_ID}),eX=ec.default.footer.withConfig({displayName:"Footer.styles__FooterStyled",componentId:"sc-7046f1ed-0"})`
  max-width: 1280px;
  width: 100%;
  margin: 16px auto 48px auto;
  padding: 0 16px;
  box-sizing: border-box;
`,e0=ec.default.div.withConfig({displayName:"Footer.styles__LegalTextParagraphStyled",componentId:"sc-7046f1ed-1"})`
  ${({theme:e})=>ec.css`
    margin-top: 16px;
    overflow-wrap: break-word; /* stylelint-disable-line plugin/no-unsupported-browser-features */

    p {
      ${(0,ep.applyTypography)(e.footer.text.default)}
      color: ${e.nav.content.value};
    }

    b,
    a {
      ${(0,ep.applyTypography)(e.footer.text.emphasised)}
    }

    a {
      text-decoration: none;
      color: ${e.nav.content.value};
    }

    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        margin-top: 24px;
      `,"group2")}
  `}
`,e1=ec.default.hr.withConfig({displayName:"Footer.styles__SeparatorStyled",componentId:"sc-7046f1ed-2"})`
  background-color: ${({theme:e,emphasis:t="lowEmphasis"})=>e.divider[t].value};
  margin-top: 120px;
  height: 1px;
  border: none;
`,e2=ec.default.div.withConfig({displayName:"Footer.styles__LogoSectionStyled",componentId:"sc-7046f1ed-3"})`
  display: flex;
`;e.s(["default",0,({mainPageUrl:e="/",languages:t,languageSubHeadline:n,languageHeadline:a,languageButtonText:i,legalLinks:o=[],contentLinks:r,testId:s,legalTextContent:l,id:c})=>{let d=(0,el.getNavigationAnalytics)("footer","Footer BBC icon","",e,"footer");return(0,eo.jsxs)(eo.Fragment,{children:[(0,eo.jsx)(e1,{"data-testid":"main-footer-divider",emphasis:"highEmphasis"}),(0,eo.jsxs)(eX,{id:c,"data-testid":s,children:[(0,eo.jsx)(e2,{children:(0,eo.jsx)(er.default,{analytics:d,href:e,children:(0,eo.jsx)(ev.default,{name:"logo:bbc",style:{height:30}})})}),(0,eo.jsx)(em,{contentLinks:r}),(0,eo.jsx)(ej,{buttonText:i,languages:t,subHeadline:n,headline:a}),(0,eo.jsx)(eQ,{hasTopDivider:!0}),(0,eo.jsx)(eF,{links:o}),(0,eo.jsx)(e0,{children:(0,eo.jsx)(es.default,{blocks:l})})]}),(0,eo.jsx)(eq,{})]})}],394527);var e5=e.i(459949),e4=e.i(275349);function e3(e){this.message=e}e3.prototype=Error(),e3.prototype.name="InvalidCharacterError";var e6="u">typeof window&&window.atob&&window.atob.bind(window)||function(e){var t=String(e).replace(/=+$/,"");if(t.length%4==1)throw new e3("'atob' failed: The string to be decoded is not correctly encoded.");for(var n,a,i=0,o=0,r="";a=t.charAt(o++);~a&&(n=i%4?64*n+a:a,i++%4)&&(r+=String.fromCharCode(255&n>>(-2*i&6))))a="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".indexOf(a);return r};function e7(e){this.message=e}e7.prototype=Error(),e7.prototype.name="InvalidTokenError";let e9=function(e,t){if("string"!=typeof e)throw new e7("Invalid token specified");var n=+(!0!==(t=t||{}).header);try{return JSON.parse(function(e){var t,n=e.replace(/-/g,"+").replace(/_/g,"/");switch(n.length%4){case 0:break;case 2:n+="==";break;case 3:n+="=";break;default:throw"Illegal base64url string!"}try{return t=n,decodeURIComponent(e6(t).replace(/(.)/g,function(e,t){var n=t.charCodeAt(0).toString(16).toUpperCase();return n.length<2&&(n="0"+n),"%"+n}))}catch(e){return e6(n)}}(e.split(".")[n]))}catch(e){throw new e7("Invalid token specified: "+e.message)}};var e8=e.i(959560),te=e.i(57988),tt=e.i(524431),tn=e.i(508259),ta=e.i(939648),ti=e.i(222009);let to=ec.createGlobalStyle`
  #${eZ.SUBSCRIPTION_BANNER_ID} {
    display: ${e=>e.$isSubscriptionAllowed?"block":"none"};
    position: sticky;
    bottom: 0;
    z-index: 9999;
  }
`,tr=(0,ec.createGlobalStyle)(({$isHeaderDefaultSize:e,$isBurgerMenuOpened:t})=>{let n=e?ta.HEADER_DEFAULT_HEIGHT+42:ta.HEADER_COLLAPSED_HEIGHT,a=e?ta.HEADER_DEFAULT_HEIGHT:ta.HEADER_COLLAPSED_HEIGHT,i=ta.HEADER_HEIGHT_MOBILE;return ec.css`
      .tp-backdrop {
        background-color: rgb(255 255 255 / 70%) !important;
        backdrop-filter: blur(4px);
        top: ${n}px !important;
        ${(0,ti.applyZIndex)("level2",!1,!0)};

        ${(0,ed.applyStylesForBreakpoints)(ec.css`
            top: ${a}px !important;
          `,"group4")};

        ${(0,ed.applyStylesForBreakpoints)(ec.css`
            top: ${i}px !important;
          `,"group2")};
      }

      .tp-modal {
        top: ${n}px !important;
        display: grid;
        place-content: center;
        ${(0,ti.applyZIndex)(t?"level2":"level3",!0,!0)};

        .tp-iframe-wrapper {
          margin-block: 0 !important;
        }

        ${(0,ed.applyStylesForBreakpoints)(ec.css`
            top: ${a}px !important;
          `,"group4")};

        ${(0,ed.applyStylesForBreakpoints)(ec.css`
            top: ${i}px !important;
            place-content: start;
          `,"group2")};
      }
    `}),ts=ec.createGlobalStyle`
  .tp-modal .tp-close.tp-active {
    display: none !important;
  }

  .tp-modal {
    background-color: #f7f2ea !important;
  }

  .tp-iframe-wrapper {
    margin: 0 auto !important;
    box-shadow: none !important;
  }
`;var tl=e.i(789799);let tc=()=>{let[e]=(0,te.useCurrentSlug)();return"subscribe"===e},td=({isHeaderDefaultSize:e,isBurgerMenuOpened:t})=>{let n,a=tc(),{isSubscriptionAllowed:i}=(0,tl.useSubscriptionContext)(),[o,l]=(0,r.useState)(!1),[c,d]=(0,r.useState)(!1),p=(0,tt.useLogMparticleEvent)();return(0,e4.useBackdropObserver)(e=>{e&&p("paywall.subscription.view")},"piano"),(0,r.useEffect)(()=>{window.tp.push(["init",()=>l(!0)]),window.tp.push(["addHandler","showOffer",e=>{(e?.displayMode!=="inline"||e?.containerSelector!==`#${eZ.SUBSCRIPTION_BANNER_ID}`)&&d(!0)}])},[]),(e=>{let{data:t}=(0,e8.default)("authInfo"),{statusUrl:n}=t||{},[a]=(0,te.useCurrentSlug)();(0,r.useEffect)(()=>{if("managesubscription"===a&&e){let e=(0,s.getCookie)(eZ.SUBSCRIPTION_SETTINGS_COOKIE),{authLevel2Expiry:t}=e?e9(String(e)):{},a=Math.round(new Date().getTime()/1e3);!t||t<a?window.location.href=`${n}${eZ.SUBSCRIPTION_SETTINGS_MANAGEMENT}?web=true&ptrt=${window.location.href}`:window.tp.myaccount.show({displayMode:"inline",containerSelector:"#bbc-main",activateTemplateInteraction:!0})}},[n,a,e])})(o),(e=>{let[t]=(0,te.useCurrentSlug)();(0,r.useEffect)(()=>{let t=new URLSearchParams(window.location.search).get("accountMarketingPreferences");if(t&&e){var n;n=[{field_name:eZ.CUSTOM_FORM_FIELD_NAME,value:"on"===t?"true":"false"}],window.tp.api.callApi("/anon/user/get",{},async e=>{let t=ea.appConfig.getValue(ei.ConfigSettings.PianoApi),a=window.tp?.aid,i=window.tp?.pianoId?.getToken(),o=`${t}/identity/userinfo?lang=en_US&aid=${a}&access_token=${i}`,r=e?.user?.uid;a&&i&&r?await fetch(o,{method:"PUT",headers:{"Content-Type":"application/json; charset=UTF-8"},body:JSON.stringify({uid:r,form_name:eZ.CUSTOM_FORM,custom_field_values:n})}).then(e=>{e.ok?tn.logger.info("Custom fields updated successfully"):tn.logger.error("Failed to update custom fields")}).catch(e=>{tn.logger.error("Error updating custom fields:",e)}):tn.logger.error(`Piano API credentials are missing: [pianoAid: ${a}, pianoToken: ${i}, pianoUid: ${r}]`)})}},[e,t])})(o),(()=>{let[e]=(0,te.useCurrentSlug)();(0,r.useEffect)(()=>{"subscribe"===e&&window.tp.push(["addHandler","checkoutCustomEvent",e=>{"checkout-attempt"===e.eventName&&document?.querySelector(".tp-iframe-wrapper.tp-active")?.scrollIntoView({behavior:"smooth"})}])},[e])})(),n=tc(),(0,r.useEffect)(()=>{let e=new MutationObserver(e=>{e.forEach(e=>{let{type:t}=e,n=e.target;"attributes"===t&&n.matches("div.tp-backdrop")&&(n.classList.contains("tp-active")&&document.body.setAttribute("style","overflow: hidden"),n.classList.contains("tp-active")||document.body.removeAttribute("style"))})});return n||e.observe(document.body,{attributes:!0,subtree:!0,attributeFilter:["class"]}),()=>{e.disconnect(),document.body.removeAttribute("style")}},[n]),(e=>{let[t,n]=(0,r.useState)({}),[a,i]=(0,r.useState)(!1);(0,r.useEffect)(()=>{let e,t,a;e=window?.embeddedMedia?.api,t=0,a=setInterval(()=>{if(!e||!e.players)return;t+=1;let i=0===Object.keys(e?.players()??{}).length;if(i&&40===t){tn.logger.warn("embeddedMedia.api.players() returned no players after 40 attempts"),clearInterval(a);return}i||(n(e.players()),clearInterval(a))},100)},[]),(0,r.useEffect)(()=>{if(Object.keys(t).length>0)for(let[,e]of Object.entries(t))e.bind("playbackInterrupted",()=>i(!0));if(!a&&e)for(let[,e]of Object.entries(t))e.stop();if(a&&e)for(let[,e]of Object.entries(t))setTimeout(()=>{e.loadPlaylist({}),e.stop()},1500)},[t,e,a])})(c),(0,eo.jsxs)(eo.Fragment,{children:[(0,eo.jsx)(to,{$isSubscriptionAllowed:i}),(0,eo.jsx)(a?ts:tr,{$isHeaderDefaultSize:e,$isBurgerMenuOpened:t})]})};var tp=e.i(276045);let tu=Object.keys(e.i(195214).breakpoints).reverse(),tg=ec.default.div.withConfig({displayName:"WatchLive.styles__WatchLiveStyled",componentId:"sc-6555d0cd-0"})`
  ${({theme:e,$visibleForBreakpoints:t})=>ec.css`
    position: relative;
    padding: 8px;
    height: 32px;

    a::before {
      position: absolute;
      content: '';
      inset: 0;
    }

    &:hover {
      background-color: ${e.nav.level1.bgHover.value};
    }

    ${tu.map(e=>{let n=t.includes(e),a=ec.css`
        display: ${n?"inline-flex":"none"};
        align-items: center;
      `;return"group6"===e?a:(0,ed.applyStylesForBreakpoints)(a,e)})};

    ${(0,ep.applyTypography)(e.button.medium)};

    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        padding-block: 6px;
      `,"group2")};
  `};
`,tf=ec.default.span.withConfig({displayName:"WatchLive.styles__WatchLiveContentStyled",componentId:"sc-6555d0cd-1"})`
  display: inline-flex;
  align-items: center;
  column-gap: 4px;
`,th=ec.default.span.withConfig({displayName:"WatchLive.styles__WatchLiveIconStyled",componentId:"sc-6555d0cd-2"})`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  aspect-ratio: 1;

  svg {
    height: 16px;
    width: 16px;
  }
`,tm=({withAnimation:e=!1,visibleForBreakpoints:t=[]})=>{let{worldNewsTvPath:n}=(0,tp.useWorldNewsData)();return n?(0,eo.jsx)(tg,{$visibleForBreakpoints:t,children:(0,eo.jsx)(er.default,{analyticsProps:{item_name:"WatchLive - Watch Live",item_type:"watch_live_button"},href:n,children:(0,eo.jsxs)(tf,{children:[(0,eo.jsx)(th,{children:(0,eo.jsx)(ev.default,{name:"content-types:live",withAnimation:e})}),(0,eo.jsx)("span",{children:"Watch Live"})]})})}):null};e.s(["default",0,tm],871071);let tv=ec.default.header.withConfig({displayName:"Header.styles__HeaderStyled",componentId:"sc-36071384-0"})`
  ${({theme:e,$isHeaderDefaultSize:t,$isPianoModalVisible:n=!1})=>ec.css`
    position: ${n?"fixed":"sticky"};
    top: 0;
    left: 0;
    right: 0;
    height: ${t?ta.HEADER_DEFAULT_HEIGHT:ta.HEADER_COLLAPSED_HEIGHT}px;
    background-color: ${e.nav.level1.bgDefault.value};
    border-bottom: 1px solid ${e.nav.lines.value};
    ${(0,ti.applyZIndex)("level4")};
    transition: height 0.5s ease;

    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        height: ${ta.HEADER_HEIGHT_MOBILE}px;
      `,"group2")};
  `};
`,ty=ec.default.div.withConfig({displayName:"Header.styles__HeaderContentStyled",componentId:"sc-36071384-1"})`
  ${({$isHeaderDefaultSize:e})=>ec.css`
    position: relative;
    display: flex;
    align-items: center;
    height: ${e?"56px":"40px"};
    padding: 12px 16px;
    transition: height 0.5s ease;

    ${(0,ed.applyStylesForBreakpoints)(ec.css`
        height: 48px;
        padding: 0 12px;
      `,"group2")};
  `}
`,tb=ec.default.div.withConfig({displayName:"Header.styles__HeaderLogoStyled",componentId:"sc-36071384-2"})`
  ${({$isHeaderDefaultSize:e})=>ec.css`
    display: flex;
    align-items: center;
    justify-content: center;

    svg {
      height: 40px;
      width: auto;
      transition: height 0.5s ease;

      ${!e&&ec.css`
        height: 30px;
      `}

      ${(0,ed.applyStylesForBreakpoints)(ec.css`
          height: 30px;

          ${!e&&ec.css`
            height: 24px;
          `}
        `,"group2")};
    }
  `}
`,tw=ec.default.button.withConfig({displayName:"Header.styles__HeaderMenuButtonStyled",componentId:"sc-36071384-3"})`
  ${({theme:e,$isBurgerMenuOpened:t})=>ec.css`
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: ${e.interactive3.onDefaultBG.default.value};

    &:hover {
      background-color: ${e.interactive3.onDefaultBG.hovered.value};
    }

    ${t&&ec.css`
      height: 36px;
      width: 36px;
    `}
  `};
`,tx=ec.default.div.attrs({className:"hide-when-no-script"}).withConfig({displayName:"Header.styles__HeaderMenuContainerStyled",componentId:"sc-36071384-4"})`
  ${({$isBurgerMenuOpened:e})=>ec.css`
    flex: 1;
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    column-gap: ${e?26:12}px;
  `};
`,t_=ec.default.div.withConfig({displayName:"Header.styles__HeaderLogoContainerStyled",componentId:"sc-36071384-5"})`
  flex: 1;
  display: flex;
  justify-content: center;
  height: 32px;
`,tS=ec.default.div.withConfig({displayName:"Header.styles__HeaderButtonsContainerStyled",componentId:"sc-36071384-6"})`
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: end;
  gap: 20px;
  height: 40px;
`,t$=({isBurgerMenuOpened:e,onClick:t,buttonRef:n})=>(0,eo.jsx)(tw,{ref:n,onClick:t,role:"button","aria-expanded":e,"aria-label":e?"Close menu":"Open menu",$isBurgerMenuOpened:e,children:(0,eo.jsx)(ev.default,{name:e?"actions:close":"actions:toggle",width:20,height:20,"aria-hidden":!0})}),tk=(0,r.forwardRef)(({isBurgerMenuOpened:e,onToggleMenuClick:t,onHeaderLogoClick:n,mainPageUrl:a,actions:i,toggleMenuButtonRef:o,isHeaderDefaultSize:s,id:l},c)=>{let[d,p]=(0,r.useState)(!1),u=(0,el.getNavigationAnalytics)("header","Header BBC icon","",a.toString(),"header");return(0,e4.useBackdropObserver)(p,"piano"),(0,eo.jsx)(tv,{id:l,ref:c,$isHeaderDefaultSize:s,$isPianoModalVisible:d,children:(0,eo.jsxs)(ty,{$isHeaderDefaultSize:s,children:[(0,eo.jsxs)(tx,{$isBurgerMenuOpened:e,children:[(0,eo.jsx)(t$,{buttonRef:o,onClick:t,isBurgerMenuOpened:e}),(0,eo.jsx)(tm,{withAnimation:!0,visibleForBreakpoints:["group6","group5","group4","group3"]})]}),(0,eo.jsx)(t_,{children:(0,eo.jsx)(tb,{onClick:n,$isHeaderDefaultSize:s,children:(0,eo.jsx)(er.default,{href:a,analytics:u,children:(0,eo.jsx)(ev.default,{name:"logo:bbc"})})})}),(0,eo.jsxs)(tS,{children:[(0,eo.jsx)(td,{isHeaderDefaultSize:s,isBurgerMenuOpened:e}),(0,eo.jsx)(e5.AccountButtons,{actions:i,onToggleMenuClick:t,isBurgerMenuOpened:e})]})]})})});e.s(["default",0,tk],219717);var tN=e.i(84541);let tI=ec.default.div.withConfig({displayName:"DismissableError.styles__DismissibleErrorContainerStyled",componentId:"sc-c275520f-0"})`
  ${({theme:e})=>ec.css`
    position: absolute;
    left: 0;
    right: 0;
    width: auto;
    background-color: ${e.errorBanner.bg.value};
    display: flex;
    height: 52px;
    padding: 8px 16px;
    justify-content: space-between;
    align-items: center;
    align-self: stretch;
    z-index: 500;
  `};
`,tC=ec.default.div.withConfig({displayName:"DismissableError.styles__DismissibleErrorInnerContainerStyled",componentId:"sc-c275520f-1"})`
  max-width: 932px;
  margin: auto;
  width: 100%;
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  align-content: center;
  align-items: center;
`,tT=ec.default.p.withConfig({displayName:"DismissableError.styles__DismissibleErrorTextStyled",componentId:"sc-c275520f-2"})`
  ${({theme:e})=>(0,ep.applyTypography)(e.errorBannerText.bpLarge)};
  color: #ffffff;
`;e.s(["default",0,({errorString:e,onClick:t})=>(0,eo.jsx)(tI,{"data-testid":"dismissable-error",children:(0,eo.jsxs)(tC,{children:[(0,eo.jsx)(tT,{children:e}),(0,eo.jsx)(tN.default,{icon:"actions:close",onClick:t})]})})],967223)},907182,e=>{"use strict";var t=e.i(391398),n=e.i(191788),a=e.i(184919),i=e.i(249356),o=e.i(154738),r=e.i(959560),s=e.i(117191),l=e.i(939648),c=e.i(257539),d=e.i(57988),p=e.i(660021),u=e.i(149250),g=e.i(317166),f=e.i(680516),h=e.i(421237),m=e.i(333109),v=e.i(240911),y=e.i(394527),b=e.i(219717),w=e.i(426710),x=e.i(967223),_=e.i(849766),S=e.i(102358),$=e.i(468364),k=e.i(893409),N=e.i(546795),I=e.i(924257),C=e.i(551068);let T=(0,n.memo)(e=>{let{isSpecial:n,externalTarget:a,externalUrl:i,title:o,isActive:r,isNewsPage:s=!1}=e,l=e.path||"";"/home"===l&&(l="/");let c={$isActive:r,"data-testid":`${f.MAIN_NAVIGATION_LINK_TEST_ID}${r?"-active":""}`,"aria-current":r?"page":void 0},d=(0,I.useExternalTarget)(l,a),p=(0,S.getNavigationAnalytics)("main",o,i,l,"main_navigation");return(0,t.jsx)(C.MainNavigationItemStyled,{isActive:r,isSpecial:n,isNews:s,"data-testid":f.MAIN_NAVIGATION_ITEM,children:i?(0,t.jsx)(C.MainNavigationLink,{"data-testid":f.MAIN_NAVIGATION_LINK_TEST_ID,$isActive:r,"aria-current":r?"page":void 0,href:(0,N.appendQueryParamsToUrl)(i),target:d,onClick:()=>p&&window.analytics.sendEvent(p),children:o}):(0,t.jsx)(k.default,{analytics:p,href:l,styledAnchor:C.MainNavigationLink,styledAnchorProps:c,children:o})})}),j=(0,n.memo)(({isSpecial:e,externalTarget:n,externalUrl:a,title:i,path:o="",isActive:r})=>{let s={$isActive:r,"data-testid":`${f.SUB_NAVIGATION_LINK_TEST_ID}${r?"-active":""}`,"aria-current":r?"page":void 0},l=(0,I.useExternalTarget)(o,n),c=(0,S.getNavigationAnalytics)("sub",i,a,o,"main_navigation");return(0,t.jsx)(C.SubNavigationItemStyled,{isSpecial:e,children:a?(0,t.jsx)(C.SubNavigationLink,{"data-testid":f.SUB_NAVIGATION_LINK_TEST_ID,onClick:()=>c&&window.analytics.sendEvent(c),$isActive:r,"aria-current":r?"page":void 0,href:(0,N.appendQueryParamsToUrl)(a),target:l,children:i}):(0,t.jsx)(k.default,{analytics:c,href:o,styledAnchor:C.SubNavigationLink,styledAnchorProps:s,children:i})})}),E=(0,n.memo)(({title:e,externalTarget:n,externalUrl:a,path:i="",isActive:o})=>{let r=(0,I.useExternalTarget)(i,n),s={$isActive:o,"data-testid":`${f.DROPDOWN_NAVIGATION_ITEM_TEST_ID}${o?"-active":""}`,"aria-current":o?"page":void 0},l=(0,S.getNavigationAnalytics)("dropdown",e,a,i,"main_navigation");return(0,t.jsx)(C.DropDownNavigationItemStyled,{children:a?(0,t.jsx)(C.DropDownNavigationLinkStyled,{"data-testid":f.DROPDOWN_NAVIGATION_ITEM_EXTERNAL_ID,onClick:()=>l&&window.analytics.sendEvent(l),target:r,"aria-current":o?"page":void 0,href:(0,N.appendQueryParamsToUrl)(a),$isActive:o,children:e}):(0,t.jsx)(k.default,{analytics:l,href:i,styledAnchor:C.DropDownNavigationLinkStyled,styledAnchorProps:s,children:e})})}),A=(0,n.memo)(({activeMainNavigationItemTitle:e,navigationData:a=[],isNavVisible:i,testId:o,onNavVisibleChange:r,isNewsPage:s,isHomePage:l})=>{let c=(0,n.useRef)(null),d=(0,n.useRef)(null),p=(0,n.useCallback)(()=>{c?.current&&d?.current&&r((0,S.isParentWiderThanChild)(c,d))},[c,d,r]);return(0,$.useResizeObserver)(c,p),(0,t.jsx)(C.NavigationSectionStyled,{"data-testid":o,ref:c,isFit:i,children:(0,t.jsx)(C.NavigationWrapper,{ref:d,children:(0,t.jsx)(C.MainNavigationWrapper,{children:a.map((n,a)=>(0,t.jsx)(T,{isNewsPage:s,isActive:l?"/home"===n.path||"/"===n.path:e===n.title,...n},a))})})})});var L=e.i(459949),D=e.i(65739),B=e.i(760814),H=e.i(339228);let F=B.default.ul.withConfig({displayName:"SubNavigation.styles__SubNavigationListStyled",componentId:"sc-6091112f-0"})`
  display: inline-block;
`,O=B.default.nav.withConfig({displayName:"SubNavigation.styles__SubNavigationInnerStyled",componentId:"sc-6091112f-1"})`
  white-space: nowrap;
  margin-bottom: -1px;
  display: block;

  & + & {
    border-top: 1px solid ${({theme:e})=>e.nav.lines.value};
  }
`,P=B.default.nav.withConfig({displayName:"SubNavigation.styles__SubNavigationContainerStyled",componentId:"sc-6091112f-2"})`
  ${({theme:e,$isLive:t})=>B.css`
    border-bottom: 1px solid ${e.nav.lines.value};
    position: relative;
    text-align: center;

    ${!t&&B.css`
      display: block;
      ${(0,H.applyStylesForBreakpoints)(B.css`
          display: none;
        `,"group4")};
    `};

    ${t&&B.css`
      display: block;
      ${(0,H.applyStylesForBreakpoints)(B.css`
          display: none;
        `,"group2")};
    `};
  `};
`,M=(0,n.memo)(({items:e,activeSubNavigationItemTitle:a,isLivePage:i})=>{let o=(0,n.useRef)(null),[r,s]=(0,n.useState)(e.length),[l,c]=(0,n.useState)(0),[d,p]=(0,n.useState)(!1),u=r>0&&r<e.length,g=(0,n.useMemo)(()=>{let n=e.slice(r);return(0,t.jsx)(t.Fragment,{children:n.map((e,n)=>(0,t.jsx)(E,{...e,isActive:a===e.title},n))})},[e,r]),h=(0,n.useCallback)(()=>p(e=>!e),[]),m=(0,n.useCallback)(()=>p(!1),[]);return(0,$.useResizeObserver)(o,(0,S.checkResponsiveFitment)(s,l)),(0,n.useEffect)(()=>{c(6*Math.max(...e.map(({title:e})=>e.length)))},[e]),(0,t.jsx)(P,{"data-testid":f.SUB_NAVIGATION,$isLive:i,children:(0,t.jsx)(O,{ref:o,children:(0,t.jsxs)(F,{children:[e.map((e,n)=>(0,t.jsx)(j,{...e,isActive:a===e.title},n)),u&&(0,t.jsxs)(L.Dropdown,{type:"subNav",overlay:g,isOpen:d,onDropdownToggle:h,onDropdownClose:m,children:["More ",(0,t.jsx)(D.default,{name:d?"arrows:arrow-up":"arrows:arrow-down"})]})]})})})}),R=(0,n.forwardRef)(({navigationData:e=[],headerHeight:n,isNavVisible:a,onNavVisibleChange:i,testId:o,showNavOnScroll:r},s)=>{let l=(0,d.useCurrentSlug)(),{error:c,clearError:p}=(0,_.useDismissibleError)(),{subNavigationItems:u,levels:g,isNewsPage:h,isHomePage:m,isLivePage:v}=(0,S.getActiveNavigationTree)(l,e),y=!!u?.length,b=g?.[0]?.title||"",w=g?.[1]?.title||"";return(0,t.jsxs)(C.NavigationContainerStyled,{"data-testid":f.NAVIGATION_TEST_ID,id:f.NAVIGATION_ID,ref:s,$top:n,$priority:!0,$showNavOnScroll:r,children:[(0,t.jsx)(A,{isHomePage:m,isNewsPage:h,activeMainNavigationItemTitle:b,navigationData:e,isNavVisible:a,onNavVisibleChange:i,testId:o}),c&&(0,t.jsx)(x.default,{errorString:c,onClick:p}),a&&y&&(0,t.jsx)(M,{isLivePage:v,items:u,activeSubNavigationItemTitle:w})]})}),G=(0,n.memo)(R);var U=e.i(292580),W=e.i(222009);let V=B.default.div.withConfig({displayName:"Drawer.styles__DrawerBackgroundStyled",componentId:"sc-211ba7ec-0"})`
  ${({theme:e,direction:t,animated:n,isOpen:a,offsetTop:i})=>B.css`
    position: fixed;
    display: block;
    bottom: 0;
    width: 100%;
    background-color: ${e.nav.background.value};
    visibility: ${a?"unset":"hidden"};

    ${(0,W.applyZIndex)("level3")};
    ${n&&B.css`
      transition: transform 0.1s ease-in-out;
    `};

    ${(()=>{switch(t){case"left":return B.css`
            top: ${i}px;
            left: 0;
            width: 320px;

            ${(0,H.applyStylesForBreakpoints)(B.css`
                width: 100%;
              `,"group2")};

            ${!a&&B.css`
              transform: translateX(-100%);
            `};
          `;case"right":return B.css`
            top: ${i}px;
            right: 0;
            width: 320px;

            ${(0,H.applyStylesForBreakpoints)(B.css`
                width: 100%;
              `,"group2")};

            ${!a&&B.css`
              transform: translateX(100%);
            `};
          `;default:return B.css`
            height: 65vh;
            ${!a&&B.css`
              transform: translateY(100%);
            `};
          `}})()};
  `};
`,z=({direction:e="left",isOpen:a=!1,children:i,testId:o,animated:r,onToggleOpen:s,offsetTop:l=0})=>{let c=(0,n.useRef)(null);return(0,n.useEffect)(()=>{if(!a||!c.current)return;let e=c.current,t=Array.from(e.querySelectorAll("a[href],button,input")).filter(e=>!e.hasAttribute("disabled")&&!e.getAttribute("aria-hidden"));t.length>0&&t[0].focus();let n=e=>{if("Tab"!==e.key)return;let n=t[0],a=t[t.length-1];document.activeElement===a&&(e.preventDefault(),n.focus())};return e.addEventListener("keydown",n),()=>{e.removeEventListener("keydown",n)}},[a]),(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(U.default,{isOpen:a,testId:o,offsetTop:l,onClick:s,variant:"lightest"}),(0,t.jsx)(V,{"data-testid":"drawer-background",animated:r,isOpen:a,direction:e,offsetTop:l,ref:c,children:i})]})};var K=e.i(704570),Y=e.i(771340),J=e.i(357391),Q=e.i(871071),Z=e.i(570549);let q=B.default.div.withConfig({displayName:"NavigationPanel.styles__DrawerContentStyled",componentId:"sc-f752c3ab-0"})`
  box-sizing: border-box;
  overflow-y: scroll;
  padding: 0 8px;
  height: 100%;
`,X=B.default.div.withConfig({displayName:"NavigationPanel.styles__IconWrapperStyled",componentId:"sc-f752c3ab-1"})`
  transform: ${({isOpen:e})=>e?"rotate(180deg)":"rotate(0deg)"};
  transition: transform 0.1s ease-in-out;
  justify-content: center;
  display: flex;
  height: 10px;
  width: 13px;
`,ee=B.default.button.withConfig({displayName:"NavigationPanel.styles__NavButtonStyled",componentId:"sc-f752c3ab-2"})`
  ${({special:e,selected:t,isNewsTitle:n,level:a,theme:i})=>B.css`
    grid-template-columns: 1fr auto;
    background-color: ${0!==a?"transparent":e?i.nav.level1.bgSpecial.value:i.nav.level1.bgDefault.value};
    padding: ${0===a?"13px 14px":"12px 32px"};
    position: relative;
    text-align: left;
    cursor: pointer;
    display: grid;
    border: none;
    width: 100%;
    gap: 22px;

    ${(0,Z.applyTypography)(i.nav.drawer[0===a?"level1":"level2"][t?"selected":"default"])};

    &:hover {
      background-color: ${i.nav[0===a?"level1":"level2"].bgHover.value};
    }

    &::before {
      background-color: ${0===a&&t?n?i.bbcNewsLogo.onDefaultBG.default.value:i.nav.content.value:"transparent"};
      transform: translateX(-100%);
      position: absolute;
      height: 100%;
      content: '';
      width: 8px;
      left: 0;
      top: 0;
    }
  `}
`,et=B.default.span.withConfig({displayName:"NavigationPanel.styles__NavButtonTextStyled",componentId:"sc-f752c3ab-3"})`
  overflow-wrap: break-word;
`,en=B.default.div.withConfig({displayName:"NavigationPanel.styles__NavContentStyled",componentId:"sc-f752c3ab-4"})`
  ${({theme:e,level:t,special:n})=>B.css`
    background-color: ${n?e.nav.level1.bgSpecial.value:0===t?e.nav.level1.bgDefault.value:"transparent"};
    padding-left: ${0!==t?"10px":0};
    position: relative;
    overflow: hidden;
    align-content: start;
    display: grid;
    height: 100%;
  `}
`,ea=B.default.div.withConfig({displayName:"NavigationPanel.styles__NavItemStyled",componentId:"sc-f752c3ab-5"})`
  ${({theme:e,level:t})=>B.css`
    border-bottom: ${0===t?`1px solid ${e.nav.level1.bgHover.value}`:"none"};
    background-color: ${0===t?e.nav.background.value:"transparent"};
    box-sizing: border-box;
    display: grid;
  `}
`,ei=B.default.div.withConfig({displayName:"NavigationPanel.styles__SearchInputBoxedStyled",componentId:"sc-f752c3ab-6"})`
  ${({theme:e})=>B.css`
    background-color: ${e.search.menu.background.value};
    border-bottom: 1px solid ${e.search.menu.backgroundBorder.value};
    padding: 8px;
    margin: 0 -8px;
  `}
`;B.default.div.withConfig({displayName:"NavigationPanel.styles__ExtraActionsStyled",componentId:"sc-f752c3ab-7"})`
  justify-content: center;
  justify-items: center;
  align-items: center;
  place-items: center;
  padding: 12px 0;
  display: flex;
  gap: 16px;
`;let eo=(0,n.forwardRef)(({onSearch:e,isHomePage:n,isOpen:a},i)=>{let{searchText:o,setSearchText:r,onSearchClick:s}=(0,Y.useSearch)(e);return(0,t.jsx)(ei,{children:(0,t.jsx)(J.default,{ref:i,searchText:o,isNavigationSearch:!0,onSearchTextChange:r,onSearch:s,isHomePage:n,isOpenNavPanel:a,isOnNavPanel:!0})})}),er=(0,n.memo)(()=>{let{worldNewsTvPath:e}=(0,K.usePageData)(),n=`navigationPanel-navItem-level0-${e}`;return e?(0,t.jsx)(ea,{level:0,"data-testid":n,children:(0,t.jsx)(Q.default,{visibleForBreakpoints:["group6","group2","group1"]})}):null});var es=e.i(701420),el=e.i(52154);let ec=({levels:e,onTogglePanelOpen:a,onSetOpenNavItem:i,openNavItems:o,level:r=0,data:s,slug:l,isHomePage:c})=>{let d=(0,n.useRef)(null),{title:p,isSpecial:u,subMenus:g=[],externalUrl:f,externalTarget:h,path:m}=s,y=m||"",b=(0,I.useExternalTarget)(y,h),w=!!s.subMenus?.length&&o[r]===y,x=!!y&&!f,_="news"===(0,es.default)(y?.split("/"))[0],$=(0,S.getNavigationAnalytics)("drawer",p,f,y,"navigation_panel"),C=`/${(0,es.default)(o[r-1]?.split("/"))}`,T=(0,n.useCallback)(e=>{if(Array.isArray(e))return i(e);let t=[...o.slice(0,r)];e===o[r]?i(t):(i([...t,y]),setTimeout(()=>{d?.current?.scrollIntoView({behavior:"smooth"})},0))},[y,r,i,o]),j=e=>()=>{e&&$&&window.analytics.sendEvent($),T(y),a()},E=(({isHomePage:e,href:t,levels:n,level:a})=>{if(e)return"/home"===t||"/"===t;if(!n||!n.length)return!1;let i=n[a];if(i)return i.path===t;let o=n.at(-1);return o?.path===t})({isHomePage:c,href:y,levels:e,level:r});return(0,t.jsx)(ea,{level:r,"data-testid":`navigationPanel-navItem-level${r}-${C}`,children:g.length?(0,t.jsxs)("div",{children:[(0,t.jsxs)(ee,{"data-testid":`level${r}NavButton-${y}`,isNewsTitle:_,selected:E,onClick:()=>{T(y)},special:u,level:r,children:[(0,t.jsx)(et,{"data-testid":`level${r}NavText-${y}`,children:p}),(0,t.jsx)(X,{isOpen:w,"data-testid":`menuItem-ChevronIconWrapper-${y}`,children:(0,t.jsx)(D.default,{testId:`menuItem-ChevronIcon-${y}`,name:"arrows:chevron-down"})})]}),w&&(0,t.jsx)(en,{"data-testid":`level${r}NavContent-${y}`,special:u,level:r,children:g.map((n,i)=>(0,t.jsx)(ec,{isHomePage:c,levels:e,slug:l,onTogglePanelOpen:a,onSetOpenNavItem:T,openNavItems:o,data:n,level:r+1},i))})]}):(0,t.jsx)(t.Fragment,{children:x?(0,t.jsx)(k.default,{analytics:$,prefetch:!1,passHref:!0,legacyBehavior:!0,href:y.includes(v.BASE_SLUG)?"/":y,tabIndex:-1,styledAnchorProps:{"aria-current":E?"page":void 0},children:(0,t.jsx)(ee,{isNewsTitle:_,"data-testid":`level${r}NavButton-${y}`,selected:E,onClick:j(!1),special:u,level:r,ref:d,children:(0,t.jsx)(et,{"data-testid":`level${r}NavText-${y}`,children:p})})}):(0,t.jsx)(el.AnchorStyled,{target:b,"aria-current":E?"page":void 0,...f?{href:(0,N.appendQueryParamsToUrl)(f)}:{},children:(0,t.jsx)(ee,{isNewsTitle:_,"data-testid":`level${r}NavButton-${f}`,selected:E,onClick:j(!0),special:u,level:r,ref:d,children:(0,t.jsx)("span",{"data-testid":`level${r}NavText-${f}`,children:p})})})})})},ed=B.default.details.withConfig({displayName:"NoJsNavigation.styles__NoJsMenuStyled",componentId:"sc-a2077f0f-0"})`
  z-index: 4001;
  position: fixed;
  top: 0;
  background: white;
  padding: 0 8px;
  display: block;
`,ep=B.default.ul.withConfig({displayName:"NoJsNavigation.styles__NoJsListStyled",componentId:"sc-a2077f0f-1"})`
  ${({$indent:e=0})=>B.css`
    padding: 0 0 8px ${16*e}px;

    ${0===e&&B.css`
      width: 320px;
      max-height: 80vh;
      overflow-y: auto;
      margin-top: 65px;
    `}
  `}
`,eu=B.default.summary.withConfig({displayName:"NoJsNavigation.styles__NoJsSummaryStyled",componentId:"sc-a2077f0f-2"})`
  position: absolute;
  left: 22px;
  top: 22px;
  cursor: pointer;
  display: block;
  ${({theme:e})=>(0,Z.applyTypography)(e.nav.topbar.level1.default)};
`,eg=B.default.li.withConfig({displayName:"NoJsNavigation.styles__NoJsListItemStyled",componentId:"sc-a2077f0f-3"})`
  ${({theme:e})=>B.css`
    border-bottom: 1px solid ${e.nav.lines.value};
    padding: 0 14px;
  `}
`,ef=({path:e,slug:n,title:a})=>{let i="home"===n?"/":`/${n}`;return(0,t.jsx)(eg,{children:(0,t.jsx)(C.MainNavigationLink,{href:e?(0,N.appendQueryParamsToUrl)(e):(0,N.appendQueryParamsToUrl)(i),$isActive:!1,children:a})})},eh=({navigationItem:e,indent:a})=>{let{subMenus:i=[],...o}=e;return(0,t.jsxs)(n.Fragment,{children:[(0,t.jsx)(ef,{...o}),(0,t.jsx)(ep,{$indent:a,children:i.map((e,n)=>(0,t.jsx)(eh,{indent:a+1,navigationItem:e},n))})]})},em=({navigationData:e})=>(0,t.jsx)("noscript",{children:(0,t.jsxs)(ed,{children:[(0,t.jsx)(eu,{children:(0,t.jsx)(D.default,{name:"actions:list-view-text",width:20,height:20})}),(0,t.jsx)(ep,{children:e.map((e,n)=>(0,t.jsx)(eh,{indent:1,navigationItem:e},n))})]})}),ev=(0,n.memo)(b.default),ey=(0,n.memo)(y.default),eb=({navigationData:e=[],headerHeight:a,showNavOnScroll:i,onHeightChange:o})=>{let r=(0,n.useRef)(null),[s,l]=(0,n.useState)(!0),c=(0,n.useCallback)(()=>{r.current&&o(r.current.getBoundingClientRect().height)},[o]);return(0,w.default)(r,c),(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(G,{ref:r,navigationData:e,isNavVisible:s,onNavVisibleChange:l,headerHeight:a,showNavOnScroll:i}),(0,t.jsx)(em,{navigationData:e})]})},ew=(0,n.memo)(({navigationData:e=[],onToggleOpen:a,isOpen:i,testId:o,offsetTop:r,forwardedInputRef:s,mainNavigationData:l})=>{let c=(0,d.useCurrentSlug)(),[p,u]=(0,n.useState)([""]),{levels:g,isHomePage:f}=(0,S.getActiveNavigationTree)(c,l,e);return(0,n.useEffect)(()=>()=>{u([""])},[]),(0,t.jsx)(z,{animated:!0,direction:"left",onToggleOpen:a,isOpen:i,offsetTop:r,children:(0,t.jsxs)(q,{"data-testid":o,children:[(0,t.jsx)(eo,{ref:s,onSearch:a,isHomePage:f,isOpen:i}),e.map((e,n)=>(0,t.jsx)(ec,{isHomePage:f,levels:g,slug:c,onTogglePanelOpen:a,onSetOpenNavItem:u,data:e,openNavItems:p},n)),(0,t.jsx)(er,{})]})})});e.s(["default",0,function(e){let y=y=>{let{type:b,isIndexPage:w=b===a.ContentType.IndexPage}=y,x=(0,d.useCurrentSlug)(),{data:_}=(0,r.default)("mainNavigation"),{data:S}=(0,r.default)("hamburgerNavigation"),{data:$}=(0,r.default)("footer"),k=(0,g.useUser)(),N=(0,n.useRef)(null),I=(0,n.useRef)(null),C=(0,n.useRef)(null),T=(0,c.useAuthAndBookmarkActions)(k),{isHeaderDefaultSize:j,showNav:E}=(0,u.useHeaderScroll)({headerRef:I}),[A,L]=(0,n.useState)(!1),[D,B]=(0,n.useState)(0),[H,F]=(0,n.useState)(0),[O,P]=(0,n.useState)(0),[M,R]=(0,v.getArrayFromSlug)(x),G="audio"===M&&["schedules","stations","play"].includes(R),U=y.worldNewsTvPath===`/${M}/`,W="video"===M||"news"===M&&"videos"===R||"reel"===M&&"video"===R,V=["subscribe","managesubscription"].includes(M)||["privacy-policy","terms-of-use","subscription-terms"].includes(R),z=M===v.BASE_SLUG,K=S.length?S:_,Y=j?l.HEADER_DEFAULT_HEIGHT:l.HEADER_COLLAPSED_HEIGHT,J=(0,n.useMemo)(()=>({showNav:E,headerHeight:E&&O>0?Math.max(Y,f.DEFAULT_HEADER_HEIGHT)+O:Y}),[E,Y,O]),Q=(0,n.useCallback)((e=!0)=>{let t=I.current,{top:n}=t.getBoundingClientRect();0!==n&&e&&window.scrollTo(0,n+window.scrollY);let{bottom:a}=t.getBoundingClientRect();F(a)},[D]),Z=(0,n.useCallback)(()=>L(!1),[]),q=()=>{Q(),L(!A)},X=(0,n.useCallback)(e=>{B(e)},[]);return(0,n.useEffect)(()=>{A?(document.body.setAttribute("style","overflow: hidden"),D&&Q(!1)):document.querySelector(".tp-iframe-wrapper.tp-active")||document.body.removeAttribute("style")},[A,D,Q]),(0,n.useEffect)(()=>{let{current:e}=I;if(!(0,o.default)(e)){let{bottom:t}=e.getBoundingClientRect();F(t)}},[]),(0,p.useGlobalKeydown)(e=>{let t=(0,i.default)(e.target,C.current);("Enter"===e.key||" "===e.key)&&t&&!A&&(e.preventDefault(),q()),"Tab"===e.key&&t&&A&&(e.preventDefault(),N.current.focus())},[A]),(0,p.useGlobalKeydown)(e=>{let t=(0,i.default)(e.target,N.current),n=e.shiftKey;"Tab"===e.key&&n&&t&&(e.preventDefault(),C.current.focus())}),(0,p.useGlobalKeydown)(e=>{"Escape"===e.key&&A&&(q(),C.current.focus())},[A]),(0,t.jsxs)(h.default,{value:J,children:[!(G||W||V||U)&&(0,t.jsx)(s.default,{type:"interstitial"}),z&&(0,t.jsx)(s.default,{type:"top",onAdvertRendered:X,showPlaceholder:!0}),(0,t.jsx)(ev,{id:"bbc-header",ref:I,mainPageUrl:"/",isBurgerMenuOpened:A,onToggleMenuClick:q,onHeaderLogoClick:Z,actions:T,toggleMenuButtonRef:C,isHeaderDefaultSize:j}),(0,t.jsx)(eb,{isIndexPage:w,navigationData:_,headerHeight:Y,showNavOnScroll:E,onHeightChange:P}),(0,t.jsx)(ew,{forwardedInputRef:N,navigationData:K,mainNavigationData:_,isOpen:A,onToggleOpen:q,offsetTop:H}),(0,t.jsx)("main",{id:"bbc-main",children:(0,t.jsx)(e,{...y})}),(0,t.jsx)(ey,{id:"bbc-footer",testId:"main-footer",...$}),(0,t.jsx)(m.default,{pageType:y?.type||"article"})]})};return y.displayName=e.displayName,y},"getIsAppLayoutEnabled",0,e=>{let{pageProps:t}=e,{state:n}=t,{isMobileWebview:a}=n;return a}],907182)},152504,e=>{"use strict";e.s(["IS_APP_LAYOUT_ENABLED_SESSION_KEY",0,"isAppLayoutEnabled"])},474085,e=>{"use strict";var t=e.i(191788),n=e.i(907182),a=e.i(152504);e.s(["useIsAppLayoutEnabled",0,function(e){let[i,o]=(0,t.useState)(!!e&&(0,n.getIsAppLayoutEnabled)(e));return(0,t.useEffect)(()=>{("true"===sessionStorage.getItem(a.IS_APP_LAYOUT_ENABLED_SESSION_KEY)||window.navigator.userAgent.includes("bbcx-mobile-webview"))&&(o(!0),sessionStorage.setItem(a.IS_APP_LAYOUT_ENABLED_SESSION_KEY,"true"))},[]),i}])}]);