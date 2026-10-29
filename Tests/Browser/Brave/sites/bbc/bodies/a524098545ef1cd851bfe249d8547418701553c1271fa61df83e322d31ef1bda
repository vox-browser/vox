(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,713584,(e,t,a)=>{"use strict";Object.defineProperty(a,"__esModule",{value:!0}),Object.defineProperty(a,"HeadManagerContext",{enumerable:!0,get:function(){return r}});let r=e.r(741705)._(e.r(191788)).default.createContext({})},894470,(e,t,a)=>{"use strict";Object.defineProperty(a,"__esModule",{value:!0}),Object.defineProperty(a,"warnOnce",{enumerable:!0,get:function(){return r}});let r=e=>{}},203828,(e,t,a)=>{t.exports=e.r(926990)},746857,2621,e=>{"use strict";var t=e.i(191788),a=e.i(879677),r=e.i(203828),i=e.i(519894),n=e.i(391398);let o=(0,t.createContext)({query:{slug:["home"]},asPath:"",pathname:""}),{Provider:s}=o;e.s(["BrowserRouterContext",0,o,"default",0,({value:e,children:t})=>(0,n.jsx)(s,{value:e,children:t})],2621);var l=e.i(222956);e.s(["useAppRouter",0,function(){let e,n,s,d=(0,i.useFeatureFlag)("client-side-routing"),c=(0,r.useRouter)(),u=(e=(0,t.useContext)(o),n=async(e,t,r)=>{let i=(t||e)?.toString(),{scroll:n=!1,shallow:o=!1}=(0,a.default)(r,{});try{return o?window.history.pushState(null,"",i):window.location.assign(i),n&&window.scrollTo(0,0),!0}catch(e){return l.default.error(`Failed to assign ${i} to window.location. Error: ${e}`),!1}},s=async(e,t,r)=>{let i=(t||e)?.toString(),{scroll:n=!1,shallow:o=!1}=(0,a.default)(r,{});try{return o?window.history.replaceState(null,"",i):window.location.replace(i),n&&window.scrollTo(0,0),!0}catch(e){return l.default.error(`Failed to placing ${i} on window.location. Error: ${e}`),!1}},{...e,push:n,replace:s});return d?c:u}],746857)},548817,e=>{"use strict";var t=e.i(462790),a=e.i(442355);e.s(["default",0,function(e){return"number"==typeof e||(0,a.default)(e)&&"[object Number]"==(0,t.default)(e)}])},788664,e=>{"use strict";var t=e.i(959560);let a=(0,e.i(116240).withMiddleware)(t.default,e=>(t,a,r)=>(r.revalidateOnFocus=!1,r.revalidateIfStale=!1,r.revalidateOnReconnect=!1,e(t,a,r)));e.s(["default",0,a])},280108,e=>{"use strict";var t=e.i(317166);e.s(["tokenRefreshMiddleware",0,e=>function(a,r,i){let{isSignedIn:n,ensureTokens:o}=(0,t.useUser)();return e(a,r?async(...e)=>(n&&await o(),r(...e)):null,i)}],280108)},849766,970062,615538,e=>{"use strict";var t=e.i(191788),a=e.i(391398),r=e.i(508259);let i=(0,t.createContext)({error:"",addError:()=>{r.logger.error("ERROR - attempting to call addError in a component that is not the child of a DismissableErrorProvider")},clearError:()=>{r.logger.error("ERROR - attempting to call clearError in a component that is not the child of a DismissableErrorProvider")}}),{Provider:n}=i;e.s(["DismissibleErrorContext",0,i,"default",0,({children:e})=>{let r,[i,o]=(0,t.useState)(""),s={error:i,addError:(0,t.useCallback)(e=>{r&&clearTimeout(r),r=setTimeout(()=>{o("")},5e3),o(e)},[]),clearError:(0,t.useCallback)(()=>o(""),[])};return(0,a.jsx)(n,{value:s,children:e})}],970062),e.s(["useDismissibleError",0,()=>{let{error:e,addError:a,clearError:r}=(0,t.useContext)(i);return{error:e,addError:a,clearError:r}}],849766);var o=e.i(548817),s=e.i(993297),l=e.i(898229);let d={credentials:"include",isLegacyApiEnabled:!0},c={bookmark:"bookmark",follow:"follow"},u={bookmarks:"bookmark",follows:"follow"};async function p(e){let[t,a,i,n]=e,c={...(0,o.default)(i)?{size:i.toString()}:{},...(0,o.default)(a)?{page:a.toString()}:{},...n?{country:n}:{}};try{let{data:{data:e,...a}}=await (0,l.fetchClient)(u[t],{cache:"no-cache",params:c,method:"GET",...d});return{data:("follows"===t?e.map(({episode:e,premiumEpisode:t,id:a,path:r,title:i,indexImage:n,summary:o,topics:s})=>({...e,path:r,title:i,indexImage:n,brand:{id:a,path:r,title:i},premiumEpisode:t,summary:o,topics:s})):e).map(e=>(0,s.transformContent)(e)),...a}}catch(e){return r.logger.error(`Error fetching ${t} list`,e),{data:[],total:0,page:0,pageSize:0}}}async function g(e){let[t,a,i,n,o]=e;if(i)try{let e={id:a,...n&&{subtype:o}},{data:r}=await (0,l.fetchClient)(c[t],{params:e,method:"GET",...d});return r}catch(e){r.logger.error(`Error fetching ${t} status`,e);return}}async function f(...e){let[t,a,r,i,n]=e,o={id:r,...i&&{subtype:n}};return await (0,l.fetchClient)(c[a],{params:o,method:"save"===t?"POST":"DELETE",...d}),{saved:"save"===t,id:r}}e.s(["getBookmarkStatus",0,g,"getBookmarks",0,p,"setBookmarkStatus",0,f],615538)},318438,e=>{"use strict";e.s(["siteLabel",0,{production:"BBCS_BBC",test:"BBCS_BBC_TEST"}])},606919,e=>{"use strict";var t=e.i(508259);e.s(["getAuthUrl",0,(e,a)=>{let r,i;try{i=(r=new URL(e)).searchParams}catch(a){t.logger.error(`Failed to construct authURL. Using: ${e} instead. Error: ${a}`),i=new URLSearchParams}for(let e in a)i.append(e,a[e]);return r?r.toString():`${e}?${i.toString()}`}],606919)},729685,e=>{"use strict";var t=e.i(746857);e.s(["useCurrentPageUrl",0,()=>{let{asPath:e}=(0,t.useAppRouter)();return window.location.origin?`${window.location.origin}${e}`:""}],729685)},79934,721854,e=>{"use strict";var t=e.i(391398),a=e.i(191788),r=e.i(154738),i=e.i(893409),n=e.i(84541),o=e.i(235680),s=e.i(254765),l=e.i(788664),d=e.i(280108),c=e.i(849766),u=e.i(519894),p=e.i(704570),g=e.i(317166),f=e.i(615538);let m=function(e="bookmark",t,a){let{id:r,subtype:i}=(0,p.usePageData)(),{isSignedIn:n}=(0,g.useUser)(),o=(0,u.useFeatureFlag)("authentication"),s=(0,u.useFeatureFlag)("bookmarking"),{addError:m}=(0,c.useDismissibleError)(),h=t||r||"",v=a||i,{mutate:y,...b}=(0,l.default)([e,h,n&&o&&("bookmark"!==e||s),!0,v],f.getBookmarkStatus,{use:[d.tokenRefreshMiddleware]}),x=t=>()=>y((0,f.setBookmarkStatus)(t,e,h,!0,v),{optimisticData:{saved:"save"===t,id:h},populateCache:!0,revalidate:!1,rollbackOnError:!0}).catch(()=>{m(`We could not ${"save"===t?"save":"remove"} this at the moment, try again or come back later.`)});return{data:function(e,t){let{isLoading:a,data:r}=e,{id:i=t,saved:n=!1}=r??{};return{isLoading:a,id:i,saved:n}}(b,h),onSave:x("save"),onRemove:x("remove")}};var h=e.i(729685),v=e.i(167971),y=e.i(606919),b=e.i(564045),x=e.i(21540),w=e.i(318438);function S(e,t){switch(e){case"save":return t?"account:saved-items":"account:saved-items-outlined";case"follow":return t?"actions:checkmark":"actions:add";default:return}}function $(e,t){let a=(0,b.getRunningEnvironment)()===x.RunningEnvironment.LIVE?w.siteLabel.production:w.siteLabel.test;return(0,y.getAuthUrl)(e,{userOrigin:a,ptrt:t})}function j(e,t){return{eventGrouping:e,eventProperties:{item_link:t,group_name:"participate_option"}}}e.s(["getAnalyticsProps",0,j,"getAnchorHref",0,$,"getButtonIcon",0,S],721854);var P=e.i(760814),k=e.i(570549);let C=P.default.div.withConfig({displayName:"SaveButton.styles__UnauthorizedPopoverStyled",componentId:"sc-900f1116-0"})`
  ${({theme:e})=>P.css`
    display: grid;
    row-gap: 16px;
    grid-auto-columns: 1fr;
    min-width: 200px;
    color: ${e.interactive5.onInverseBG.default.value};
  `};
`,B=P.default.span.withConfig({displayName:"SaveButton.styles__UnauthorizedPopoverTitleStyled",componentId:"sc-900f1116-1"})`
  ${({theme:e})=>P.css`
    ${(0,k.applyTypography)(e.generic.description.Regular.bpLarge)};
  `}
`,T=P.default.div.withConfig({displayName:"SaveButton.styles__UnauthorizedPopoverActionsStyled",componentId:"sc-900f1116-2"})`
  ${({theme:e})=>P.css`
    display: flex;
    column-gap: 8px;
    flex-direction: row;
    align-items: center;
    ${(0,k.applyTypography)(e.button.small)};
  `}
`;P.default.div.withConfig({displayName:"SaveButton.styles__SaveButtonTemplateStyled",componentId:"sc-900f1116-3"})`
  min-width: 30vw;
  min-height: 30vh;
  padding-block: 16px;
  display: grid;
  justify-items: center;
  align-items: start;
  background-color: ${({$isInverse:e})=>e?"#000000":"#ffffff"};
`;let I=({action:e="save",variant:a="news",isSelected:r=!1,...i})=>{let o=S(e,r);return(0,t.jsx)(n.default,{withoutPaddingBlock:!0,withoutPaddingInline:!0,type:"news"===a?"unboxed-share":"round",icon:o,"data-action":e,isSelected:r,...i})};e.s(["FollowButtonInner",0,({alignment:e,text:i,withoutText:n,contentId:s,contentSubtype:l,isSelected:d,contentUrl:c,avProperties:u,...p})=>{let{data:g,onSave:f,onRemove:v}=m("follow",s,l),{saved:y,isLoading:b}=g,[x,w]=(0,a.useState)(!1),S=y?"Following":"Follow",$=(0,h.useCurrentPageUrl)(),j=async e=>{e.stopPropagation(),w(!0),(y?v:f)().then(()=>setTimeout(()=>w(!1),1e3));let t=y?"av_unfollow":"av_follow";window.analytics.sendEvent({eventGrouping:t,eventProperties:{item_link:c?(0,o.getAnalyticsFullUrl)(c):$,...u&&{...u}}})};return!b&&(0,r.default)(y)?null:(0,t.jsx)(I,{action:"follow",variant:"audio",testId:"followButton",disabled:b||x,text:n?"":S,onClick:j,isSelected:y,...p})},"SaveButtonComponent",0,I,"SaveButtonInner",0,({alignment:e,text:i,variant:n="news",withoutText:l,contentId:d,contentUrl:c,isSelected:u,contentSubtype:g,avProperties:f,...v})=>{let{data:y,onSave:b,onRemove:x}=m("bookmark",d,g),{saved:w,isLoading:S}=y,[$,j]=(0,a.useState)(!1),P=w?"Saved":"Save",{urn:k}=(0,p.usePageData)(),C=(0,h.useCurrentPageUrl)();return!S&&(0,r.default)(w)?null:(0,t.jsx)(I,{action:"save",variant:n,testId:"saveButton",disabled:S||$,text:l?"":P,ariaLabel:l?P:void 0,onClick:e=>{e.stopPropagation(),j(!0),(w?x:b)().then(()=>setTimeout(()=>j(!1),1e3));let t=w?"bookmark_remove":"bookmark_add";window.analytics.sendEvent({eventGrouping:t,eventProperties:{item_link:c?(0,o.getAnalyticsFullUrl)(c):C,item_resource_id:(0,s.getItemResourceId)(d??k,g),...f&&{...f}}})},isSelected:w,...v})},"SaveButtonPopover",0,({alignment:e="bottom-right",action:a="save",isOnLeftEdge:r=!1,withoutText:o=!1,variant:s="news",...l})=>{let{signInUrl:d,registerUrl:c}=(0,g.useUser)(),u=(0,h.useCurrentPageUrl)(),p=`Sign in to ${a} for later`,f=(0,t.jsxs)(C,{children:[(0,t.jsx)(B,{children:p}),(0,t.jsxs)(T,{children:[(0,t.jsx)(i.default,{href:$(d,u),analytics:j("sign_in",$(d,u)),children:(0,t.jsx)(n.default,{text:"Sign In",size:"small",type:"general"})}),(0,t.jsx)("span",{children:"or"}),(0,t.jsx)(i.default,{href:$(c,u),analytics:j("register",$(c,u)),children:(0,t.jsx)(n.default,{text:"Register",size:"small",type:"unboxed-share",isInverse:!0,withoutPaddingInline:!0})})]})]}),m="save"===a?"Save":"Follow";return(0,t.jsx)(v.default,{isInverse:!0,content:f,trigger:"click",alignment:e,isOnLeftEdge:r,children:(0,t.jsx)(I,{action:a,variant:s,testId:"save"===a?"saveButton":"followButton",text:o?"":m,ariaLabel:o?m:void 0,...l})})}],79934)},852827,e=>{"use strict";var t=e.i(508259),a=e.i(898229);let r={credentials:"include",isLegacyApiEnabled:!0},i="heartbeat";async function n(e){let{isFetchAllowed:n,ids:o=[]}=e,s=o?.map(e=>({id:e,offset:0}));if(!n||!o.length)return s;let l=new URLSearchParams;o.forEach(e=>l.append("id",e));let d={cache:"no-cache",params:l,method:"GET",paramsHaveIdenticalKeys:o.length>1,...r};try{if(1===o.length){let{data:e}=await (0,a.fetchClient)(i,d);return[e]}{let{data:e}=await (0,a.fetchClient)(i,d);return e}}catch(e){return t.logger.error("Error attempting to get media progress: ",JSON.stringify(e)),s}}let o=async(e,n)=>{try{let t=((e,t)=>{var a;if(a=e,Math.floor(a.currentTime)%30!=0)return!1;let r=t[0].model.blocks[0].model.blocks[0].model,i=r.versions[0],n=new URLSearchParams;return n.append("action","started"),n.append("versionPid",i.versionId),n.append("offset",Math.round(e.currentTime).toString()),n.append("id",r.id),n})(e,n);if(!1===t)return;await (0,a.fetchClient)(i,{cache:"no-cache",params:t,method:"POST",...r})}catch(e){t.logger.error("Error attempting to set media progress: ",e)}};e.s(["getMediaProgress",0,n,"setLFVMediaProgress",0,function(e){return async function(n){try{let{versions:t}=e,[{versionId:o}]=t,s=new URLSearchParams;s.append("action","started"),s.append("versionPid",o),s.append("offset",Math.round(n.currentTime).toString()),s.append("id",e.id),await (0,a.fetchClient)(i,{cache:"no-cache",params:s,method:"POST",...r})}catch(e){t.logger.error("Error attempting to set LFV media progress: ",e)}}},"setMediaProgress",0,o])},937515,497030,94930,745853,e=>{"use strict";var t=e.i(391398);let a=(e,t)=>{if(!Array.isArray(e))return 0;let[{offset:a=0}={}]=e.filter(e=>e.id===t);return a};function r(e,t,r){return{...e,progress:a(t,r)}}e.s(["extendMetadata",0,r,"getMediaOffsetFromProgress",0,a],497030);let i=e=>e.map(({id:e=""})=>e).filter(Boolean);e.s(["getIdsFromContent",0,i],94930);var n=e.i(788664),o=e.i(280108),s=e.i(519894),l=e.i(317166),d=e.i(852827);let c=function(e=[]){let{isSignedIn:t}=(0,l.useUser)(),a=(0,s.useFeatureFlag)("authentication"),{data:r=[]}=(0,n.default)({isFetchAllowed:t&&a,ids:e},d.getMediaProgress,{use:[o.tokenRefreshMiddleware]});return r};e.s(["useMediaProgress",0,c],745853);var u=e.i(554692),p=e.i(760814),g=e.i(339228);let f=p.default.div.withConfig({displayName:"Massachusetts.styles__MassachusettsContainerStyled",componentId:"sc-bf2d27d-0"})`
  display: grid;
  row-gap: 24px;

  ${(0,g.applyStylesForBreakpoints)(p.css`
      row-gap: 16px;
    `,"group2")};
`,m=({content:e=[],testId:a="massachusetts",onCardClick:n})=>{let o=c(i(e));return(0,t.jsx)(f,{"data-testid":`${a}`,children:e.map((a,i)=>{let{type:s,id:l,metadata:d,...c}=a,p=r(d,o,l);return(0,t.jsx)(u.default,{id:l,type:"lancaster",...c,metadata:p,hideBottomBorder:i===e.length-1,itemPosition:i,onClick:()=>n?.(a,i),...i===e.length-1?{isLastCard:!0}:{}},i)})})};e.s(["Massachusetts",0,m,"default",0,m],937515)},109072,e=>{"use strict";var t=e.i(760814);e.s(["addHoverState",0,function(e){return t.css`
    @media (hover: hover) {
      &:hover {
        ${e};
      }
    }
  `}])},249356,e=>{"use strict";var t=e.i(977546);e.s(["default",0,function(e,a){return(0,t.default)(e,a)}])},548241,e=>{"use strict";var t=e.i(391398),a=e.i(191788),r=e.i(937515),i=e.i(235680),n=e.i(524431),o=e.i(249356);function s(e){return`tabpanel-${e}`}var l=e.i(760814);let d=l.default.div.withConfig({displayName:"TabPanel.styles__TabPanelStyled",componentId:"sc-ac3b66d4-0"})`
  ${({$isActive:e})=>l.css`
    ${!e&&l.css`
      display: none;
    `};
  `};
`,c=(0,a.memo)(({tabName:e,isActive:a,children:r})=>(0,t.jsx)(d,{role:"tabpanel",id:s(e),"aria-labelledby":`tab-${e}`,$isActive:a,children:r}),function({children:e,...t},{children:a,...r}){return(0,o.default)(t,r)&&(0,o.default)(e,a)});var u=e.i(109072),p=e.i(570549);let g=l.default.button.withConfig({displayName:"TabList.styles__TabButtonStyled",componentId:"sc-a10e8206-0"})`
  ${({theme:e,$isActive:t})=>l.css`
    padding-inline: 8px;
    padding-block: 15px;
    position: relative;
    ${(0,p.applyTypography)(e.nav.topbar.level1.default)};

    ${(0,u.addHoverState)(l.css`
      cursor: pointer;
      background-color: ${e.tabs.hover.inverse.background.value};
    `)};

    ${t&&l.css`
      &::after {
        position: absolute;
        content: '';
        bottom: 0;
        left: 0;
        right: 0;
        width: 100%;
        height: 4px;
        background-color: ${e.tabs.selected.inverse.stroke.value};
      }
    `};
  `};
`,f=l.default.div.withConfig({displayName:"TabList.styles__TabListStyled",componentId:"sc-a10e8206-1"})`
  ${({theme:e})=>l.css`
    display: inline-flex;
    color: ${e.tabs.default.inverse.content.content.value};
  `};
`,m=({tabName:e,isActive:a,onClick:r})=>{let i=`tab-${e}`,n=s(e);return(0,t.jsx)(g,{id:i,role:"tab","aria-selected":a,"aria-controls":n,onClick:()=>!a&&r(e),$isActive:a,...a?{}:{tabIndex:-1},children:e})},h=({tabs:e,activeTab:r,onTabClick:i})=>{let n=(0,a.useRef)(null);return(0,t.jsx)(f,{ref:n,role:"tablist",onKeyDown:({key:e,target:t})=>{let{current:a}=n;if(a&&t instanceof HTMLButtonElement){let{nextElementSibling:r,previousElementSibling:i}=t;switch(e){case"ArrowRight":return r&&r.focus();case"ArrowLeft":return i&&i.focus();case"Home":{let{firstElementChild:e}=a;return e&&e.focus()}case"End":{let{lastElementChild:e}=a;return e&&e.focus()}}}},children:e.map(e=>(0,t.jsx)(m,{tabName:e,isActive:e===r,onClick:i},e))})};var v=e.i(339228);let y=l.default.div.withConfig({displayName:"Tabs.styles__TabsStyled",componentId:"sc-a6f3457c-0"})`
  display: grid;
  row-gap: 24px;

  ${(0,v.applyStylesForBreakpoints)(l.css`
      row-gap: 16px;
    `,"group2")};
`,b=({activeTab:e,onSelectTab:a,tabs:r,children:i})=>{let n=Array.from(r);return(0,t.jsxs)(y,{children:[n.length>1?(0,t.jsx)(h,{activeTab:e,tabs:n,onTabClick:a}):null,i]})},x=l.default.div.withConfig({displayName:"DetailsTab.styles__DetailsTabStyled",componentId:"sc-870edce0-0"})`
  display: grid;
  ${({$centered:e,theme:t})=>e?`
    place-items: center;
    min-height: 128px;

  `:`
    grid-template-columns: repeat(2, 1fr);
    grid-template-rows: minmax(0, min-content) repeat(auto-fill, minmax(0, 1fr));
    row-gap: 32px;
    column-gap: 32px;
  `}

  ${(0,v.applyStylesForBreakpoints)(l.css`
      grid-template-columns: 1fr;
    `,"group2")};
`,w=l.default.div.withConfig({displayName:"DetailsTab.styles__DetailsTabItemStyled",componentId:"sc-870edce0-1"})`
  ${({$variant:e="primary",$rowSpan:t,$withNestedItems:a})=>l.css`
    display: grid;
    grid-auto-rows: min-content;

    ${a?l.css`
          row-gap: 12px;
        `:l.css`
          row-gap: ${"primary"===e?"8px":"4px"};
        `};

    ${t&&l.css`
      grid-row: span ${t};
    `};

    ${(0,v.applyStylesForBreakpoints)(l.css`
        grid-row: span 1;
        ${a&&l.css`
          row-gap: 16px;
        `};
      `,"group2")};
  `};
`,S=l.default.h3.withConfig({displayName:"DetailsTab.styles__DetailsTabHeadingStyled",componentId:"sc-870edce0-2"})`
  ${({theme:e,$variant:t="primary"})=>l.css`
    ${"primary"===t?l.css`
          text-transform: uppercase;
          ${(0,p.applyTypography)(e.sectionTitle.bpLarge)};
          color: ${e.text.onInverseBG.default.value};
        `:l.css`
          text-transform: capitalize;
          ${(0,p.applyTypography)(e.longFormVideo.details.bpLarge)};
          color: ${e.text.onInverseBG.lowEmpasis.value};

          ${(0,v.applyStylesForBreakpoints)(l.css`
              ${(0,p.applyTypography)(e.longFormVideo.details.bpSmall)};
            `,"group2")};
        `};
  `};
`,$=l.default.p.withConfig({displayName:"DetailsTab.styles__DetailsTabValueStyled",componentId:"sc-870edce0-3"})`
  ${({theme:e,$noDetails:t})=>l.css`
    ${t?l.css`
          ${(0,p.applyTypography)(e.generic.info1.default.bpLarge)};
          color: ${e.button.general.disabled.inverse.content.value};
          ${(0,v.applyStylesForBreakpoints)(l.css`
              ${(0,p.applyTypography)(e.generic.info1.default.bpSmall)};
            `,"group2")};
        `:l.css`
          ${(0,p.applyTypography)(e.longFormVideo.details.bpLarge)};
          color: ${e.text.onInverseBG.default.value};
          ${(0,v.applyStylesForBreakpoints)(l.css`
              ${(0,p.applyTypography)(e.longFormVideo.details.bpSmall)};
            `,"group2")};
        `}
    display: grid;
    row-gap: 16px;
  `};
`,j=({contributors:e,distributionCompany:a,productionCompany:r})=>{let i=Array.isArray(a)?a.join(", "):a,n=e.reduce((e,{name:t,role:a="cast"})=>({...e,[a]:[...e[a]||[],t]}),{}),o=e&&e.length>0,s=!!r;return o||s||i?(0,t.jsxs)(x,{children:[o&&(0,t.jsxs)(w,{$rowSpan:2,$withNestedItems:!0,children:[(0,t.jsx)(S,{children:"Contributors"}),(0,t.jsx)($,{as:"div",children:Object.entries(n).sort().map(([e,a],r)=>(0,t.jsxs)(w,{$variant:"secondary",children:[(0,t.jsx)(S,{$variant:"secondary",as:"h4",children:`${!(a.length>1)||"cast"===e?e:`${e}s`}:`}),(0,t.jsx)($,{children:a.join(", ")})]},r))})]}),s&&(0,t.jsxs)(w,{children:[(0,t.jsx)(S,{children:"Series Production Company"}),(0,t.jsx)($,{children:r})]})]}):(0,t.jsx)(x,{$centered:!0,children:(0,t.jsx)($,{$noDetails:!0,children:"No details available for this content"})})};e.s(["default",0,({episodes:e,isSubscriptionAllowed:o,seriesName:s,seasonNumber:l,...d})=>{let u=o?["Episodes","Details"]:["Details"],[p]=u,g=new Set(u),[f,m]=(0,a.useState)(p),h=e.map(e=>(function(e,t,a){let r,{id:i,title:n,path:o,indexImage:s,episodeNumber:l,duration:d,durationFormatted:c,rating:u,releaseDate:p,description:g}=e,f=`${t} Season ${a} Episode ${l}`,m={...s,model:{blocks:{...s?.model?.blocks,altText:f}}};return{id:i,title:n,href:o,type:"lancaster",metadata:{cardType:"lancaster",contentType:"video",duration:d,durationFormatted:c,rating:u,lastUpdated:((r=new Date(p)).setDate(r.getDate()+1),r.setUTCHours(0,0,0),r.getTime())},image:m,episodeNumber:l,description:g?.shortDescription||g?.mediumDescription||g?.longDescription||""}})(e,s,l)),v=(0,n.useLogMparticleEvent)();return(0,t.jsxs)(b,{tabs:g,activeTab:f,onSelectTab:e=>m(e),children:[(0,t.jsx)(c,{tabName:"Episodes",isActive:"Episodes"===f,children:(0,t.jsx)(r.default,{content:h,onCardClick:(e,t)=>{v("docs.episode.select",{title:e.title,page:window.location.toString(),url:(0,i.getAnalyticsFullUrl)(e.href),itemPosition:t+1,referrer:document.referrer,userAgent:navigator.userAgent},{forceUpload:!0})}})}),(0,t.jsx)(c,{tabName:"Details",isActive:"Details"===f,children:(0,t.jsx)(j,{...d})})]})}],548241)},202680,964191,296601,48397,193783,e=>{"use strict";var t=e.i(391398),a=e.i(191788);let r=e=>{let t=new URL(window.location.href);return t.searchParams.set("page",String(e)),t.toString()};e.s(["appendPageQueryParamToUrl",0,r],964191);var i=e.i(760814),n=e.i(570549);let o=i.default.div.withConfig({displayName:"Pagination.styles__PaginationStyled",componentId:"sc-3094f74e-0"})`
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
`,s=i.default.span.withConfig({displayName:"Pagination.styles__PaginationPlaceholderStyled",componentId:"sc-3094f74e-1"})`
  ${({theme:e,$isInverse:t})=>i.css`
    min-width: 44px;
    display: inline-flex;
    justify-content: center;
    box-sizing: border-box;
    color: ${t?e.pagination.default.inverse.content.value:e.interactiveInnner.onDefaultBG.value};
    ${(0,n.applyTypography)(e.button.regular)};
  `}
`,l=i.default.div.withConfig({displayName:"Pagination.styles__MobileTextStyled",componentId:"sc-3094f74e-2"})`
  ${({theme:e,$isInverse:t})=>i.css`
    color: ${t?e.pagination.default.inverse.content.value:e.pagination.default.normal.content.value};
    ${(0,n.applyTypography)(e.button.regular)};
    padding: 13px;
    margin-right: 4px;
  `}
`;e.s(["MobileTextStyled",0,l,"PaginationPlaceholderStyled",0,s,"PaginationStyled",0,o],296601);var d=e.i(893409),c=e.i(109072);let u=(0,i.css)(({theme:e,$isActive:t,$isDisabled:a,$isInverse:r})=>i.css`
    display: inline-flex;
    align-items: center;
    justify-content: center;
    box-sizing: border-box;
    min-width: 44px;
    height: 44px;
    padding-inline: 12px;
    color: ${r?e.pagination.default.inverse.content.value:e.pagination.default.normal.content.value};
    background-color: ${r?e.interactive2.onInverseBG.default.value:e.interactive2.onDefaultBG.default.value};

    ${(0,n.applyTypography)(e.button.regular)};
    ${(0,c.addHoverState)(i.css`
      cursor: pointer;
    `)};

    &:hover {
      background-color: ${r?e.interactive2.onInverseBG.hovered.value:e.interactive2.onDefaultBG.hovered.value};
      color: ${r?e.pagination.hover.inverse.content.value:e.pagination.hover.normal.content.value};
    }

    ${a&&i.css`
      pointer-events: none;
      background-color: ${r?e.interactive2.onInverseBG.default.value:e.interactive2.onDefaultBG.default.value};
      color: ${r?e.pagination.disabled.inverse.content.value:e.pagination.disabled.normal.content.value};
    `}

    ${t&&i.css`
      color: ${r?e.pagination.focus.inverse.content.value:e.pagination.focus.normal.content.value};
      background-color: ${r?e.interactive2.onInverseBG.pressed.value:e.interactive2.onDefaultBG.pressed.value};
    `};
  `),p=i.default.button.withConfig({displayName:"PaginationButton.styles__PaginationButtonStyled",componentId:"sc-c649ee72-0"})`
  ${u};
`,g=i.default.a.withConfig({displayName:"PaginationButton.styles__PaginationAnchorStyled",componentId:"sc-c649ee72-1"})`
  text-decoration: none;
  ${u};
`;e.s(["PaginationAnchorStyled",0,g,"PaginationButtonStyled",0,p],48397);let f=(0,a.memo)(e=>{let{href:a="",title:r,isActive:i,isDisabled:n,isInverse:o,onClick:s,children:l}=e,c={$isActive:i,$isDisabled:n,$isInverse:o};return s?(0,t.jsx)(p,{title:r,"aria-label":r,"aria-disabled":n,"aria-current":i?"page":void 0,onClick:s,disabled:n,...c,children:l}):(0,t.jsx)(d.default,{href:a,styledAnchor:g,styledAnchorProps:{...c,title:r,"aria-label":r,"aria-disabled":n,"aria-current":i?"page":void 0},children:l})});e.s(["default",0,f],193783);let m=(0,a.memo)(({isInverse:e})=>(0,t.jsx)(s,{$isInverse:e,children:"..."}));e.s(["DesktopPaginationBody",0,({currentPage:e,onPageChange:a,pageCount:i,pageNumbers:n,isInverse:o})=>{let{0:s,[n.length-1]:l}=n;return(0,t.jsxs)(t.Fragment,{children:[1!==s&&(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(f,{href:r(1),isInverse:o,isActive:!1,isDisabled:!1,title:"Go to page 1",...a?{onClick:()=>a(1)}:{},children:1}),(0,t.jsx)(m,{isInverse:o})]}),n.map(i=>(0,t.jsx)(f,{href:r(i),isInverse:o,isActive:e===i,isDisabled:!1,title:`Go to page ${i}`,...a?{onClick:()=>a(i)}:{},children:i.toString()},i)),l!==i&&(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(m,{isInverse:o}),(0,t.jsx)(f,{href:r(i),isInverse:o,isActive:!1,isDisabled:!1,title:`Go to page ${i}`,...a?{onClick:()=>a(i)}:{},children:i.toString()})]})]})},"MobilePaginationBody",0,({currentPage:e,pageCount:a,isInverse:r})=>(0,t.jsx)(l,{"data-testid":"pagination-mobile",$isInverse:r,children:`Page ${e} of ${a}`}),"PaginationPlaceholder",0,m],202680)},459949,e=>{"use strict";var t=e.i(391398),a=e.i(168489),r=e.i(191788);let i=function(e){let a=(0,r.createContext)({}),{Provider:i}=a,n=e(()=>(0,r.useContext)(a));return e=>(0,t.jsx)(i,{value:e,children:(0,t.jsx)(n,{...e})})};var n=e.i(893409),o=e.i(686764),s=e.i(162644),l=e.i(818883);let d=({title:e,episodes:a=[]})=>{let{length:r}=a,[i]=a,{path:d}=i??{};return(0,t.jsxs)(l.SeriesCtasStyled,{children:[(0,t.jsx)(o.default,{condition:!!r,wrapper:e=>(0,t.jsx)(n.default,{href:d,children:e}),children:(0,t.jsx)(l.SeriesCtasButtonStyled,{isInverse:!0,type:"general",size:"medium",text:"Watch now",disabled:!r,tabIndex:-1})}),(0,t.jsx)(l.SeriesCtasButtonStyled,{isInverse:!0,type:"ghost",size:"medium",text:"Watch trailer"}),(0,t.jsx)(l.SeriesCtasExtraActionsStyled,{children:(0,t.jsx)(s.default,{variant:"video-series-page",title:e,avProperties:{},contentTopic:""})})]})};var c=e.i(548241),u=e.i(84541),p=e.i(79934);let g=({variant:e="news",action:a="save",text:r="Save",iconPosition:i="right",...n})=>(0,t.jsx)(p.SaveButtonComponent,{disabled:!0,variant:e,action:a,text:r,iconPosition:i,...n}),f=()=>(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(u.default,{disabled:!0,type:"unboxed-share",icon:"social:share",size:"small",text:"Share",iconPosition:"right"}),(0,t.jsx)(g,{action:"save",variant:"news",text:"Save",iconPosition:"right",size:"small"})]});var m=e.i(65739),h=e.i(202680),v=e.i(296601),y=e.i(48397);let b=()=>(0,t.jsxs)(v.PaginationStyled,{children:[(0,t.jsx)(y.PaginationButtonStyled,{$isDisabled:!0,$isInverse:!1,$isActive:!1,children:(0,t.jsx)(m.default,{name:"arrows:chevron-left",width:15})}),(0,t.jsx)(h.PaginationPlaceholder,{isInverse:!1}),(0,t.jsx)(y.PaginationButtonStyled,{$isDisabled:!0,$isInverse:!1,$isActive:!1,children:(0,t.jsx)(m.default,{name:"arrows:chevron-right",width:15})})]}),x=(0,a.default)(()=>e.A(176096),{loadableGenerated:{modules:[964284]},ssr:!1}),w=(0,a.default)(()=>e.A(684958),{loadableGenerated:{modules:[208405]},ssr:!1,loading:()=>(0,t.jsx)(f,{})}),S=(0,a.default)(()=>e.A(646790),{loadableGenerated:{modules:[621743]},ssr:!1}),$=(0,a.default)(()=>e.A(704815),{loadableGenerated:{modules:[340986]}}),j=(0,a.default)(()=>e.A(98934),{loadableGenerated:{modules:[700930]},ssr:!1}),P=(0,a.default)(()=>e.A(762970),{loadableGenerated:{modules:[343854]}}),k=(0,a.default)(()=>e.A(593201),{loadableGenerated:{modules:[846310]},ssr:!1}),C=(0,a.default)(()=>e.A(211169),{loadableGenerated:{modules:[230230]},ssr:!1}),B=(0,a.default)(()=>e.A(445290),{loadableGenerated:{modules:[924189]},ssr:!1}),T=(0,a.default)(()=>e.A(871926),{loadableGenerated:{modules:[995919]},ssr:!1}),I=(0,a.default)(()=>e.A(439890),{loadableGenerated:{modules:[511310]},ssr:!1,loading:()=>(0,t.jsx)(b,{})}),A=(0,a.default)(()=>e.A(922605),{loadableGenerated:{modules:[748558]},ssr:!1}),_=(0,a.default)(()=>e.A(260421),{loadableGenerated:{modules:[47375]},ssr:!1}),E=(0,a.default)(()=>e.A(967106),{loadableGenerated:{modules:[766583]},ssr:!1}),D=i(r=>(0,a.default)(()=>e.A(272637),{loadableGenerated:{modules:[329301]},ssr:!1,loading:()=>(0,t.jsx)(g,{...r()})})),F=(0,a.default)(()=>e.A(717929),{loadableGenerated:{modules:[701066]},ssr:!1}),G=(0,a.default)(()=>e.A(739128),{loadableGenerated:{modules:[91973]}}),L=i(r=>(0,a.default)(()=>e.A(611005),{loadableGenerated:{modules:[549362]},ssr:!1,loading:()=>(0,t.jsx)(d,{...r()})})),R=i(r=>(0,a.default)(()=>e.A(506839),{loadableGenerated:{modules:[713866]},ssr:!1,loading:()=>(0,t.jsx)(c.default,{...r(),isSubscriptionAllowed:!0})}));e.s(["AccountButtons",0,x,"ArticlePageButtons",0,w,"Dropdown",0,$,"Embed",0,j,"FeedbackForm",0,P,"Include",0,k,"IndexCardLinks",0,C,"MediaProgress",0,S,"NonPlayableSection",0,B,"Obituary",0,T,"Pagination",0,I,"PlayableStandalone",0,A,"PlayableWorldNews",0,_,"RemoveButton",0,E,"SaveButton",0,D,"SavedItemsPage",0,F,"SeriesCtas",0,L,"SeriesTabs",0,R,"Slideshow",0,G],459949)}]);