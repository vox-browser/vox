(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,418933,e=>{"use strict";var t=e.i(391398),o=e.i(191788),n=e.i(893409),s=e.i(84541),i=e.i(324951),r=e.i(317166),a=e.i(65739),l=e.i(520087),c=e.i(480495),u=e.i(959560),d=e.i(746857),p=e.i(542383),g=e.i(57988),b=e.i(519894),f=e.i(704570),h=e.i(227162),m=e.i(395497),y=e.i(318438),x=e.i(830945),v=e.i(232489),w=e.i(24768),S=e.i(394030),C=e.i(760814),$=e.i(339228),_=e.i(570549);let k=C.default.button.withConfig({displayName:"Subscription.styles__SubscribeButtonStyled",componentId:"sc-b799d13d-0"})`
  ${({theme:e,$variant:t="default"})=>C.css`
    background-color: ${e.subscription.button.default.normal.background.value};
    color: ${e.subscription.button.default.normal.content.value};
    padding: 6px 12px;
    cursor: pointer;
    border: 2px solid ${e.subscription.button.default.normal.background.value};

    ${(0,_.applyTypography)(e.button.regular)};

    ${"video-series-page"===t&&C.css`
      width: 248px;
      display: flex;
      line-height: 28px;
      padding: 6px 36px;

      svg {
        width: 14px;
        height: 28px;
        margin-right: 8px;
      }
      ${(0,$.applyStylesForBreakpoints)(C.css`
          width: 203px;
          padding: 6px 16px;
        `,"group3")};
      ${(0,$.applyStylesForBreakpoints)(C.css`
          width: unset;
          padding: 6px 24px;
          justify-content: center;
        `,"group2")};
    `};

    &:hover,
    &:focus {
      background-color: ${e.subscription.button.hover.normal.background.value};
      border: 2px solid ${e.subscription.button.hover.normal.background.value};
      outline: 2px solid ${e.subscription.button.hover.normal.background.value};
    }

    &:focus {
      outline: none;
      position: relative;
      border: 2px solid ${e.subscription.button.default.normal.content.value};

      &::before {
        content: '';
        inset: -3.5px;
        border: 2px solid ${e.subscription.button.focused.normal.stroke.value};
        position: absolute;
      }
    }
  `};
`;var I=e.i(789799);let A=({isAuthenticated:e,variant:n,title:s="Subscribe",redirectPath:i})=>{let{data:C}=(0,u.default)("authInfo"),{signInUrl:$}=C||{},_=(0,d.useAppRouter)(),[A,j]=(0,g.useCurrentSlug)(),[B,T]=(0,o.useState)(!1),{isSubscriptionAllowed:E}=(0,I.useSubscriptionContext)(),O=(0,I.useSubscriptionUpdateContext)(),R=(0,I.useRefetchSubscriptionClaims)(),P=(0,b.useFeatureFlag)("subscription-claims-based"),N=(0,b.useFeatureFlag)("mparticle-sdk"),U=h.appConfig.getValue(m.ConfigSettings.MparticleKey),{country:F}=(0,f.usePageData)(),{ensureTokens:M}=(0,r.useUser)(),{dotcom:{hasFullSourcepointConsent:L}}=(0,p.useConsent)(),K=h.appConfig.getValue(m.ConfigSettings.PianoSubsRid);return(0,o.useEffect)(()=>{window.tp.push(["init",()=>T(!0)])},[]),(0,o.useEffect)(()=>{if("subscribe"===A&&!j&&B){let t,o=(0,c.getCookie)(w.CHECKOUT_STATE_COOKIE),n=new URLSearchParams(window.location.search),s=n.get("offerId"),i=n.get("termId"),r=n.get("_ptid");if(void 0!==o&&e)try{t=o&&JSON.parse(o)}catch{t=!1}else s&&i&&r&&(t={offerId:s,termId:i,trackingId:r});t&&window.tp.offer.startCheckout(t)}},[e,B,A,j]),(0,o.useEffect)(()=>{if("subscribe"===A&&!j&&B){let t,o=(0,c.getCookie)(w.CHECKOUT_STATE_COOKIE),n=new URLSearchParams(window.location.search),s=n.get("redirect_uri")||"",i=n.get("offerId"),r=n.get("termId"),a=n.get("_ptid"),u=s;try{t=JSON.parse(o)}catch{t=null}t?.redirectUriCookie&&(u=t.redirectUriCookie),!u&&document.referrer&&(u=new URL(document.referrer).hostname.endsWith(".bbc.com")?document.referrer:"https://www.bbc.com"),t&&e&&(0,c.deleteCookie)(w.CHECKOUT_STATE_COOKIE,{domain:"bbc.com"}),window.tp.push(["addHandler","loginRequired",()=>{if(!(0,c.hasCookie)(x.USER_ID)&&((0,c.setCookie)(w.CHECKOUT_STATE_COOKIE,`${JSON.stringify({...u&&{redirectUriCookie:u},...i&&{offerId:i},...r&&{termId:r},...a&&{trackingId:a}})}`,{domain:"bbc.com",maxAge:3600}),$)){let e="https://www.bbc.com"===origin?y.siteLabel.production:y.siteLabel.test;window.location.href=`${$}?ptrt=${window.location.href}&purpose=subscription&userOrigin=${e}`}}]),window.tp.push(["addHandler","checkoutClose",e=>{if("checkoutCompleted"===e.state&&N&&U&&"us"===F&&L&&l.default.logEvent("Subscription Completed",l.default.EventType.Transaction,{eventName:"Subscription Completed",page:window.location.toString(),referrer:document.referrer,userAgent:navigator.userAgent},{"Facebook.ActionSource":"website","Facebook.EventSourceUrl":"https://www.bbc.com"}),"checkoutCompleted"===e.state||"alreadyHasAccess"===e.state){P?R():O({isSubscribed:!0});let e=localStorage.getItem(w.SUBSCRIPTION_REDIRECT_PATH_LOCAL_STORAGE_KEY);if(e){localStorage.removeItem(w.SUBSCRIPTION_REDIRECT_PATH_LOCAL_STORAGE_KEY),_.push(e);return}u&&_.push(u)}}])}},[A,_,B,$,N,U,O,R,P,L,F,j,e]),(0,o.useEffect)(()=>{let e=!!(0,c.getCookie)(x.USER_ID);if(B&&e&&E&&"subscribe"===A){let e=new URLSearchParams(window.location.search).get("shared_account_code");if(j&&j.includes("bbc-")||e)return(0,S.manualSubscriptionCheck)({isGlobalClaimsBasedEnabled:P,PianoSubscriptionResourceId:K,refetchSubscriptionClaims:R,updateSubscribedStatus:O})}},[A,j,B,P,E,R,O]),(0,t.jsxs)(k,{$variant:n,onClick:()=>{i&&localStorage.setItem(w.SUBSCRIPTION_REDIRECT_PATH_LOCAL_STORAGE_KEY,i),_.push("/subscribe"),window.analytics.sendEvent({eventGrouping:"subscribe",eventProperties:{group_name:"account_option",item_link:(0,v.getHref)("","subscribe"),item_type:"subscription"}})},children:["video-series-page"===n&&(0,t.jsx)(a.default,{testId:"section-title-chevron",name:"playback-avkx:play"}),s]})},j=C.css`
  ${({theme:e,$actionName:t,$isInverse:o})=>C.css`
    ${"sign_in"===t||o?C.css`
          background-color: white;
          color: ${e.button.unboxed.default.normal.content.value};
        `:C.css`
          background-color: ${e.nav.level3.bgInverseBackground.value};
          color: white;
        `}
  `}
`,B=C.default.span.withConfig({displayName:"AccountButton.styles__AccountItemIconStyled",componentId:"sc-d4d75573-0"})`
  ${({$size:e})=>C.css`
    display: flex;
    align-items: center;
    justify-content: center;

    ${()=>{switch(e){case"small":return C.css`
            width: 20px;
            height: 20px;
          `;case"large":return C.css`
            width: 24px;
            height: 24px;
          `;default:return C.css``}}};

    > svg {
      max-width: 66%;
      max-height: 66%;
    }
  `};
`,T=C.css`
  ${({theme:e})=>C.css`
    background-color: ${e.nav.level3.bgInverseBackground.value};
    ${(0,_.applyTypography)(e.nav.topbar.level3.default)};
    color: ${e.text.onInverseBG.default.value};
    grid-template-columns: auto 1fr;
    justify-items: start;
    align-items: center;
    padding: 10px 13px;
    text-align: left;
    gap: 4px;
    display: grid;
    width: 130px;
    text-decoration: none;
    cursor: pointer;
    white-space: nowrap;
    ${(0,_.applyTypography)(e.button.small)};
    ${j};

    &:hover {
      background-color: ${e.button.unboxed.hovered.normal.background.value};
      color: ${e.text.onInverseBG.default.value};
    }

    &:disabled {
      background-color: white;
      color: ${e.button.unboxed.disabled.normal.content.value};
      cursor: not-allowed;
    }

    ${(0,$.applyStylesForBreakpoints)(C.css`
        ${j};
        font-weight: 500;
        padding: 10px 12px;
        width: fit-content;
      `,"group2")}
  `}
`,E=C.default.button.withConfig({displayName:"AccountButton.styles__AccountItemButtonStyled",componentId:"sc-d4d75573-1"})`
  ${T};
`;C.default.a.withConfig({displayName:"AccountButton.styles__AccountItemAnchorStyled",componentId:"sc-d4d75573-2"})`
  ${T};
`;let O=({onClick:e,icon:o,text:n,isInverse:s,analytics:i,size:r="small"})=>(0,t.jsxs)(E,{onClick:t=>{window.analytics.sendEvent(i),e?.(t)},$isInverse:s,$actionName:"your_account",children:[o&&(0,t.jsx)(B,{$size:r,children:(0,t.jsx)(a.default,{name:o})}),n]}),R=({isInverse:e,icon:o,href:s="",text:i,analytics:r,size:l="small",styledAnchor:c,tabIndex:u=0})=>(0,t.jsxs)(n.default,{href:s,styledAnchor:c,styledAnchorProps:{$isInverse:e},analytics:r,tabIndex:u,children:[o&&(0,t.jsx)(B,{$size:l,children:(0,t.jsx)(a.default,{name:o})}),i]});var P=e.i(222009);let N=C.default.button.withConfig({displayName:"AccountButtons.styles__AccountMobileToggleButtonStyled",componentId:"sc-32916240-0"})`
  ${({$isPopupOpen:e,theme:t})=>C.css`
    cursor: pointer;

    ${e&&C.css`
      position: relative;
      background-color: ${t.nav.level3.bgInverseBackground.value};
      padding: calc((30px - 17.5px) / 2);

      &::before {
        content: '';
        position: absolute;
        inset: -12px;
        background: ${t.nav.level3.bgInverseBackground.value};
      }
    `};
  `};
`,U=C.default.div.withConfig({displayName:"AccountButtons.styles__AccountPopupMobileTitleDivStyled",componentId:"sc-32916240-1"})`
  ${({theme:e})=>C.css`
    display: none;
    vertical-align: middle;
    color: ${e.text.onInverseBG.default.value};
    border-bottom: solid 1px ${e.nav.lines.value};
    margin: 0 16px;
    padding: 12px;

    ${(0,$.applyStylesForBreakpoints)(C.css`
        display: block;
        ${(0,_.applyTypography)(e.nav.drawer.level1.default)};
      `,"group2")};
  `};
`,F=C.default.li.withConfig({displayName:"AccountButtons.styles__AccountPopupListItemStyled",componentId:"sc-32916240-2"})`
  ${({theme:e})=>(0,$.applyStylesForBreakpoints)(C.css`
        margin: 0 16px;

        &:not(:last-child) {
          border-bottom: solid 1px ${e.nav.lines.value};
        }
      `,"group2")}
`,M=C.default.a.withConfig({displayName:"AccountButtons.styles__AccountPopupListItemAnchorStyled",componentId:"sc-32916240-3"})`
  ${({theme:e})=>C.css`
    ${T};

    ${(0,$.applyStylesForBreakpoints)(C.css`
        display: flex;
        column-gap: 4px;
        padding: 12px;
        color: ${e.text.onInverseBG.default.value};
        ${(0,_.applyTypography)(e.nav.drawer.level1.default)};
      `,"group2")};
  `}
`,L=C.default.div.withConfig({displayName:"AccountButtons.styles__AccountPopupMobileButtonDivStyled",componentId:"sc-32916240-4"})`
  ${({theme:e,$hasDividerLine:t})=>C.css`
    display: none;
    align-items: center;
    justify-content: center;
    padding: 12px;

    ${(0,$.applyStylesForBreakpoints)(C.css`
        display: flex;
        margin-inline: 16px;

        ${t&&C.css`
          border-top: solid 1px ${e.nav.lines.value};
        `}
      `,"group2")}
  `};
`,K=C.default.div.withConfig({displayName:"AccountButtons.styles__AccountPopupContainerStyled",componentId:"sc-32916240-5"})`
  height: max-content;
  width: 130px;
  position: absolute;
  top: 40px;
  overflow: hidden;
  ${(0,P.applyZIndex)("level4")};

  ${(0,$.applyStylesForBreakpoints)(C.css`
      width: 100%;
      right: 0;
      left: 0;
      top: 48px;
    `,"group2")}
`,H=C.keyframes`
  from {
    transform: translateX(100vw);
  }
  to {
    transform: translateX(0);
  }
`,D=C.default.div.withConfig({displayName:"AccountButtons.styles__AccountPopupStyled",componentId:"sc-32916240-6"})`
  ${({theme:e})=>C.css`
    border-top: 1px solid ${e.button.unboxed.hovered.normal.background.value};
    background-color: ${e.nav.level3.bgInverseBackground.value};
    height: max-content;
    width: 100%;
    overflow: hidden;

    ${(0,$.applyStylesForBreakpoints)(C.css`
        border-top: none;
        top: 64px;
        animation: ${H} 0.1s linear forwards;
      `,"group2")}
  `}
`,G=C.default.div.withConfig({displayName:"AccountButtons.styles__AccountButtonsWrapperStyled",componentId:"sc-32916240-7"})`
  position: relative;
`,Y=C.default.div.withConfig({displayName:"AccountButtons.styles__AccountButtonsDesktopContainerStyled",componentId:"sc-32916240-8"})`
  display: flex;
  align-items: center;
  justify-content: end;
  gap: 20px;

  ${(0,$.applyStylesForBreakpoints)(C.css`
      display: none;
    `,"group2")}
`,z=C.default.div.withConfig({displayName:"AccountButtons.styles__AccountButtonsMobileContainerStyled",componentId:"sc-32916240-9"})`
  display: none;
  align-items: center;
  justify-content: end;

  ${(0,$.applyStylesForBreakpoints)(C.css`
      display: flex;
    `,"group2")}
`,J=({actions:e,isSignedIn:o})=>{let n=e.filter(({actionName:e})=>"register"!==e);return(0,t.jsx)(K,{children:(0,t.jsxs)(D,{"data-testid":"your-account-popup",children:[o&&(0,t.jsx)(U,{children:"Your Account"}),(0,t.jsx)("ul",{children:n.map(({showInHeader:e,...o},n)=>e&&(0,t.jsx)(F,{children:(0,t.jsx)(R,{styledAnchor:M,...o})},n))}),(0,t.jsx)(V,{isSignedIn:o,actions:e})]})})},V=({isSignedIn:e,actions:i})=>{let{isSubscribed:r,isSubscriptionAllowed:a,isSubscriptionCheckComplete:l}=(0,I.useSubscriptionContext)(),[c]=i.filter(({actionName:e})=>"register"===e),u=(0,o.useMemo)(()=>{if(void 0!==c){let{href:e="",analytics:o}=c;return(0,t.jsx)("div",{"data-mobile-button":"true",children:(0,t.jsx)(n.default,{href:e,analytics:o,children:(0,t.jsx)(s.default,{isInverse:!0,size:"small",type:"general",text:"Register"})})})}return e&&r||!a||!l?null:(0,t.jsxs)("div",{"data-mobile-button":"true",children:[(0,t.jsx)(A,{isAuthenticated:e}),";"]})},[e,r,a,l,c]);return(0,t.jsx)(L,{$hasDividerLine:!!u,children:u})},W=({actions:e,isSignedIn:n,onToggleMenuClick:s,isBurgerMenuOpened:r})=>{let l=(0,o.useRef)(null),[c,u]=(0,o.useState)(!1);return(0,i.useOutsideClicker)(l,()=>u(!1)),(0,t.jsxs)(z,{ref:l,children:[(0,t.jsx)(N,{onClick:()=>u(e=>(r&&s(),!e)),$isPopupOpen:c,"data-testid":"mobile-account-toggle",children:c?(0,t.jsx)(a.default,{name:"actions:close",style:{fontSize:17.5,fill:"white",position:"relative",pointerEvents:"none"}}):n?(0,t.jsx)(a.default,{name:"account:your-account",style:{fill:"none",height:20,pointerEvents:"none"}}):(0,t.jsx)(a.default,{name:"account:account-signed-out",style:{fill:"none",height:20,pointerEvents:"none"}})}),c&&(0,t.jsx)(J,{actions:e,isSignedIn:n})]})},X=({actions:e,onToggleMenuClick:o,isBurgerMenuOpened:i})=>{let{isSubscriptionAllowed:r,isSubscriptionCheckComplete:a}=(0,I.useSubscriptionContext)();return(0,t.jsxs)(t.Fragment,{children:[(0,t.jsx)(Y,{children:(0,t.jsxs)(t.Fragment,{children:[r&&a&&(0,t.jsx)(A,{isAuthenticated:!1}),e.map(({href:e,icon:o,text:i,actionName:r,analytics:a,...l},c)=>(0,t.jsx)(n.default,{href:e,analytics:a,children:(0,t.jsx)(s.default,{icon:o,text:i,...l})},c))]})}),(0,t.jsx)(W,{actions:e,isSignedIn:!1,onToggleMenuClick:o,isBurgerMenuOpened:i})]})},q=({actions:e,onToggleMenuClick:n,isBurgerMenuOpened:s})=>{let r=(0,o.useRef)(null),[a,l]=(0,o.useState)(!1);(0,i.useOutsideClicker)(r,()=>l(!1));let{isSubscribed:c,isSubscriptionAllowed:u,isSubscriptionCheckComplete:d}=(0,I.useSubscriptionContext)();return(0,t.jsxs)(t.Fragment,{children:[(0,t.jsxs)(Y,{children:[u&&!c&&d&&(0,t.jsx)(A,{isAuthenticated:!0}),(0,t.jsxs)(G,{ref:r,children:[(0,t.jsx)(O,{actionName:"your_account",analytics:{eventGrouping:"account_option",eventProperties:{group_name:"account_option",item_name:"your_account"}},isInverse:!a,text:"Your Account",icon:"account:your-account",onClick:()=>l(e=>!e)}),a&&(0,t.jsx)(J,{actions:e,isSignedIn:!0})]})]}),(0,t.jsx)(W,{actions:e,isSignedIn:!0,onToggleMenuClick:n,isBurgerMenuOpened:s})]})};e.s(["MobilePopupMenu",0,W,"YourAccountPopup",0,J,"default",0,({actions:e,onToggleMenuClick:o,isBurgerMenuOpened:n})=>{let{isSignedIn:s}=(0,r.useUser)();return s?(0,t.jsx)(q,{actions:e,onToggleMenuClick:o,isBurgerMenuOpened:n}):(0,t.jsx)(X,{actions:e,onToggleMenuClick:o,isBurgerMenuOpened:n})}],418933)},964284,e=>{e.n(e.i(418933))}]);