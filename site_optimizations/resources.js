// The adblock adapter consumes this catalog; site policy belongs here.
import { chatgptFilters, chatgptResources } from './chatgpt.js';

export const siteFilters = chatgptFilters;
export const siteResources = new Map(chatgptResources);
