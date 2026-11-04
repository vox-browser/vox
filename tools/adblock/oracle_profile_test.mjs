import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { createOracleProfile, saveClosedOracleProfile } from './oracle_profile.mjs';

test('image animation policy is pinned in fresh and copied profiles without changing the template', async t => {
    const template = await createOracleProfile('', {imageAnimationPolicy:'none'});
    const profiles = [template];
    t.after(()=>Promise.all(profiles.map(p=>fs.rm(p,{recursive:true,force:true}))));
    const prefs = p=>fs.readFile(path.join(p,'Default/Preferences'),'utf8').then(JSON.parse);
    assert.equal((await prefs(template)).settings.a11y.animation_policy,'none');
    const normal = await createOracleProfile(template);
    const still = await createOracleProfile(template,{imageAnimationPolicy:'none'});
    profiles.push(normal,still);
    assert.equal((await prefs(normal)).settings.a11y.animation_policy,'allowed');
    assert.equal((await prefs(still)).settings.a11y.animation_policy,'none');
    assert.equal((await prefs(template)).settings.a11y.animation_policy,'none');
    await assert.rejects(createOracleProfile('',{imageAnimationPolicy:'skip'}),/Unsupported/);
});

test('a closed warm profile retains encoded cache without overwriting another trial', async t => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-oracle-warm-'));
    t.after(() => fs.rm(root, {recursive: true, force: true}));
    const source = path.join(root, 'source'), saved = path.join(root, 'saved');
    await fs.mkdir(path.join(source, 'Default/Cache/Cache_Data'), {recursive: true});
    await fs.writeFile(path.join(source, 'Default/Cache/Cache_Data/response'), 'encoded response');
    await fs.writeFile(path.join(source, 'DevToolsActivePort'), 'old endpoint');
    await fs.symlink('/closed-browser', path.join(source, 'SingletonLock'));
    await saveClosedOracleProfile(source, saved);
    assert.equal(await fs.readFile(path.join(saved, 'Default/Cache/Cache_Data/response'), 'utf8'), 'encoded response');
    assert.equal((await fs.stat(saved)).mode & 0o777, 0o700);
    for (const name of ['DevToolsActivePort', 'SingletonLock']) {
        await assert.rejects(fs.lstat(path.join(saved, name)), {code: 'ENOENT'});
    }
    await assert.rejects(saveClosedOracleProfile(source, saved), {code: 'EEXIST'});
    assert.equal(await fs.readFile(path.join(saved, 'Default/Cache/Cache_Data/response'), 'utf8'), 'encoded response');
});

test('fresh oracle disables the separate Brave blocker', async () => {
    const profile = await createOracleProfile();
    try {
        const preferences = JSON.parse(await fs.readFile(path.join(profile, 'Default/Preferences')));
        assert.equal(preferences.profile.default_content_setting_values.braveShields, 2);
    } finally { await fs.rm(profile, { recursive: true, force: true }); }
});

test('prepared full-uBO state is copied independently without process locks', async () => {
    const template = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-oracle-template-'));
    let profile;
    try {
        await fs.mkdir(path.join(template, 'Default/Local Extension Settings/ubo'), { recursive: true });
        const preferences = { profile: { name: 'fixture', default_content_setting_values: { braveShields: 1 } }, extensions: { fixture: true } };
        const original = JSON.stringify(preferences);
        await fs.writeFile(path.join(template, 'Default/Preferences'), original);
        await fs.writeFile(path.join(template, 'Default/Local Extension Settings/ubo/data'), 'compiled pinned filters');
        await fs.writeFile(path.join(template, 'DevToolsActivePort'), 'obsolete endpoint');
        await fs.symlink('/nonexistent-process-lock', path.join(template, 'SingletonLock'));
        profile = await createOracleProfile(template);
        assert.notEqual(profile, template);
        const copied = JSON.parse(await fs.readFile(path.join(profile, 'Default/Preferences')));
        assert.equal(copied.profile.name, 'fixture');
        assert.equal(copied.extensions.fixture, true);
        assert.equal(copied.profile.default_content_setting_values.braveShields, 2);
        assert.equal(await fs.readFile(path.join(profile, 'Default/Local Extension Settings/ubo/data'), 'utf8'), 'compiled pinned filters');
        for (const name of ['DevToolsActivePort', 'SingletonLock']) {
            await assert.rejects(fs.lstat(path.join(profile, name)), { code: 'ENOENT' });
        }
        await fs.writeFile(path.join(profile, 'Default/Local Extension Settings/ubo/data'), 'changed clone');
        assert.equal(await fs.readFile(path.join(template, 'Default/Local Extension Settings/ubo/data'), 'utf8'), 'compiled pinned filters');
        assert.equal(await fs.readFile(path.join(template, 'Default/Preferences'), 'utf8'), original);
    } finally {
        if (profile) await fs.rm(profile, { recursive: true, force: true });
        await fs.rm(template, { recursive: true, force: true });
    }
});

test('invalid prepared preferences fail instead of silently replacing them', async () => {
    const template = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-oracle-invalid-'));
    try {
        await fs.mkdir(path.join(template, 'Default'));
        await fs.writeFile(path.join(template, 'Default/Preferences'), 'invalid JSON');
        await assert.rejects(createOracleProfile(template), SyntaxError);
        assert.equal(await fs.readFile(path.join(template, 'Default/Preferences'), 'utf8'), 'invalid JSON');
    } finally { await fs.rm(template, { recursive: true, force: true }); }
});

test('prepared caches cannot restore a page before the measured navigation', async t=>{
    const template=await fs.mkdtemp(path.join(os.tmpdir(),'vox-oracle-startup-'));
    t.after(()=>fs.rm(template,{recursive:true,force:true}));
    await fs.mkdir(path.join(template,'Default/Sessions'),{recursive:true});
    await fs.mkdir(path.join(template,'Default/Cache/Cache_Data'),{recursive:true});
    const preferences={session:{restore_on_startup:1,startup_urls:['https://example.com/']},
        profile:{exit_type:'Crashed'}};
    await fs.writeFile(path.join(template,'Default/Preferences'),JSON.stringify(preferences));
    await fs.writeFile(path.join(template,'Default/Sessions/Tabs_123'),'restored tabs');
    await fs.writeFile(path.join(template,'Default/Current Session'),'legacy restored tab');
    await fs.writeFile(path.join(template,'Default/Cache/Cache_Data/response'),'original encoded bytes');
    const profile=await createOracleProfile(template);
    t.after(()=>fs.rm(profile,{recursive:true,force:true}));
    const actual=JSON.parse(await fs.readFile(path.join(profile,'Default/Preferences')));
    assert.equal(actual.profile.exit_type,'Normal');
    assert.deepEqual(actual.session,{restore_on_startup:5,startup_urls:[]});
    for(const name of ['Sessions','Current Session'])
        await assert.rejects(fs.stat(path.join(profile,'Default',name)),{code:'ENOENT'});
    assert.equal(await fs.readFile(path.join(profile,'Default/Cache/Cache_Data/response'),'utf8'),'original encoded bytes');
    assert.equal(await fs.readFile(path.join(template,'Default/Sessions/Tabs_123'),'utf8'),'restored tabs');
    assert.deepEqual(JSON.parse(await fs.readFile(path.join(template,'Default/Preferences'))),preferences);
});
