// Minimal platform services used by uBO's static cosmetic selector cache.
// There is no extension timer loop in the isolated filtering context.
globalThis.vAPI = {
    defer: { create: () => ({ on() {}, off() {}, onvs() {}, onidle() {}, onraf() {}, offon() {}, ongoing: () => false }) },
    tabs: { insertCSS() {} },
    warSecret: { short: () => '' },
    localStorage: { getItem() { return null; }, setItem() {}, removeItem() {} },
};
