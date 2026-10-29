(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,789799,24768,394030,e=>{"use strict";var t=e.i(391398),i=e.i(191788),a=e.i(480495),n=e.i(519894),s=e.i(508259);let l="ckns_subscription_status",o={longFormVideo:"longFormVideo",AdFreeAudio:"AdFreeAudio"};e.s(["CHECKOUT_STATE_COOKIE",0,"ckns_checkout_state","CUSTOM_FORM",0,"MarketingConsent","CUSTOM_FORM_FIELD_NAME",0,"MarketingConsent","SUBSCRIPTION_BANNER_ID",0,"subliminal-banner","SUBSCRIPTION_CLAIM",0,o,"SUBSCRIPTION_REDIRECT_PATH_LOCAL_STORAGE_KEY",0,"subliminal_redirect_path","SUBSCRIPTION_SETTINGS_COOKIE",0,"ckns_subscription_settings","SUBSCRIPTION_SETTINGS_MANAGEMENT",0,"/settings/subscription-management","SUBSCRIPTION_STATUS_COOKIE",0,l],24768);var r=e.i(184919),d=e.i(704570),u=e.i(317166),c=e.i(227162),p=e.i(395497),g=e.i(830945);let y=["invalid-user error","invalid-signature error"],m=Object.keys(o),b=e=>{let t={};return Object.keys(o).forEach(i=>{t[i]=e}),t},h=(e=0,t)=>{let{ensureTokens:l}=(0,u.useUser)(),o=b("PENDING"),[h,f]=(0,i.useState)(o),[v,C]=(0,i.useState)("IDLE"),[S,w]=(0,i.useState)(void 0),[I,x]=(0,i.useState)(void 0),_=(0,n.useFeatureFlag)("subscription-claims-based"),{type:P,subtype:E}=(0,d.usePageData)(),O=P===r.ContentType.LongFormVideo&&(E===r.ContentSubtype.Series||E===r.ContentSubtype.Episode),T=P===r.ContentType.Audio,A=()=>{C("UNNECESSARY"),f(b("DENIED"))};return(0,i.useEffect)(()=>{let e=async()=>{await l();try{let e=c.appConfig.getValue(p.ConfigSettings.AuthProxyUrl),t=new URLSearchParams({__tac:S,ckns_registration:I});s.logger.info("LFV Auth: Making xproxy request to piano/token-auth",{hasTacCookie:!!S,hasRegCookie:!!I});let i=await fetch(`${e}/piano/token-auth`,{method:"POST",body:t});s.logger.info("LFV Auth: Received xproxy response",{status:i.status,statusText:i.statusText,ok:i.ok});let a=await i.text(),n=y.indexOf(a);if(-1!==n)throw Error(`xproxy token-auth call failed >>  ${y[n]}`);let l=JSON.parse(a),o=JSON.parse(l.sub),r=b("DENIED");if(s.logger.info("LFV Auth: Parsed subscription claims",{hasAccessList:!!o.al,hasUserId:!!o.u}),!o.al){s.logger.info("LFV Auth: No access list found - user not subscribed"),f(r),C("RESOLVED");return}let d=c.appConfig.getValue(p.ConfigSettings.PianoAid),u=o.al[d];s.logger.info("LFV Auth: Processing claims for Piano AID",{hasPianoAid:!!d}),u.forEach(e=>{m.includes(e.r)&&(r={...r,[e.r]:"ALLOWED"})}),s.logger.info("LFV Auth: Claims processing completed",{validClaims:r}),f(r),C("RESOLVED")}catch(e){s.logger.error(`LFV Auth: Xproxy fetch failed: ${e}`),f(b("ERROR")),C("ERROR")}};S&&I&&e()},[S,I]),(0,i.useEffect)(()=>{let e=!1,i=(0,a.getCookie)(g.PIANO_TAC),n=(0,a.getCookie)(g.PIANO_REG),l=!!(0,a.getCookie)(g.USER_ID);if(t)if(l)if(_||O||T)if(_?s.logger.info("[SUBSCRIPTION] Fetching claims (flag ON). Claims will determine subscription status."):s.logger.info("[SUBSCRIPTION] Fetching claims (flag OFF, LFV/Audio page). Claims for content gating only, cookies for subscription status."),i&&n)w(i),x(n),C("PENDING");else{let t=setTimeout(()=>e=!0,5e3),i=setInterval(()=>{let n=(0,a.getCookie)(g.PIANO_TAC),l=(0,a.getCookie)(g.PIANO_REG);n&&l?(w(n),x(l),C("PENDING"),clearInterval(i),clearTimeout(t)):e&&(f(b("ERROR")),C("TIMEOUT"),s.logger.error("LFV Auth: timed out waiting for piano values"),clearInterval(i))},200)}else s.logger.info("[SUBSCRIPTION] Skipping claims fetch (flag OFF, non-LFV/Audio page). Using cookies only."),C("UNNECESSARY");else A();else A()},[t,O,T,_,e]),{claims:h,subscriptionClaimsFetch:v}};e.s(["manualSubscriptionCheck",0,({isGlobalClaimsBasedEnabled:e,PianoSubscriptionResourceId:t,refetchSubscriptionClaims:i,updateSubscribedStatus:a})=>{let n=0,s=null,l=()=>{n+=1,e?i():window.tp.api.callApi("/access/check",{rid:t},function(e){e&&e.access&&e.access.granted&&(a({isSubscribed:!0}),s&&clearInterval(s))}),3===n&&s&&clearInterval(s)};return l(),s=setInterval(l,3e3),()=>{s&&clearInterval(s)}},"useUsersSubscriptionAccessClaims",0,h],394030);let f=()=>{let e={};return Object.keys(o).forEach(t=>{e[t]="PENDING"}),e},v=e=>Object.values(e).some(e=>"ALLOWED"===e),C={isSubscribed:!1,isSubscriptionAllowed:!1,claims:f(),subscriptionClaimsFetch:"IDLE",isSubscriptionCheckComplete:!1},S=(0,i.createContext)(C),w=(0,i.createContext)(()=>null),I=(0,i.createContext)(()=>null);e.s(["SubscriptionProvider",0,({value:{isSubscriptionAllowed:e},children:o})=>{let r=(0,n.useFeatureFlag)("subscription-claims-based"),[d,u]=(0,i.useState)(0),{claims:c,subscriptionClaimsFetch:p}=h(d,e);(0,i.useEffect)(()=>{m({claims:{...f(),...c},subscriptionClaimsFetch:p})},[c,p]);let[g,y]=(0,i.useState)({...C,isSubscribed:!r&&"active"===(0,a.getCookie)(l),isSubscriptionAllowed:e}),m=({isSubscribed:e,claims:t,subscriptionClaimsFetch:i})=>y(n=>{if(r){s.logger.info("[SUBSCRIPTION] Using claims-based logic (feature flag ON)");let e=t||n.claims,a=i||n.subscriptionClaimsFetch,l="RESOLVED"===a&&v(e);return s.logger.info("[SUBSCRIPTION] Claims result:",JSON.stringify({isSubscribed:l,fetchStatus:a,hasAnyClaim:v(e)})),{...n,isSubscribed:l,isSubscriptionCheckComplete:"RESOLVED"===a||"ERROR"===a||"TIMEOUT"===a||"UNNECESSARY"===a,...t&&{claims:t},...i&&{subscriptionClaimsFetch:i}}}{s.logger.info("[SUBSCRIPTION] Using cookie-based logic (feature flag OFF)");let o=i||n.subscriptionClaimsFetch;"RESOLVED"===o&&s.logger.info("[SUBSCRIPTION] Note: Claims were fetched for content gating but NOT used for subscription status"),e&&(0,a.setCookie)(l,"active",{domain:"bbc.com",maxAge:7800});let r=void 0!==e?e:n.isSubscribed;return s.logger.info("[SUBSCRIPTION] Cookie result:",JSON.stringify({isSubscribed:r,fetchStatus:o})),{...n,isSubscribed:r,isSubscriptionCheckComplete:"RESOLVED"===o||"ERROR"===o||"TIMEOUT"===o||"UNNECESSARY"===o,...t&&{claims:t},...i&&{subscriptionClaimsFetch:i}}}});return(0,t.jsx)(S.Provider,{value:g,children:(0,t.jsx)(w.Provider,{value:m,children:(0,t.jsx)(I.Provider,{value:()=>{u(e=>e+1)},children:o})})})},"useRefetchSubscriptionClaims",0,()=>(0,i.useContext)(I),"useSubscriptionContext",0,()=>(0,i.useContext)(S),"useSubscriptionUpdateContext",0,()=>(0,i.useContext)(w)],789799)},427885,e=>{"use strict";var t=e.i(480495),i=e.i(494373),a=e.i(876278),n=e.i(830945),s=e.i(508259),l=e.i(318438),o=e.i(898229);let r=(e,t)=>"landscape"!==t&&t?{holdingImage:{url:e,orientation:t}}:{holdingImageURL:e},d=e=>{let t=Math.floor(e/60),i=e-60*t;return`${t}${0!==i?`:${i<10?`0${i}`:`${i}`}`:":00"}`};function u(e){let t=e??a.INDEX_CARD_IMAGE_FALLBACK;return t.includes("1920xn")?t.replace("1920xn","$recipe"):t}let c=(e,t,i=!1,a=!1,n="landscape",s="landscape")=>{let{page:o="",destination:r=l.siteLabel.test,producer:d="BBC_STUDIOS",content_id:u,content_topic:c,device_first_party_id:p,device_first_party_id_version:g,referrer_url:y,user_first_party_id:m,user_first_party_id_version:b,user_first_party_idp:h,user_id:f,content_window_is_enabled:v,early_access_start_date:C,early_access_end_date:S}=e||{};return{counterName:o,destination:r,producer:d,sessionLabels:{counterName:o,destination:r,producer:d,av_player_orientation:"portrait"===s?"portrait":"landscape",device_first_party_id:p,device_first_party_id_version:g,referrer_url:y,user_first_party_id:m,user_first_party_id_version:b,user_first_party_idp:h,user_id:f},playlistLabels:{content_id:t?.content_id||u,content_topic:t?.content_topic||c,av_show:t?.av_show,av_content_genre:t?.av_content_genre,av_content_topic:t?.av_content_topic||t?.content_topic||c,content_type:t?.content_type,content_window_is_enabled:v?.toString(),early_access_start_date:C,early_access_end_date:S,av_content_duration_range:i?"audio":"portrait"===n||"portrait"===s?"sfv-vertical":"sfv",ad_enabled:a}}},p=(e,i,a,s,l,o,r=!0,d=!1,u=0,c=!1,p=!1,g=!1)=>{let y={livePulseColour:"#FFFFFF",...d?{skin:"audio",skipInterval:20,colour:"#FFFFFF",controls:{includeNextButton:!0,includePreviousButton:!0,includeForwardIntervalButton:!0,includeBackIntervalButton:!0,alwaysEnablePreviousButton:!0,alwaysEnableNextButton:c,popout:!1,displayJumpButtonText:!0,previousNextJustEvents:!0,speed:!1},playbackSettingsPanel:{enabled:!g,continuousPlaySetting:!0}}:{poster:{verticalBlur:!0},cta:{enabled:!1,visiblyHidden:!0},controls:{availableOnMediaEnded:!0}},...d&&!p&&{colourOnHighlightColour:"#000000",cta:{enabled:!1,visiblyHidden:!0}},...d&&p&&{foreColour:"#000000"}},m={html5Debug:!1,product:"bbcx",playlistObject:e,autoplay:o,continuousPlay:r,waitOnPluginLoad:!0,enableToucan:!d||d&&p,supportFakeFullscreen:!0,counterName:l,appName:"bbc_web",appType:"responsive",allowCasting:!0,startTime:u,statsObject:i,ui:y,plugins:{toLoad:[]},...d&&{significantTime:1}},b=(0,t.getCookie)(n.ANALYTICS_APP)?.toString();b&&(m.appName=b,m.appType="mobile-web");let h={debug:!1,...d&&{audioAdTag:s},...!d&&{adTag:s}};a&&s&&m.plugins?.toLoad.push({html:"name:dfpAds.js",data:{name:"AdsPluginParameters",data:h}});let f=e.items[e.items.length-1];return f.serviceID&&!0===f.live&&!d&&m.plugins?.toLoad.push({html:"name:smp-subs-config-plugin.js",module:!0}),m},g=async(e,t)=>{try{let i=`media-token?${t?"serviceId":"versionPid"}=${e}`,{data:a}=await (0,o.fetchClient)(i,{});return a.token}catch(t){return s.logger.error(`getJwtToken failed for: ${e} - Error: ${t}`),""}},y=async(e,t,i="landscape",a,n=!1,s=!1)=>{let[l]=e.versions,{versionId:o="",duration:d=0,warning:c="",warnings:p={}}=l??{},y=n?await g(o,s):null,m={live:s,kind:n?"audio":"programme",duration:(e=>{let t=e.split(":");if(t.length>1){let e=parseInt(t[2].split(".")[0]);return 60*parseInt(t[0])*60+60*parseInt(t[1])+e}return parseInt(e)})(d.toString())};s?m.serviceID=o:m.versionID=o,y&&(m.jwtToken=y);let b=[m];return a&&b.unshift({kind:"advert"}),{title:e.title,summary:e.synopses.medium,items:b,...r(u(e.imageUrl),i),warning:c||p?.short,liveRewind:s,simulcast:s}},m=(e,t,i,a,n)=>({clipPID:e.id,destination:t,producer:i,playlistName:"",playerPosition:"",playlistLabels:n,sessionLabels:a}),b=e=>e?e.model.blocks.find(e=>"media"===e.type).model.blocks.find(e=>"mediaMetadata"===e.type).model:null,h=async(e,t,i,a,n,s,l,o,r,d,u,g,b,h)=>{let f=await y(e,g,b,t,s,l),{sessionLabels:v,playlistLabels:C,counterName:S,destination:w,producer:I}=c(r,d,s,t,h,g);return p(f,m(e,w,s?"SOUNDS":I,v,C),t,i,S,a,n,s,0,o,u,l)},f=async(e,t,i,a,n,s,l="Y",o,d="landscape")=>{let u="Y"===l?"portrait":"landscape",c=await S(t,i,a,n,s,u,o,d);o?.[i]&&Object.assign(e.playlistObject,r(o[i],u)),c.queuedPlaylist&&C(e.playlistObject,"queuedPlaylist",c.queuedPlaylist,c.queuedOptions),c.previousPlaylist&&C(e.playlistObject,"previousPlaylist",c.previousPlaylist,c.previousOptions)},v=async(e,t,i,a,n,s)=>{let l=[];for(let e=0;e<t.length;e++){let o=b(t[e]),r=await y(o,s,s,i),{sessionLabels:d,playlistLabels:u,counterName:p,destination:g,producer:h}=c(a,n[e],!1,i,"landscape",s),f={playlist:r,statsObject:m(o,g,h,d,u),showLiveOrDuration:!0,counterName:p,autoplay:t.length>2};l.push(f)}return e.plugins?.toLoad.push({html:"name:onwardJourney.js",data:{name:"smp.plugin.continuousplay.playlistSetChanged",data:{items:l,stopAutoplayOnGuidance:!0}}}),l},C=(e,t,i,a)=>{Object.defineProperty(e,t,{value:i,enumerable:!1,configurable:!0}),a&&Object.defineProperty(e,"queuedPlaylist"===t?"queuedOptions":"previousOptions",{value:a,enumerable:!1,configurable:!0})},S=async(e,t,i,a,n,s,l,o="landscape")=>{let r=e.map(e=>b(e)),d=await Promise.all(r.map(e=>y(e,s,s,i)));if(l)for(let e=0;e<d.length;e++){let t=l[e];t&&(d[e].holdingImage={url:t,orientation:s})}let u=r.map((e,t)=>{let{sessionLabels:l,playlistLabels:r,destination:d,producer:u}=c(a,n[t],!1,i,s,o),p=r.av_content_genre,g=r.av_content_topic;return m(e,d,u,l,{...r,content_topic:r.content_topic??"",av_content_genre:Array.isArray(p)?p.join(", "):p??"",av_content_topic:Array.isArray(g)?g.join(", "):g??""})});for(let e=0;e<d.length-1;e++)C(d[e],"queuedPlaylist",d[e+1],{statsObject:u[e+1],autoplay:!0});for(let e=1;e<d.length;e++)C(d[e],"previousPlaylist",d[e-1],{statsObject:u[e-1],autoplay:!0});return d[t]};e.s(["createSMPsettingsForLiveWorldNews",0,(e,t,i,a,n)=>{let s=[{live:!0,kind:"programme",serviceID:e}];t&&s.unshift({kind:"advert"});let{sessionLabels:l,playlistLabels:o,counterName:r,destination:d,producer:u}=c(a,n);return p({title:"",summary:"",items:s,holdingImageURL:"https://ichef.bbci.co.uk/images/ic/raw/p0g6qbw7.jpg",liveRewind:!0,simulcast:!0},{clipPID:"",playlistName:"",playerPosition:"",destination:d,producer:u,sessionLabels:l,playlistLabels:o},t,i,r,!1)},"createSMPsettingsFromBlock",0,h,"findBlockIndexByVersionId",0,(e,t)=>e.findIndex(e=>{let i=b(e),[a]=i?.versions||[];return a?.versionId===t}),"getAvAnalytics",0,c,"getCtaProps",0,e=>{let t=e.items[e.items.length-1];return{duration:t.duration?d(t.duration):"",warning:e.warning||""}},"getImageUrl",0,u,"getMediaMetaDataBlockModelFromVideoBlock",0,b,"isContentAvailableInTerritory",0,(e,t)=>{let[a]=b(t).versions,{availableTerritories:n}=a??{};if(!n)return!0;let s=e===i.COUNTRY_UK,l=n.uk,o=n.nonUk;return s?l:o},"loadOnwardJourneyPlugin",0,v,"loadSwipeablePlaylist",0,f,"secondsToMMSS",0,d])},753924,399274,e=>{"use strict";var t=e.i(391398);let i=()=>(0,t.jsxs)("svg",{viewBox:"0 0 82 82",children:[(0,t.jsx)("circle",{cx:"41",cy:"41",r:"37",fill:"#fff"}),(0,t.jsx)("polygon",{fill:"#202224",points:"32,25 32,58 60,42"})]}),a=()=>(0,t.jsxs)("svg",{width:"15",height:"16",viewBox:"0 0 15 16",fill:"none",children:[(0,t.jsxs)("g",{clipPath:"url(#clip0_32424_6036)",children:[(0,t.jsx)("path",{d:"M7.5 15.2964C11.4844 15.2964 14.5312 12.2495 14.5312 8.26514C14.5312 4.28076 11.4844 1.23389 7.5 1.23389C3.51562 1.23389 0.46875 4.28076 0.46875 8.26514C0.46875 12.2495 3.51562 15.2964 7.5 15.2964Z",fill:"white"}),(0,t.jsx)("path",{d:"M7.5 15.2964C11.4844 15.2964 14.5312 12.2495 14.5312 8.26514C14.5312 4.28076 11.4844 1.23389 7.5 1.23389C3.51562 1.23389 0.46875 4.28076 0.46875 8.26514C0.46875 12.2495 3.51562 15.2964 7.5 15.2964ZM7.73438 12.2495C5.25 12.2495 3.70312 10.7495 3.70312 8.26514C3.70312 5.87451 5.34375 4.28076 7.92188 4.28076C8.85938 4.28076 9.70312 4.42139 10.4531 4.74951V6.39014C9.79688 6.10889 9.09375 5.87451 8.20312 5.87451C6.5625 5.87451 5.67188 6.71826 5.67188 8.31201C5.67188 10.2808 6.89062 11.0776 9.04688 10.6558V9.01514H7.6875V7.74951H10.6875V11.7339C9.84375 12.062 8.76562 12.2495 7.73438 12.2495Z",fill:"#FF0000"})]}),(0,t.jsx)("defs",{children:(0,t.jsx)("clipPath",{id:"clip0_32424_6036",children:(0,t.jsx)("rect",{width:"15",height:"15",fill:"white",transform:"translate(0 0.765137)"})})})]});var n=e.i(760814),s=e.i(339228),l=e.i(570549),o=e.i(222009);let r=n.default.div.withConfig({displayName:"CustomCTA.styles__CtaPlayIconStyled",componentId:"sc-be08601b-0"})`
  width: 80px !important;
  height: 80px !important;
  transition: opacity 0.3s;

  svg {
    width: auto !important;
    height: auto !important;
  }

  ${(0,s.applyStylesForBreakpoints)(n.css`
      width: 56px;
      height: 56px;
    `,"group2")}
`,d=n.default.button.withConfig({displayName:"CustomCTA.styles__CtaContainerButtonStyled",componentId:"sc-be08601b-1"})`
  ${({$zIndex:e})=>n.css`
    ${(0,o.applyZIndex)(e,!0,!0)};
  `};

  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  cursor: pointer;
  top: 0;
  bottom: 0;
  left: 0;
  right: 0;
  position: absolute;
  background-color: transparent !important;

  ${r} {
    opacity: 0.75;
  }

  &:hover {
    ${r} {
      opacity: 1;
    }
  }
`,u=n.default.div.withConfig({displayName:"CustomCTA.styles__DurationStyled",componentId:"sc-be08601b-2"})`
  ${({theme:e})=>n.css`
    padding: 8px;
    background-color: ${e.container.onDefaultBG3.value};
    display: flex;
    align-items: center;
  `}
`,c=n.default.div.withConfig({displayName:"CustomCTA.styles__WarningStyled",componentId:"sc-be08601b-3"})`
  ${({theme:e})=>n.css`
    display: grid;
    grid-template-columns: auto auto;
    padding-inline: 9px 16px;
    padding-block: 8px;
    text-align: start;
    font-weight: 700;
    background-color: ${`${e.container.onDefaultBG3.value}b3`};
    max-width: 332px;
    align-items: center;

    & svg {
      width: 15px;
      height: 15px;
      padding-right: 8px;
    }

    ${(0,s.applyStylesForBreakpoints)(n.css`
        max-width: unset;
      `,"group2")}
  `}
`,p=n.default.div.withConfig({displayName:"CustomCTA.styles__CtaInfoStyled",componentId:"sc-be08601b-4"})`
  ${({theme:e})=>n.css`
    position: absolute;
    left: 0;
    bottom: 0;
    color: ${e.nonInteractive.onInverseBG.default.value};
    display: grid;

    ${(0,l.applyTypography)(e.credit)};
  `};

  ${({$hasDuration:e})=>e&&n.css`
      grid-template-columns: min-content 1fr;
    `}

  ${({$type:e})=>"longForm"===e&&n.css`
      left: 280px;
      top: 32px;
      bottom: unset;

      ${(0,s.applyStylesForBreakpoints)(n.css`
          left: calc((100% - 750px) / 2);
          top: 16px;
        `,"group5")}

      ${(0,s.applyStylesForBreakpoints)(n.css`
          left: calc((100% - 540px) / 2);
          top: 16px;
        `,"group4")}

      ${(0,s.applyStylesForBreakpoints)(n.css`
          left: 16px;
          top: 16px;
        `,"group3")}
    `}
`;e.s(["default",0,({onClick:e,isVisible:n,duration:s,warning:l,zIndex:o="level1",ariaLabel:g="Play video",type:y=""})=>n?(0,t.jsxs)(d,{"data-testid":"player-play-button",onClick:e,$zIndex:o,"aria-label":g,tabIndex:0,children:[(0,t.jsx)(r,{"data-testid":"cta-play-icon",children:(0,t.jsx)(i,{})}),(0,t.jsxs)(p,{$hasDuration:""!==s,$type:y,children:[s&&(0,t.jsx)(u,{"data-testid":"cta-duration",children:s}),l&&(0,t.jsxs)(c,{children:[(0,t.jsx)(a,{}),(0,t.jsx)("p",{"data-testid":"cta-warning-text",children:l})]})]})]}):null],753924);var g=e.i(191788),y=e.i(147097);e.s(["useEchoCustomEvent",0,()=>{let e=(0,y.getIsClient)(),[t,i]=(0,g.useState)(e?window.analytics?.data:null),a=e=>{e?i({...window.analytics?.data}):i({})};return(0,g.useEffect)(()=>{if(!t)return window.addEventListener("echo_initialize_success",()=>a(!0)),window.addEventListener("echo_initialize_fail",()=>a(!1)),()=>{window.removeEventListener("echo_initialize_success",()=>a(!0)),window.removeEventListener("echo_initialize_fail",()=>a(!1))}},[t]),t}],399274)},771563,e=>{"use strict";var t=e.i(391398),i=e.i(191788),a=e.i(610503),n=e.i(746857),s=e.i(396866);let l=(0,i.createContext)([!1]),{Provider:o}=l;e.s(["EmbeddedMediaContext",0,l,"default",0,({children:e,value:i})=>{let[l,r]=i,{query:d}=(0,n.useAppRouter)(),u="true"===d.testBump?"testBump":"bump",c=(0,a.default)(()=>{window.embeddedMedia?l||r(!0):c()},250,{leading:!1,trailing:!0});return(0,t.jsxs)(o,{value:i,children:[(0,t.jsx)(s.default,{strategy:"beforeInteractive",source:u,onReady:c}),e]})}])},246024,978113,e=>{"use strict";var t=e.i(191788),i=e.i(21456),a=e.i(771563);e.s(["useIsEmbeddedMediaReady",0,function(){let e=(0,t.useContext)(i.CMSContext),[n=!1]=(0,t.useContext)(a.EmbeddedMediaContext);return e||n}],246024);var n=e.i(760814),s=e.i(339228),l=e.i(570549),o=e.i(222009);let r=n.default.div.withConfig({displayName:"Player.styles__LongFormPlayerStyled",componentId:"sc-6416b0a0-0"})`
  ${({$isInFakeFullscreen:e,$isPlaybackStarted:t=!1,$isPlaybackAllowed:i=!1})=>n.css`
    position: relative;
    max-width: 1248px;
    margin: 0 auto;
    margin-inline: -16px;

    ${!i&&n.css`
      pointer-events: none;
    `}

    ${!t&&n.css`
      &::after {
        content: '';
        position: absolute;
        inset: 0;
        background: linear-gradient(
          180deg,
          rgba(20, 22, 24, 0) 33.81%,
          rgba(20, 22, 24, 0.93) 82.36%,
          #141618 88.3%
        );
        pointer-events: none;
        ${(0,o.applyZIndex)("level1")}
      }
    `};

    ${e&&n.css`
      z-index: 9999;
    `};
  `}
`,d=n.default.div.withConfig({displayName:"Player.styles__PlayerStyled",componentId:"sc-6416b0a0-1"})`
  ${({$isInFakeFullscreen:e,$isAudio:t,$withNegativeMargin:i=!1})=>n.css`
    position: relative;

    ${e&&n.css`
      z-index: 9999;
    `};

    ${t?n.css`
          height: 160px;
        `:n.css`
          * {
            overflow: hidden;
          }
        `};

    ${!t&&i&&(0,s.applyStylesForBreakpoints)(n.css`
        margin-inline: -16px;
      `,"group2")}
  `}
`,u=n.default.div.withConfig({displayName:"Player.styles__VideoPlayerStyled",componentId:"sc-6416b0a0-2"})`
  ${({$isAudio:e,$zIndex:t})=>n.css`
    width: 100%;
    height: auto;

    ${t&&(0,o.applyZIndex)(t,!0,!0)};

    ${e&&n.css`
      height: 100%;
    `}

    ${!e&&n.css`
      aspect-ratio: 16/9;
    `}
  `}
`;n.default.div.withConfig({displayName:"Player.styles__AudioPlayerStyled",componentId:"sc-6416b0a0-3"})`
  width: 100%;
  height: 200px;
`,n.default.div.withConfig({displayName:"Player.styles__BackgroundVideoStyled",componentId:"sc-6416b0a0-4"})`
  width: 100vw;
  height: 100vh;
  max-width: 1000px;
`;let c=n.default.div.withConfig({displayName:"Player.styles__ContentUnavailableWrapperStyled",componentId:"sc-6416b0a0-5"})`
  ${({theme:e})=>n.css`
    background: ${e.container.onInverseBG2.value};
    justify-content: center;
    align-content: center;
    align-items: center;
    position: absolute;
    gap: 20px;
    display: grid;
    z-index: 1002;
    height: 100%;
    width: 100%;
    left: 0;
    top: 0;
  `}
`,p=n.default.div.withConfig({displayName:"Player.styles__ContentUnavailableTitleStyled",componentId:"sc-6416b0a0-6"})`
  ${({theme:e})=>n.css`
    ${(0,l.applyTypography)(e.watchContentVideoTitleSmall.bpLarge)};
    color: ${e.text.onInverseBG.default.value};
    text-align: center;
  `}
`,g=n.default.div.withConfig({displayName:"Player.styles__ContentUnavailableSubTitleStyled",componentId:"sc-6416b0a0-7"})`
  ${({theme:e})=>n.css`
    ${(0,l.applyTypography)(e.watchContentTitle.bpLarge)};
    color: ${e.text.onInverseBG.default.value};
    text-align: center;
  `}
`;e.s(["ContentUnavailableSubTitleStyled",0,g,"ContentUnavailableTitleStyled",0,p,"ContentUnavailableWrapperStyled",0,c,"LongFormPlayerStyled",0,r,"PlayerStyled",0,d,"VideoPlayerStyled",0,u],978113)},753630,e=>{"use strict";e.s(["errorSubTitle",0,"This content is not available in your location.","errorTitle",0,"There was an error","playerContainerProps",0,{$type:"mobileFullWidth",$marginBottom:["s","m","m","m","m","m"]}])},731954,518628,e=>{"use strict";var t=e.i(191788),i=e.i(608554),a=(0,e.i(344948).default)(function(e,t,a){(0,i.default)(e,t,a)}),n=e.i(399274),s=e.i(519894),l=e.i(246024),o=e.i(704570),r=e.i(317166),d=e.i(427885),u=e.i(879677),c=e.i(789799),p=e.i(508259),g=e.i(852827);e.s(["useSmp",0,({playlistLabels:e,blocks:i,mediaMetadataModel:y,activeIndex:m=0,onNextOnwardJourneyItemStartsPlaying:b,serviceId:h="",isWntvPrerollEnabled:f=!1,playerPosition:v,isAutoPlayDisabled:C,nextItemAutoPlay:S=!0,isAudio:w,isLiveRadio:I,playerDoubleVerifyDetails:x,playerInnerContainerRef:_,startTime:P=0,onTimeUpdate:E,onPlaybackStarted:O,onPlaybackPaused:T,onPlaybackEnded:A,onUserAutoplaySettingChange:F,onNextRequested:k,includeNextButton:N,uiOverrides:R,disableAds:$=!1,onExitFakeFullscreen:L,autoEnterFakeFullscreen:B=!1,holdingImageUrls:j,playerOrientation:M="landscape",holdingImageOrientation:U,onPlayerInitialized:D})=>{let[V,G]=(0,t.useState)(0),[q,W]=(0,t.useState)([]),[z,J]=(0,t.useState)(void 0),[H,K]=(0,t.useState)(!0),[Y,Z]=(0,t.useState)({duration:"",warning:""}),[X,Q]=(0,t.useState)(!0),{isInFakeFullscreen:ee,onPlayerReady:et}=(({playerInnerContainerRef:e,autoEnter:i=!1,onExit:a})=>{let[n,s]=(0,t.useState)(!1),l=(0,t.useCallback)(t=>{if(i){let t=e.current?.querySelector("smp-toucan-player");t?.requestFakeFullscreen?.()}t.bind("enterFakeFullscreen",()=>s(!0)),t.bind("exitFakeFullscreen",()=>{s(!1),a?.()})},[i,a,e]);return(0,t.useEffect)(()=>{let e=e=>e.preventDefault();return n&&window.addEventListener("touchmove",e,{passive:!1}),()=>{window.removeEventListener("touchmove",e)}},[n]),{isInFakeFullscreen:n,onPlayerReady:l}})({playerInnerContainerRef:_,autoEnter:B,onExit:L}),ei=(0,l.useIsEmbeddedMediaReady)(),{country:ea,type:en="",allowAdvertising:es}=(0,o.usePageData)(),el=!C&&["video","indexPage"].includes(en),eo=(0,n.useEchoCustomEvent)(),{isSignedIn:er}=(0,r.useUser)(),ed=(0,s.useFeatureFlag)("authentication"),eu=er&&ed&&w,ec=(0,s.useFeatureFlag)("toucan-audio"),ep=(0,s.useFeatureFlag)("audio-adverts"),{isSubscriptionAllowed:eg,claims:ey,isSubscriptionCheckComplete:em}=(0,c.useSubscriptionContext)(),{AdFreeAudio:eb}=ey;return(0,t.useEffect)(()=>{if(!eo||!em)return;let t=async()=>{let t;if(h||!ea||y||(0,d.isContentAvailableInTerritory)(ea,i[0])||(Q(!1),el=!1),w&&(el=!C),!window.dotcom)return;window.dotcom.ads||p.logger.error("dotcom-bootstrap.js has failed to load");let n=y||(0,d.getMediaMetaDataBlockModelFromVideoBlock)(i[m]),[s]=n?.versions||[],l=s?.types?.includes("Portrait")?"portrait":"landscape",o=async()=>{let e=await window?.dotcom?.ads?.enabled(),t=n?.advertising??!0;if(!e||!(t&&es))return!1;if(w){if(I)return!1;if(eg)try{let e=await new Promise((e,t)=>{"DENIED"===eb&&e(!1),"ERROR"===eb&&t(Error("AdFreeAudio - claims check error")),"ALLOWED"===eb&&e(!0)});return ep&&!e}catch(e){p.logger.error("areAdsEnabled:",e)}return ep}return!0},r=!$&&await o(),u="";if(h)u=f&&r&&window.dotcom.ads?await window.dotcom.ads.getAdTag(x,"live"):"",t=(0,d.createSMPsettingsForLiveWorldNews)(h,f&&r,u,eo,e[0]);else{let i=async(e,t)=>{let i="";return e&&window.dotcom.ads&&r&&(i=t?await window.dotcom.ads.getAudioAdTag(e?.tritonStationId||""):await window.dotcom.ads.getAdTag(x,s.duration.toString(),"portrait"===M)),i};u=await i(n,w),t=await (0,d.createSMPsettingsFromBlock)(n,r,u,el,S,w,I,N,eo,e[m],ec,M,U,l)}t.statsObject.playerPosition=v,t.startTime=P,R&&(t.ui=a({},t.ui,R));let c=i.length>1,L=!!R?.swipable?.enabled;c&&(L?await (0,d.loadSwipeablePlaylist)(t,i,m,r,eo,e,R.swipable?.direction,j,M):W(await (0,d.loadOnwardJourneyPlugin)(t,i,r,eo,e,M))),Z((0,d.getCtaProps)(t.playlistObject));let B=window.embeddedMedia.api.player(_.current,t);b&&L&&B.bind("mediaItemChanged",e=>{let t=e.mediaItem?.identifier||e.mediaItem?.vpid;if(t){let e=(0,d.findBlockIndexByVersionId)(i,t);-1!==e&&e!==V&&(G(e),b({index:e}))}}),B.bind("initialised",()=>{_.current&&(_.current.style.visibility="visible"),et(B),D?.(B)}),B.bind("playing",()=>{K(!1);let e=window.embeddedMedia.api.players();for(let t in e){let i=e[t];i===B||i.paused()||i.pause()}}),B.bind("adsPlugin",e=>{"adStarted"===e.id&&K(!1)}),B.bind("bbc.smp.plugins.ads.event.AdsPluginExternalEvent.ALL_ADS_COMPLETED",()=>{}),1===i.length&&B.bind("ended",()=>K(!0)),w&&B.bind("continuousPlayChange",({status:e})=>F?.(e)),b&&B.bind("continuousPlay.play",e=>{if(e.index&&e.index!==V){let t=!0;ea&&(t=(0,d.isContentAvailableInTerritory)(ea,i[e.index])),Q(t),t||B.pause(),G(e.index),b(e)}}),E&&B.bind("significanttimeupdate",E),eu&&B.bind("significanttimeupdate",e=>(0,g.setMediaProgress)(e,i)),O&&B.bind("playing",O),T&&B.bind("pause",T),A&&B.bind("ended",A),k&&B.bind("nextRequested",k),B.bind("previousRequested",()=>{B.currentTime(0)}),B.load(),J(B)};return ei&&t().then(),()=>{}},[ei,eo,eb]),(0,t.useEffect)(()=>{if(m!==V&&z){let e=!0;ea&&(e=(0,d.isContentAvailableInTerritory)(ea,i[m])),Q(e),z.loadPlaylist(q[m].playlist,{autoplay:e,statsObject:q[m].statsObject}),G(m),Z((0,d.getCtaProps)(q[m].playlist))}},[m]),(0,t.useEffect)(()=>{let e=(0,u.default)(window.embeddedMedia?.api.players(),{}),t=document.querySelectorAll('iframe[title="youtube-embed"]'),i=i=>{if(i.persisted){for(let t in e)e[t].pause(),K(!0);Array.from(t).forEach(e=>{e.contentWindow&&e.contentWindow.postMessage('{"event":"command","func":"stopVideo","args":""}',"*")})}};return window.addEventListener("pageshow",i),()=>window.removeEventListener("pageshow",i)}),{contentAvailableInTerritory:X,customCtaOptions:Y,isCustomCtaVisible:H,isInFakeFullscreen:ee,handleOnCustomCTAClick:()=>{z&&z.play(!0),K(!1)}}}],731954);var y=e.i(184874);e.s(["getHoldingImageOrientation",0,function(e=[]){let t=e.find(e=>"media"===e.type);if(t){let e=(0,y.getNestedValue)(t,"rawImage","width"),i=(0,y.getNestedValue)(t,"rawImage","height");if(Number.isInteger(e)&&Number.isInteger(i))return e===i?"square":e<i?"portrait":"landscape"}return"landscape"}],518628)},46230,e=>{"use strict";var t=e.i(391398),i=e.i(191788),a=e.i(184919),n=e.i(753924),s=e.i(868783),l=e.i(519894),o=e.i(704570),r=e.i(731954),d=e.i(518628),u=e.i(753630),c=e.i(978113),p=e.i(246024),g=e.i(427885),y=e.i(318438),m=e.i(760814),b=e.i(339228);let h=m.default.div.withConfig({displayName:"SpaPlayerInner.styles__SpaPlayerInnerStyled",componentId:"sc-82491dc0-0"})(({$isAudio:e=!1,$isVerticalVideoPage:t=!1,$orientation:i})=>m.css`
    width: 100%;
    height: auto;
    visibility: hidden;

    ${e&&m.css`
      height: 100%;
    `}

    ${"portrait"===i?m.css`
            aspect-ratio: 9/16;
          `:e?m.css``:m.css`
                aspect-ratio: 16/9;
              `};

    ${t&&(0,b.applyStylesForBreakpoints)(m.css`
        aspect-ratio: 9/16;
      `,"group2")}
  `),f=(0,i.forwardRef)(({isAudio:e=!1,orientation:i="landscape",testId:a},n)=>(0,t.jsx)(h,{"data-testid":a,ref:n,$isAudio:e,$isVerticalVideoPage:!1,$orientation:i})),v=(0,i.memo)(f),C=0,S=(0,s.withCMSFallback)(({playlistLabels:e,blocks:s=[],mediaMetadataModel:p,activeIndex:g=0,testId:y="",onNextOnwardJourneyItemStartsPlaying:m,serviceId:b="",isWntvPrerollEnabled:h=!1,playerPosition:f,isAutoPlayDisabled:S,nextItemAutoPlay:w,isAudio:I=!1,isLiveRadio:x=!1,onTimeUpdate:_,onPlaybackStarted:P,onPlaybackPaused:E,onPlaybackEnded:O,onUserAutoplaySettingChange:T,onNextRequested:A,startTime:F=0,includeNextButton:k=!0,playerOrientation:N="landscape",uiOverrides:R,disableAds:$=!1,disableCta:L=!1,onExitFakeFullscreen:B,autoEnterFakeFullscreen:j=!1,holdingImageUrls:M,onPlayerInitialized:U})=>{let D=s.length?(0,d.getHoldingImageOrientation)(s[0].model.blocks):"landscape",{subtype:V}=(0,o.usePageData)(),G=(0,l.useFeatureFlag)("legacy-article-rendering-logic"),q=(0,l.useFeatureFlag)("features-double-column"),W=(0,i.useRef)(null),z=(0,i.useRef)(null),J=V===a.ContentSubtype.News,H=V===a.ContentSubtype.Features&&q,[K]=(0,i.useState)(()=>`spa-player-${++C}`),[Y,Z]=(0,i.useState)({spaPlayerId:K,sizes:[{width:0,height:0}]}),{contentAvailableInTerritory:X,customCtaOptions:Q,isCustomCtaVisible:ee,handleOnCustomCTAClick:et,isInFakeFullscreen:ei}=(0,r.useSmp)({playlistLabels:e,blocks:s,mediaMetadataModel:p,activeIndex:g,testId:y,onNextOnwardJourneyItemStartsPlaying:m,serviceId:b,isWntvPrerollEnabled:h,playerPosition:f,isAutoPlayDisabled:S,nextItemAutoPlay:w,isAudio:I,isLiveRadio:x,playerDoubleVerifyDetails:Y,playerInnerContainerRef:z,startTime:F,onTimeUpdate:_,onPlaybackStarted:P,onPlaybackPaused:E,onPlaybackEnded:O,onUserAutoplaySettingChange:T,onNextRequested:A,includeNextButton:k,uiOverrides:R,disableAds:$,onExitFakeFullscreen:B,autoEnterFakeFullscreen:j,holdingImageUrls:M,playerOrientation:N,holdingImageOrientation:D,onPlayerInitialized:U});return(0,i.useEffect)(()=>{if(!W.current)return;let e=W.current.getBoundingClientRect();W.current.id=K,Z({spaPlayerId:K,sizes:[{width:Math.round(e.width),height:Math.round(e.height)}]})},[K]),(0,t.jsxs)(c.PlayerStyled,{$isInFakeFullscreen:ei,$isAudio:I,$withNegativeMargin:!G||J||H,ref:W,children:[!X&&(0,t.jsxs)(c.ContentUnavailableWrapperStyled,{children:[(0,t.jsx)(c.ContentUnavailableTitleStyled,{children:u.errorTitle}),(0,t.jsx)(c.ContentUnavailableSubTitleStyled,{children:u.errorSubTitle})]}),(0,t.jsx)(v,{isAudio:I,orientation:N,ref:z,testId:y}),!I&&!L&&(0,t.jsx)(n.default,{isVisible:ee,onClick:et,...Q})]})},({blocks:e,serviceId:a="",isAudio:s=!1})=>{let l=(0,i.useRef)(null),{handleOnCustomCtaClick:o,isCustomCtaVisible:r}=function({serviceId:e="",isAudio:t=!1,blocks:a,playerContainerRef:n}){let[s,l]=(0,i.useState)(!0),[o,r]=(0,i.useState)(),[d]=a,u=(0,p.useIsEmbeddedMediaReady)();return(0,i.useEffect)(()=>{let i=async()=>{let i={page:"",destination:y.siteLabel.test,producer:"BBC_STUDIOS"},a=e?(0,g.createSMPsettingsForLiveWorldNews)(e,!1,"",i,{}):await (0,g.createSMPsettingsFromBlock)((0,g.getMediaMetaDataBlockModelFromVideoBlock)(d),!1,"",!1,!0,t,!1,!0,i,{},!0,"landscape","landscape","landscape"),s=window.embeddedMedia.api.player(n.current,a);s.bind("playing",()=>{l(!1);let e=window.embeddedMedia.api.players();for(let t in e){let i=e[t];i===s||i.paused()||i.pause()}}),s.bind("ended",()=>l(!0)),s.load(),r(s)};u&&i()},[u,t,d,n,e]),{isCustomCtaVisible:s,handleOnCustomCtaClick:()=>{o&&o.play(!0),l(!1)}}}({serviceId:a,isAudio:s,blocks:e,playerContainerRef:l});return(0,t.jsxs)(c.PlayerStyled,{$isInFakeFullscreen:!1,$isAudio:s,children:[(0,t.jsx)(v,{ref:l,isAudio:s}),(0,t.jsx)(n.default,{isVisible:r,onClick:o})]})});e.s(["default",0,S],46230)}]);