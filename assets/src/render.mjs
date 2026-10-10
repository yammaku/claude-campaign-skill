// Render the README figures: sh fetch-fonts.sh, then
// PW_PATH=<path to playwright module> node render.mjs figs.html .. 2
import { createRequire } from 'module';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PW_PATH);

const [,, htmlPath, outDir, scale = '2'] = process.argv;
const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: Number(scale), viewport: { width: 1300, height: 900 } });
for (const lang of ['en', 'zh']) {
  await page.goto('file://' + path.resolve(htmlPath) + '?lang=' + lang);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(400);
  for (const id of ['hero', 'compare', 'triage', 'flow', 'chain']) {
    await page.locator('#' + id).screenshot({ path: `${outDir}/${id}-${lang}.png` });
  }
}
await browser.close();
