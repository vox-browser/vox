// The adblock adapter consumes this catalog; site policy belongs here.
import { chatgptFilters, chatgptResources } from './chatgpt.js';
import { githubFilters, githubResources } from './github_resources.js';
import { githubStylesheetFilters, githubStylesheetResources } from './github_css_resources.js';

export const siteFilters = chatgptFilters + githubFilters + githubStylesheetFilters;
export const siteResources = new Map([...chatgptResources, ...githubResources, ...githubStylesheetResources]);
