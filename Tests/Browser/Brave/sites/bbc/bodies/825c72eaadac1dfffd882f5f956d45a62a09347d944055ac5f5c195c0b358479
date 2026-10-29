(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,324951,e=>{"use strict";var t=e.i(191788);e.s(["useOutsideClicker",0,function(e,i,n="click"){let a=(0,t.useRef)(!1);(0,t.useEffect)(()=>{function t(t){let{current:n}=a,{current:o}=e,r=o?.contains(t.target);n&&o&&!r&&i(t)}return a.current=!1,setTimeout(()=>{a.current=!0},0),document.addEventListener(n,t),()=>{document.removeEventListener(n,t)}},[e,i,n])}],324951)},394941,(e,t,i)=>{"use strict";Object.defineProperty(i,"__esModule",{value:!0}),Object.defineProperty(i,"default",{enumerable:!0,get:function(){return s}});let n=e.r(191788),a="u"<typeof window,o=a?()=>{}:n.useLayoutEffect,r=a?()=>{}:n.useEffect;function s(e){let{headManager:t,reduceComponentsToState:i}=e;function s(){if(t&&t.mountedInstances){let e=n.Children.toArray(Array.from(t.mountedInstances).filter(Boolean));t.updateHead(i(e))}}return a&&(t?.mountedInstances?.add(e.children),s()),o(()=>(t?.mountedInstances?.add(e.children),()=>{t?.mountedInstances?.delete(e.children)})),o(()=>(t&&(t._pendingUpdate=s),()=>{t&&(t._pendingUpdate=s)})),r(()=>(t&&t._pendingUpdate&&(t._pendingUpdate(),t._pendingUpdate=null),()=>{t&&t._pendingUpdate&&(t._pendingUpdate(),t._pendingUpdate=null)})),null}},280963,(e,t,i)=>{"use strict";Object.defineProperty(i,"__esModule",{value:!0});var n={default:function(){return m},defaultHead:function(){return c}};for(var a in n)Object.defineProperty(i,a,{enumerable:!0,get:n[a]});let o=e.r(741705),r=e.r(952456),s=e.r(391398),l=r._(e.r(191788)),d=o._(e.r(394941)),p=e.r(713584);function c(){return[(0,s.jsx)("meta",{charSet:"utf-8"},"charset"),(0,s.jsx)("meta",{name:"viewport",content:"width=device-width"},"viewport")]}function u(e,t){return"string"==typeof t||"number"==typeof t?e:t.type===l.default.Fragment?e.concat(l.default.Children.toArray(t.props.children).reduce((e,t)=>"string"==typeof t||"number"==typeof t?e:e.concat(t),[])):e.concat(t)}e.r(894470);let g=["name","httpEquiv","charSet","itemProp"];function y(e){let t,i,n,a;return e.reduce(u,[]).reverse().concat(c().reverse()).filter((t=new Set,i=new Set,n=new Set,a={},e=>{let o=!0,r=!1;if(e.key&&"number"!=typeof e.key&&e.key.indexOf("$")>0){r=!0;let i=e.key.slice(e.key.indexOf("$")+1);t.has(i)?o=!1:t.add(i)}switch(e.type){case"title":case"base":i.has(e.type)?o=!1:i.add(e.type);break;case"meta":for(let t=0,i=g.length;t<i;t++){let i=g[t];if(e.props.hasOwnProperty(i))if("charSet"===i)n.has(i)?o=!1:n.add(i);else{let t=e.props[i],n=a[i]||new Set;("name"!==i||!r)&&n.has(t)?o=!1:(n.add(t),a[i]=n)}}}return o})).reverse().map((e,t)=>{let i=e.key||t;return l.default.cloneElement(e,{key:i})})}let m=function({children:e}){let t=(0,l.useContext)(p.HeadManagerContext);return(0,s.jsx)(d.default,{reduceComponentsToState:y,headManager:t,children:e})};("function"==typeof i.default||"object"==typeof i.default&&null!==i.default)&&void 0===i.default.__esModule&&(Object.defineProperty(i.default,"__esModule",{value:!0}),Object.assign(i.default,i),t.exports=i.default)},958678,(e,t,i)=>{t.exports=e.r(280963)},581620,e=>{"use strict";e.s(["SEARCH_RESULTS_MAX_PAGES",0,29,"SEARCH_SLUG",0,"search"])},771340,362132,357391,500131,e=>{"use strict";var t=e.i(191788),i=e.i(581620);let n=function(e){let t=new URLSearchParams(e),n=t.toString().length>0?`?${t.toString()}`:"";return`/${i.SEARCH_SLUG}${n}`};e.s(["getSearchUrl",0,n],362132);var a=e.i(746857);e.s(["useSearch",0,function(e){let[i,o]=(0,t.useState)(""),r=(0,a.useAppRouter)(),s=(0,t.useCallback)(t=>{if(!t)return;let i=n({q:t});r.push(i).then(()=>{o(""),e?.()})},[r,e]);return{searchText:i,setSearchText:o,onSearchClick:s}}],771340);var o=e.i(391398),r=e.i(84541),s=e.i(901414),l=e.i(324951),d=e.i(760814);let p=d.default.span.withConfig({displayName:"VisuallyHidden.styles__VisuallyHiddenStyled",componentId:"sc-69248fc2-0"})`
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
`,c=({as:e,testId:t,children:i})=>(0,o.jsx)(p,{"data-testid":t,as:e,children:i});var u=e.i(567290),g=e.i(339228),y=e.i(570549);let m=d.default.div.withConfig({displayName:"SearchInput.styles__SearchInputWrapperStyled",componentId:"sc-50f6a0bc-0"})`
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
    ${t?(0,y.applyTypography)(e.searchMenuText.bpLarge):(0,y.applyTypography)(e.searchText.bpLarge)};
    font-size: 16px;
    width: 40px;

    ${(0,g.applyStylesForBreakpoints)(d.css`
        ${t?(0,y.applyTypography)(e.searchMenuText.bpSmall):(0,y.applyTypography)(e.searchText.bpSmall)};
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
`,x=d.default.div.withConfig({displayName:"SearchInput.styles__SuggestionsItemStyled",componentId:"sc-50f6a0bc-3"})`
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
`,_=({suggestions:e,searchText:t,onSuggestionClick:i,testId:n})=>(0,o.jsx)(f,{"data-testid":n,children:e.map((e,n)=>(0,o.jsx)(x,{"data-testid":"suggestions-item",onClick:()=>i(e),children:(0,o.jsx)(b,{text:e,keyword:t})},n))}),b=({text:e,keyword:t})=>(0,o.jsx)(o.Fragment,{children:((e,t)=>{if(""===t)return e;let i=RegExp(`^${t}`,"i"),n=e.split(i),[a,r]=n;return 1===n.length?a:(0,o.jsxs)(o.Fragment,{children:[(0,o.jsx)("b",{children:e.match(i)}),r]})})(e,t)}),v=(0,t.forwardRef)(({isNavigationSearch:e=!1,placeholderText:i="Search news, topics and more",searchText:n,suggestions:a=[],onSearchTextChange:d,onSearch:p,isHomePage:u=!1,isOpenNavPanel:g=!1,isOnNavPanel:y=!1},f)=>{let[x,b]=(0,t.useState)(!1),v=(0,t.useRef)(null),w=(0,t.useRef)(!1),[S,k]=(0,s.useBreakpoints)("SearchInput"),[$,I]=(0,t.useState)(!0),[C,j]=(0,t.useState)(!1),E=(0,t.useRef)(null),P=(0,t.useId)();(0,t.useImperativeHandle)(f,()=>E.current);let T=()=>{n&&(p(n),b(!1))},A=(0,t.useCallback)(e=>{d(e),b(!1)},[d]),N=(0,t.useCallback)(()=>{A("")},[A]);return(0,l.useOutsideClicker)(v,()=>{b(!1)}),(0,t.useEffect)(()=>{w.current=u&&k},[S]),(0,t.useEffect)(()=>{C||g||!w.current||setTimeout(()=>{let e=document.getElementsByTagName("header");e[0]&&(e[0].style.position="sticky");let t=document.getElementById("bbc-main");t&&(t.style.marginTop="unset")},100)},[C,g]),y?g?setTimeout(()=>{$&&I(!1)},100):$||I(!0):$&&I(!1),(0,o.jsxs)(m,{ref:v,$isPopulated:!!n,$isNavigationSearch:e,"data-testid":"search-input-wrapper",children:[(0,o.jsx)("label",{htmlFor:P,children:(0,o.jsx)(c,{children:"Site search"})}),(0,o.jsx)(h,{ref:E,id:P,type:"text",placeholder:i,value:n,"data-testid":"search-input-field",$isNavigationSearch:e,onChange:e=>{let{target:{value:t}}=e;d(t),b(!!t.length)},onKeyDown:e=>{"Enter"===e.key&&T()},onFocus:()=>{if(j(!0),w.current){let e=document.getElementsByTagName("header");e[0]&&(e[0].style.position="fixed");let t=document.getElementById("bbc-main");t&&(t.style.marginTop="90px")}},onBlur:()=>{j(!1)},disabled:$}),!!n&&(0,o.jsx)(r.default,{icon:"actions:close",testId:"search-input-clear-button",onClick:N,type:"unboxed",ariaLabel:"Clear"}),(0,o.jsx)(r.default,{icon:"actions:search",testId:"search-input-search-button",onClick:T,"aria-label":"Search"}),x&&!!a.length&&(0,o.jsx)(_,{testId:"suggestions-box",suggestions:a,searchText:n,onSuggestionClick:A})]})});e.s(["default",0,v],357391);var w=e.i(923976);e.s(["PageDataProvider",()=>w.default],500131)},102358,680516,e=>{"use strict";var t=e.i(147097),i=e.i(240911);function n(e){return e?.current?.clientWidth||0}e.s(["DEFAULT_HEADER_HEIGHT",0,65,"DROPDOWN_NAVIGATION_ITEM_EXTERNAL_ID",0,"dropdown-navigation-item-external","DROPDOWN_NAVIGATION_ITEM_TEST_ID",0,"dropdown-navigation-item","MAIN_NAVIGATION_ITEM",0,"mainNavigationItemStyled","MAIN_NAVIGATION_LINK_TEST_ID",0,"mainNavigationLink","NAVIGATION_ID",0,"main-navigation-container","NAVIGATION_TEST_ID",0,"level1-navigation-container","NAVIGATION_THRESHOLD",0,100,"SUB_NAVIGATION",0,"level2-navigation-container","SUB_NAVIGATION_LINK_TEST_ID",0,"subNavigationLink"],680516);let a={header:"header",main:"main",sub:"sub_navigation",dropdown:"sub_navigation",drawer:"drawer",footer:"footer",error:"error"};e.s(["checkResponsiveFitment",0,(e,t,i=!1)=>n=>{let[{target:a,contentRect:o}]=n,{children:r}=a,{width:s}=o,{children:l}=r[0],d=Array.from(l),p=i?s/1.6:s;d.reduce((e,t)=>{let{clientWidth:i}=t;return e>p&&!t.hasAttribute("data-show")?t.setAttribute("data-hidden","true"):t.removeAttribute("data-hidden"),e+i},100+t),e(d.findIndex(e=>e.hasAttribute("data-hidden")))},"getActiveNavigationTree",0,(e,t,n)=>{let a=(0,i.getStringFromSlug)(e,!0,!1),o=(e,t,i=[],n=1)=>{for(let a of t){if(a.path===e)return{activeNavigationItem:{...a,level:n},parents:i};if(a.subMenus&&a.subMenus.length>0){let t=o(e,a.subMenus,[...i,{...a,level:n}],n+1);if(t.activeNavigationItem)return t}}return{activeNavigationItem:null,parents:[]}},{activeNavigationItem:r,parents:s}=n&&o(a,n)||{},{activeNavigationItem:l,parents:d}=o(a,t),p=(s?.length?[...s,r]:[...d,l]).map(e=>{let{title:t,level:i,path:n=""}=e||{};return e&&{title:t,level:i,path:n}}).filter(Boolean),c="/home"===a||"/"===a,u=!!l&&!c,g=[...d,l],y=g?.[0]||null,m=y?.subMenus||[],h=u&&l&&g.indexOf(l)>=1?l.subMenus?.length?l:p.length>2?d.slice(-1)[0]:l:null,f=g.indexOf(l)>=1&&h&&h?.subMenus||[],x=p?.[0]?.title||"",_=!!f.length,b="live"===x.toLowerCase(),v="news"===x.toLowerCase(),w=h?.title||null;return{isHomePage:c,isLivePage:b,isNestedMainNav:u,isNestedNavAvailable:_,isNewsPage:v,levels:!!p.length&&p||null,nestedNavigationItems:f,subNavigationItems:m,activeNavigationItem:l,nestedNavigationTitle:w}},"getNavigationAnalytics",0,(e,i,n,o,r)=>{if((0,t.getIsClient)()){let t=o?.toString()[0]==="/"?"":"/";return{eventGrouping:"navigation",eventProperties:{item_name:i,item_link:n||`${window?.location.origin}${t}${o}`,group_name:r||"navigation",group_type:a[e]}}}},"isParentWiderThanChild",0,function(e,t){return!e.current||!t.current||n(e)>n(t)}],102358)},36480,e=>{"use strict";var t=e.i(391398),i=e.i(893409),n=e.i(108019),a=e.i(102358);let o={429:"Too many requests.",500:"We ran into a technical problem."};var r=e.i(760814),s=e.i(339228),l=e.i(570549);let d=r.default.div.withConfig({displayName:"ErrorPage.styles__ErrorPageStyled",componentId:"sc-967c0ce6-0"})`
  padding-top: 32px;
  margin-bottom: 88px;
  ${(0,s.applyStylesForBreakpoints)(r.css`
      padding-top: 24px;
    `,"group2")};
`,p=r.default.h2.withConfig({displayName:"ErrorPage.styles__ErrorStyled",componentId:"sc-967c0ce6-1"})`
  ${({theme:e})=>r.css`
    display: grid;
    ${(0,l.applyTypography)(e.headline.small.bpLarge)};
    color: ${e.text.lowEmphasis.value};
    padding-bottom: 24px;
  `};
`,c=r.default.p.withConfig({displayName:"ErrorPage.styles__ErrorDetailStyled",componentId:"sc-967c0ce6-2"})`
  ${({theme:e})=>r.css`
    display: grid;
    ${(0,l.applyTypography)(e.bodyCopy.default.bpLarge)};
    color: ${e.text.lowEmphasis.value};
    padding-bottom: 24px;
  `};
`,u=r.default.div.withConfig({displayName:"ErrorPage.styles__ErrorPageVisitTextStyled",componentId:"sc-967c0ce6-3"})`
  float: left;
`,g=r.default.a.withConfig({displayName:"ErrorPage.styles__ErrorPageHomeLinkStyled",componentId:"sc-967c0ce6-4"})`
  ${({theme:e})=>r.css`
    ${(0,l.applyTypography)(e.bodyCopy.links.bpLarge)};
    color: ${e.text.default.value};
    padding-bottom: 24px;
    text-decoration-line: underline;
    cursor: pointer;
  `};
`,y=r.default.div.withConfig({displayName:"ErrorPage.styles__ErrorPageHomeLinkWrapperStyled",componentId:"sc-967c0ce6-5"})`
  display: inline-block;
  margin-left: 6px;
`;e.s(["default",0,({statusCode:e=500})=>{let r=o[e]||o[500],s=(0,a.getNavigationAnalytics)("error","Home",void 0,"/");return(0,t.jsx)(n.ContainerStyled,{$type:"contained",children:(0,t.jsxs)(d,{children:[(0,t.jsx)(p,{children:`Error ${e} - ${r}`}),(0,t.jsx)(c,{children:"The server wasn’t able to load this page. Please press refresh or try again later."}),(0,t.jsxs)("div",{children:[(0,t.jsx)(u,{children:(0,t.jsx)(c,{children:"Visit the"})}),(0,t.jsx)(y,{children:(0,t.jsx)(i.default,{href:"/",analytics:s,styledAnchor:g,children:"Homepage"})})]})]})})}],36480)},643616,e=>{"use strict";var t=e.i(391398),i=e.i(36480),n=e.i(704570);e.s(["default",0,()=>{let{statusCode:e}=(0,n.usePageData)();return(0,t.jsx)(i.default,{statusCode:e})}])},984063,e=>{"use strict";var t=e.i(391398),i=e.i(959560),n=e.i(57988),a=e.i(771340),o=e.i(893409),r=e.i(108019),s=e.i(357391),l=e.i(900324),d=e.i(760814),p=e.i(339228),c=e.i(570549);let u=d.default.div.withConfig({displayName:"NoutFoundPage.styles__NotFoundTopStyled",componentId:"sc-38310dc4-0"})`
  padding-top: 32px;
  margin-bottom: 48px;
  ${(0,p.applyStylesForBreakpoints)(d.css`
      padding-top: 24px;
      margin-bottom: 32px;
    `,"group2")}
`,g=d.default.div.withConfig({displayName:"NoutFoundPage.styles__NotFoundDividerStyled",componentId:"sc-38310dc4-1"})`
  ${({theme:e})=>d.css`
    border-bottom: 1px solid ${e.divider.lowEmphasis.value};
  `}
`,y=d.default.h2.withConfig({displayName:"NoutFoundPage.styles__NotFoundErrorStyled",componentId:"sc-38310dc4-2"})`
  ${({theme:e})=>d.css`
    display: grid;
    ${(0,c.applyTypography)(e.headline.small.bpSmall)};
    color: ${e.text.lowEmphasis.value};
    padding-bottom: 24px;
  `}
`,m=d.default.h1.withConfig({displayName:"NoutFoundPage.styles__NotFoundSuggestionStyled",componentId:"sc-38310dc4-3"})`
  ${({theme:e})=>d.css`
    ${(0,c.applyTypography)(e.headline.small.bpLarge)};
    color: ${e.text.default.value};
    padding: 24px 0;
    ${(0,p.applyStylesForBreakpoints)(d.css`
        ${(0,c.applyTypography)(e.headline.large.bpSmall)};
      `,"group5")}
    ${(0,p.applyStylesForBreakpoints)(d.css`
        ${(0,c.applyTypography)(e.headline.small.bpSmall)};
      `,"group2")}
  `}
`,h=d.default.div.withConfig({displayName:"NoutFoundPage.styles__NotFoundInfoStyled",componentId:"sc-38310dc4-4"})`
  margin-bottom: 16px;

  div:first-child {
    display: inline;
  }
  ${({theme:e})=>d.css`
    ${(0,c.applyTypography)(e.bodyCopy.default.bpLarge)};
    a {
      ${(0,c.applyTypography)(e.bodyCopy.links.bpLarge)};
      font-family: ${e.fontFamilies.bbcReithSans};
    }
  `}
`,f=d.default.div.withConfig({displayName:"NoutFoundPage.styles__NotFoundSearchInputWrapperStyled",componentId:"sc-38310dc4-5"})`
  margin-bottom: 52px;
  ${(0,p.applyStylesForBreakpoints)(d.css`
      margin-bottom: 40px;
    `,"group2")}
`,x=({recentStories:e,searchText:i,onSearch:n,onSearchTextChange:a})=>(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(r.ContainerStyled,{$type:"contained",children:(0,t.jsxs)(u,{children:[(0,t.jsx)(y,{children:"Error 404 - Oops, the page you're looking for is no longer here"}),(0,t.jsx)(g,{}),(0,t.jsx)(m,{children:"Try searching for it instead"}),(0,t.jsx)(f,{children:(0,t.jsx)(s.default,{onSearch:n,onSearchTextChange:a,searchText:i})}),(0,t.jsxs)(h,{children:["We can't find the page you're looking for. If you've typed the URL into your browser, check that you entered it correctly. If you reached this page via our site or search, please let us know by emailing"," ",(0,t.jsx)(o.default,{href:"mailto:comhelp.bbc@bbc.com",children:"comhelp.bbc@bbc.com"}),"."]}),(0,t.jsx)(h,{children:"Our team will investigate this feedback but will not reply directly."})]})}),!!e.length&&(0,t.jsx)(l.default,{type:"alaska",title:"More from BBC",content:e,testId:"not-found-page-alaska",titleAsHeadingTag:!1})]});e.s(["default",0,()=>{let e=(0,n.useCurrentSlug)(),{data:o}=(0,i.default)(e),{searchText:r,setSearchText:s,onSearchClick:l}=(0,a.useSearch)();return(0,t.jsx)(x,{recentStories:o,onSearch:l,searchText:r,onSearchTextChange:s})}],984063)},463226,660021,292580,172035,e=>{"use strict";var t=e.i(391398),i=e.i(191788),n=e.i(893409),a=e.i(84541),o=e.i(120928),r=e.i(772701),s=e.i(901414);let l=function(e,t=[]){(0,i.useEffect)(()=>(window.addEventListener("keydown",e),()=>{window.removeEventListener("keydown",e)}),t)};e.s(["useGlobalKeydown",0,l],660021);var d=e.i(324951),p=e.i(46230),c=e.i(490602),u=e.i(760814),g=e.i(339228),y=e.i(570549),m=e.i(222009);let h=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__AlbertaModalStyled",componentId:"sc-3996c3f6-0"})(({theme:e})=>u.css`
    position: relative;
    aspect-ratio: 9 / 16;
    background-color: ${e.container.onDefaultBG3.value};
    /* stylelint-disable-next-line plugin/no-unsupported-browser-features */
    height: min(90vh, 900px);

    ${(0,m.applyZIndex)("level2")};

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
`,x=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__ContentOverlayStyled",componentId:"sc-3996c3f6-2"})(({theme:e,$controlsVisible:t})=>u.css`
    position: absolute;
    bottom: 80px;
    left: 16px;
    right: 16px;
    ${(0,m.applyZIndex)("level3")};
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
  `),_=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__ContentTextContainerStyled",componentId:"sc-3996c3f6-3"})`
  flex: 1;
  min-width: 0;
`,b=u.default.div.withConfig({displayName:"AlbertaVideoModal.styles__ShareButtonContainerStyled",componentId:"sc-3996c3f6-4"})`
  flex-shrink: 0;
`,v=u.default.a.withConfig({displayName:"AlbertaVideoModal.styles__VideoTitleLink",componentId:"sc-3996c3f6-5"})(({theme:e})=>u.css`
    ${(0,y.applyTypography)(e.generic.info1.emphasised.bpSmall)};

    margin: 0;
    color: ${e.text.onInverseBG.default.value};
    text-decoration: none;
    font-size: 12px;
    line-height: 24px;
    font-weight: 700;
    &:hover {
      text-decoration: underline;
    }
  `);e.s(["default",0,({onClose:e,blocks:u,playlistLabels:g,startIndex:y,holdingImageUrls:m,contentPageHrefs:w=[],contentPageTitles:S=[],onwardJourneyHrefs:k=[],onwardJourneyLinkTexts:$=[],contentIds:I=[],subtypes:C=[]})=>{let j=(0,i.useRef)(null),E=(0,i.useRef)(y),[P]=(0,s.useBreakpoints)("AlbertaVideoModal"),T="not-set"!==P,A=["group1","group2"].includes(P),[N,F]=(0,i.useState)(!1),[L,B]=(0,i.useState)(y),[O,M]=(0,i.useState)(!1),[D,G]=(0,i.useState)(!1),R=w[L],V=S[L]||"",U=k[L],H=$[L]||"",z=I[L]||"",W=g[L],K=C[L],q=W?{av_content_id:W.content_id,av_content_type:W.content_type,av_content_duration_range:"sfv-vertical"}:void 0,Z=U&&(0,r.isExternalLink)(U),Y=U&&(0,o.isBBCExternal)(U),J={eventGrouping:Z&&!Y?"click_exit":"click_action",eventProperties:{item_name:H,item_type:"custom_link",item_link:U||"",item_resource_id:z,item_position:L+1},groupProperties:{group_name:H,group_type:K,group_resource_id:z,group_position:L+1,group_item_count:g.length}};return(0,d.useOutsideClicker)(j,t=>{let i=t.target;i?.closest('[data-testid="popoverStyled"], [data-testid="popoverOverlay"]')||e()}),l(t=>{"Escape"===t.key&&e()}),(0,t.jsxs)(h,{ref:j,tabIndex:-1,role:"dialog","aria-label":"Video player",children:[T&&(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(p.default,{playerOrientation:"portrait",blocks:u,playlistLabels:g,activeIndex:y,playerPosition:"alberta-modal",uiOverrides:{swipable:{enabled:!0,direction:"Y"},fullscreen:A?{enabled:!0,useCloseIconForExitFullscreen:!0}:{enabled:!1},chromecast:{enabled:!1},subtitles:{enabled:!0},pictureInPicture:{enabled:!1},controls:{speed:!0,includeNextButton:!0,includePreviousButton:!0}},disableAds:!0,disableCta:!0,onExitFakeFullscreen:e,autoEnterFakeFullscreen:A,holdingImageUrls:m,onPlayerInitialized:e=>{F(!0),e.bind("uiControlBarShown",()=>{M(!0)}),e.bind("uiControlBarHidden",()=>{M(!1)})},onNextOnwardJourneyItemStartsPlaying:e=>{if(void 0===e.index)return;let t=E.current,i=e.index,n=i>t,a=$[t]||"",o=I[t]||"",r=$[i]||"",s=k[i]||"",l=I[i]||"";window.analytics.sendEvent({eventGrouping:"click_action",eventProperties:{item_name:n?"play_next":"play_previous",item_type:"navigation_button",item_text:r,item_link:s,item_resource_id:l,item_position:i+1},groupProperties:{group_name:a,group_type:K,group_resource_id:o,group_position:t+1,group_item_count:g.length}}),E.current=i,B(i),G(!1)}}),N&&(U||R)&&(0,t.jsxs)(x,{$controlsVisible:O||D,children:[U&&(0,t.jsx)(_,{children:(0,t.jsx)(n.default,{href:U,styledAnchor:v,analytics:J,children:H})}),R&&(0,t.jsx)(b,{children:(0,t.jsx)(c.default,{trigger:"click",alignment:"top-right",isButtonInverse:!1,type:"general",size:"small",iconOnly:!0,isAvContent:!0,title:V,href:R,avProperties:q,onOpenChange:G},`share-${L}`)})]})]}),(0,t.jsx)(f,{children:(0,t.jsx)(a.default,{isInverse:!0,testId:"close-button",withoutPaddingInline:!0,withoutPaddingBlock:!0,type:"unboxed",icon:"actions:close",onClick:()=>{window.analytics.sendEvent({eventGrouping:"click_action",eventProperties:{item_name:"close_modal",item_type:"close_button",item_resource_id:z,item_position:L+1},groupProperties:{group_name:H,group_type:K,group_resource_id:z,group_position:L+1,group_item_count:g.length}}),e()}})})]})}],463226);let w=u.default.div.withConfig({displayName:"Backdrop.styles__BackdropStyled",componentId:"sc-9f7d4825-0"})`
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

    ${(0,m.applyZIndex)(n)};
  `};
`;e.s(["default",0,({isOpen:e,offsetTop:i=0,testId:n="backdrop",children:a,zIndex:o="level3",variant:r="heavy",...s})=>(0,t.jsx)(w,{"data-testid":n,$isOpen:e,$offsetTop:i,$zIndex:o,$hasChildren:!!a,$variant:r,...s,children:a})],292580);let S=u.default.div.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupStyled",componentId:"sc-921b484e-0"})`
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
`,k=u.default.div.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupSectionStyled",componentId:"sc-921b484e-1"})`
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
`,$=u.default.h2.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupTitleStyled",componentId:"sc-921b484e-2"})`
  ${({theme:e})=>u.css`
    ${(0,y.applyTypography)(e.promoHeadline.extraLarge.default.bpLarge)};

    ${(0,g.applyStylesForBreakpoints)(u.css`
        ${(0,y.applyTypography)(e.promoHeadline.extraLarge.default.bpSmall)};
      `,"group2")}
  `}
`,I=u.default.p.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupDescriptionStyled",componentId:"sc-921b484e-3"})`
  ${({theme:e})=>u.css`
    text-align: center;
    ${(0,y.applyTypography)(e.bodyCopy.default.bpLarge)};

    ${(0,g.applyStylesForBreakpoints)(u.css`
        /* 
          Ensure final word is not "orphaned", appearing by itself on it's own
          line.
        */
        span {
          display: inline-block;
        }
        ${(0,y.applyTypography)(e.bodyCopy.default.bpSmall)};
      `,"group2")}
  `}
`,C=u.default.div.withConfig({displayName:"LeavingPagePopup.styles__LeavingPagePopupTopActionsStyled",componentId:"sc-921b484e-4"})`
  position: absolute;
  right: 16px;
  top: 16px;
`;e.s(["default",0,({onPrimaryAction:e,onSecondaryAction:n,onClose:o})=>{let r=(0,i.useRef)(null);return(0,d.useOutsideClicker)(r,o),(0,t.jsxs)(S,{ref:r,children:[(0,t.jsxs)(k,{children:[(0,t.jsx)($,{children:"Are you sure?"}),(0,t.jsxs)(I,{children:["Playback will stop if you leave ",(0,t.jsx)("span",{children:"this page."}),(0,t.jsx)("br",{}),"Would you like to:"]})]}),(0,t.jsxs)(k,{$variant:"actions",children:[(0,t.jsx)(a.default,{testId:"primary-button",type:"general",text:"Leave and stop listening",size:"large",onClick:e}),(0,t.jsx)(a.default,{testId:"secondary-button",type:"ghost",text:"Open page in new tab",size:"large",onClick:n})]}),(0,t.jsx)(C,{children:(0,t.jsx)(a.default,{testId:"close-button",withoutPaddingInline:!0,withoutPaddingBlock:!0,type:"unboxed",icon:"actions:close",onClick:o})})]})}],172035)},481978,e=>{"use strict";var t=e.i(417183),i=e.i(564045),n=e.i(508259),a=e.i(21540);let o={forms_button:{action_type:"viewability",action_name:"select",group_type:"form",item_type:"button"},forms_input:{action_type:"viewability",action_name:"select",group_type:"form"},indexCard_select:{action_type:"viewability",action_name:"select"},indexCard_view:{action_type:"viewability",action_name:"view"},subsection_view:{action_type:"viewability",action_name:"view"},navigation:{action_type:"click",action_name:"navigation"},click_action:{action_type:"click",action_name:"action"},click_exit:{action_type:"click",action_name:"exit"},article_share:{action_type:"article",action_name:"share",item_type:"icon_share",group_name:"share_menu"},av_share:{action_type:"av",action_name:"share",item_type:"icon_share",group_name:"share_menu"},internal_search_result_click:{action_type:"internal_search_result",action_name:"click"},internal_search_result_display:{action_type:"internal_search_result",action_name:"display"},ads_click:{action_type:"ads",action_name:"click"},ads_impression:{action_type:"ads",action_name:"impression"},page_scroll:{action_type:"page",action_name:"scroll"},bookmark_add:{action_type:"bookmark",action_name:"add",item_name:"bookmark"},bookmark_remove:{action_type:"bookmark",action_name:"remove",item_name:"unbookmark"},ads_blocked:{action_type:"ads",action_name:"blocked"},optimizely:{mv_engine_name:"Optimizely",action_type:"mv_test",action_name:"display"},section_title_select:{action_type:"viewability",action_name:"select"},account_option:{action_type:"viewability",action_name:"select",group_name:"account_option"},sign_in:{action_type:"signin",action_name:"select",item_name:"sign_in"},register:{action_type:"registration",action_name:"select",item_name:"register"},subscribe:{action_type:"subscription",action_name:"select",item_name:"subscribe"},av_follow:{action_type:"av",action_name:"follow",item_name:"follow"},av_unfollow:{action_type:"av",action_name:"unfollow",item_name:"unfollow"},av_lfv_cta:{action_type:"click",action_name:"action",group_name:"lfv_option"}};e.s(["default",0,({eventGrouping:e,eventProperties:r,groupProperties:s})=>{try{let{action_name:l,action_type:d,...p}=o[e],{echoClient:c,data:u}=window.analytics,g={...u,...p,...s,...r};c?((0,i.getRunningEnvironment)()!==a.RunningEnvironment.LIVE&&("indexCard_view"===e||"indexCard_select"===e)&&((0,t.default)(s)||!s)&&n.logger.debug("### sendAnalyticsEventByMap/sendEvent ===> group properties might be missing!",{...r,groupProperties:s}),"ads_blocked"===e||"internal_search_result_display"===e?setTimeout(()=>{c?.userActionEvent?.(d,l,g)},100):c?.userActionEvent?.(d,l,g)):window.analytics.buffer.push({eventGrouping:e,eventProperties:r,groupProperties:s})}catch(t){let e=`Failed to send analytics event: ${t}`;throw n.logger.error(e),Error(e)}}])},242866,275349,396141,e=>{"use strict";var t=e.i(391398),i=e.i(191788),n=e.i(463226),a=e.i(292580),o=e.i(172035),r=e.i(481978),r=r,s=e.i(660021),l=e.i(324951),d=e.i(65739),p=e.i(753924),c=e.i(746857);let u=function(e){(0,i.useEffect)(()=>{let t=new MutationObserver(t=>{t.forEach(t=>{let{type:i,attributeName:n}=t;"attributes"===i&&"style"===n&&e("hidden"===document.body.style.overflow)})});return t.observe(document.body,{attributes:!0,attributeFilter:["style"]}),()=>{t.disconnect()}},[e])},g=function(e){(0,i.useEffect)(()=>{let t=new MutationObserver(t=>{t.forEach(t=>{let{type:i,target:n}=t,a=Array.from(n.classList);"attributes"===i&&a.includes("tp-backdrop")&&e(a.includes("tp-active"))})});return t.observe(document.body,{attributes:!0,subtree:!0,childList:!0,attributeFilter:["class"]}),()=>{t.disconnect()}},[e])},y=function(e,t="global"){("piano"===t?g:u)(e)};e.s(["useBackdropObserver",0,y],275349);var m=e.i(399274),h=e.i(246024),f=e.i(450228),x=e.i(427885),_=e.i(789799),b=e.i(105271),v=e.i(161772),w=e.i(227162),S=e.i(395497),k=e.i(240911),$=e.i(508259),I=e.i(898229),C=e.i(852827),j=e.i(978113);let E=({mediaMetadataModel:e,onPlayClick:n,isTrailer:a=!1,onEnded:o,stopPlayer:r,startTime:s})=>{let{query:l}=(0,c.useAppRouter)(),{slug:d}=l,u=(0,k.getStringFromSlug)(d,!0),g=`${w.appConfig.getValue(S.ConfigSettings.SiteUrl)}${u}`,E=(0,i.useRef)(null),[P,T]=(0,i.useState)(!1),[A,N]=(0,i.useState)(!1),[F,L]=(0,i.useState)(!1),[B,O]=(0,i.useState)(void 0),[M,D]=(0,i.useState)(!1),[G,R]=(0,i.useState)(""),[V,U]=(0,i.useState)("level2"),H=(0,h.useIsEmbeddedMediaReady)(),z=(0,m.useEchoCustomEvent)(),W=(0,_.useSubscriptionContext)(),K=(0,i.useMemo)(()=>W.claims.longFormVideo,[W]);(0,i.useEffect)(()=>{("ALLOWED"===K||a)&&T(!0)},[K,a]);let q=async(e,t)=>{try{let i=`media-token?versionPid=${e}&playbackAuthorisation=${t}`,{data:n}=await (0,I.fetchClient)(i,{});return n.token}catch{return $.logger.error(`getJwtToken failed for: ${e}`),""}},Z=async e=>{let[t]=e.versions;if(!t)return{holdingImageURL:(0,x.getImageUrl)(e.imageUrl),items:[],summary:"",title:""};let i=await q(t.versionId,t.playbackAuthorisation||""),n={kind:"programme",duration:t.duration,versionID:t.versionId,jwtToken:i};return{title:e.title,summary:e.synopses?.medium||"",items:[n],holdingImageURL:(0,x.getImageUrl)(e.imageUrl),warning:t.warning,autoplay:!1}},Y=async()=>{let t=(0,x.getAvAnalytics)(z,{content_type:a?"doc-trailer":"doc-episode"});return t.clipPID=e.id,t.playerPosition=a?"lf-video-series-page":"lf-video-episode-page",t.playlistLabels={...t.playlistLabels,av_content_duration_range:"lfv",av_episode:z?.av_episode,av_show:z?.av_show},{html5Debug:!1,product:"bbcx",playlistObject:await Z(e),autoplay:!1,waitOnPluginLoad:!0,enableToucan:!0,supportFakeFullscreen:!0,appName:"bbc_web",appType:"responsive",significantTime:30,...s&&s>0?{startTime:s}:{},ui:{colour:"#FFFFFF",foreColour:"#000000",cta:{enabled:!1,visiblyHidden:!0},playbackSettingsPanel:{enabled:!1},controls:{speed:!1}},counterName:t.counterName||"",statsObject:t}};(0,i.useEffect)(()=>{E.current&&H&&z&&null!==s&&(async()=>{let t=await Y(),i=E.current;if(i)if(0===t.playlistObject.items.length)R(t.playlistObject.holdingImageURL);else{let a=window.embeddedMedia.api.player(i,t);a.bind("initialised",()=>L(!0)),a.bind("enterFakeFullscreen",()=>D(!0)),a.bind("exitFakeFullscreen",()=>D(!1)),a.bind("fullscreenExit",()=>{!a.paused()&&(N(!0),n&&n())}),a.bind("playing",()=>N(!0)),a.bind("ended",()=>{N(!1),o&&o()}),a.bind("significanttimeupdate",(0,C.setLFVMediaProgress)(e)),a.load(),O(a)}})()},[H,z,s]),y(e=>U(e?"level1":"level2")),r&&B&&B.stop();let[J]=e.versions;return(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(v.default,{contentUrl:g,...(0,b.getBaseVideoObjectProps)(e)}),(0,t.jsxs)(j.LongFormPlayerStyled,{"data-testid":"long-form-player",$isInFakeFullscreen:M,$isPlaybackStarted:A,$isPlaybackAllowed:P,children:[(0,t.jsx)(j.VideoPlayerStyled,{ref:E,$isAudio:!1,children:G&&(0,t.jsx)(f.default,{imageUrlTemplate:G})}),(0,t.jsx)(p.default,{isVisible:P&&F&&!A,onClick:()=>{B&&B.play(!0),setTimeout(()=>N(!0),0),n?.()},warning:J?.warning,duration:"",zIndex:V,type:"longForm"})]})]})};e.s(["default",0,E],396141);var P=e.i(760814),T=e.i(339228),A=e.i(222009);P.default.div.withConfig({displayName:"LongFormVideoTrailerModal.styles__Overlay",componentId:"sc-481ecf7e-0"})`
  ${({theme:e})=>P.css`
    position: fixed;
    inset: 0;
    background-color: ${e.overlay.medium.value};
    display: flex;
    justify-content: center;
    align-items: center;

    ${(0,A.applyZIndex)("level0")};
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
`,F="75vh",L=P.default.div.withConfig({displayName:"LongFormVideoTrailerModal.styles__TrailerBox",componentId:"sc-481ecf7e-2"})`
  ${({theme:e})=>P.css`
    max-width: 90vw;
    max-height: 90%;
    position: relative;
    background-color: ${e.container.onDefaultBG3.value};
    aspect-ratio: 16 / 9;

    ${(0,A.applyZIndex)("level2")};

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
`,B=({onClose:e,trailer:n})=>{let a=(0,i.useRef)(null),[o,p]=(0,i.useState)(!1),c=()=>{p(!0),setTimeout(()=>{(0,r.default)({eventGrouping:"click_action",eventProperties:{item_name:"trailer-close-button",item_text:"Close",item_type:"button",item_link:""}}),e()},50)};return(0,l.useOutsideClicker)(a,c),(0,s.useGlobalKeydown)(e=>{"Escape"===e.key&&c()}),(0,i.useEffect)(()=>{if(!a.current)return;let e=a.current,t=()=>Array.from(e.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')).filter(e=>!e.hasAttribute("disabled")&&!e.getAttribute("aria-hidden"));t()[0]?.focus();let i=i=>{"Tab"===i.key&&setTimeout(()=>{e.contains(document.activeElement)||t()[0]?.focus()},0)};return document.addEventListener("keydown",i),()=>document.removeEventListener("keydown",i)},[]),(0,t.jsxs)(L,{ref:a,tabIndex:-1,role:"dialog","aria-label":"Trailer player","aria-modal":"true",children:[(0,t.jsx)(N,{onClick:c,"aria-label":"close trailer modal",children:(0,t.jsx)(d.default,{width:24,height:24,name:"actions:close",fill:"white"})}),(0,t.jsx)(E,{mediaMetadataModel:n,isTrailer:!0,onEnded:e,stopPlayer:o})]})},O=(0,i.createContext)([{},()=>null]),{Provider:M}=O;e.s(["PopupContext",0,O,"default",0,({children:e,value:r})=>{let[s,l]=r,{variant:d,onPrimaryAction:p=()=>null,onSecondaryAction:c=()=>null,popupProps:u}=s,g=!!d,y=(0,i.useMemo)(()=>{switch(d){case"leaving-page":return o.default;case"trailer":return B;case"alberta":return n.default;default:return()=>null}},[d]),m="leaving-page"===d?"lightest":"alberta"===d?"medium":"heavy";return(0,t.jsxs)(M,{value:r,children:[(0,t.jsx)(a.default,{isOpen:g,zIndex:"level5",variant:m,children:(0,t.jsx)(y,{onPrimaryAction:p,onSecondaryAction:c,onClose:()=>l({}),...u})}),e]})}],242866)},753423,e=>{"use strict";var t=e.i(191788),i=e.i(242866);e.s(["usePopup",0,function(){let[,e]=(0,t.useContext)(i.PopupContext);return e}],753423)},656612,e=>{"use strict";var t=e.i(823575),i=e.i(519894),n=e.i(789799);e.s(["useCanPlayEpisode",0,function(){let e=(0,i.useFeatureFlag)("audio-windowing"),{isSubscriptionAllowed:a,isSubscribed:o,isSubscriptionCheckComplete:r}=(0,n.useSubscriptionContext)(),s=r&&o;return i=>(0,t.canPlayEpisode)(i,{isAudioWindowingEnabled:e,isSubscriptionAllowed:a,isSubscribed:s})}],656612)},256609,669694,677440,e=>{"use strict";var t=e.i(391398),i=e.i(893409),n=e.i(459949),a=e.i(913777),o=e.i(65739),r=e.i(490602),s=e.i(760814),l=e.i(339228),d=e.i(570549);let p=s.default.div.withConfig({displayName:"AudioEpisodeDetails.styles__AudioEpisodeMetadataStyled",componentId:"sc-9e3f8507-0"})`
  display: flex;
  gap: 12px;
  align-items: center;

  ${(0,l.applyStylesForBreakpoints)(s.css`
      flex-direction: column;
      gap: 16px;
      align-items: flex-start;
    `,"group2")};
`,c=s.default.div.withConfig({displayName:"AudioEpisodeDetails.styles__AudioEpisodeInlineMetadataStyled",componentId:"sc-9e3f8507-1"})`
  ${({theme:e})=>s.css`
    display: inline-flex;
    flex-flow: row wrap;

    ${(0,l.applyStylesForBreakpoints)(s.css`
        flex-wrap: wrap;
      `,"group1")};

    p {
      color: #545658;
      display: flex;
      flex-direction: row;
      ${(0,d.applyTypography)(e.metaData.large)};
      white-space: nowrap;

      &:not(:last-of-type)::after {
        content: '';
        background-color: #545658;
        width: 2px;
        height: 2px;
        margin: 8px;
        border-radius: 50%;
        display: flex;
        justify-content: center;
        align-items: center;
      }

      ${(0,l.applyStylesForBreakpoints)(s.css`
          text-align: center;
        `,"group1")};
    }
  `}
`,u=s.default.p.withConfig({displayName:"AudioEpisodeDetails.styles__AudioEpisodeTextStyled",componentId:"sc-9e3f8507-2"})`
  ${({theme:e})=>s.css`
    /* stylelint-disable-next-line plugin/no-unsupported-browser-features */
    overflow-wrap: anywhere;
    ${(0,d.applyTypography)(e.bodyCopy.default.bpLarge)};
  `}
`,g=s.default.a.withConfig({displayName:"AudioEpisodeDetails.styles__AudioEpisodeSeeMoreStyled",componentId:"sc-9e3f8507-3"})`
  ${({theme:e})=>s.css`
    display: flex;
    flex-direction: row;
    gap: 4px;
    height: 44px;
    align-items: center;
    ${(0,d.applyTypography)(e.textLink.large.regular.bpLarge)};
    text-decoration: none;
    cursor: pointer;
    color: unset;
    padding-right: 24px;

    &:hover {
      text-decoration: underline;
    }
  `}
`,y=(0,s.default)(a.GridStyled).withConfig({displayName:"AudioEpisodeDetails.styles__AudioEpisodeActionsContainer",componentId:"sc-9e3f8507-4"})`
  ${({$isStationPage:e})=>e&&(0,l.applyStylesForBreakpoints)(s.css`
        display: none;
      `,"group3")};
`,m=s.default.div.withConfig({displayName:"AudioEpisodeDetails.styles__AudioButtonsStyled",componentId:"sc-9e3f8507-5"})`
  display: flex;
  ${(0,l.applyStylesForBreakpoints)(s.css`
      display: unset;
    `,"group2")}
`,h="This content is not currently available";e.s(["CONTENT_UNAVAILABLE_MESSAGE",0,h,"DAY_MS",0,864e5,"YEAR_MS",0,31536e6],669694);var f=e.i(16234),x=e.i(789799);let _=({releaseDate:e,duration:i,isWithinSubscriptionWindow:n=!1,availabilityInfo:a,isContentUnavailable:o=!1})=>{let{isSubscriptionAllowed:r}=(0,x.useSubscriptionContext)(),s=n&&r,l=n?r&&!!e:!!e;return s||l||i||a||o?(0,t.jsxs)(p,{children:[s&&(0,t.jsx)(f.default,{variant:"subscribers-only"}),(0,t.jsxs)(c,{children:[l&&e&&(0,t.jsx)("p",{suppressHydrationWarning:!0,children:e.toString()}),i&&(0,t.jsx)("p",{children:i}),a&&(0,t.jsx)("p",{suppressHydrationWarning:!0,children:a}),o&&(0,t.jsx)("p",{children:h})]})]}):null};e.s(["default",0,({releaseDate:e,duration:s,availabilityInfo:l,description:d,moreEpisodesPath:p,programmesUrl:c,isActionVisible:h=!0,isStationPage:f=!1,contentSubtype:x,avProperties:b,isWithinSubscriptionWindow:v=!1,isContentUnavailable:w=!1,isSaveDisabled:S=!1})=>{let{av_episode_id:k,av_brand_id:$,av_series_id:I}=b||{};return(0,t.jsxs)(a.GridStyled,{$columns:[1,1,"minmax(90px, auto) auto","minmax(90px, auto) auto","minmax(90px, auto) auto","minmax(90px, auto) auto"],$maxWidth:["722px","722px","722px","722px","722px","722px"],$gridGap:["32px","32px","16px","16px","16px","16px"],$margin:["auto","auto","auto","auto","auto","auto"],$padding:["0 16px","0 16px","0 16px","0 16px","0 16px","0 16px"],$alignItems:"start","data-testid":"audio-episode-details-wrapper",children:[(0,t.jsx)(y,{$isStationPage:f,"data-testid":"audio-episode-details-buttons",$columns:["repeat(3, 90px)","repeat(3, 90px)",1,1,1,1],$gridGap:["0px","0px","24px","24px","24px","24px"],$margin:["0 -1rem","0 -1rem","0","0","0","0"],children:h&&(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(n.SaveButton,{alignment:"bottom-left",isOnLeftEdge:!0,action:"save",isInverse:!1,iconPosition:"top",variant:"audio",contentId:k,avProperties:b,disabled:S}),(0,t.jsx)(n.SaveButton,{alignment:"bottom-left",isOnLeftEdge:!0,action:"follow",isInverse:!1,iconPosition:"top",variant:"audio",contentId:$||I,contentSubtype:x,avProperties:{...b,av_content_subtype:x,av_content_id:$||I}}),(0,t.jsx)(r.default,{withOverlayBackground:!0,alignment:"bottom-left",isInverse:!0,size:"large",trigger:"click",isOnLeftEdge:!0,iconPosition:"top",type:"round",title:"Share",avProperties:b})]})}),(0,t.jsxs)(a.GridStyled,{"data-testid":"audio-episode-details-info",$columns:[1,1,1,1,1,1],$gridGap:["16px","16px","24px","24px","24px","24px"],children:[(0,t.jsx)(_,{duration:s,releaseDate:e,isWithinSubscriptionWindow:v,availabilityInfo:l,isContentUnavailable:w}),(0,t.jsxs)(a.GridStyled,{$columns:[1,1,1,1,1,1],$gridGap:["16px","16px","16px","16px","16px","16px"],children:[d.map((e,i)=>(0,t.jsx)(u,{children:e},i)),(0,t.jsxs)(m,{children:[p&&(0,t.jsxs)(i.default,{href:p,styledAnchor:g,children:[(0,t.jsx)("p",{children:"See more episodes"}),(0,t.jsx)(o.default,{name:"arrows:chevron-right"})]}),c&&(0,t.jsxs)(i.default,{href:c,styledAnchor:g,target:"_blank",children:[(0,t.jsx)("p",{children:"Programme website"}),(0,t.jsx)(o.default,{name:"arrows:chevron-right"})]})]})]})]})]})}],256609),e.s(["checkResponsiveFitment",0,(e,t,i=10)=>n=>{let[{target:a,contentRect:o}]=n,{children:r}=a,{width:s}=o,l=Array.from(r),d=t?l[l.length-1]:null,p=l.reduce((e,t)=>{let{clientWidth:i}=t;return e+i},i),c=p>s;if(d){let{clientWidth:t}=d;s-t>p&&e(c)}else c!==t&&e(c)}],677440)}]);