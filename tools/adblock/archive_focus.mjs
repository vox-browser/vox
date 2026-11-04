// Restore recorded interaction state without changing author DOM or CSS.
export function parseArchiveFocus(encoded) {
    if (!encoded) return null;
    const state=JSON.parse(encoded);
    if (!state || typeof state.id!=='string' || !state.id || typeof state.tag!=='string'
        || !/^[A-Z][A-Z0-9-]*$/.test(state.tag) || state.focus_visible!==true)
        throw Error('Archive focus requires a uniquely identified element with visible focus');
    return {id:state.id,tag:state.tag,focus_visible:true};
}

export async function restoreArchiveFocus(page,state) {
    if (!state) return;
    const actual=await page.evaluate(`(async(state)=>{
        const matches=[...document.querySelectorAll('[id]')].filter(e=>e.id===state.id);
        if(matches.length!==1 || matches[0].tagName!==state.tag)
            throw Error('Archive focus target is missing or ambiguous');
        matches[0].focus({preventScroll:true,focusVisible:state.focus_visible});
        await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
        const active=document.activeElement;
        return {id:active?.id||'',tag:active?.tagName||'',focus_visible:active?.matches(':focus-visible')||false};
    })(${JSON.stringify(state)})`);
    if (JSON.stringify(actual)!==JSON.stringify(state))
        throw Error('Archive focus did not restore the recorded state: '+JSON.stringify(actual));
}
