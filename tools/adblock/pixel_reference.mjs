// Capture through the real full-uBO profile, after its content scripts ran.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';

export async function waitForPixelDocument(page) {
    // A navigation can return while its response body is still streaming. Start
    // the caller's settle period after load, rather than freezing partial HTML.
    return page.evaluate(`new Promise(resolve=>{
        const deadline=Date.now()+45000;
        const check=()=>{
            if(Date.now()>=deadline) {resolve(false);return;}
            if(document.readyState==='complete') document.fonts.ready.then(()=>resolve(true));
            else setTimeout(check,50);
        };
        check();
    })`);
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

export async function capturePixelReference(page, file, navigation) {
    if (navigation?.coverage !== 'page') throw new Error('Pixel reference requires successful page coverage');
    const state = await page.evaluate(`(async()=>{
        await document.fonts.ready;
        await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
        return {url:location.href,title:document.title,ready:document.readyState,
            width:innerWidth,height:innerHeight,scale:devicePixelRatio,fonts:document.fonts.status,
            text:document.body?.innerText||'',
            images:[...document.images].map(image=>{const r=image.getBoundingClientRect();
                return {url:image.currentSrc||image.src,complete:image.complete,naturalWidth:image.naturalWidth,
                    x:r.x,y:r.y,width:r.width,height:r.height};}),
            rects:[...document.querySelectorAll('*')].map(element=>{
                const r=element.getBoundingClientRect();
                return {tag:element.tagName,id:element.id,classes:element.getAttribute('class'),
                    x:r.x,y:r.y,width:r.width,height:r.height};})};
    })()`);
    if (state.ready !== 'complete' || state.fonts !== 'loaded' || state.text.length < 1000
        || state.width !== 1024 || state.height !== 768 || state.scale !== 1
        || state.url !== navigation.url) throw new Error('Pixel reference is not ready at the required viewport');
    const missing = state.images.filter(i=>i.width>0 && i.height>0 && i.x<1024 && i.y<768
        && i.x+i.width>0 && i.y+i.height>0 && (!i.complete || !i.naturalWidth));
    if (missing.length) throw new Error(`Pixel reference has ${missing.length} missing visible images`);
    const capture = async()=>Buffer.from((await page.send('Page.captureScreenshot',
        {format:'png',captureBeyondViewport:false})).data,'base64');
    const first = await capture();
    await new Promise(resolve=>setTimeout(resolve,250));
    const second = await capture();
    if (!first.equals(second)) throw new Error('Pixel reference changed between consecutive captures');
    await fs.writeFile(file,second);
    await fs.writeFile(file+'.json',JSON.stringify(state,null,2)+'\n');
    return {file,sha256:crypto.createHash('sha256').update(second).digest('hex'),
        width:state.width,height:state.height,scale:state.scale,stable:true};
}
