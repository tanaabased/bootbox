import { execFile } from 'node:child_process';
import { chmod, cp, mkdir, rm, stat, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const DIST_URL = new URL('./dist/', import.meta.url);
const REPO_URL = new URL('./', import.meta.url);
const REPO_ROOT = fileURLToPath(REPO_URL);
const PUBLIC_ORIGIN = 'https://bootbox.tanaab.sh';
const ROBOTS_URL = new URL('./robots.txt', DIST_URL);
const SITEMAP_URL = new URL('./sitemap.xml', DIST_URL);
const BOOTBOX_SOURCE_URL = new URL('./bootbox.sh', import.meta.url);
const DIST_FILES = [
  ['bootbox.sh', 'bootbox.sh'],
  ['site/index.html', 'index.html'],
  ['site/netlify.toml', 'netlify.toml'],
];
const EXECUTABLES = ['bootbox.sh'];
const execFileAsync = promisify(execFile);

function log(message) {
  process.stdout.write(`${message}\n`);
}

function normalizeLastmod(value) {
  if (!value) {
    return null;
  }

  const parsedDate = new Date(value);

  if (Number.isNaN(parsedDate.valueOf())) {
    return null;
  }

  return parsedDate.toISOString();
}

async function getGitLastmod() {
  try {
    const { stdout } = await execFileAsync(
      'git',
      ['log', '-1', '--format=%cI', '--', 'bootbox.sh'],
      {
        cwd: REPO_ROOT,
      },
    );

    return normalizeLastmod(stdout.trim());
  } catch {
    return null;
  }
}

async function getFileLastmod() {
  try {
    const fileStats = await stat(BOOTBOX_SOURCE_URL);

    return normalizeLastmod(fileStats.mtime.toISOString());
  } catch {
    return null;
  }
}

async function resolveSitemapLastmod() {
  const explicitLastmod = normalizeLastmod(process.env.SITEMAP_LASTMOD);

  if (explicitLastmod) {
    return explicitLastmod;
  }

  const gitLastmod = await getGitLastmod();

  if (gitLastmod) {
    return gitLastmod;
  }

  const fileLastmod = await getFileLastmod();

  if (fileLastmod) {
    return fileLastmod;
  }

  return new Date().toISOString();
}

function renderSitemap(lastmod) {
  return `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${PUBLIC_ORIGIN}/bootbox.sh</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.5</priority>
  </url>
</urlset>
`;
}

function renderRobots() {
  return `User-agent: *
Disallow: /
Sitemap: ${PUBLIC_ORIGIN}/sitemap.xml
Host: ${PUBLIC_ORIGIN}
Allow: /bootbox.sh
Allow: /sitemap.xml
`;
}

async function resetDist() {
  await rm(DIST_URL, { recursive: true, force: true });
  await mkdir(DIST_URL, { recursive: true });
}

async function copyDistFile(sourcePath, destinationPath) {
  const sourceUrl = new URL(`./${sourcePath}`, import.meta.url);
  const destinationUrl = new URL(`./${destinationPath}`, DIST_URL);

  await cp(sourceUrl, destinationUrl, { force: true });

  return destinationUrl.pathname;
}

async function makeExecutable(filename) {
  await chmod(new URL(`./${filename}`, DIST_URL), 0o755);
}

async function writeSitemap() {
  const lastmod = await resolveSitemapLastmod();

  await writeFile(SITEMAP_URL, renderSitemap(lastmod), 'utf8');

  log(`wrote ${SITEMAP_URL.pathname}`);
}

async function writeRobots() {
  await writeFile(ROBOTS_URL, renderRobots(), 'utf8');

  log(`wrote ${ROBOTS_URL.pathname}`);
}

async function main() {
  await resetDist();

  for (const [sourcePath, destinationPath] of DIST_FILES) {
    const copiedPath = await copyDistFile(sourcePath, destinationPath);
    log(`copied ${copiedPath}`);
  }

  await writeSitemap();
  await writeRobots();

  for (const executable of EXECUTABLES) {
    await makeExecutable(executable);
  }

  log(`prepared ${DIST_URL.pathname}`);
}

await main();
