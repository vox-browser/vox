// Local supplements to the subscription lists. Match reviewed, versioned
// modules only: a changed export contract must fall back to the site's code.
import { basicSiteFilters, basicSiteResources } from './chatgpt_basic_resources.js';
export const chatgptFilters = String.raw`
! ChatGPT anonymous web client: suppress collection before downloading its JS.
/^https:\/\/chatgpt\.com\/unauth-mweb\/assets\/analytics-ces-business-context-DAjYxggM\.js(?:\?[^#]*)?$/$script,match-case,domain=chatgpt.com,redirect=vox-chatgpt-business.js
/^https:\/\/chatgpt\.com\/unauth-mweb\/assets\/native-performance-bootstrap-DnIgxW1S\.js(?:\?[^#]*)?$/$script,match-case,domain=chatgpt.com,redirect=vox-chatgpt-performance.js
/^https:\/\/chatgpt\.com\/unauth-mweb\/assets\/analytics-ces-business-context-Bx7D-YTR\.js(?:\?[^#]*)?$/$script,match-case,domain=chatgpt.com,redirect=vox-chatgpt-business.js
/^https:\/\/chatgpt\.com\/unauth-mweb\/assets\/native-performance-bootstrap-_6lrVRz4\.js(?:\?[^#]*)?$/$script,match-case,domain=chatgpt.com,redirect=vox-chatgpt-performance-20261106.js
/^https:\/\/chatgpt\.com\/unauth-mweb\/assets\/analytics-ces-business-context-DAkvOubI\.js(?:\?[^#]*)?$/$script,match-case,domain=chatgpt.com,redirect=vox-chatgpt-business.js
/^https:\/\/chatgpt\.com\/unauth-mweb\/assets\/native-performance-bootstrap-vLAyyR-4\.js(?:\?[^#]*)?$/$script,match-case,domain=chatgpt.com,redirect=vox-chatgpt-performance-20261106-b.js
` + basicSiteFilters;

// Do not replace native-telemetry: it also installs soft-login handling,
// service-worker cleanup and the behavior-ready lifecycle. These two leaves
// only report measurements/events. Their callers need successful module loads,
// not empty scripts (which would fail ES module linking).
function performanceResource(dependency) {
    return `import {
    setPageLoadPerformanceMeasurementReporter,
    takeInitialLongTaskMetrics,
} from 'https://chatgpt.com/unauth-mweb/assets/${dependency}';

export function startOctanePerformanceMetrics({canStart, setPerformanceCollectionAbandoner}) {
    return Promise.resolve().then(() => {
        if (!canStart()) return false;
        // Drain the queued startup measurements and disconnect the initial
        // observer. Installing a sink prevents a growing, unreported queue.
        takeInitialLongTaskMetrics();
        setPageLoadPerformanceMeasurementReporter(() => {});
        setPerformanceCollectionAbandoner(() => {});
        // false makes native-telemetry retry; true completes its lifecycle.
        return true;
    });
}
`;
}

export const chatgptResources = new Map([
    ...basicSiteResources,
    ['vox-chatgpt-business.js', `export function reportCesBusinessEvent() {}\n`],
    ['vox-chatgpt-performance.js', performanceResource('page-load-performance-CGytc5Xs.js')],
    ['vox-chatgpt-performance-20261106.js', performanceResource('page-load-performance-Bjb58u76.js')],
    ['vox-chatgpt-performance-20261106-b.js', performanceResource('page-load-performance-B9hsBOlx.js')],
]);
