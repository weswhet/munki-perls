import { cp, mkdir, rm } from 'node:fs/promises';

await rm('dist', { recursive: true, force: true });
await mkdir('dist/assets', { recursive: true });
await cp('site/index.html', 'dist/index.html');
await cp('site/site.js', 'dist/assets/site.js');
await cp('site/styles/base.css', 'dist/assets/base.css');
await cp('site/assets', 'dist/assets', { recursive: true });
