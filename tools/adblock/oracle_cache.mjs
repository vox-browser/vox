// Prepare only the disposable page target. Preserve full-uBO extension stores.
export async function prepareOraclePageCache(page, {
    httpCachePolicy = 'preserve', serviceWorkerPolicy = 'allow',
} = {}) {
    if (!['empty', 'preserve'].includes(httpCachePolicy)) throw Error('Unsupported HTTP cache policy');
    if (!['allow', 'bypass'].includes(serviceWorkerPolicy)) throw Error('Unsupported service worker policy');
    await page.send('Network.setBypassServiceWorker', {bypass: serviceWorkerPolicy === 'bypass'});
    if (httpCachePolicy === 'empty') await page.send('Network.clearBrowserCache');
    return {http_cache_policy: httpCachePolicy, http_cache_cleared: httpCachePolicy === 'empty',
        service_worker_policy: serviceWorkerPolicy};
}
