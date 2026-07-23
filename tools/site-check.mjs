import { readFile, stat } from 'node:fs/promises';
import { parse } from 'acorn';

const required = [
  'dist/index.html',
  'dist/assets/base.css',
  'dist/assets/site.css',
  'dist/assets/site.js',
  'dist/assets/munki-perls-hero.png',
  'dist/assets/munki-perls-hero.webp',
  'dist/assets/favicon.png'
];

for (const path of required) {
  const details = await stat(path);
  if (!details.isFile() || details.size === 0) throw new Error(`Missing build output: ${path}`);
}

const html = await readFile('dist/index.html', 'utf8');
const js = await readFile('dist/assets/site.js', 'utf8');
parse(js, { ecmaVersion: 5 });
for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  parse(match[1], { ecmaVersion: 5 });
}

for (const marker of ['<main id="main">', 'Skip to content', 'prefers-reduced-motion', 'munki-perls-hero.png']) {
  if (!html.includes(marker) && !js.includes(marker)) throw new Error(`Missing required marker: ${marker}`);
}

for (const match of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
  const target = match[1];
  if (target.startsWith('/') && !target.startsWith('//')) throw new Error(`Root-relative URL is unsafe for project Pages: ${target}`);
}

console.log('Site output, project-relative URLs, and ES5 JavaScript validated.');
