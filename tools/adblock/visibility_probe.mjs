export function validateVisibilityProbe(probe) {
    if (!probe || !Array.isArray(probe.candidates) || !probe.candidates.length
        || !Array.isArray(probe.controls) || !probe.controls.length) {
        throw new Error('Visibility probe requires candidate and content-control IDs');
    }
    const ids = [...probe.candidates, ...probe.controls];
    if (ids.some(id => typeof id !== 'string' || !id) || new Set(ids).size !== ids.length) {
        throw new Error('Visibility probe IDs must be nonempty and unique');
    }
    if (probe.expected?.blocked !== probe.candidates.length || probe.expected?.visible !== 0
        || probe.expected?.controls_visible !== probe.controls.length) {
        throw new Error('Visibility probe must require all candidates blocked and all controls visible');
    }
    return ids;
}

// This function is also evaluated inside the inspected browser. Keep it
// self-contained: missing elements count only after their original fixture IDs
// have been verified before the filter observers run.
export function collectVisibility(probe) {
    const inspect = id => {
        const node = document.getElementById(id);
        if (!node) return { id, state: 'removed' };
        for (let ancestor = node; ancestor; ancestor = ancestor.parentElement) {
            const style = getComputedStyle(ancestor);
            if (style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse') {
                return { id, state: 'hidden', ancestor_id: ancestor.id || '', display: style.display, visibility: style.visibility };
            }
        }
        const rect = node.getBoundingClientRect();
        return { id, state: rect.width > 0 && rect.height > 0 ? 'visible' : 'empty', width: rect.width, height: rect.height };
    };
    const candidates = probe.candidates.map(inspect);
    const controls = probe.controls.map(inspect);
    const counts = {
        candidates: candidates.length,
        blocked: candidates.filter(entry => entry.state === 'hidden' || entry.state === 'removed').length,
        visible: candidates.filter(entry => entry.state === 'visible').length,
        controls: controls.length,
        controls_visible: controls.filter(entry => entry.state === 'visible').length,
    };
    return {
        unit: 'known ad-slot candidates in the shared HTML fixture',
        candidates, controls, counts,
        matches: counts.blocked === probe.expected.blocked && counts.visible === probe.expected.visible
            && counts.controls_visible === probe.expected.controls_visible,
    };
}
