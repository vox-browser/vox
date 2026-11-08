// Compatibility entry point for the adblock build command.
import { pathToFileURL } from 'node:url';
import { writeBasicResources } from '../../site_optimizations/chatgpt_builder.mjs';
export { buildBasicResources } from '../../site_optimizations/chatgpt_builder.mjs';
if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) await writeBasicResources();
