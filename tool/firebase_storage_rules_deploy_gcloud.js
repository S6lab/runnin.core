#!/usr/bin/env node

const { execFileSync } = require('node:child_process');
const { readFileSync } = require('node:fs');

const projectId = process.argv[2] || 'runnin-494520';
const bucket = process.argv[3] || 'runnin-494520.firebasestorage.app';
const rulesFile = process.argv[4] || 'storage.rules';

const token = execFileSync('gcloud', ['auth', 'print-access-token'], {
  encoding: 'utf8',
}).trim();

const baseUrl = 'https://firebaserules.googleapis.com/v1';
const headers = {
  authorization: `Bearer ${token}`,
  'content-type': 'application/json',
  'x-goog-user-project': projectId,
};

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
  const files = [
    {
      name: rulesFile,
      content: readFileSync(rulesFile, 'utf8'),
    },
  ];

  const ruleset = await request(`${baseUrl}/projects/${projectId}/rulesets`, {
    method: 'POST',
    body: JSON.stringify({ source: { files } }),
  });

  const releaseName = `firebase.storage/${bucket}`;
  const payload = {
    release: {
      name: `projects/${projectId}/releases/${releaseName}`,
      rulesetName: ruleset.name,
    },
  };

  try {
    await request(`${baseUrl}/projects/${projectId}/releases/${releaseName}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  } catch (_) {
    await request(`${baseUrl}/projects/${projectId}/releases`, {
      method: 'POST',
      body: JSON.stringify(payload.release),
    });
  }

  console.log(`Storage rules deployed to gs://${bucket}`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
