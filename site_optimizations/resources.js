// The adblock adapter consumes this catalog; site policy belongs here.
import { chatgptFilters, chatgptResources } from './chatgpt.js';
import { githubFilters, githubResources } from './github_resources.js';

export const siteFilters = chatgptFilters + githubFilters;
export const siteResources = new Map([...chatgptResources, ...githubResources]);
