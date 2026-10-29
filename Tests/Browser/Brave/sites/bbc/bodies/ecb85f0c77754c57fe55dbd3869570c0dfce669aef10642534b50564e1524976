(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,117191,e=>{"use strict";var t=e.i(391398),i=e.i(191788),n=e.i(868783),a=e.i(895270),o=e.i(704570),r=e.i(147097),l=e.i(760814),s=e.i(339228);let d=e=>l.css`
  ${({theme:t})=>l.css`
    .dotcom-ad.active {
      padding-top: 15px;
      padding-bottom: 5px;

      ${e?l.css`
            background-color: ${t.advert.onInverse.container.value} !important;
            border-top: 1px solid ${t.advert.onInverse.border.value} !important;
            border-bottom: 1px solid ${t.advert.onInverse.border.value} !important;
          `:l.css`
            border-top: 1px solid ${t.advert.border.value} !important;
            border-bottom: 1px solid ${t.advert.border.value} !important;
          `};
    }
  `};
`,c=l.default.div.withConfig({displayName:"AdSlot.styles__AdSlotContainerStyled",componentId:"sc-4b576bed-0"})`
  ${({theme:e,$isDark:t,$type:i,$hasPlaceholder:n})=>{let a,o;return l.css`
    ${n&&(a="mid"===i||i?.startsWith("mid_"),o="sid"===i||i?.startsWith("sid_"),l.css`
        background-color: ${e.advert.container.value};

        ${o&&l.css`
          max-height: 655px;
        `}

        ${a&&l.css`
          /* - Ad: 250px
           * - dotcom-ad-text-wrapper (25px with -12px margin-top): +13px
           * - dotcom-ad-inner margin-bottom: +8px
           * - Container padding + borders (15px + 5px + 1px + 1px): +22px
           */
          height: 293px;

          ${(0,s.applyStylesForBreakpoints)(l.css`
              height: 293px;
            `,"group4")}

          ${(0,s.applyStylesForBreakpoints)(l.css`
              height: 293px;
            `,"group2")}
        `}

        ${!a&&!o&&l.css`
          height: 278px;

          ${(0,s.applyStylesForBreakpoints)(l.css`
              height: 118px;
            `,"group4")}

          ${(0,s.applyStylesForBreakpoints)(l.css`
              height: 78px;
            `,"group2")}
        `}
      `)};

    ${(()=>{switch(i){case"spo":case"col":return l.css``;case"mid":return l.css`
            ${d(t)};

            ${t?l.css`
                  padding-block: 24px;

                  ${(0,s.applyStylesForBreakpoints)(l.css`
                      padding-block: 16px;
                    `,"group2")}
                `:l.css`
                  margin-block: 48px;

                  ${(0,s.applyStylesForBreakpoints)(l.css`
                      margin-block: 32px;
                    `,"group2")}
                `};
          `;default:return l.css`
            ${d(t)};
          `}})()};
  `}};
`,p=l.default.div.withConfig({displayName:"AdSlot.styles__AdSlotDummyContainerStyled",componentId:"sc-4b576bed-1"})`
  display: contents;
`;function u(e){let[t]=e.split("_");return t}let g=({type:e,sponsorAdTargetingValues:n=null,isFullWidth:l=!0,onAdvertRendered:s,deferRequest:d=!1,forwardedAdRef:g={current:null},showPlaceholder:m=!1,showContainer:y=!0})=>{let{allowAdvertising:h=!0}=(0,o.usePageData)(),f=(0,r.getIsClient)(),_=(0,i.useRef)(null),v=(0,i.useRef)(null),b=(0,a.useDarkMode)(),[x,w]=(0,i.useState)(e),[k,$]=(0,i.useState)(m||e.includes("sid_")),S=()=>{let e=new IntersectionObserver(([t])=>{!t.isIntersecting&&($(!1),v.current&&e.unobserve(v.current))},{root:null,rootMargin:"0px",threshold:0});v.current&&e.observe(v.current)},I=()=>{if(!h)return;let{coll_name:e}=n||{};f&&"col"===x&&(window._ads=window._ads||{colSlots:{},colSlotCount:0},window._ads.colSlots[e]?w(`col_${window._ads.colSlots[e]}`):(window._ads.colSlotCount++,window._ads.colSlots[e]=window._ads.colSlotCount,w(`col_${window._ads.colSlotCount}`))),window.dotcom.cmd.push(()=>{n?window.dotcom.ads.registerSlot(x,n):window.dotcom.ads.registerSlot(x),(s||m)&&window.googletag.cmd.push(()=>{window.googletag.pubads().addEventListener("slotRenderEnded",e=>{let{slot:t,isEmpty:i,size:n}=e;if(t.getSlotElementId().replace("dotcom-slot-","")===x){let[,e]=n??[0,0];s?.(e),i?S():$(!1)}})})})},C=()=>{k&&S()};return((0,i.useImperativeHandle)(g,()=>({requestAd:I,closePlaceholder:C})),(0,i.useEffect)(()=>{if(!h||d)return;I();let e=_.current;return()=>{e&&window.dotcom.cmd.push(()=>{window.dotcom.ads.destroySlot(x)})}},[x,h,d]),h)?(0,t.jsx)(y?c:p,{ref:v,"data-testid":"ad-unit","data-component":"ad-slot",$type:u(e),$isFullWidth:l,$isDark:b,$hasPlaceholder:k,children:(0,t.jsx)("div",{ref:_,"data-testid":`dotcom-${x}`,id:`dotcom-${x}`,className:"dotcom-ad"})}):null};g.displayName="AdSlot";let m=(0,n.withCMSFallback)(g,({type:e,isFullWidth:i=!0})=>(0,t.jsx)(c,{$type:u(e),$isFullWidth:i,$isDark:!1,$hasPlaceholder:!1,"data-component":"ad-slot","data-testid":"ad-unit",children:(0,t.jsx)("div",{"data-testid":`dotcom-${e}`,id:`dotcom-${e}`,className:"dotcom-ad"})}));e.s(["AdSlot",0,g,"default",0,m],117191)},324951,e=>{"use strict";var t=e.i(191788);e.s(["useOutsideClicker",0,function(e,i,n="click"){let a=(0,t.useRef)(!1);(0,t.useEffect)(()=>{function t(t){let{current:n}=a,{current:o}=e,r=o?.contains(t.target);n&&o&&!r&&i(t)}return a.current=!1,setTimeout(()=>{a.current=!0},0),document.addEventListener(n,t),()=>{document.removeEventListener(n,t)}},[e,i,n])}],324951)},394941,(e,t,i)=>{"use strict";Object.defineProperty(i,"__esModule",{value:!0}),Object.defineProperty(i,"default",{enumerable:!0,get:function(){return l}});let n=e.r(191788),a="u"<typeof window,o=a?()=>{}:n.useLayoutEffect,r=a?()=>{}:n.useEffect;function l(e){let{headManager:t,reduceComponentsToState:i}=e;function l(){if(t&&t.mountedInstances){let e=n.Children.toArray(Array.from(t.mountedInstances).filter(Boolean));t.updateHead(i(e))}}return a&&(t?.mountedInstances?.add(e.children),l()),o(()=>(t?.mountedInstances?.add(e.children),()=>{t?.mountedInstances?.delete(e.children)})),o(()=>(t&&(t._pendingUpdate=l),()=>{t&&(t._pendingUpdate=l)})),r(()=>(t&&t._pendingUpdate&&(t._pendingUpdate(),t._pendingUpdate=null),()=>{t&&t._pendingUpdate&&(t._pendingUpdate(),t._pendingUpdate=null)})),null}},280963,(e,t,i)=>{"use strict";Object.defineProperty(i,"__esModule",{value:!0});var n={default:function(){return y},defaultHead:function(){return p}};for(var a in n)Object.defineProperty(i,a,{enumerable:!0,get:n[a]});let o=e.r(741705),r=e.r(952456),l=e.r(391398),s=r._(e.r(191788)),d=o._(e.r(394941)),c=e.r(713584);function p(){return[(0,l.jsx)("meta",{charSet:"utf-8"},"charset"),(0,l.jsx)("meta",{name:"viewport",content:"width=device-width"},"viewport")]}function u(e,t){return"string"==typeof t||"number"==typeof t?e:t.type===s.default.Fragment?e.concat(s.default.Children.toArray(t.props.children).reduce((e,t)=>"string"==typeof t||"number"==typeof t?e:e.concat(t),[])):e.concat(t)}e.r(894470);let g=["name","httpEquiv","charSet","itemProp"];function m(e){let t,i,n,a;return e.reduce(u,[]).reverse().concat(p().reverse()).filter((t=new Set,i=new Set,n=new Set,a={},e=>{let o=!0,r=!1;if(e.key&&"number"!=typeof e.key&&e.key.indexOf("$")>0){r=!0;let i=e.key.slice(e.key.indexOf("$")+1);t.has(i)?o=!1:t.add(i)}switch(e.type){case"title":case"base":i.has(e.type)?o=!1:i.add(e.type);break;case"meta":for(let t=0,i=g.length;t<i;t++){let i=g[t];if(e.props.hasOwnProperty(i))if("charSet"===i)n.has(i)?o=!1:n.add(i);else{let t=e.props[i],n=a[i]||new Set;("name"!==i||!r)&&n.has(t)?o=!1:(n.add(t),a[i]=n)}}}return o})).reverse().map((e,t)=>{let i=e.key||t;return s.default.cloneElement(e,{key:i})})}let y=function({children:e}){let t=(0,s.useContext)(c.HeadManagerContext);return(0,l.jsx)(d.default,{reduceComponentsToState:m,headManager:t,children:e})};("function"==typeof i.default||"object"==typeof i.default&&null!==i.default)&&void 0===i.default.__esModule&&(Object.defineProperty(i.default,"__esModule",{value:!0}),Object.assign(i.default,i),t.exports=i.default)},958678,(e,t,i)=>{t.exports=e.r(280963)},102358,680516,e=>{"use strict";var t=e.i(147097),i=e.i(240911);function n(e){return e?.current?.clientWidth||0}e.s(["DEFAULT_HEADER_HEIGHT",0,65,"DROPDOWN_NAVIGATION_ITEM_EXTERNAL_ID",0,"dropdown-navigation-item-external","DROPDOWN_NAVIGATION_ITEM_TEST_ID",0,"dropdown-navigation-item","MAIN_NAVIGATION_ITEM",0,"mainNavigationItemStyled","MAIN_NAVIGATION_LINK_TEST_ID",0,"mainNavigationLink","NAVIGATION_ID",0,"main-navigation-container","NAVIGATION_TEST_ID",0,"level1-navigation-container","NAVIGATION_THRESHOLD",0,100,"SUB_NAVIGATION",0,"level2-navigation-container","SUB_NAVIGATION_LINK_TEST_ID",0,"subNavigationLink"],680516);let a={header:"header",main:"main",sub:"sub_navigation",dropdown:"sub_navigation",drawer:"drawer",footer:"footer",error:"error"};e.s(["checkResponsiveFitment",0,(e,t,i=!1)=>n=>{let[{target:a,contentRect:o}]=n,{children:r}=a,{width:l}=o,{children:s}=r[0],d=Array.from(s),c=i?l/1.6:l;d.reduce((e,t)=>{let{clientWidth:i}=t;return e>c&&!t.hasAttribute("data-show")?t.setAttribute("data-hidden","true"):t.removeAttribute("data-hidden"),e+i},100+t),e(d.findIndex(e=>e.hasAttribute("data-hidden")))},"getActiveNavigationTree",0,(e,t,n)=>{let a=(0,i.getStringFromSlug)(e,!0,!1),o=(e,t,i=[],n=1)=>{for(let a of t){if(a.path===e)return{activeNavigationItem:{...a,level:n},parents:i};if(a.subMenus&&a.subMenus.length>0){let t=o(e,a.subMenus,[...i,{...a,level:n}],n+1);if(t.activeNavigationItem)return t}}return{activeNavigationItem:null,parents:[]}},{activeNavigationItem:r,parents:l}=n&&o(a,n)||{},{activeNavigationItem:s,parents:d}=o(a,t),c=(l?.length?[...l,r]:[...d,s]).map(e=>{let{title:t,level:i,path:n=""}=e||{};return e&&{title:t,level:i,path:n}}).filter(Boolean),p="/home"===a||"/"===a,u=!!s&&!p,g=[...d,s],m=g?.[0]||null,y=m?.subMenus||[],h=u&&s&&g.indexOf(s)>=1?s.subMenus?.length?s:c.length>2?d.slice(-1)[0]:s:null,f=g.indexOf(s)>=1&&h&&h?.subMenus||[],_=c?.[0]?.title||"",v=!!f.length,b="live"===_.toLowerCase(),x="news"===_.toLowerCase(),w=h?.title||null;return{isHomePage:p,isLivePage:b,isNestedMainNav:u,isNestedNavAvailable:v,isNewsPage:x,levels:!!c.length&&c||null,nestedNavigationItems:f,subNavigationItems:y,activeNavigationItem:s,nestedNavigationTitle:w}},"getNavigationAnalytics",0,(e,i,n,o,r)=>{if((0,t.getIsClient)()){let t=o?.toString()[0]==="/"?"":"/";return{eventGrouping:"navigation",eventProperties:{item_name:i,item_link:n||`${window?.location.origin}${t}${o}`,group_name:r||"navigation",group_type:a[e]}}}},"isParentWiderThanChild",0,function(e,t){return!e.current||!t.current||n(e)>n(t)}],102358)},581620,e=>{"use strict";e.s(["SEARCH_RESULTS_MAX_PAGES",0,29,"SEARCH_SLUG",0,"search"])},771340,362132,357391,500131,e=>{"use strict";var t=e.i(191788),i=e.i(581620);let n=function(e){let t=new URLSearchParams(e),n=t.toString().length>0?`?${t.toString()}`:"";return`/${i.SEARCH_SLUG}${n}`};e.s(["getSearchUrl",0,n],362132);var a=e.i(746857);e.s(["useSearch",0,function(e){let[i,o]=(0,t.useState)(""),r=(0,a.useAppRouter)(),l=(0,t.useCallback)(t=>{if(!t)return;let i=n({q:t});r.push(i).then(()=>{o(""),e?.()})},[r,e]);return{searchText:i,setSearchText:o,onSearchClick:l}}],771340);var o=e.i(391398),r=e.i(84541),l=e.i(901414),s=e.i(324951),d=e.i(760814);let c=d.default.span.withConfig({displayName:"VisuallyHidden.styles__VisuallyHiddenStyled",componentId:"sc-69248fc2-0"})`
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
`,p=({as:e,testId:t,children:i})=>(0,o.jsx)(c,{"data-testid":t,as:e,children:i});var u=e.i(567290),g=e.i(339228),m=e.i(570549);let y=d.default.div.withConfig({displayName:"SearchInput.styles__SearchInputWrapperStyled",componentId:"sc-50f6a0bc-0"})`
  ${({$isPopulated:e,$isNavigationSearch:t,theme:i})=>d.css`
    position: relative;
    display: flex;
    border: 1px solid ${i.search.field.borderDefault.value};
    width: 100%;
    height: ${t?"44px":"52px"};
    background-color: ${i.search.field.background.value};

    &:focus-within,
    &:hover {
      border: 2px solid ${i.search.field.borderFocused.value};
      margin: -1px;
    }

    & svg[icon='search'] {
      width: 20px;
      height: 20px;
    }

    & svg[icon='close'] {
      width: ${t?"12px":"20px"};
      height: ${t?"12px":"20px"};
    }

    ${u.GeneralButton} {
      width: ${t?"44px":"52px"};
      height: ${t?"44px":"52px"};
      outline: 1px solid ${i.search.button.default.value};

      & span {
        width: 18px;
      }
    }

    ${u.UnboxedButton} {
      width: ${t?"44px":"52px"};
      height: ${t?"44px":"52px"};
      outline: 0;
      border: 0;

      &:hover {
        background-color: ${i.search.field.background.value};
        color: ${i.search.button.default.value};
        outline: 0;
        border: 0;
      }
    }

    ${!e&&d.css`
      &:hover {
        border: 2px solid ${i.search.field.borderHover.value};
        margin: -1px;
        & ${u.GeneralButton} {
          background-color: ${i.interactive1.onDefaultBG.hovered.value};
          border: 2px solid ${i.interactive1.onDefaultBG.hovered.value};
          outline: 0;
        }
      }
    `};
  `}
`,h=d.default.input.withConfig({displayName:"SearchInput.styles__SearchInputStyled",componentId:"sc-50f6a0bc-1"})`
  ${({theme:e,$isNavigationSearch:t})=>d.css`
    flex: 1;
    border: none;
    outline: none;
    color: ${e.search.text.default.value};
    padding: ${t?"13px 0 13px 13px":"15px 0 15px 12px"};
    ${t?(0,m.applyTypography)(e.searchMenuText.bpLarge):(0,m.applyTypography)(e.searchText.bpLarge)};
    font-size: 16px;
    width: 40px;

    ${(0,g.applyStylesForBreakpoints)(d.css`
        ${t?(0,m.applyTypography)(e.searchMenuText.bpSmall):(0,m.applyTypography)(e.searchText.bpSmall)};
        font-size: 16px;
      `,"group2")}
  `}
`,f=d.default.div.withConfig({displayName:"SearchInput.styles__SuggestionsWrapperStyled",componentId:"sc-50f6a0bc-2"})`
  ${({theme:e})=>d.css`
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    padding: 16px 13px;
    position: absolute;
    top: calc(100% + 1px);
    left: 0;
    width: 100%;
    box-sizing: border-box;
    background-color: ${e.search.menu.background.value};
    border: 1px solid ${e.search.menu.backgroundBorder.value};
    z-index: 8;
  `}
`,_=d.default.div.withConfig({displayName:"SearchInput.styles__SuggestionsItemStyled",componentId:"sc-50f6a0bc-3"})`
  display: flex;
  align-items: center;
  cursor: pointer;
  width: 100%;
  font-family: ${({theme:e})=>e.fontFamilies.bbcReithSerif};
  font-size: 16px;
  line-height: 28px;
  letter-spacing: -0.01em;

  &:not(:last-of-type) {
    margin-bottom: 12px;
  }

  b {
    font-weight: 500;
    display: inline;
  }
`,v=({suggestions:e,searchText:t,onSuggestionClick:i,testId:n})=>(0,o.jsx)(f,{"data-testid":n,children:e.map((e,n)=>(0,o.jsx)(_,{"data-testid":"suggestions-item",onClick:()=>i(e),children:(0,o.jsx)(b,{text:e,keyword:t})},n))}),b=({text:e,keyword:t})=>(0,o.jsx)(o.Fragment,{children:((e,t)=>{if(""===t)return e;let i=RegExp(`^${t}`,"i"),n=e.split(i),[a,r]=n;return 1===n.length?a:(0,o.jsxs)(o.Fragment,{children:[(0,o.jsx)("b",{children:e.match(i)}),r]})})(e,t)}),x=(0,t.forwardRef)(({isNavigationSearch:e=!1,placeholderText:i="Search news, topics and more",searchText:n,suggestions:a=[],onSearchTextChange:d,onSearch:c,isHomePage:u=!1,isOpenNavPanel:g=!1,isOnNavPanel:m=!1},f)=>{let[_,b]=(0,t.useState)(!1),x=(0,t.useRef)(null),w=(0,t.useRef)(!1),[k,$]=(0,l.useBreakpoints)("SearchInput"),[S,I]=(0,t.useState)(!0),[C,A]=(0,t.useState)(!1),E=(0,t.useRef)(null),P=(0,t.useId)();(0,t.useImperativeHandle)(f,()=>E.current);let T=()=>{n&&(c(n),b(!1))},j=(0,t.useCallback)(e=>{d(e),b(!1)},[d]),N=(0,t.useCallback)(()=>{j("")},[j]);return(0,s.useOutsideClicker)(x,()=>{b(!1)}),(0,t.useEffect)(()=>{w.current=u&&$},[k]),(0,t.useEffect)(()=>{C||g||!w.current||setTimeout(()=>{let e=document.getElementsByTagName("header");e[0]&&(e[0].style.position="sticky");let t=document.getElementById("bbc-main");t&&(t.style.marginTop="unset")},100)},[C,g]),m?g?setTimeout(()=>{S&&I(!1)},100):S||I(!0):S&&I(!1),(0,o.jsxs)(y,{ref:x,$isPopulated:!!n,$isNavigationSearch:e,"data-testid":"search-input-wrapper",children:[(0,o.jsx)("label",{htmlFor:P,children:(0,o.jsx)(p,{children:"Site search"})}),(0,o.jsx)(h,{ref:E,id:P,type:"text",placeholder:i,value:n,"data-testid":"search-input-field",$isNavigationSearch:e,onChange:e=>{let{target:{value:t}}=e;d(t),b(!!t.length)},onKeyDown:e=>{"Enter"===e.key&&T()},onFocus:()=>{if(A(!0),w.current){let e=document.getElementsByTagName("header");e[0]&&(e[0].style.position="fixed");let t=document.getElementById("bbc-main");t&&(t.style.marginTop="90px")}},onBlur:()=>{A(!1)},disabled:S}),!!n&&(0,o.jsx)(r.default,{icon:"actions:close",testId:"search-input-clear-button",onClick:N,type:"unboxed",ariaLabel:"Clear"}),(0,o.jsx)(r.default,{icon:"actions:search",testId:"search-input-search-button",onClick:T,"aria-label":"Search"}),_&&!!a.length&&(0,o.jsx)(v,{testId:"suggestions-box",suggestions:a,searchText:n,onSuggestionClick:j})]})});e.s(["default",0,x],357391);var w=e.i(923976);e.s(["PageDataProvider",()=>w.default],500131)},481978,e=>{"use strict";var t=e.i(417183),i=e.i(564045),n=e.i(508259),a=e.i(21540);let o={forms_button:{action_type:"viewability",action_name:"select",group_type:"form",item_type:"button"},forms_input:{action_type:"viewability",action_name:"select",group_type:"form"},indexCard_select:{action_type:"viewability",action_name:"select"},indexCard_view:{action_type:"viewability",action_name:"view"},subsection_view:{action_type:"viewability",action_name:"view"},navigation:{action_type:"click",action_name:"navigation"},click_action:{action_type:"click",action_name:"action"},click_exit:{action_type:"click",action_name:"exit"},article_share:{action_type:"article",action_name:"share",item_type:"icon_share",group_name:"share_menu"},av_share:{action_type:"av",action_name:"share",item_type:"icon_share",group_name:"share_menu"},internal_search_result_click:{action_type:"internal_search_result",action_name:"click"},internal_search_result_display:{action_type:"internal_search_result",action_name:"display"},ads_click:{action_type:"ads",action_name:"click"},ads_impression:{action_type:"ads",action_name:"impression"},page_scroll:{action_type:"page",action_name:"scroll"},bookmark_add:{action_type:"bookmark",action_name:"add",item_name:"bookmark"},bookmark_remove:{action_type:"bookmark",action_name:"remove",item_name:"unbookmark"},ads_blocked:{action_type:"ads",action_name:"blocked"},optimizely:{mv_engine_name:"Optimizely",action_type:"mv_test",action_name:"display"},section_title_select:{action_type:"viewability",action_name:"select"},account_option:{action_type:"viewability",action_name:"select",group_name:"account_option"},sign_in:{action_type:"signin",action_name:"select",item_name:"sign_in"},register:{action_type:"registration",action_name:"select",item_name:"register"},subscribe:{action_type:"subscription",action_name:"select",item_name:"subscribe"},av_follow:{action_type:"av",action_name:"follow",item_name:"follow"},av_unfollow:{action_type:"av",action_name:"unfollow",item_name:"unfollow"},av_lfv_cta:{action_type:"click",action_name:"action",group_name:"lfv_option"}};e.s(["default",0,({eventGrouping:e,eventProperties:r,groupProperties:l})=>{try{let{action_name:s,action_type:d,...c}=o[e],{echoClient:p,data:u}=window.analytics,g={...u,...c,...l,...r};p?((0,i.getRunningEnvironment)()!==a.RunningEnvironment.LIVE&&("indexCard_view"===e||"indexCard_select"===e)&&((0,t.default)(l)||!l)&&n.logger.debug("### sendAnalyticsEventByMap/sendEvent ===> group properties might be missing!",{...r,groupProperties:l}),"ads_blocked"===e||"internal_search_result_display"===e?setTimeout(()=>{p?.userActionEvent?.(d,s,g)},100):p?.userActionEvent?.(d,s,g)):window.analytics.buffer.push({eventGrouping:e,eventProperties:r,groupProperties:l})}catch(t){let e=`Failed to send analytics event: ${t}`;throw n.logger.error(e),Error(e)}}])},463226,660021,292580,172035,e=>{"use strict";var t=e.i(391398),i=e.i(191788),n=e.i(893409),a=e.i(84541),o=e.i(120928),r=e.i(772701),l=e.i(901414);let s=function(e,t=[]){(0,i.useEffect)(()=>(window.addEventListener("keydown",e),()=>{window.removeEventListener("keydown",e)}),t)};e.s(["useGlobalKeydown",0,s],660021);var d=e.i(324951),c=e.i(46230),p=e.i(490602),u=e.i(760814),g=e.i(339228),m=e.i(570549),y=e.i(222009);let h=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__AlbertaModalStyled",componentId:"sc-3996c3f6-0"})(({theme:e})=>u.css`
    position: relative;
    aspect-ratio: 9 / 16;
    background-color: ${e.container.onDefaultBG3.value};
    /* stylelint-disable-next-line plugin/no-unsupported-browser-features */
    height: min(90vh, 900px);

    ${(0,y.applyZIndex)("level2")};

    ${(0,g.applyStylesForBreakpoints)(u.css`
        aspect-ratio: unset;
        height: unset;
      `,"group2")}
  `),f=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__AlbertaCloseButtonContainerStyled",componentId:"sc-3996c3f6-1"})`
  position: absolute;
  top: 0;
  left: calc(100% + 24px);

  ${(0,g.applyStylesForBreakpoints)(u.css`
      display: none;
    `,"group2")}
`,_=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__ContentOverlayStyled",componentId:"sc-3996c3f6-2"})(({theme:e,$controlsVisible:t})=>u.css`
    position: absolute;
    bottom: 80px;
    left: 16px;
    right: 16px;
    ${(0,y.applyZIndex)("level3")};
    color: ${e.text.onInverseBG.default.value};
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 16px;

    /* Let pointer events fall through to the SMP player; only interactive
       children opt back in below. */
    pointer-events: none;

    opacity: ${t?"1":"0"};
    transition: opacity 0.2s ease;

    /* Keep the overlay up while hovered/focused. Required, not cosmetic:
       moving onto a child makes SMP hide its bar, and without this the child
       would lose pointer-events mid-click. */
    &:hover,
    &:focus-within {
      opacity: 1;
    }

    & > * {
      pointer-events: ${t?"auto":"none"};
    }

    &:hover > *,
    &:focus-within > * {
      pointer-events: auto;
    }

    ${(0,g.applyStylesForBreakpoints)(u.css`
        position: fixed;
      `,"group2")}
  `),v=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__ContentTextContainerStyled",componentId:"sc-3996c3f6-3"})`
  flex: 1;
  min-width: 0;
`,b=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__ShareButtonContainerStyled",componentId:"sc-3996c3f6-4"})`
  flex-shrink: 0;
`,x=u.default.a.withConfig({displayName:"AlbertaVideoModal.styles__VideoTitleLink",componentId:"sc-3996c3f6-5"})(({theme:e})=>u.css`
    ${(0,m.applyTypography)(e.generic.info1.emphasised.bpSmall)};

    margin: 0;
    color: ${e.text.onInverseBG.default.value};
    text-decoration: none;
    font-size: 12px;
    line-height: 24px;
    font-weight: 700;
    &:hover {
      text-decoration: underline;
    }
  `);e.s(["default",0,({onClose:e,blocks:u,playlistLabels:g,startIndex:m,holdingImageUrls:y,contentPageHrefs:w=[],contentPageTitles:k=[],onwardJourneyHrefs:$=[],onwardJourneyLinkTexts:S=[],contentIds:I=[],subtypes:C=[]})=>{let A=(0,i.useRef)(null),E=(0,i.useRef)(m),[P]=(0,l.useBreakpoints)("AlbertaVideoModal"),T="not-set"!==P,j=["group1","group2"].includes(P),[N,F]=(0,i.useState)(!1),[B,L]=(0,i.useState)(m),[O,M]=(0,i.useState)(!1),[R,D]=(0,i.useState)(!1),V=w[B],U=k[B]||"",G=$[B],H=S[B]||"",z=I[B]||"",W=g[B],K=C[B],Z=W?{av_content_id:W.content_id,av_content_type:W.content_type,av_content_duration_range:"sfv-vertical"}:void 0,q=G&&(0,r.isExternalLink)(G),J=G&&(0,o.isBBCExternal)(G),X={eventGrouping:q&&!J?"click_exit":"click_action",eventProperties:{item_name:H,item_type:"custom_link",item_link:G||"",item_resource_id:z,item_position:B+1},groupProperties:{group_name:H,group_type:K,group_resource_id:z,group_position:B+1,group_item_count:g.length}};return(0,d.useOutsideClicker)(A,t=>{let i=t.target;i?.closest('[data-testid="popoverStyled"], [data-testid="popoverOverlay"]')||e()}),s(t=>{"Escape"===t.key&&e()}),(0,t.jsxs)(h,{ref:A,tabIndex:-1,role:"dialog","aria-label":"Video player",children:[T&&(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(c.default,{playerOrientation:"portrait",blocks:u,playlistLabels:g,activeIndex:m,playerPosition:"alberta-modal",uiOverrides:{swipable:{enabled:!0,direction:"Y"},fullscreen:j?{enabled:!0,useCloseIconForExitFullscreen:!0}:{enabled:!1},chromecast:{enabled:!1},subtitles:{enabled:!0},pictureInPicture:{enabled:!1},controls:{speed:!0,includeNextButton:!0,includePreviousButton:!0}},disableAds:!0,disableCta:!0,onExitFakeFullscreen:e,autoEnterFakeFullscreen:j,holdingImageUrls:y,onPlayerInitialized:e=>{F(!0),e.bind("uiControlBarShown",()=>{M(!0)}),e.bind("uiControlBarHidden",()=>{M(!1)})},onNextOnwardJourneyItemStartsPlaying:e=>{if(void 0===e.index)return;let t=E.current,i=e.index,n=i>t,a=S[t]||"",o=I[t]||"",r=S[i]||"",l=$[i]||"",s=I[i]||"";window.analytics.sendEvent({eventGrouping:"click_action",eventProperties:{item_name:n?"play_next":"play_previous",item_type:"navigation_button",item_text:r,item_link:l,item_resource_id:s,item_position:i+1},groupProperties:{group_name:a,group_type:K,group_resource_id:o,group_position:t+1,group_item_count:g.length}}),E.current=i,L(i),D(!1)}}),N&&(G||V)&&(0,t.jsxs)(_,{$controlsVisible:O||R,children:[G&&(0,t.jsx)(v,{children:(0,t.jsx)(n.default,{href:G,styledAnchor:x,analytics:X,children:H})}),V&&(0,t.jsx)(b,{children:(0,t.jsx)(p.default,{trigger:"click",alignment:"top-right",isButtonInverse:!1,type:"general",size:"small",iconOnly:!0,isAvContent:!0,title:U,href:V,avProperties:Z,onOpenChange:D},`share-${B}`)})]})]}),(0,t.jsx)(f,{children:(0,t.jsx)(a.default,{isInverse:!0,testId:"close-button",withoutPaddingInline:!0,withoutPaddingBlock:!0,type:"unboxed",icon:"actions:close",onClick:()=>{window.analytics.sendEvent({eventGrouping:"click_action",eventProperties:{item_name:"close_modal",item_type:"close_button",item_resource_id:z,item_position:B+1},groupProperties:{group_name:H,group_type:K,group_resource_id:z,group_position:B+1,group_item_count:g.length}}),e()}})})]})}],463226);let w=u.default.div.withConfig({displayName:"Backdrop.styles__BackdropStyled",componentId:"sc-9f7d4825-0"})`
  ${({theme:e,$offsetTop:t,$isOpen:i,$zIndex:n,$hasChildren:a,$variant:o})=>u.css`
    background-color: ${e.overlay[o].value};
    display: ${i?"block":"none"};
    visibility: ${i?"unset":"hidden"};
    top: ${t}px;
    position: fixed;
    border: none;
    width: 100%;
    bottom: 0;

    ${a&&u.css`
      display: grid;
      place-items: center;
    `}

    ${(0,y.applyZIndex)(n)};
  `};
`;e.s(["default",0,({isOpen:e,offsetTop:i=0,testId:n="backdrop",children:a,zIndex:o="level3",variant:r="heavy",...l})=>(0,t.jsx)(w,{"data-testid":n,$isOpen:e,$offsetTop:i,$zIndex:o,$hasChildren:!!a,$variant:r,...l,children:a})],292580);let k=u.default.div.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupStyled",componentId:"sc-921b484e-0"})`
  ${({theme:e})=>u.css`
    box-sizing: border-box;
    background-color: ${e.container.onDefaultBG4.value};
    width: min(532px, 70vw);
    max-height: 366px;
    padding: 64px;
    display: grid;
    place-items: center;
    row-gap: 32px;
    grid-auto-rows: min-content;
    position: relative;

    ${(0,g.applyStylesForBreakpoints)(u.css`
        width: max(342px, 90vw);
        max-height: 428px;
        padding: 32px;
      `,"group2")}
  `}
`,$=u.default.div.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupSectionStyled",componentId:"sc-921b484e-1"})`
  ${({$variant:e="description"})=>u.css`
    display: grid;
    row-gap: 12px;
    min-width: 326px;

    ${"description"===e&&u.css`
      justify-items: center;
    `}
  `}

  ${(0,g.applyStylesForBreakpoints)(u.css`
      min-width: 260px;
    `,"group3")}

  ${(0,g.applyStylesForBreakpoints)(u.css`
      min-width: 240px;
    `,"group1")}
`,S=u.default.h2.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupTitleStyled",componentId:"sc-921b484e-2"})`
  ${({theme:e})=>u.css`
    ${(0,m.applyTypography)(e.promoHeadline.extraLarge.default.bpLarge)};

    ${(0,g.applyStylesForBreakpoints)(u.css`
        ${(0,m.applyTypography)(e.promoHeadline.extraLarge.default.bpSmall)};
      `,"group2")}
  `}
`,I=u.default.p.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupDescriptionStyled",componentId:"sc-921b484e-3"})`
  ${({theme:e})=>u.css`
    text-align: center;
    ${(0,m.applyTypography)(e.bodyCopy.default.bpLarge)};

    ${(0,g.applyStylesForBreakpoints)(u.css`
        /* 
          Ensure final word is not "orphaned", appearing by itself on it's own
          line.
        */
        span {
          display: inline-block;
        }
        ${(0,m.applyTypography)(e.bodyCopy.default.bpSmall)};
      `,"group2")}
  `}
`,C=u.default.div.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupTopActionsStyled",componentId:"sc-921b484e-4"})`
  position: absolute;
  right: 16px;
  top: 16px;
`;e.s(["default",0,({onPrimaryAction:e,onSecondaryAction:n,onClose:o})=>{let r=(0,i.useRef)(null);return(0,d.useOutsideClicker)(r,o),(0,t.jsxs)(k,{ref:r,children:[(0,t.jsxs)($,{children:[(0,t.jsx)(S,{children:"Are you sure?"}),(0,t.jsxs)(I,{children:["Playback will stop if you leave ",(0,t.jsx)("span",{children:"this page."}),(0,t.jsx)("br",{}),"Would you like to:"]})]}),(0,t.jsxs)($,{$variant:"actions",children:[(0,t.jsx)(a.default,{testId:"primary-button",type:"general",text:"Leave and stop listening",size:"large",onClick:e}),(0,t.jsx)(a.default,{testId:"secondary-button",type:"ghost",text:"Open page in new tab",size:"large",onClick:n})]}),(0,t.jsx)(C,{children:(0,t.jsx)(a.default,{testId:"close-button",withoutPaddingInline:!0,withoutPaddingBlock:!0,type:"unboxed",icon:"actions:close",onClick:o})})]})}],172035)},242866,275349,396141,e=>{"use strict";var t=e.i(391398),i=e.i(191788),n=e.i(463226),a=e.i(292580),o=e.i(172035),r=e.i(481978),r=r,l=e.i(660021),s=e.i(324951),d=e.i(65739),c=e.i(753924),p=e.i(746857);let u=function(e){(0,i.useEffect)(()=>{let t=new MutationObserver(t=>{t.forEach(t=>{let{type:i,attributeName:n}=t;"attributes"===i&&"style"===n&&e("hidden"===document.body.style.overflow)})});return t.observe(document.body,{attributes:!0,attributeFilter:["style"]}),()=>{t.disconnect()}},[e])},g=function(e){(0,i.useEffect)(()=>{let t=new MutationObserver(t=>{t.forEach(t=>{let{type:i,target:n}=t,a=Array.from(n.classList);"attributes"===i&&a.includes("tp-backdrop")&&e(a.includes("tp-active"))})});return t.observe(document.body,{attributes:!0,subtree:!0,childList:!0,attributeFilter:["class"]}),()=>{t.disconnect()}},[e])},m=function(e,t="global"){("piano"===t?g:u)(e)};e.s(["useBackdropObserver",0,m],275349);var y=e.i(399274),h=e.i(246024),f=e.i(450228),_=e.i(427885),v=e.i(789799),b=e.i(105271),x=e.i(161772),w=e.i(227162),k=e.i(395497),$=e.i(240911),S=e.i(508259),I=e.i(898229),C=e.i(852827),A=e.i(978113);let E=({mediaMetadataModel:e,onPlayClick:n,isTrailer:a=!1,onEnded:o,stopPlayer:r,startTime:l})=>{let{query:s}=(0,p.useAppRouter)(),{slug:d}=s,u=(0,$.getStringFromSlug)(d,!0),g=`${w.appConfig.getValue(k.ConfigSettings.SiteUrl)}${u}`,E=(0,i.useRef)(null),[P,T]=(0,i.useState)(!1),[j,N]=(0,i.useState)(!1),[F,B]=(0,i.useState)(!1),[L,O]=(0,i.useState)(void 0),[M,R]=(0,i.useState)(!1),[D,V]=(0,i.useState)(""),[U,G]=(0,i.useState)("level2"),H=(0,h.useIsEmbeddedMediaReady)(),z=(0,y.useEchoCustomEvent)(),W=(0,v.useSubscriptionContext)(),K=(0,i.useMemo)(()=>W.claims.longFormVideo,[W]);(0,i.useEffect)(()=>{("ALLOWED"===K||a)&&T(!0)},[K,a]);let Z=async(e,t)=>{try{let i=`media-token?versionPid=${e}&playbackAuthorisation=${t}`,{data:n}=await (0,I.fetchClient)(i,{});return n.token}catch{return S.logger.error(`getJwtToken failed for: ${e}`),""}},q=async e=>{let[t]=e.versions;if(!t)return{holdingImageURL:(0,_.getImageUrl)(e.imageUrl),items:[],summary:"",title:""};let i=await Z(t.versionId,t.playbackAuthorisation||""),n={kind:"programme",duration:t.duration,versionID:t.versionId,jwtToken:i};return{title:e.title,summary:e.synopses?.medium||"",items:[n],holdingImageURL:(0,_.getImageUrl)(e.imageUrl),warning:t.warning,autoplay:!1}},J=async()=>{let t=(0,_.getAvAnalytics)(z,{content_type:a?"doc-trailer":"doc-episode"});return t.clipPID=e.id,t.playerPosition=a?"lf-video-series-page":"lf-video-episode-page",t.playlistLabels={...t.playlistLabels,av_content_duration_range:"lfv",av_episode:z?.av_episode,av_show:z?.av_show},{html5Debug:!1,product:"bbcx",playlistObject:await q(e),autoplay:!1,waitOnPluginLoad:!0,enableToucan:!0,supportFakeFullscreen:!0,appName:"bbc_web",appType:"responsive",significantTime:30,...l&&l>0?{startTime:l}:{},ui:{colour:"#FFFFFF",foreColour:"#000000",cta:{enabled:!1,visiblyHidden:!0},playbackSettingsPanel:{enabled:!1},controls:{speed:!1}},counterName:t.counterName||"",statsObject:t}};(0,i.useEffect)(()=>{E.current&&H&&z&&null!==l&&(async()=>{let t=await J(),i=E.current;if(i)if(0===t.playlistObject.items.length)V(t.playlistObject.holdingImageURL);else{let a=window.embeddedMedia.api.player(i,t);a.bind("initialised",()=>B(!0)),a.bind("enterFakeFullscreen",()=>R(!0)),a.bind("exitFakeFullscreen",()=>R(!1)),a.bind("fullscreenExit",()=>{!a.paused()&&(N(!0),n&&n())}),a.bind("playing",()=>N(!0)),a.bind("ended",()=>{N(!1),o&&o()}),a.bind("significanttimeupdate",(0,C.setLFVMediaProgress)(e)),a.load(),O(a)}})()},[H,z,l]),m(e=>G(e?"level1":"level2")),r&&L&&L.stop();let[X]=e.versions;return(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(x.default,{contentUrl:g,...(0,b.getBaseVideoObjectProps)(e)}),(0,t.jsxs)(A.LongFormPlayerStyled,{"data-testid":"long-form-player",$isInFakeFullscreen:M,$isPlaybackStarted:j,$isPlaybackAllowed:P,children:[(0,t.jsx)(A.VideoPlayerStyled,{ref:E,$isAudio:!1,children:D&&(0,t.jsx)(f.default,{imageUrlTemplate:D})}),(0,t.jsx)(c.default,{isVisible:P&&F&&!j,onClick:()=>{L&&L.play(!0),setTimeout(()=>N(!0),0),n?.()},warning:X?.warning,duration:"",zIndex:U,type:"longForm"})]})]})};e.s(["default",0,E],396141);var P=e.i(760814),T=e.i(339228),j=e.i(222009);P.default.div.withConfig({displayName:"LongFormVideoTrailerModal.styles__Overlay",componentId:"sc-481ecf7e-0"})`
  ${({theme:e})=>P.css`
    position: fixed;
    inset: 0;
    background-color: ${e.overlay.medium.value};
    display: flex;
    justify-content: center;
    align-items: center;

    ${(0,j.applyZIndex)("level0")};
  `};
`;let N=P.default.button.withConfig({displayName:"LongFormVideoTrailerModal.styles__CloseButton",componentId:"sc-481ecf7e-1"})`
  ${({theme:e})=>P.css`
    position: absolute;
    top: -53px;
    right: 0;
    background: transparent;
    color: white;
    border: none;
    cursor: pointer;
    padding: 10px;

    &:hover {
      background-color: ${e.button.unboxed.hovered.normal.background.value};
    }
  `};
`,F="75vh",B=P.default.div.withConfig({displayName:"LongFormVideoTrailerModal.styles__TrailerBox",componentId:"sc-481ecf7e-2"})`
  ${({theme:e})=>P.css`
    max-width: 90vw;
    max-height: 90%;
    position: relative;
    background-color: ${e.container.onDefaultBG3.value};
    aspect-ratio: 16 / 9;

    ${(0,j.applyZIndex)("level2")};

    ${(0,T.applyStylesForBreakpoints)(P.css`
        height: min(584px, ${F});
      `,"group6")};
    ${(0,T.applyStylesForBreakpoints)(P.css`
        height: min(549px, ${F});
      `,"group5")};
    ${(0,T.applyStylesForBreakpoints)(P.css`
        height: min(413px, ${F});
      `,"group4")};
    ${(0,T.applyStylesForBreakpoints)(P.css`
        height: min(319px, ${F});
      `,"group3")};
    /* Mobile  view need work as it need to transition to fullscreen directly*/
    ${(0,T.applyStylesForBreakpoints)(P.css`
        height: min(210px, ${F});
      `,"group2")};
  `};
`,L=({onClose:e,trailer:n})=>{let a=(0,i.useRef)(null),[o,c]=(0,i.useState)(!1),p=()=>{c(!0),setTimeout(()=>{(0,r.default)({eventGrouping:"click_action",eventProperties:{item_name:"trailer-close-button",item_text:"Close",item_type:"button",item_link:""}}),e()},50)};return(0,s.useOutsideClicker)(a,p),(0,l.useGlobalKeydown)(e=>{"Escape"===e.key&&p()}),(0,i.useEffect)(()=>{if(!a.current)return;let e=a.current,t=()=>Array.from(e.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')).filter(e=>!e.hasAttribute("disabled")&&!e.getAttribute("aria-hidden"));t()[0]?.focus();let i=i=>{"Tab"===i.key&&setTimeout(()=>{e.contains(document.activeElement)||t()[0]?.focus()},0)};return document.addEventListener("keydown",i),()=>document.removeEventListener("keydown",i)},[]),(0,t.jsxs)(B,{ref:a,tabIndex:-1,role:"dialog","aria-label":"Trailer player","aria-modal":"true",children:[(0,t.jsx)(N,{onClick:p,"aria-label":"close trailer modal",children:(0,t.jsx)(d.default,{width:24,height:24,name:"actions:close",fill:"white"})}),(0,t.jsx)(E,{mediaMetadataModel:n,isTrailer:!0,onEnded:e,stopPlayer:o})]})},O=(0,i.createContext)([{},()=>null]),{Provider:M}=O;e.s(["PopupContext",0,O,"default",0,({children:e,value:r})=>{let[l,s]=r,{variant:d,onPrimaryAction:c=()=>null,onSecondaryAction:p=()=>null,popupProps:u}=l,g=!!d,m=(0,i.useMemo)(()=>{switch(d){case"leaving-page":return o.default;case"trailer":return L;case"alberta":return n.default;default:return()=>null}},[d]),y="leaving-page"===d?"lightest":"alberta"===d?"medium":"heavy";return(0,t.jsxs)(M,{value:r,children:[(0,t.jsx)(a.default,{isOpen:g,zIndex:"level5",variant:y,children:(0,t.jsx)(m,{onPrimaryAction:c,onSecondaryAction:p,onClose:()=>s({}),...u})}),e]})}],242866)}]);