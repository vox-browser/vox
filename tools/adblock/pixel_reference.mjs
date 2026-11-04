// Capture through the real full-uBO profile, after its content scripts ran.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {isExpectedSiteURL} from './navigation.mjs';

export async function waitForPixelDocument(page, expectedURL, {timeoutMs=45000,pollMs=50}={}) {
    // Page.navigate can return before the old about:blank context is replaced.
    // Poll from the client so a destroyed context cannot lose the load waiter.
    const expression=`(${isExpectedSiteURL.toString()})(${JSON.stringify(expectedURL)},location.href)
        && document.readyState==='complete' && document.fonts.status==='loaded'
        && (document.body?.innerText.length||0)>=1000`;
    const deadline=Date.now()+timeoutMs;
    do {
        try {
            if(await page.evaluate(expression)) return true;
        } catch(error) {
            if(!/Execution context was destroyed|Cannot find (?:default execution )?context|Inspected target navigated/i.test(error.message)) throw error;
        }
        if(Date.now()>=deadline) return false;
        await new Promise(resolve=>setTimeout(resolve,Math.min(pollMs,deadline-Date.now())));
    } while(Date.now()<deadline);
    return false;
}

export function referenceLaunchArguments(options) {
    const args = ['--force-color-profile=srgb', '--lang=en-US', '--hide-scrollbars'];
    if (options['proxy-server']) args.push(`--proxy-server=${options['proxy-server']}`);
    if (options['replay-spki']) {
        if (!options['proxy-server']) throw new Error('--replay-spki requires the archive proxy');
        args.push(`--ignore-certificate-errors-spki-list=${options['replay-spki']}`);
    }
    return args;
}

export async function pixelReferenceState() {
    await document.fonts.ready;
    // A complete response and natural dimensions do not establish decode
    // completion. Await visible bitmaps before the paint checkpoint; a
    // deferred decode can otherwise change pixels between fresh processes.
    const visible=[...document.images].filter(image=>{
        const r=image.getBoundingClientRect(),style=getComputedStyle(image);
        return image.complete && image.naturalWidth>0 && r.width>0 && r.height>0
            && r.x<innerWidth && r.y<innerHeight && r.x+r.width>0 && r.y+r.height>0
            && style.visibility==='visible' && style.display!=='none';
    });
    const decodeErrors=[];
    await Promise.all(visible.map(async image=>{
        try {await image.decode();}
        catch(error) {decodeErrors.push({url:image.currentSrc||image.src,
            error:error?.message||String(error)});}
    }));
    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
    return {url:location.href,title:document.title,ready:document.readyState,
        image_decode_preparation:'visible-image-decode',
        decoded_images:visible.map(image=>image.currentSrc||image.src),
        image_decode_errors:decodeErrors,
        active_element:document.activeElement ? {tag:document.activeElement.tagName,
            id:document.activeElement.id||'',focus_visible:document.activeElement.matches(':focus-visible')} : null,
        width:innerWidth,height:innerHeight,scale:devicePixelRatio,fonts:document.fonts.status,
        text:document.body?.innerText||'',
        styles:[...document.querySelectorAll('link[rel~="stylesheet"]')].map(link=>({
            url:link.href,active:!link.disabled && (!link.media||matchMedia(link.media).matches),
            loaded:Boolean(link.sheet)})),
        images:[...document.images].map(image=>{const r=image.getBoundingClientRect();
            return {url:image.currentSrc||image.src,complete:image.complete,naturalWidth:image.naturalWidth,
                x:r.x,y:r.y,width:r.width,height:r.height};}),
        rects:[...document.querySelectorAll('*')].map(element=>{
            const r=element.getBoundingClientRect();
            return {tag:element.tagName,id:element.id,classes:element.getAttribute('class'),
                x:r.x,y:r.y,width:r.width,height:r.height};})};
}

export async function capturePixelReference(page, file, navigation) {
    if (navigation?.coverage !== 'page') throw new Error('Pixel reference requires successful page coverage');
    const state = await page.evaluate(`(${pixelReferenceState.toString()})()`);
    // Retain readiness and resource failures even when no PNG can qualify as
    // a reference. A failed run must never leave a sidecar claiming stability.
    await fs.writeFile(file+'.json',JSON.stringify({...state,stable:false},null,2)+'\n');
    if (state.ready !== 'complete' || state.fonts !== 'loaded' || state.text.length < 1000
        || state.width !== 1024 || state.height !== 768 || state.scale !== 1
        || state.url !== navigation.url) throw new Error('Pixel reference is not ready at the required viewport');
    const missing = state.images.filter(i=>i.width>0 && i.height>0 && i.x<1024 && i.y<768
        && i.x+i.width>0 && i.y+i.height>0 && (!i.complete || !i.naturalWidth));
    if (missing.length) throw new Error(`Pixel reference has ${missing.length} missing visible images: `+
        missing.map(image=>image.url||'(unknown URL)').join(', '));
    const missingStyles=(state.styles||[]).filter(style=>style.active&&!style.loaded);
    if(missingStyles.length) throw new Error('Pixel reference has missing active stylesheets: '+
        missingStyles.map(style=>style.url).join(', '));
    if(state.image_decode_errors?.length) throw new Error('Pixel reference has visible image decode failures: '+
        state.image_decode_errors.map(image=>image.url+': '+image.error).join(', '));
    const capture = async()=>Buffer.from((await page.send('Page.captureScreenshot',
        {format:'png',captureBeyondViewport:false})).data,'base64');
    const first = await capture();
    await new Promise(resolve=>setTimeout(resolve,250));
    const second = await capture();
    if (!first.equals(second)) {
        const captures=[file+'.unstable-1.png',file+'.unstable-2.png'];
        await fs.writeFile(captures[0],first);
        await fs.writeFile(captures[1],second);
        await fs.writeFile(file+'.json',JSON.stringify({...state,stable:false,
            unstable_captures:captures},null,2)+'\n');
        throw new Error('Pixel reference changed between consecutive captures; frames: '+captures.join(', '));
    }
    await fs.writeFile(file,second);
    await fs.writeFile(file+'.json',JSON.stringify({...state,stable:true},null,2)+'\n');
    return {file,sha256:crypto.createHash('sha256').update(second).digest('hex'),
        width:state.width,height:state.height,scale:state.scale,stable:true,
        image_decode_preparation:state.image_decode_preparation};
}
