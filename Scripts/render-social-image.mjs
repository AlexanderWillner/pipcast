// Run from website/ after npm ci; uses Next's installed image renderer.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const require = createRequire(new URL('../website/package.json', import.meta.url));
const sharp = require('sharp');
const logo = readFileSync(new URL('../docs/branding/pipcast-logo.svg', import.meta.url), 'utf8');
const mark = Buffer.from(logo).toString('base64');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
<rect width="1200" height="630" fill="#f4f5f7"/>
<image href="data:image/svg+xml;base64,${mark}" x="40" y="75" width="480" height="480"/>
<text x="530" y="300" font-family="Helvetica,Arial,sans-serif" font-size="86" font-weight="700" fill="#303030">Pipcast</text>
<text x="535" y="365" font-family="Helvetica,Arial,sans-serif" font-size="28" fill="#50545a">A free, native macOS launcher.</text>
</svg>`;
await sharp(Buffer.from(svg)).png().toFile(new URL('../website/public/og.png', import.meta.url).pathname);
