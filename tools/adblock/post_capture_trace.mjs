// Diagnostic snapshots belong after the measured reference and before CDP
// teardown: detaching the page client removes its emulated viewport.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const categories = ['disabled-by-default-cc.debug','disabled-by-default-devtools.timeline.layers',
    'disabled-by-default-cc.debug.picture'];

export function validatePostCaptureTrace(options) {
    if (!options['post-capture-trace-dir']) return;
    if ((!options['pixel-reference'] && !options['capture-dir']) || options['vox-log'] || options.requests)
        throw Error('--post-capture-trace-dir requires a captured page reference');
    if (options['profile-output'])
        throw Error('Post-capture diagnostics cannot save a prepared browser profile');
}

export async function capturePostReferenceTrace(page, directory, reference, {timeoutMs=10000}={}) {
    if (reference?.stable!==true || !reference.file || !reference.sha256)
        throw Error('Post-capture tracing requires a completed stable reference');
    const original = await fs.readFile(reference.file);
    if (digest(original) !== reference.sha256) throw Error('Reference changed before post-capture tracing');
    await fs.mkdir(directory, {mode:0o700}); // Never replace a previous diagnostic.
    const metadata = {scope:'Instrumented post-capture state; never a replacement pixel reference',
        reference:{file:reference.file,sha256:reference.sha256,width:reference.width,height:reference.height},
        categories,complete:false,errors:[]};
    const firstEvent = page.events.length;
    let started = false;
    try {
        metadata.layout_before = await page.send('Page.getLayoutMetrics');
        await page.send('Tracing.start', {traceConfig:{recordMode:'recordContinuously',
            includedCategories:categories},transferMode:'ReportEvents'});
        started = true;
        const result = await page.send('Page.captureScreenshot', {format:'png',captureBeyondViewport:false});
        const png = Buffer.from(result.data, 'base64');
        await fs.writeFile(path.join(directory, 'post-trace.png'), png);
        metadata.post_png_sha256 = digest(png);
        metadata.post_png_matches_reference = png.equals(original);
        metadata.layout_after = await page.send('Page.getLayoutMetrics');
    } catch (error) {
        metadata.errors.push(error?.message || String(error));
    } finally {
        if (started) {
            try {
                await page.send('Tracing.end');
                const deadline = Date.now() + timeoutMs;
                while (!page.events.slice(firstEvent).some(e=>e.method==='Tracing.tracingComplete')
                    && Date.now() < deadline)
                    await new Promise(resolve=>setTimeout(resolve,Math.min(25,deadline-Date.now())));
                metadata.complete = page.events.slice(firstEvent).some(e=>e.method==='Tracing.tracingComplete');
                if (!metadata.complete) metadata.errors.push('Post-capture trace did not complete');
            } catch (error) {
                metadata.errors.push(error?.message || String(error));
            }
        }
        const events = page.events.slice(firstEvent).filter(e=>e.method==='Tracing.dataCollected')
            .flatMap(e=>e.params.value);
        await fs.writeFile(path.join(directory, 'trace.json'), JSON.stringify(events)+'\n');
        const snapshots = events.filter(e=>e.name==='LayerTreeHostImpl:snapshot'
            && e.args?.snapshot?.device_viewport_size?.width===reference.width
            && e.args.snapshot.device_viewport_size.height===reference.height
            && Array.isArray(e.args.snapshot.active_tree?.layers));
        metadata.reference_viewport_layer_snapshots = snapshots.length;
        if (metadata.complete && !snapshots.length)
            metadata.errors.push('No layer snapshots at the reference viewport');
        if ([metadata.layout_before,metadata.layout_after].filter(Boolean).some(layout=>
            layout.cssLayoutViewport?.clientWidth!==reference.width
            || layout.cssLayoutViewport?.clientHeight!==reference.height))
            metadata.errors.push('Post-capture viewport differs from saved reference');
        await fs.writeFile(path.join(directory, 'layers.json'), JSON.stringify(snapshots,null,2)+'\n');
        try {metadata.reference_unchanged = digest(await fs.readFile(reference.file)) === reference.sha256;}
        catch (error) {metadata.reference_unchanged=false;metadata.errors.push(error?.message||String(error));}
        if (!metadata.reference_unchanged) metadata.errors.push('Reference changed during post-capture tracing');
        metadata.success = metadata.complete && metadata.errors.length===0;
        await fs.writeFile(path.join(directory, 'summary.json'), JSON.stringify(metadata,null,2)+'\n');
    }
    return metadata;
}
