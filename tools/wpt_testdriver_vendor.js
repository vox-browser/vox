// Vox's native Page operations for WPT's standard vendor backend.
// Launch with VOX_WPT_TESTDRIVER=1. Unsupported operations retain the stock
// test-driver errors; tests, assertions, and harness completion stay upstream.
(() => {
    const backend = globalThis.test_driver_internal;
    const internals = globalThis.internals;
    if (!backend || !internals) {
        throw new Error("Vox WPT operations require the native browser backend");
    }
    const click = internals.testDriverClick;
    const label = internals.getComputedLabel;
    const role = internals.getComputedRole;
    backend.in_automation = true;
    if (typeof click === "function") {
        backend.click = async (element, coordinates) => {
            click(element, coordinates.x, coordinates.y);
        };
    }
    backend.get_computed_label = async element => {
        if (typeof label !== "function") {
            throw new Error("get_computed_label is not supported by this browser build");
        }
        return label(element);
    };
    backend.get_computed_role = async element => {
        if (typeof role !== "function") {
            throw new Error("get_computed_role is not supported by this browser build");
        }
        return role(element);
    };
})();
