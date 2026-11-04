// A prepared profile can leave background/service-worker events after its old
// tabs close. Only the measured tab supplies this navigation's uBO observations.
export function oracleTabEntries(entries, tabId) {
    if (!Number.isSafeInteger(tabId) || tabId <= 0) throw Error('Missing measured oracle tab identity');
    return entries.filter(entry => entry.tabId === tabId);
}
