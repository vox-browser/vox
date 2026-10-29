(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,876278,631546,e=>{"use strict";e.i(350461);let t=RegExp("/","g"),r=RegExp("^https?://","ig"),n=new class{appPrefix;constructor(e){if("string"!=typeof e)throw Error("prefix must be string");const t=this.addSuffixIfNeeded(this.addPrefixIfNeeded(e.trim()));this.checkPrefix(t),this.appPrefix=t}prefixAsset(e){return this.appPrefix+e.trim()}addPrefixIfNeeded(e){return(this.prefixIsAlreadyPresent(e)?"":"/")+e}addSuffixIfNeeded(e){return e+(e.endsWith("/")?"":"/")}checkPrefix(e){if(this.prefixIsEmpty(e))throw Error("prefix must not be empty")}prefixIsAlreadyPresent(e){return e.startsWith("/")||this.stringMatchesRegexp(e,r)}prefixIsEmpty(e){return!!this.stringMatchesRegexp(e,r)&&0===e.replace(r,"").replace(t,"").trim().length}stringMatchesRegexp(e,t){return null!==e.match(t)}}("https://static.files.bbci.co.uk/bbcdotcom/web/20261027-121803-88dfe2b2c8-web-3.26.0-4/");e.s(["PAGE_TYPES_CONSTANTS",0,{FEATURES_ARTICLE:"FEATURES_ARTICLE",NEWS_ARTICLE:"NEWS_ARTICLE"},"publicAssetsPrefixer",0,n],631546);let o=n.prefixAsset("grey-placeholder.png");e.s(["INDEX_CARD_IMAGE_FALLBACK",0,"https://ichef.bbci.co.uk/images/ic/1024x1024/p0hq72jn.png.webp","excludedCopyrightHolders",0,["BBC","BBC Sport"],"heroImageContainerProps",0,{$type:"hero",$marginBottom:["s","m","m","m","m","m"]},"icIchefRecipeHeights",0,[90,135,180,270,360,450,576,774,1080],"icIchefRecipeWidths",0,[160,240,320,480,640,800,1024,1376,1920],"imageContainerProps",0,{$type:"mobileFullWidth",$marginBottom:["s","m","m","m","m","m"]},"newsIchefRecipoeWidths",0,[240,320,480,640,800,1024,1536],"prefixedPlaceholderImage",0,o],876278)},184874,e=>{"use strict";let t=(e,r,n="text")=>{if(e?.type===r)return e?.model?.[n]||void 0;if(e?.model?.blocks?.length)for(let o of e.model.blocks){let e=t(o,r,n);if(void 0!==e)return e}};e.s(["getNestedValue",0,t])},270340,141420,e=>{"use strict";var t=e.i(191788),r=e.i(391398);let n=(0,t.createContext)([]),{Provider:o}=n;e.s(["EagerImagesContext",0,n,"default",0,({children:e})=>{let{current:n}=(0,t.useRef)([]);return(0,r.jsx)(o,{value:n,children:e})}],141420),e.s(["useEagerImages",0,function(){let e=(0,t.useContext)(n);return{setEagerImages:t=>e.push(...t),getIsEager:t=>e.some(e=>t.includes(e))}}],270340)},946497,e=>{"use strict";e.s(["iChefFeaturesTemplate",0,"https://ichef.bbci.co.uk/images/","iChefTemplate",0,"https://ichef.bbci.co.uk/news/$recipe/"])},808824,e=>{"use strict";var t=e.i(823575),r=e.i(184874),n=e.i(946497),o=e.i(508259),a=e.i(876278);let i=(e,t,r)=>{let n="",o=e.split(`/${t}/`)[0],i=`${o}/${t}/`,s=e.split(`/${r}/`)[1],l=`/${r}/${s}`;return a.newsIchefRecipoeWidths.forEach((e,t)=>{let r=e.toString(),o=`${i}${r}${l}`,s=`${o} ${a.newsIchefRecipoeWidths[t].toString()}w,`;n=`${n}${s}`}),n=n.slice(0,-1)};e.s(["getAltTextString",0,e=>{let t=e.find(e=>"altText"===e.type);return t&&(0,r.getNestedValue)(t,"fragment")},"getCalloutImageUrlTemplate",0,e=>n.iChefFeaturesTemplate+e.model.originCode+"/raw"+e.model.locator,"getCopyrightHolderString",0,(e,t)=>!a.excludedCopyrightHolders.includes(e.model.copyrightHolder.trim())||t?e.model.copyrightHolder:void 0,"getFeaturesImageUrlTemplate",0,e=>n.iChefFeaturesTemplate+e.model.originCode+"/1920xn"+e.model.locator,"getImageUrlTemplate",0,e=>n.iChefTemplate+e.model.originCode+"/"+e.model.locator,"getIsPlaceholderSupported",0,({browser:e})=>{let{name:t,version:r=""}=e;return"Safari"!==t||parseInt(r,10)>10},"getSizesByCardType",0,(e,t,r)=>{let[n]=e.split("-");switch(n){case"edinburgh:vermont":return"(min-width: 1008px) 25vw, 33vw";case"westminster:vermont":return"(min-width: 1008px) 33vw, (min-width: 600px) 66vw, 100vw";case"edinburgh:indiana":return"(min-width: 600px) 50vw, 100vw";case"london:virginia":return"(min-width: 768px) 50vw, 100vw";case"edinburgh:virginia":return"(min-width: 768px) 33vw, 96vw";case"edinburgh:texas":return"(min-width: 1280px) 20vw, (min-width: 1008px) 25vw, (min-width: 800px) 33vw, 50vw";case"windsor:montana":case"oxford:florida":return"(min-width: 1008px) 75vw, 100vw";case"windsor:oregon":return"(min-width: 1280px) 50vw, (min-width: 1008px) 66vw, 100vw";case"edinburgh:wyoming":return"(min-width: 1008px) 25vw, (min-width: 600px) 50vw, 100vw";case"dundee":return"25vw";case"glastonbury":return"(min-width: 1008px) 20vw, (min-width: 600px) 33vw, 96vw";case"AudioSeriesPage":return"(min-width: 1280px) 20vw, (min-width: 1008px) 25vw, (min-width: 600px) 33vw, 50vw";case"bath":return"114px";case"york":return"(min-width: 600px) 132px, 118px";case"derby":return"(min-width: 1280px) 5vw, (min-width: 600px) 10vw, 20vw";case"derby:delaware":case"ipswich:iowa":case"derby:nebraska":return"(min-width: 1280px) 347px, (min-width: 1020px) calc(35.42vw - 31px), (min-width: 780px) calc(44.55vw - 36px), (min-width: 600px) calc(58.75vw - 34px), calc(88.21vw - 40px)";case"bradford":case"wells":return"(min-width: 1280px) 5vw 10vw";case"norwich":case"wakefield":case"louisiana":return"20vw";case"northampton:northcarolina":return"(min-width: 1280px) 20vw, (min-width: 600px) 33vw, (min-width: 400px) 50vw, 100vw";case"londonderry":return"5vw";case"southend:southcarolina":return"50vw";case"edinburgh:newyork":case"edinburgh:nevada":case"edinburgh:florida":return"(min-width: 1008px) 25vw, (min-width: 600px) 33vw, 100vw";case"oxford:newyork":return"(min-width: 1008px) 50vw, (min-width: 600px) 66vw, 100vw";case"london:washington":return"(min-width: 1008px) 66vw, (min-width: 768px) 75vw, 100vw";case"aberdeen:hawaii":return"(min-width: 900px) 15vw, (min-width: 800px) 20vw, 25vw";case"liverpool:alaska":return"(min-width: 1008px) 25vw, (min-width: 600px) 33vw, 50vw";case"edinburgh:pennsylvania":return"(min-width: 768px) 25vw, (min-width: 600px) 50vw, 100vw";case"birmingham:pennsylvania":return"(min-width: 1008px) 50vw, 100vw";case"article":case"kingston":return"(min-width: 1280px) 50vw, (min-width: 1008px) 66vw, 96vw";case"sheffield":return"100vw";case"birmingham:georgia":return"(min-width: 1080px) 75vw, (min-width: 600px) 96vw, 100vw";case"edinburgh:georgia":return"(min-width: 1008px) 25vw, (min-width: 600px) 33vw, 96vw";case"doncaster":return"(min-width: 1280px) 66vw, 100vw";case"worcester":case"maidstone":return"(min-width: 1280px) 300px, (min-width: 780px) calc(2.08vw + 214px), (min-width: 600px) calc(50vw - 24px), calc(100vw - 32px)";case"lancaster":return"(min-width: 1280px) 20vw, (min-width: 1080px) 25vw, (min-width: 600px) 40vw, 20vw";case"ashfordTitle":return"30vw";case"contributor":return"8vw";default:return t}},"getSrcAndSrcSet",0,(e,r=!0,n=!0)=>{let s={mainImageSource:e,srcSet:"",src:""},l=n?`${e}.webp`:e;if(l.includes("/ic/")){let e=l.includes("{recipe}")?(0,t.getAudioImageSrc)(l):l,n=`480x${r?"270":"n"}`;s.mainImageSource=e.replace("1920xn",n),s.srcSet=((e,t=!0)=>{let r="";return a.icIchefRecipeWidths.forEach((n,o)=>{let i=a.icIchefRecipeWidths[o].toString(),s=t?a.icIchefRecipeHeights[o].toString():"n",l=`${i}x${s}`,c=e.replace("1920xn",l),u=`${c} ${a.icIchefRecipeWidths[o].toString()}w,`;r=0===o?`${u}`:`${r} ${u}`}),r=r.slice(0,-1)})(e,r)}else l.includes("/news/")?(s.mainImageSource=l.replace("$recipe","480"),l.includes("cpsdevpb")?s.srcSet=i(l,"news","cpsdevpb"):l.includes("cpsprodpb")?s.srcSet=i(l,"news","cpsprodpb"):(s.mainImageSource=e.replace("$recipe","624"),s.srcSet="")):l.includes("/ace/")?(s.mainImageSource=l.replace("$recipe","480"),s.srcSet=i(l,"standard","cpsprodpb")):l.includes("data:image")?s.src=l:(s.mainImageSource=a.INDEX_CARD_IMAGE_FALLBACK,s.srcSet="",o.logger.log("Unrecognised image URL format > "+l));return s},"supportsWebP",0,({browser:e})=>{let{name:t,version:r=""}=e;return!("Safari"===t&&14>parseInt(r,10))}])},120012,e=>{"use strict";var t=e.i(760814),r=e.i(339228),n=e.i(570549);let o=t.default.img.withConfig({displayName:"Image.styles__ImageStyled",componentId:"sc-8c99a12b-0"})`
  ${({theme:e,$cardType:r,isFullHeight:n,$isInverse:o,$hasPlaceholder:a,$isPlaceholder:i})=>t.css`
    width: 100%;
    object-fit: contain;

    ${a&&t.css`
      background-color: ${e.fallback.background.value};

      ${o&&t.css`
        background-color: ${e.fallback.onInverseBackground.value};
      `};

      ${["worcester","maidstone","lancaster"].includes(r||"")&&t.css`
        background-color: ${e.container.onInverseBG.value};
      `}
    `};

    ${n&&t.css`
      height: 100%;
    `};

    ${i&&t.css`
      ${!["liverpool","newcastle"].includes(r?.split(":")[0]||"")&&t.css`
        position: absolute;
      `};

      ${"worcester"===r&&t.css`
        aspect-ratio: 2 / 3;
        object-fit: contain !important;
      `};
    `};

    ${["doncaster","lancaster","bath:kentucky","bath","alberta"].includes(r||"")&&t.css`
      object-fit: cover;
    `};

    ${("lancaster"===r||"maidstone"===r)&&t.css`
      aspect-ratio: 16 / 9;
    `};

    ${("bath:kentucky"===r||"bath"===r)&&t.css`
      aspect-ratio: 1 / 1;
    `};
  `};
`,a=t.default.div.withConfig({displayName:"Image.styles__ImageCardStyled",componentId:"sc-8c99a12b-1"})`
  ${({$isFullHeight:e,$withNegativeMargin:n=!1,$isEmphasized:o=!1})=>t.css`
    position: relative;
    line-height: 0;

    ${e&&t.css`
      height: 100%;
    `};

    ${n&&(0,r.applyStylesForBreakpoints)(t.css`
        margin-inline: -16px;
      `,"group2")};

    ${o&&n&&(0,r.applyStylesForBreakpoints)(t.css`
        margin-inline: -16px;
      `,"group4")}
  `};
`,i=t.default.span.withConfig({displayName:"Image.styles__CreditStyled",componentId:"sc-8c99a12b-2"})`
  ${({theme:e})=>t.css`
    display: block;
    color: ${e.text.onInverseBG.default.value};
    position: absolute;
    bottom: 0;
    right: 0;
    padding: 4px 8px;
    gap: 10px;
    background-color: ${e.nonInteractive.onDefaultBG.highEmpasis.value};
    ${(0,n.applyTypography)(e.credit)};
  `};
`;e.s(["CreditStyled",0,i,"ImageCardStyled",0,a,"ImageStyled",0,o])},450228,e=>{"use strict";var t=e.i(391398),r=e.i(191788),n=e.i(184919),o=e.i(868783),a=e.i(270340),i=e.i(704570),s=e.i(876278),l=e.i(808824),c=e.i(120012),u=e.i(823575);let d=(0,o.withCMSFallback)((0,r.memo)(({imageUrlTemplate:e,cardType:o="",sizes:u,isFullHeight:d=!1,isDefaultAspectRatio:p="article"!==o,alt:g="",loading:h,fetchPriority:f,webpSupport:b=!0,isInverse:w=!1,testId:v})=>{let{type:m,os:x={},browser:$={}}=(0,i.usePageData)(),{getIsEager:y}=(0,a.useEagerImages)(),S=(0,l.getIsPlaceholderSupported)({os:x,browser:$}),[E,k]=(0,r.useState)(!1),[I,C]=(0,r.useState)(S),T=(0,r.useRef)(null),R=p??m===n.ContentType.IndexPage,_=u??(0,l.getSizesByCardType)(o,"96vw",g),A=b&&(0,l.supportsWebP)({os:x,browser:$}),B=(0,l.getSrcAndSrcSet)(e,R,A),L=B.mainImageSource,P=h??(y(L)?"eager":"lazy");return(0,r.useEffect)(()=>{T?.current?.complete&&C(!1)}),(0,t.jsxs)(t.Fragment,{children:[I&&(0,t.jsx)(c.ImageStyled,{src:s.prefixedPlaceholderImage,isFullHeight:d,className:"hide-when-no-script","data-testid":v,"aria-label":"image unavailable",$isPlaceholder:!0,$cardType:o}),(0,t.jsx)(c.ImageStyled,{$cardType:o,ref:T,sizes:E?"":_,srcSet:E?"":B.srcSet,src:E?s.INDEX_CARD_IMAGE_FALLBACK:L,isFullHeight:d,loading:P,fetchpriority:f,alt:g,onError:()=>k(!0),onLoad:()=>C(!1),$hasPlaceholder:!B.srcSet||E,$isInverse:w,"data-testid":v,$isPlaceholder:L===s.INDEX_CARD_IMAGE_FALLBACK})]})}),({imageUrlTemplate:e,cardType:r="",isFullHeight:o=!1,alt:a="",isInverse:l=!1,testId:d})=>{let{type:p}=(0,i.usePageData)(),g=function(e="",t=!0){if(e.includes("/ic/")){let r=e.includes("{recipe}")?(0,u.getAudioImageSrc)(e):e,n=`480x${t?"270":"n"}`;return r.replace("1920xn",n)}return e.includes("/news/")?e.replace("$recipe","480"):e.includes("/ace/")?e.replace("$recipe","480"):s.INDEX_CARD_IMAGE_FALLBACK}(e,"article"!==r||p===n.ContentType.IndexPage);return(0,t.jsx)(c.ImageStyled,{$cardType:r,src:g,isFullHeight:o,loading:"eager",alt:a,$isInverse:l,"data-testid":d})});e.s(["default",0,d],450228)},567290,e=>{"use strict";var t=e.i(760814),r=e.i(339228),n=e.i(570549);let o={left:"row",right:"row-reverse",top:"column",bottom:"column-reverse"},a=t.default.span.withConfig({displayName:"Button.styles__ButtonIcon",componentId:"sc-c0f7f974-0"})`
  ${({$type:e,$isSelected:n,$isInPopover:o,$isInverse:a,$size:i="large"})=>t.css`
    display: flex;
    justify-content: center;
    align-items: center;

    svg,
    img {
      width: 24px;
      height: 24px;
    }

    ${"unboxed-share"===e&&t.css`
      width: 14px;
      height: 14px;
    `}

    /* For share buttons IN POPOVER on mobile web */
    ${"social-unboxed-share"===e&&t.css`
      svg,
      img {
        width: 12px;
        height: 12px;
      }

      ${o&&t.css`
        ${(0,r.applyStylesForBreakpoints)(t.css`
            svg,
            img {
              width: auto;
              height: auto;
            }
          `,"group2")};
      `}
    `}

    ${"social-follow-us"===e&&t.css`
      /* TODO check other instances */
      /* Unsetting the CSS for unboxed-share as we don't want to distort icons with different aspect-ratios and dimensions */
      svg,
      img {
        width: unset;
        height: unset;
      }

      ${(0,r.applyStylesForBreakpoints)(t.css`
          transform: scale(1.2);
        `,"group2")};
    `}


    ${"round"===e&&t.css`
      border-radius: 50%;
      box-sizing: border-box;
      border-width: 1px;
      border-style: solid;

      ${n?t.css`
            border-color: ${a?"#DCDEE0":"#202224"};
            background-color: ${a?"#DCDEE0":"#202224"};
            color: ${a?"#202224":"#ffffff"};
          `:t.css`
            border-color: ${a?"#545658":"#D2D4D6"};

            ${a&&t.css`
              color: #e6e8ea;
            `};
          `};

      ${(()=>{switch(i){case"small":return t.css`
              width: 24px;
              height: 24px;

              svg,
              img {
                width: 10px;
                height: 10px;
              }
            `;case"medium":return t.css`
              width: 32px;
              height: 32px;

              svg,
              img {
                width: 12px;
                height: 12px;
              }
            `;case"large":return t.css`
              width: 44px;
              height: 44px;

              svg,
              img {
                width: max(16px, 35%);
                height: max(16px, 35%);
              }
            `}})()};
    `}
  `}
`,i=t.default.span.withConfig({displayName:"Button.styles__ButtonText",componentId:"sc-c0f7f974-1"})`
  white-space: nowrap;
`,s=t.default.button.withConfig({displayName:"Button.styles__ButtonBase",componentId:"sc-c0f7f974-2"})`
  ${({theme:e,buttonSize:r,variant:a,iconPosition:i,isHeaderButton:s})=>t.css`
    cursor: pointer;
    font-weight: 500;
    border: 2px solid transparent;
    outline: 2px solid transparent;
    display: flex;
    flex-direction: ${o[i]};
    column-gap: ${"small"===r?"4px":"9.3px"};
    row-gap: ${"small"===r?"4px":"9.3px"};
    align-items: center;
    justify-content: center;
    box-sizing: border-box;

    /* TODO refactor this */
    ${s?t.css`
          padding: 2px 8px;
        `:a&&["social-follow-us","round"].includes(a)?t.css`
            padding: 0; /* TODO check other instances => we distort certian icons if we use constraint dimensions AND heavy paddings */
          `:t.css`
            padding: ${"small"===r?"6px 8px":"6px 12px 6px 12px"};
          `}

    ${(0,n.applyTypography)("small"===r?e.button.small:e.button.regular)};
  `}
`,l=(0,t.default)(s).withConfig({displayName:"Button.styles__GeneralButton",componentId:"sc-c0f7f974-3"})`
  ${({theme:e,isInverse:r})=>{let n=r?"inverse":"normal";return t.css`
      position: relative;
      background-color: ${e.button.general.default[n].background.value};
      color: ${e.button.general.default[n].content.value};
      border-color: ${e.button.general.default[n].background.value};
      outline-color: ${e.button.general.default[n].background.value};

      &:hover {
        background-color: ${e.button.general.hovered[n].background.value};
        border-color: ${e.button.general.hovered[n].background.value};
        outline-color: ${e.button.general.hovered[n].background.value};
      }

      &:focus {
        outline: 2px solid ${e.button.general.focussed[n].background.value};
        border: 2px solid ${e.button.general.focussed[n].background.value};
      }

      &:active {
        background-color: ${e.button.general.pressed[n].background.value};
        color: ${e.button.general.pressed[n].content.value};
        border-color: ${e.button.general.pressed[n].background.value};
        outline-color: ${e.button.general.pressed[n].background.value};
      }

      &:disabled,
      &[disabled] {
        cursor: not-allowed;
        background-color: ${e.button.general.disabled[n].background.value};
        color: ${e.button.general.disabled[n].content.value};
        outline-color: ${e.button.general.disabled[n].background.value};
        border-color: ${e.button.general.disabled[n].background.value};
      }
    `}}
`,c=(0,t.default)(s).withConfig({displayName:"Button.styles__GhostButton",componentId:"sc-c0f7f974-4"})`
  ${({theme:e,isInverse:r})=>{let n=r?"inverse":"normal";return t.css`
      background-color: transparent;
      color: ${e.button.ghost.default[n].content.value};
      border-color: ${e.button.ghost.default[n].border.value};
      outline-color: ${e.button.ghost.default[n].background.value};

      &:hover {
        background-color: ${e.button.ghost.hovered[n].background.value};
        color: ${e.button.ghost.hovered[n].content.value};
        border-color: ${e.button.ghost.hovered[n].background.value};
        outline-color: ${e.button.ghost.hovered[n].background.value};
      }

      &:focus {
        background-color: ${e.button.ghost.focussed[n].background.value};
        color: ${e.button.ghost.focussed[n].content.value};
        outline-color: ${e.button.ghost.focussed[n].background.value};
        border-color: ${e.button.ghost.focussed[n].background.value};
      }

      &:active {
        color: ${e.button.ghost.pressed[n].content.value};
        background-color: ${e.button.ghost.pressed[n].background.value};
        border-color: ${e.button.ghost.pressed[n].background.value};
      }

      &:disabled,
      &[disabled] {
        cursor: not-allowed;
        color: ${e.button.ghost.disabled[n].content.value};
        outline-color: ${e.button.ghost.disabled[n].background.value};
        border-color: transparent;
      }
    `}};
`,u=(0,t.default)(s).withConfig({displayName:"Button.styles__UnboxedButton",componentId:"sc-c0f7f974-5"})`
  ${({theme:e,isInverse:r,withoutPaddingInline:n=!1,withoutPaddingBlock:o=!1})=>{let a=r?"inverse":"normal";return t.css`
      background-color: transparent;
      color: ${e.button.unboxed.default[a].content.value};

      ${n&&t.css`
        padding-left: 0;
        padding-right: 0;
      `}

      ${o&&t.css`
        padding-top: 0;
        padding-bottom: 0;
      `}

      &:hover {
        background-color: ${e.button.unboxed.hovered[a].background.value};
        color: ${e.button.unboxed.hovered[a].content.value};
        border: 2px solid ${e.button.unboxed.hovered[a].background.value};
        outline: 2px solid ${e.button.unboxed.hovered[a].background.value};
      }

      &:focus {
        color: ${e.button.unboxed.focussed[a].content.value};
        background-color: ${e.button.unboxed.focussed[a].background.value};
        outline-color: ${e.button.unboxed.focussed[a].background.value};
        border-color: ${e.button.unboxed.focussed[a].background.value};
      }

      &:active {
        background-color: ${e.button.unboxed.pressed[a].background.value};
        color: ${e.button.unboxed.pressed[a].content.value};
        outline-color: ${e.button.unboxed.pressed[a].background.value};
        border-color: ${e.button.unboxed.pressed[a].background.value};
      }

      &:disabled,
      &[disabled] {
        cursor: not-allowed;
        background-color: transparent;
        color: ${e.button.unboxed.disabled[a].content.value};
        outline-color: transparent;
        border-color: transparent;
      }
    `}}
`,d=(0,t.default)(u).withConfig({displayName:"Button.styles__UnboxedShareButton",componentId:"sc-c0f7f974-6"})`
  ${({theme:e,isInPopover:o,isInverse:a,withoutPaddingInline:i})=>{let s=a?"inverse":"normal";return t.css`
      ${i&&t.css`
        padding-left: 0;
        padding-right: 0;
      `}

      border: none;
      outline: none;
      column-gap: 6px;
      box-sizing: border-box;
      color: ${e.button.unboxed.default[s].content.value}; /* interactive5/onInverseBG/default */
      ${(0,n.applyTypography)(e.textLink.small.regular.bpLarge)};

      &:hover {
        background-color: inherit;
        border: none;
        outline: none;
        color: ${e.button.unboxed.default[s].content.value};
        text-decoration: underline;
        ${(0,n.applyTypography)(e.textLink.small.linked.bpLarge)};
      }

      &:focus,
      &:active {
        /* TODO THIS (text-shadow) IS JUST WRONG!!!! text-shadow is not good here... */
        /* font-weight: 700 */
        text-shadow:
          0.25px 0 0.1px,
          -0.25px 0 0.1px;
        text-decoration: none;
        background-color: inherit;
        color: ${e.button.unboxed.default[s].content.value};

        ${(0,n.applyTypography)(e.textLink.small.emphasised.bpLarge)};
      }

      &:disabled {
        pointer-events: none;
        color: ${e.button.unboxed.disabled[s].content.value};
      }

      /* For shared buttons in popover */
      ${(0,r.applyStylesForBreakpoints)(t.css`
          ${o&&t.css`
            ${(0,n.applyTypography)(e.textLink.large.regular.bpLarge)};

            &:focus,
            &:active,
            &:hover {
              ${(0,n.applyTypography)(e.textLink.large.regular.bpLarge)};
            }

            &:hover {
              text-decoration: underline;
            }
          `}
        `,"group1","group2")};
    `}}
`,p=(0,t.default)(d).withConfig({displayName:"Button.styles__SocialUnboxedShareButton",componentId:"sc-c0f7f974-7"})`
  ${({theme:e})=>t.css`
    color: ${e.interactive5.onInverseBG.default.value};
    ${(0,n.applyTypography)(e.textLink.small.regular.bpLarge)};

    &:focus,
    &:hover {
      color: ${e.interactive5.onInverseBG.default.value};
      text-shadow: none;
    }

    &:active {
      ${(0,n.applyTypography)(e.textLink.small.emphasised.bpLarge)};
      text-shadow: none;
    }

    &:focus {
      outline: 1px solid ${e.interactive5.onInverseBG.pressed.value};
      outline-offset: -1px;
    }

    &:disabled {
      color: ${e.interactive5.onInverseBG.disabled.value};
    }

    span:first-of-type {
      width: 20px;
      height: 20px;
    }
  `};
`,g=(0,t.default)(s).withConfig({displayName:"Button.styles__RoundButton",componentId:"sc-c0f7f974-8"})`
  ${({isInverse:e,withoutPaddingBlock:r,withoutPaddingInline:n,isSelected:o})=>t.css`
    min-width: 90px;
    border: none;
    justify-content: flex-start;
    color: ${e?"#E6E8EA":"#202224"};

    &:disabled {
      pointer-events: none;
      cursor: not-allowed;
    }

    &:focus ${a} {
      border-width: 2px;
    }

    &:hover ${a} {
      ${o?t.css`
            background-color: ${"#8A8C8E"};
            border-color: ${"#8A8C8E"};
          `:t.css`
            background-color: ${e?"#545658":"#DCDEE0"};
          `}
    }

    ${r&&t.css`
      padding-top: 0;
      padding-bottom: 0;
    `};

    ${n&&t.css`
      padding-left: 0;
      padding-right: 0;
    `};
  `}
`;e.s(["ButtonBase",0,s,"ButtonIcon",0,a,"ButtonText",0,i,"GeneralButton",0,l,"GhostButton",0,c,"RoundButton",0,g,"SocialUnboxedShareButton",0,p,"UnboxedButton",0,u,"UnboxedShareButton",0,d])},84541,e=>{"use strict";var t=e.i(391398),r=e.i(191788),n=e.i(65739),o=e.i(450228),a=e.i(567290);let i={general:a.GeneralButton,ghost:a.GhostButton,unboxed:a.UnboxedButton,"unboxed-share":a.UnboxedShareButton,"social-follow-us":a.UnboxedShareButton,"social-unboxed-share":a.SocialUnboxedShareButton,round:a.RoundButton},s=(0,r.forwardRef)(({tabIndex:e,text:r,icon:s,img:l,alt:c="",type:u="general",size:d="large",onClick:p=()=>null,disabled:g=!1,iconPosition:h="left",iconProps:{ref:f=null,...b}={},testId:w,iconTestId:v,isInverse:m=!1,withoutPaddingInline:x=!1,withoutPaddingBlock:$=!1,isSubmit:y=!1,isHeaderButton:S=!1,onMouseEnter:E=()=>null,onMouseLeave:k=()=>null,ariaLabel:I,isSelected:C=!1,isInPopover:T=!1,...R},_)=>{let A=i[u];return r||s?(0,t.jsxs)(A,{withoutPaddingInline:x,withoutPaddingBlock:$,isInverse:m,buttonSize:d,disabled:g,type:y?"submit":"button",variant:u,onClick:p,"data-testid":w,iconPosition:h,"aria-label":I||r,isHeaderButton:S,onMouseEnter:E,onMouseLeave:k,ref:_,isInPopover:T,isSelected:C,"data-selected":C||void 0,tabIndex:e,...R,children:[(s||l)&&(0,t.jsxs)(a.ButtonIcon,{"data-testid":"button-icon-wrapper",$type:u,$isSelected:C,$isInPopover:T,$isInverse:m,$size:d,children:[l&&(0,t.jsx)(o.default,{imageUrlTemplate:l,alt:c}),s&&(0,t.jsx)(n.default,{...b,name:s,testId:v,ref:f,"aria-hidden":!0})]}),r&&(0,t.jsx)(a.ButtonText,{"data-testid":"button-text","aria-hidden":!!I,children:r})]}):null});e.s(["default",0,s],84541)},760121,(e,t,r)=>{"use strict";var n=e.r(191788),o="function"==typeof Object.is?Object.is:function(e,t){return e===t&&(0!==e||1/e==1/t)||e!=e&&t!=t},a=n.useState,i=n.useEffect,s=n.useLayoutEffect,l=n.useDebugValue;function c(e){var t=e.getSnapshot;e=e.value;try{var r=t();return!o(e,r)}catch(e){return!0}}var u="u"<typeof window||void 0===window.document||void 0===window.document.createElement?function(e,t){return t()}:function(e,t){var r=t(),n=a({inst:{value:r,getSnapshot:t}}),o=n[0].inst,u=n[1];return s(function(){o.value=r,o.getSnapshot=t,c(o)&&u({inst:o})},[e,r,t]),i(function(){return c(o)&&u({inst:o}),e(function(){c(o)&&u({inst:o})})},[e]),l(r),r};r.useSyncExternalStore=void 0!==n.useSyncExternalStore?n.useSyncExternalStore:u},890979,(e,t,r)=>{"use strict";t.exports=e.r(760121)},317166,116240,959560,e=>{"use strict";var t=e.i(191788),r=e.i(480495),n=e.i(890979);let o=()=>{},a=o(),i=Object,s=e=>e===a,l=e=>"function"==typeof e,c=(e,t)=>({...e,...t}),u=new WeakMap,d=0,p=e=>{let t,r,n=typeof e,o=e&&e.constructor,a=o==Date;if(i(e)!==e||a||o==RegExp)t=a?e.toJSON():"symbol"==n?e.toString():"string"==n?JSON.stringify(e):""+e;else{if(t=u.get(e))return t;if(t=++d+"~",u.set(e,t),o==Array){for(r=0,t="@";r<e.length;r++)t+=p(e[r])+",";u.set(e,t)}if(o==i){t="#";let n=i.keys(e).sort();for(;!s(r=n.pop());)s(e[r])||(t+=r+":"+p(e[r])+",");u.set(e,t)}}return t},g=new WeakMap,h={},f={},b="undefined",w=typeof window!=b,v=typeof document!=b,m=(e,t)=>{let r=g.get(e);return[()=>!s(t)&&e.get(t)||h,n=>{if(!s(t)){let o=e.get(t);t in f||(f[t]=o),r[5](t,c(o,n),o||h)}},r[6],()=>!s(t)&&t in f?f[t]:!s(t)&&e.get(t)||h]},x=!0,[$,y]=w&&window.addEventListener?[window.addEventListener.bind(window),window.removeEventListener.bind(window)]:[o,o],S={initFocus:e=>(v&&document.addEventListener("visibilitychange",e),$("focus",e),()=>{v&&document.removeEventListener("visibilitychange",e),y("focus",e)}),initReconnect:e=>{let t=()=>{x=!0,e()},r=()=>{x=!1};return $("online",t),$("offline",r),()=>{y("online",t),y("offline",r)}}},E=!t.default.useId,k=!w||"Deno"in window,I=e=>w&&typeof window.requestAnimationFrame!=b?window.requestAnimationFrame(e):setTimeout(e,1),C=k?t.useEffect:t.useLayoutEffect,T="u">typeof navigator&&navigator.connection,R=!k&&T&&(["slow-2g","2g"].includes(T.effectiveType)||T.saveData),_=e=>{if(l(e))try{e=e()}catch(t){e=""}let t=e;return[e="string"==typeof e?e:(Array.isArray(e)?e.length:e)?p(e):"",t]},A=0,B=()=>++A;var L={__proto__:null,ERROR_REVALIDATE_EVENT:3,FOCUS_EVENT:0,MUTATE_EVENT:2,RECONNECT_EVENT:1};async function P(...e){let[t,r,n,o]=e,i=c({populateCache:!0,throwOnError:!0},"boolean"==typeof o?{revalidate:o}:o||{}),u=i.populateCache,d=i.rollbackOnError,p=i.optimisticData,h=!1!==i.revalidate,f=i.throwOnError;if(l(r)){let e=[];for(let n of t.keys())!/^\$(inf|sub)\$/.test(n)&&r(t.get(n)._k)&&e.push(n);return Promise.all(e.map(b))}return b(r);async function b(r){let o,[i]=_(r);if(!i)return;let[c,b]=m(t,i),[w,v,x,$]=g.get(t),y=w[i],S=()=>h&&(delete x[i],delete $[i],y&&y[0])?y[0](2).then(()=>c().data):c().data;if(e.length<3)return S();let E=n,k=B();v[i]=[k,0];let I=!s(p),C=c(),T=C.data,R=C._c,A=s(R)?T:R;if(I&&b({data:p=l(p)?p(A,T):p,_c:A}),l(E))try{E=E(A)}catch(e){o=e}if(E&&l(E.then)){let e;if(E=await E.catch(e=>{o=e}),k!==v[i][0]){if(o)throw o;return E}o&&I&&(e=o,"function"==typeof d?d(e):!1!==d)&&(u=!0,b({data:E=A,_c:a}))}u&&!o&&(l(u)&&(E=u(E,A)),b({data:E,error:a,_c:a})),v[i][1]=B();let L=await S();if(b({_c:a}),o){if(f)throw o;return}return u?L:E}}let O=(e,t)=>{for(let r in e)e[r][0]&&e[r][0](t)},N=(e,t)=>{if(!g.has(e)){let r=c(S,t),n={},i=P.bind(a,e),s=o,l={},u=(e,t)=>{let r=l[e]||[];return l[e]=r,r.push(t),()=>r.splice(r.indexOf(t),1)},d=(t,r,n)=>{e.set(t,r);let o=l[t];if(o)for(let e of o)e(r,n)},p=()=>{if(!g.has(e)&&(g.set(e,[n,{},{},{},i,d,u]),!k)){let t=r.initFocus(setTimeout.bind(a,O.bind(a,n,0))),o=r.initReconnect(setTimeout.bind(a,O.bind(a,n,1)));s=()=>{t&&t(),o&&o(),g.delete(e)}}};return p(),[e,i,p,s]}return[e,g.get(e)[4]]},[D,U]=N(new Map),F=c({onLoadingSlow:o,onSuccess:o,onError:o,onErrorRetry:(e,t,r,n,o)=>{let a=r.errorRetryCount,i=o.retryCount,l=~~((Math.random()+.5)*(1<<(i<8?i:8)))*r.errorRetryInterval;(s(a)||!(i>a))&&setTimeout(n,l,o)},onDiscarded:o,revalidateOnFocus:!0,revalidateOnReconnect:!0,revalidateIfStale:!0,shouldRetryOnError:!0,errorRetryInterval:R?1e4:5e3,focusThrottleInterval:5e3,dedupingInterval:2e3,loadingTimeout:R?5e3:3e3,compare:(e,t)=>p(e)==p(t),isPaused:()=>!1,cache:D,mutate:U,fallback:{}},{isOnline:()=>x,isVisible:()=>{let e=v&&document.visibilityState;return s(e)||"hidden"!==e}}),V=(e,t)=>{let r=c(e,t);if(t){let{use:n,fallback:o}=e,{use:a,fallback:i}=t;n&&a&&(r.use=n.concat(a)),o&&i&&(r.fallback=c(o,i))}return r},j=(0,t.createContext)({}),M=e=>{let{value:r}=e,n=(0,t.useContext)(j),o=l(r),i=(0,t.useMemo)(()=>o?r(n):r,[o,n,r]),s=(0,t.useMemo)(()=>o?i:V(n,i),[o,n,i]),u=i&&i.provider,d=(0,t.useRef)(a);u&&!d.current&&(d.current=N(u(s.cache||D),i));let p=d.current;return p&&(s.cache=p[0],s.mutate=p[1]),C(()=>{if(p)return p[2]&&p[2](),p[3]},[]),(0,t.createElement)(j.Provider,c(e,{value:s}))},G=w&&window.__SWR_DEVTOOLS_USE__,W=G?window.__SWR_DEVTOOLS_USE__:[],H=e=>l(e[1])?[e[0],e[1],e[2]||{}]:[e[0],null,(null===e[1]?e[2]:e[1])||{}],z=()=>c(F,(0,t.useContext)(j)),K=W.concat(e=>(t,r,n)=>{let o=r&&((...e)=>{let[n]=_(t),[,,,o]=g.get(D),a=o[n];return s(a)?r(...e):(delete o[n],a)});return e(t,o,n)}),J=e=>function(...t){let r=z(),[n,o,a]=H(t),i=V(r,a),s=e,{use:l}=i,c=(l||[]).concat(K);for(let e=c.length;e--;)s=c[e](s);return s(n,o||i.fetcher||null,i)},q=(e,t,r)=>{let n=t[e]||(t[e]=[]);return n.push(r),()=>{let e=n.indexOf(r);e>=0&&(n[e]=n[n.length-1],n.pop())}};G&&(window.__SWR_DEVTOOLS_REACT__=t.default),e.s(["IS_REACT_LEGACY",0,E,"IS_SERVER",0,k,"OBJECT",0,i,"SWRConfig",0,M,"SWRGlobalState",0,g,"UNDEFINED",0,a,"createCacheHelper",0,m,"defaultConfig",0,F,"getTimestamp",0,B,"internalMutate",0,P,"isFunction",0,l,"isUndefined",0,s,"mergeObjects",0,c,"rAF",0,I,"revalidateEvents",0,L,"serialize",0,_,"subscribeCallback",0,q,"useIsomorphicLayoutEffect",0,C,"useSWRConfig",0,z,"withArgs",0,J,"withMiddleware",0,(e,t)=>(...r)=>{let[n,o,a]=H(r),i=(a.use||[]).concat(t);return e(n,o,{...a,use:i})}],116240);let X=t.default.use||(e=>{if("pending"===e.status)throw e;if("fulfilled"===e.status)return e.value;if("rejected"===e.status)throw e.reason;throw e.status="pending",e.then(t=>{e.status="fulfilled",e.value=t},t=>{e.status="rejected",e.reason=t}),e}),Y={dedupe:!0},Q=i.defineProperty(M,"defaultValue",{value:F}),Z=J((e,r,o)=>{let{cache:i,compare:u,suspense:d,fallbackData:p,revalidateOnMount:h,revalidateIfStale:f,refreshInterval:b,refreshWhenHidden:w,refreshWhenOffline:v,keepPreviousData:x}=o,[$,y,S,T]=g.get(i),[R,A]=_(e),O=(0,t.useRef)(!1),N=(0,t.useRef)(!1),D=(0,t.useRef)(R),U=(0,t.useRef)(r),F=(0,t.useRef)(o),V=()=>F.current.isVisible()&&F.current.isOnline(),[j,M,G,W]=m(i,R),H=(0,t.useRef)({}).current,z=s(p)?o.fallback[R]:p,K=(e,t)=>{for(let r in H)if("data"===r){if(!u(e[r],t[r])&&(!s(e[r])||!u(ea,t[r])))return!1}else if(t[r]!==e[r])return!1;return!0},J=(0,t.useMemo)(()=>{let e=!!R&&!!r&&(s(h)?!F.current.isPaused()&&!d&&(!!s(f)||f):h),t=t=>{let r=c(t);return(delete r._k,e)?{isValidating:!0,isLoading:!0,...r}:r},n=j(),o=W(),a=t(n),i=n===o?a:t(o),l=a;return[()=>{let e=t(j());return K(e,l)?(l.data=e.data,l.isLoading=e.isLoading,l.isValidating=e.isValidating,l.error=e.error,l):(l=e,e)},()=>i]},[i,R]),Q=(0,n.useSyncExternalStore)((0,t.useCallback)(e=>G(R,(t,r)=>{K(r,t)||e()}),[i,R]),J[0],J[1]),Z=!O.current,ee=$[R]&&$[R].length>0,et=Q.data,er=s(et)?z:et,en=Q.error,eo=(0,t.useRef)(er),ea=x?s(et)?eo.current:et:er,ei=(!ee||!!s(en))&&(Z&&!s(h)?h:!F.current.isPaused()&&(d?!s(er)&&f:s(er)||f)),es=!!(R&&r&&Z&&ei),el=s(Q.isValidating)?es:Q.isValidating,ec=s(Q.isLoading)?es:Q.isLoading,eu=(0,t.useCallback)(async e=>{let t,r,n=U.current;if(!R||!n||N.current||F.current.isPaused())return!1;let i=!0,c=e||{},d=!S[R]||!c.dedupe,p=()=>E?!N.current&&R===D.current&&O.current:R===D.current,g={isValidating:!1,isLoading:!1},h=()=>{M(g)},f=()=>{let e=S[R];e&&e[1]===r&&delete S[R]},b={isValidating:!0};s(j().data)&&(b.isLoading=!0);try{if(d&&(M(b),o.loadingTimeout&&s(j().data)&&setTimeout(()=>{i&&p()&&F.current.onLoadingSlow(R,o)},o.loadingTimeout),S[R]=[n(A),B()]),[t,r]=S[R],t=await t,d&&setTimeout(f,o.dedupingInterval),!S[R]||S[R][1]!==r)return d&&p()&&F.current.onDiscarded(R),!1;g.error=a;let e=y[R];if(!s(e)&&(r<=e[0]||r<=e[1]||0===e[1]))return h(),d&&p()&&F.current.onDiscarded(R),!1;let l=j().data;g.data=u(l,t)?l:t,d&&p()&&F.current.onSuccess(t,R,o)}catch(r){f();let e=F.current,{shouldRetryOnError:t}=e;!e.isPaused()&&(g.error=r,d&&p()&&(e.onError(r,R,e),(!0===t||l(t)&&t(r))&&V()&&e.onErrorRetry(r,R,e,e=>{let t=$[R];t&&t[0]&&t[0](L.ERROR_REVALIDATE_EVENT,e)},{retryCount:(c.retryCount||0)+1,dedupe:!0})))}return i=!1,h(),!0},[R,i]),ed=(0,t.useCallback)((...e)=>P(i,D.current,...e),[]);if(C(()=>{U.current=r,F.current=o,s(et)||(eo.current=et)}),C(()=>{if(!R)return;let e=eu.bind(a,Y),t=0,r=q(R,$,(r,n={})=>{if(r==L.FOCUS_EVENT){let r=Date.now();F.current.revalidateOnFocus&&r>t&&V()&&(t=r+F.current.focusThrottleInterval,e())}else if(r==L.RECONNECT_EVENT)F.current.revalidateOnReconnect&&V()&&e();else if(r==L.MUTATE_EVENT)return eu();else if(r==L.ERROR_REVALIDATE_EVENT)return eu(n)});return N.current=!1,D.current=R,O.current=!0,M({_k:A}),ei&&(s(er)||k?e():I(e)),()=>{N.current=!0,r()}},[R]),C(()=>{let e;function t(){let t=l(b)?b(j().data):b;t&&-1!==e&&(e=setTimeout(r,t))}function r(){!j().error&&(w||F.current.isVisible())&&(v||F.current.isOnline())?eu(Y).then(t):t()}return t(),()=>{e&&(clearTimeout(e),e=-1)}},[b,w,v,R]),(0,t.useDebugValue)(ea),d&&s(er)&&R){if(!E&&k)throw Error("Fallback data is required when using suspense in SSR.");U.current=r,F.current=o,N.current=!1;let e=T[R];if(s(e)||X(ed(e)),s(en)){let e=eu(Y);s(ea)||(e.status="fulfilled",e.value=!0),X(e)}else throw en}return{mutate:ed,get data(){return H.data=!0,ea},get error(){return H.error=!0,en},get isValidating(){return H.isValidating=!0,el},get isLoading(){return H.isLoading=!0,ec}}});e.s(["SWRConfig",0,Q,"default",0,Z],959560);var ee=e.i(508259),et=e.i(830945);let er=(0,e.i(610503).default)(async e=>{let t=await fetch(e,{credentials:"include",headers:{"Content-Type":"application/json"}});if(!t.ok)throw Error(`fetch failed with status code ${t.status}`);return t},1e3,{leading:!0,trailing:!1});e.s(["useUser",0,function(){let{data:e,mutate:n}=Z("authInfo",null,{revalidateOnReconnect:!1,revalidateOnFocus:!1,revalidateIfStale:!0}),o=async()=>{let t=(0,r.getCookie)(et.USER_ID);if(!e||!t)return!1;if(e.isMissingAccessToken)"GREEN"===e.idAvailability&&"off"===e.accountMaintenanceMode&&(await er(e.accessTokenRefreshUrl),await n({...e,isMissingAccessToken:!1}));else{let{"tkn-exp":r}=JSON.parse(window.atob(t)),n=new Date(r-6e5);if(Date.now()<n.getTime())return!0;ee.logger.warn("Access token expired, refreshing"),"GREEN"===e.idAvailability&&"off"===e.accountMaintenanceMode&&await er(e.accessTokenRefreshUrl)}return!0};return(0,t.useEffect)(()=>{let t=(0,r.hasCookie)(et.USER_ID);e&&n({...e,isSignedIn:t})},[e,n]),{...e,ensureTokens:o}}],317166)},898229,732299,258069,e=>{"use strict";e.i(350461);var t=e.i(227162),r=e.i(395497),n=e.i(508259);class o extends Error{statusCode;constructor(e,t){super(e),this.statusCode=t}}e.s(["HTTPError",0,o],732299);let a=/^https?:\/\//i;async function i(e,i){let{isLegacyApiEnabled:s,params:l,paramsHaveIdenticalKeys:c,cache:u="default",correlationId:d,headers:p,revalidationTime:g,...h}=i,f=s&&t.appConfig.getValue(r.ConfigSettings.ApiUrlLegacy)||t.appConfig.getValue(r.ConfigSettings.ApiUrl),b=a.test(e),w=new URL(e,b?void 0:f),v=new Headers(p),m=parseInt(t.appConfig.getValue(r.ConfigSettings.ApiRevalidationTime)||`${g}`||"20"),x=c?[...new URLSearchParams(w.search),...new URLSearchParams(l)]:{...Object.fromEntries(new URLSearchParams(w.search)),...Object.fromEntries(new URLSearchParams(l))};w.search=new URLSearchParams(x).toString();let $={cache:u,next:{revalidate:m},headers:v,...h};n.logger.info(`HTTP request log: ${JSON.stringify({url:w,init:$})}`);let y=await fetch(w,$),S=await y.json();if(y.status>=400)throw new o(y.statusText,y.status);return{data:S,httpStatus:y.status,headers:y.headers}}e.s(["buildFetchInit",0,function(e,t){let r=new URLSearchParams(t),n=new URLSearchParams(e.params);return{...e,params:new URLSearchParams({...Object.fromEntries(n),...Object.fromEntries(r)})}},"default",0,i],258069),e.s(["fetchClient",0,i],898229)}]);