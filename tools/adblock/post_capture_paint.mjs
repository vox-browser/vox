// Paint logs are collected after the saved reference, never as a replacement.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');

export function validatePostCapturePaint(options) {
    if (!options['post-capture-paint-dir']) return;
    if ((!options['pixel-reference'] && !options['capture-dir']) || options['vox-log'] || options.requests)
        throw Error('--post-capture-paint-dir requires a captured page reference');
    if (options['profile-output']) throw Error('Post-capture paint diagnostics cannot export a prepared profile');
}

export async function capturePostReferencePaint(page,directory,reference) {
    if (reference?.stable!==true || !reference.file || !reference.sha256)
        throw Error('Paint diagnostics require a completed stable reference');
    const original=await fs.readFile(reference.file);
    if (digest(original)!==reference.sha256) throw Error('Reference changed before paint diagnostics');
    await fs.mkdir(directory,{mode:0o700});
    const metadata={scope:'Instrumented post-capture paint commands; never a replacement pixel reference',
        reference:{file:reference.file,sha256:reference.sha256,width:reference.width,height:reference.height},
        command_log_limits:'CDP omits opaque shader and text-blob contents; resource/content audits remain separate',
        complete:false,errors:[]};
    const records=[];
    const firstEvent=page.events.length;
    let enabled=false;
    try {
        metadata.layout_before=await page.send('Page.getLayoutMetrics');
        await page.send('LayerTree.enable');
        enabled=true;
        const frame=await page.send('Runtime.evaluate',{
            expression:'new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))',
            awaitPromise:true,returnByValue:true});
        if (frame.exceptionDetails) throw Error('Paint diagnostic frame checkpoint failed');
        const result=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
        const png=Buffer.from(result.data,'base64');
        await fs.writeFile(path.join(directory,'post-paint.png'),png);
        metadata.post_png_sha256=digest(png);
        metadata.post_png_matches_reference=png.equals(original);
        const change=page.events.slice(firstEvent).findLast(event=>event.method==='LayerTree.layerTreeDidChange');
        const layers=change?.params?.layers?.filter(layer=>layer.drawsContent && layer.width>0 && layer.height>0);
        if (!layers?.length) throw Error('No painted content layers at the diagnostic checkpoint');
        for (const layer of layers) {
            const row={layer};
            records.push(row);
            let snapshot;
            try {
                snapshot=(await page.send('LayerTree.makeSnapshot',{layerId:layer.layerId})).snapshotId;
                if (!snapshot) throw Error('Layer snapshot has no identity');
                const log=await page.send('LayerTree.snapshotCommandLog',{snapshotId:snapshot});
                if (!Array.isArray(log.commandLog)) throw Error('Layer snapshot has no command log');
                row.commands=log.commandLog;
                row.commands_sha256=digest(JSON.stringify(row.commands));
            } catch (error) {
                row.error=error?.message||String(error);
                metadata.errors.push(row.error);
            } finally {
                if (snapshot) {
                    try {await page.send('LayerTree.releaseSnapshot',{snapshotId:snapshot});}
                    catch (error) {metadata.errors.push(error?.message||String(error));}
                }
            }
        }
        metadata.layout_after=await page.send('Page.getLayoutMetrics');
        metadata.complete=records.every(row=>Array.isArray(row.commands));
    } catch (error) {
        metadata.errors.push(error?.message||String(error));
    } finally {
        if (enabled) {
            try {await page.send('LayerTree.disable');}
            catch (error) {metadata.errors.push(error?.message||String(error));}
        }
        if ([metadata.layout_before,metadata.layout_after].filter(Boolean).some(layout=>
            layout.cssLayoutViewport?.clientWidth!==reference.width || layout.cssLayoutViewport?.clientHeight!==reference.height))
            metadata.errors.push('Paint diagnostic viewport differs from saved reference');
        await fs.writeFile(path.join(directory,'paint-records.json'),JSON.stringify(records,null,2)+'\n');
        try {metadata.reference_unchanged=digest(await fs.readFile(reference.file))===reference.sha256;}
        catch (error) {metadata.reference_unchanged=false;metadata.errors.push(error?.message||String(error));}
        if (!metadata.reference_unchanged) metadata.errors.push('Reference changed during paint diagnostics');
        metadata.painted_layers=records.length;
        metadata.success=metadata.complete && metadata.errors.length===0;
        await fs.writeFile(path.join(directory,'summary.json'),JSON.stringify(metadata,null,2)+'\n');
    }
    return metadata;
}
