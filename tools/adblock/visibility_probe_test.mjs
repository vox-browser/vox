import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs/promises';
import { collectVisibility, validateVisibilityProbe } from './visibility_probe.mjs';

const specification = JSON.parse(await fs.readFile(new URL('./fixtures/pikabu-slots-probe.json', import.meta.url)));

function inspect(probe, nodes) {
    return vm.runInNewContext(`(${collectVisibility.toString()})(${JSON.stringify(probe)})`, {
        document: { getElementById: id => nodes[id] || null },
        getComputedStyle: node => ({ display: node.display || 'block', visibility: node.visibility || 'visible' }),
    });
}

function element(properties = {}) {
    return { getBoundingClientRect: () => ({ width: 80, height: 32 }), ...properties };
}

test('Pikabu shared fixture declares five candidate slots and two content controls', async () => {
    const ids = validateVisibilityProbe(specification);
    assert.equal(specification.candidates.length, 5);
    assert.equal(specification.controls.length, 2);
    const source = await fs.readFile(new URL('./fixtures/pikabu-slots.html', import.meta.url), 'utf8');
    for (const id of ids) assert.equal(source.split(`id="${id}"`).length - 1, 1, id);
});

test('removed nodes and nodes hidden through an ancestor both count, with visible controls required', () => {
    const probe = { candidates: ['removed', 'hidden'], controls: ['content'], expected: { blocked: 2, visible: 0, controls_visible: 1 } };
    const nodes = { hidden: element({ parentElement: element({ id: 'wrapper', display: 'none' }) }), content: element() };
    const result = inspect(probe, nodes);
    assert.equal(result.matches, true);
    assert.equal(result.counts.blocked, 2);
    assert.equal(result.candidates[0].state, 'removed');
    assert.equal(result.candidates[1].ancestor_id, 'wrapper');
    nodes.content.display = 'none';
    assert.equal(inspect(probe, nodes).matches, false);
});

test('an empty candidate does not substitute for a confirmed hidden or removed ad', () => {
    const probe = { candidates: ['ad'], controls: ['content'], expected: { blocked: 1, visible: 0, controls_visible: 1 } };
    const result = inspect(probe, { ad: element({ getBoundingClientRect: () => ({ width: 0, height: 0 }) }), content: element() });
    assert.equal(result.candidates[0].state, 'empty');
    assert.equal(result.matches, false);
});

test('duplicate IDs and weaker expected outcomes cannot pass probe validation', () => {
    assert.throws(() => validateVisibilityProbe({ ...specification, controls: ['slot-brand'] }), /unique/);
    assert.throws(() => validateVisibilityProbe({ ...specification, expected: { blocked: 0, visible: 5, controls_visible: 2 } }), /all candidates/);
});
