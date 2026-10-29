(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,692935,e=>{"use strict";var t=e.i(102705),a=e.i(740889),i=e.i(670257),l=e.i(46315);e.s(["default",0,function(e,n){return((0,l.default)(e)?t.default:i.default)(e,(0,a.default)(n,3))}])},876172,e=>{"use strict";var t=e.i(391398),a=e.i(191788),i=e.i(117191),l=e.i(868783),n=e.i(519894),r=e.i(232854),d=e.i(554692),s=e.i(521670),o=e.i(760814),c=e.i(339228),p=e.i(570549);let u=o.default.div.withConfig({displayName:"DundeeCardSkeleton.styles__DundeeSkeletonStyled",componentId:"sc-1f308e8c-0"})`
  ${({$isInverse:e,theme:t})=>o.css`
    display: grid;
    grid-template-columns: 1fr;
    row-gap: 8px;
    align-items: start;
    padding-bottom: 4px;
    border-bottom: 1px solid
      ${e?t.divider.onInverseBG.lowEmphasis.value:t.divider.lowEmphasis.value};

    ${(0,c.applyStylesForBreakpoints)(o.css`
        grid-template-columns: 132px minmax(0, 1fr);
        column-gap: 8px; /* stylelint-disable-line plugin/no-unsupported-browser-features */
        row-gap: 0;
      `,"group2")};
  `};
`,f=o.default.div.withConfig({displayName:"DundeeCardSkeleton.styles__DundeeSkeletonMediaStyled",componentId:"sc-1f308e8c-1"})`
  position: relative;
  width: 100%;
  aspect-ratio: 16 / 9;
`,m=o.default.div.withConfig({displayName:"DundeeCardSkeleton.styles__DundeeSkeletonTextStyled",componentId:"sc-1f308e8c-2"})`
  ${({$isContentRevealing:e,theme:t})=>o.css`
    visibility: ${e?"hidden":"visible"};
    display: grid;
    row-gap: 6px;
    align-content: start;

    ${(0,p.applyTypography)(t.promoHeadline.small.default.bpLarge)};

    ${(0,c.applyStylesForBreakpoints)(o.css`
        ${(0,p.applyTypography)(t.promoHeadline.small.default.bpSmall)};
      `,"group2")}
  `};
`,g=({isInverse:e=!1,isContentRevealing:a=!1})=>(0,t.jsx)(s.SkeletonCardStyled,{"aria-hidden":"true",children:(0,t.jsxs)(u,{$isInverse:e,children:[(0,t.jsx)(f,{children:(0,t.jsx)(s.SkeletonBlockStyled,{$height:"100%",$isInverse:e})}),(0,t.jsxs)(m,{$isContentRevealing:a,children:[(0,t.jsx)(s.SkeletonBlockStyled,{$height:"calc(1lh - 6px)",$width:"90%",$isInverse:e}),(0,t.jsx)(s.SkeletonBlockStyled,{$height:"calc(1lh - 6px)",$width:"70%",$isInverse:e})]})]})});var h=e.i(588299),v=e.i(508259),y=e.i(692935);let x=(0,y.default)(Array(6),()=>"0 16px"),$=(0,y.default)(Array(6),()=>"16px"),S={1:2,2:2,3:[2,3,3,3],5:[2,3,5,5]},C=[2,3,4,4];var k=e.i(879677);let A=(e,t)=>{if(!t)return(0,y.default)(Array(6),()=>"auto");{let t=e>5?3:2;return["auto","auto",Math.ceil(e/2),Math.ceil(e/2),Math.ceil(e/t),Math.ceil(e/t)]}};var b=e.i(835381),w=e.i(913777);let E=(0,o.default)(w.GridStyled).withConfig({displayName:"Nevada.styles__NevadaGridStyled",componentId:"sc-d2820c3c-0"})`
  ${({theme:e})=>o.css`
    & a > div {
      border-bottom: none;

      ${(0,c.applyStylesForBreakpoints)(o.css`
          border-bottom: 1px solid ${e.divider.lowEmphasis.value};
        `,"group2")}
    }

    & a:last-of-type > div {
      border-bottom: none;
    }
  `};
`,j=o.default.div.withConfig({displayName:"Nevada.styles__NevadaAdSlotContainerStyled",componentId:"sc-d2820c3c-1"})`
  grid-column-start: -2;
  grid-row: 1 / -1;

  ${(0,c.applyStylesForBreakpoints)(o.css`
      grid-column-start: unset;
      grid-row: unset;
    `,"group2")}
`,_=o.default.div.withConfig({displayName:"Nevada.wp.styles__AdSlotPlaceHolder",componentId:"sc-6c680025-0"})`
  background-color: #111111;
  height: 100%;
  color: #ffffff;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 0 16px;
  font-family: 'BBC Reith Serif', Helvetica, Arial, sans-serif;
  font-weight: 500;
  font-size: 18px;
`,N=(e,t)=>`${e.id??e.href??e.title??"card"}-${t}`,I=({content:e=[],testId:l="nevada",collectionAnalytics:s,adBlock:o,title:c})=>{let p=(0,r.useIsAdsServiceEnabled)(),u=(0,n.useFeatureFlag)("nevada-ad"),f=e.slice(0,12),{incrementedType:m}=o||{},w=p&&u&&!!m,_=(0,a.useMemo)(()=>({active:!1,variant:"",activateExperiment:()=>{},userContext:null,isLoading:!1,personalizedContent:[]}),[]),I=(0,b.useIsHomePageNevadaExperiment)(c),M=(0,b.useHomePageNevadaExperimentRunning)(I,!0),P=I?M:_;I&&(v.logger.info("Home page nevada experimentDetails:"),v.logger.info("active = "+P.active),v.logger.info("variant = "+P.variant)),P.active&&(f=(0,b.getNevadaExperimentCards)(e,P.personalizedContent,P.variant));let B=(0,a.useMemo)(()=>P.active?f.map((e,t)=>N(e,t)):[],[f,P.active]),[R,T]=(0,a.useState)({}),D=(0,a.useCallback)((e,t,a,i)=>{P.active&&P.userContext.trackEvent(b.MPARTICLE_HOMEPAGE_NEVADA_CLICK,{experiment:b.MPARTICLE_HOMEPAGE_NEVADA,variant:P.variant,item_position:t+1,item_name:a||"",item_link:i||""})},[P.active,P.userContext,P.variant]);(0,a.useEffect)(()=>{T(e=>{let t=B.reduce((t,a)=>(e[a]&&(t[a]=!0),t),{});return Object.keys(t).length===Object.keys(e).length?e:t})},[B]),(0,a.useEffect)(()=>{P.active&&P.activateExperiment(b.MPARTICLE_HOMEPAGE_NEVADA)},[P]);let H=(0,a.useCallback)(e=>{T(t=>t[e]?t:{...t,[e]:!0})},[]),G=0===B.length||B.every(e=>R[e]),F=({isContentRevealing:e})=>(0,t.jsx)(g,{isContentRevealing:e});return(0,t.jsxs)(E,{"data-testid":`${l}-grid-${f.length}`,$columns:((e,t)=>{if(t){let t=e>5?3:2;return[1,1,"repeat(2, 1fr) min-content","repeat(2, 1fr) min-content",`repeat(${t}, 1fr) min-content`,`repeat(${t}, 1fr) min-content`]}{let t=(0,k.default)(S[e],C);return[1,1,...Array.isArray(t)?t:(0,y.default)([,,,,],()=>t)]}})(f.length,w),$rows:A(f.length,w),$gridGap:$,$margin:x,children:[f.map((e,a)=>{let i=N(e,a);return P.active?(0,t.jsx)(h.default,{revealKey:i,hasImage:!!e.image,isRevealed:G,onReady:H,fallback:F,children:(0,t.jsx)(d.default,{itemPosition:a,...e,type:"dundee",collectionAnalytics:s,onClick:t=>D(t,a,e.title,e.href),hideMetadata:!0})},i):(0,t.jsx)(d.default,{itemPosition:a,...e,type:"dundee",collectionAnalytics:s,hideMetadata:!0},i)}),w&&(0,t.jsx)(j,{children:(0,t.jsx)(i.default,{type:m,isFullWidth:!1})})]})},M=(0,l.withCMSFallback)(I,({content:e=[],testId:a="nevada",adBlock:i,collectionId:l,...n})=>{let r=!!i,s=e.slice(0,12),o=1;return r&&(o=s.length>5?4:3),(0,t.jsxs)(E,{"data-testid":`${a}-grid-${s.length}`,$columns:((e,t)=>{if(t){let t=e>5?4:3;return[1,1,"repeat(2, 1fr)","repeat(2, 1fr)",`repeat(${t}, 1fr)`,`repeat(${t}, 1fr)`]}{let t=(0,k.default)(S[e],C);return[1,1,...Array.isArray(t)?t:(0,y.default)([,,,,],()=>t)]}})(s.length,!0),$rows:A(s.length,!0),$gridGap:$,$margin:x,children:[s.map((e,a)=>(0,t.jsx)(d.default,{...e,type:"dundee",...n,hideMetadata:!0},a)),r&&(0,t.jsx)(w.GridStyled,{$height:[1,1,1,1,1,2],$columns:[1,1,1,1,1,1],$width:[1,1,1,1,1,1],$left:[1,1,1,2,2,o],$top:[2,2,2,1,1,1],children:(0,t.jsx)(_,{className:"adslot-cms-placeholder",children:(0,t.jsx)("p",{children:"Placeholder for ad"})})})]})});e.s(["Nevada",0,I,"default",0,M],876172)},320925,e=>{e.n(e.i(876172))}]);