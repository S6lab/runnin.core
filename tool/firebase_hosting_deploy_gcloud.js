#!/usr/bin/env node

const { execFileSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const { readdirSync, readFileSync, statSync } = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const projectId = process.argv[2] || 'runnin-494520';
const siteId = process.argv[3] || projectId;
const channel = process.argv[4];
const publicDir = path.resolve(process.argv[5] || 'app/build/web');

// Permite passar o token via env var (necessário no Windows, onde
// execFileSync não resolve `gcloud.cmd` automaticamente). Fallback chama
// o gcloud do PATH como antes.
const token = (process.env.GCLOUD_ACCESS_TOKEN
  ? process.env.GCLOUD_ACCESS_TOKEN
  : execFileSync('gcloud', ['auth', 'print-access-token'], {
      encoding: 'utf8',
    })
).trim();

const headers = {
  authorization: `Bearer ${token}`,
  'content-type': 'application/json',
  'x-goog-user-project': projectId,
};

function walk(dir, root = dir) {
  return readdirSync(dir).flatMap((entry) => {
    const fullPath = path.join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) return walk(fullPath, root);
    return path.relative(root, fullPath).split(path.sep).join('/');
  });
}

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${text}`);
  }
  return body;
}

async function main() {
  const files = walk(publicDir);
  const hashToPath = new Map();
  const pathToHash = {};

  for (const file of files) {
    const gzipped = zlib.gzipSync(readFileSync(path.join(publicDir, file)), {
      level: 9,
    });
    const hash = createHash('sha256').update(gzipped).digest('hex');
    hashToPath.set(hash, file);
    pathToHash[`/${file}`] = hash;
  }

  const version = await request(
    `https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/${siteId}/versions`,
    {
      method: 'POST',
      body: JSON.stringify({
        status: 'CREATED',
        labels: { 'deployment-tool': 'codex-gcloud-api' },
      }),
    },
  );

  const populate = await request(
    `https://firebasehosting.googleapis.com/v1beta1/${version.name}:populateFiles`,
    {
      method: 'POST',
      body: JSON.stringify({ files: pathToHash }),
    },
  );

  for (const hash of populate.uploadRequiredHashes || []) {
    const file = hashToPath.get(hash);
    const gzipped = zlib.gzipSync(readFileSync(path.join(publicDir, file)), {
      level: 9,
    });
    const response = await fetch(`${populate.uploadUrl}/${hash}`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
      body: gzipped,
    });
    if (!response.ok) {
      throw new Error(`Upload failed for ${file}: ${response.status}`);
    }
  }

  await request(
    `https://firebasehosting.googleapis.com/v1beta1/${version.name}?updateMask=status,config`,
    {
      method: 'PATCH',
      body: JSON.stringify({
        status: 'FINALIZED',
        config: {
          rewrites: [{ glob: '**', path: '/index.html' }],
        },
      }),
    },
  );

  await request(
    `https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/${siteId}/channels/${channel || 'live'}/releases?versionName=${encodeURIComponent(version.name)}`,
    {
      method: 'POST',
      body: JSON.stringify({}),
    },
  );

  console.log(`Hosting deployed to channel '${channel || 'live'}': https://${siteId}.web.app`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
