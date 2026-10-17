import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

// Copy a closed, explicitly supplied prepared profile. Never launch Brave
// against the template or retain its process locks/debugging endpoint.
export async function createOracleProfile(template = '') {
    const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-adblock-parity-'));
    try {
        if (template) {
            await fs.cp(path.resolve(template), profile, {
                recursive: true,
                filter: source => !['SingletonLock', 'SingletonCookie', 'SingletonSocket',
                    'DevToolsActivePort'].includes(path.basename(source)),
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
        await fs.writeFile(preferencesPath, JSON.stringify(preferences));
        return profile;
    } catch (error) {
        await fs.rm(profile, { recursive: true, force: true });
        throw error;
    }
}
