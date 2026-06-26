#!/usr/bin/env node

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '..');
const packPath = process.env.PACK_YAML || path.join(repoRoot, 'pack.yaml');
const secretName = process.env.PACK_SECRET_NAME || 'KELOMPOK3_DATABASE_URL';
const secretValue = process.env[secretName];
const keyB64 = process.env.VFLOW_PACK_SECRET_KEY_B64;

if (!keyB64) {
  throw new Error('VFLOW_PACK_SECRET_KEY_B64 is required');
}
if (!secretValue) {
  throw new Error(`${secretName} is required`);
}

const key = Buffer.from(keyB64.trim(), 'base64');
if (key.length !== 32) {
  throw new Error('VFLOW_PACK_SECRET_KEY_B64 must decode to 32 bytes');
}

const nonce = crypto.randomBytes(12);
const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
const encrypted = Buffer.concat([
  cipher.update(secretValue, 'utf8'),
  cipher.final(),
  cipher.getAuthTag(),
]);

const request = {
  pack_yaml: fs.readFileSync(packPath, 'utf8'),
  encrypted_secrets: {
    [secretName]: {
      alg: 'A256GCM',
      nonce_b64: nonce.toString('base64'),
      ciphertext_b64: encrypted.toString('base64'),
    },
  },
  replace: true,
  tenant: process.env.VFLOW_TENANT || '_default',
};

process.stdout.write(`${JSON.stringify(request, null, 2)}\n`);
