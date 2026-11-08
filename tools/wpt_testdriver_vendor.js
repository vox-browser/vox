// Vox's optional native Page input adapter for WPT's standard vendor backend.
// Launch with VOX_WPT_TESTDRIVER=1. Unsupported operations retain the stock
// test-driver errors; tests, assertions, and harness completion stay upstream.
(() => {
    const backend = globalThis.test_driver_internal;
    const internals = globalThis.internals;
    if (!backend || !internals || typeof internals.testDriverClick !== "function") {
        throw new Error("Vox WPT input requires VOX_WPT_TESTDRIVER=1 and an owning Page");
    }
    const click = internals.testDriverClick;
    backend.in_automation = true;
    backend.click = async (element, coordinates) => {
        click(element, coordinates.x, coordinates.y);
    };
})();
