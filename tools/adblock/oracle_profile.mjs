import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const transientFiles = new Set(['SingletonLock', 'SingletonCookie', 'SingletonSocket',
    'DevToolsActivePort']);
const persistentFile = source => !transientFiles.has(path.basename(source));

// The caller must stop its disposable browser first so the HTTP cache and
// extension stores are closed. Never overwrite a template or a prior trial.
export async function saveClosedOracleProfile(profile, destination) {
    const target = path.resolve(destination);
    await fs.mkdir(target, {mode: 0o700});
    try {
        await fs.cp(profile, target, {recursive: true, filter: persistentFile});
    } catch (error) {
        await fs.rm(target, {recursive: true, force: true});
        throw error;
    }
}

// Copy a closed, explicitly supplied prepared profile. Never launch Brave
// against the template or retain its process locks/debugging endpoint.
export async function createOracleProfile(template = '') {
    const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-adblock-parity-'));
    try {
        if (template) {
            await fs.cp(path.resolve(template), profile, {
                recursive: true,
                filter: persistentFile,
            });
        }
        const defaults = path.join(profile, 'Default');
        await fs.mkdir(defaults, { recursive: true });
        const preferencesPath = path.join(defaults, 'Preferences');
        let preferences = {};
        try {
            preferences = JSON.parse(await fs.readFile(preferencesPath, 'utf8'));
        } catch (error) {
            if (error.code !== 'ENOENT') throw error;
        }
        preferences.profile ??= {};
        preferences.profile.default_content_setting_values ??= {};
        preferences.profile.default_content_setting_values.braveShields = 2;
        // Restore encoded HTTP/extension state, with no unmeasured page
        // navigation before the oracle target is sized and filtering is ready.
        // A restored tab can populate the shared image decode cache first.
        preferences.profile.exit_type = 'Normal';
        preferences.session ??= {};
        preferences.session.restore_on_startup = 5;
        preferences.session.startup_urls = [];
        for (const name of ['Sessions', 'Current Session', 'Current Tabs', 'Last Session', 'Last Tabs'])
            await fs.rm(path.join(defaults,name), {recursive:true,force:true});
        await fs.writeFile(preferencesPath, JSON.stringify(preferences));
        return profile;
    } catch (error) {
        await fs.rm(profile, { recursive: true, force: true });
        throw error;
    }
}
