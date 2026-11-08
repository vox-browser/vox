import { writeGithubResources } from './github_builder.mjs';
import { writeGithubStylesheetResources } from './github_css_builder.mjs';
await writeGithubResources();
await writeGithubStylesheetResources();
