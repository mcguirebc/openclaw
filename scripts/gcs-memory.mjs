import fs from "node:fs/promises";

const METADATA_TOKEN_URL =
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token";

function usage() {
  console.error(
    [
      "Usage:",
      "  node scripts/gcs-memory.mjs read <path> [--out <file>]",
      "  node scripts/gcs-memory.mjs write <path> --content <text>",
      "  node scripts/gcs-memory.mjs write <path> --file <path>",
      "  node scripts/gcs-memory.mjs versions <path>",
      "  node scripts/gcs-memory.mjs rollback <path> --generation <id>",
    ].join("\n"),
  );
}

function parseArgs(argv) {
  const args = [...argv];
  const result = { _: [] };
  while (args.length > 0) {
    const token = args.shift();
    if (!token) {
      break;
    }
    if (token.startsWith("--")) {
      const key = token.slice(2);
      const value = args.shift();
      result[key] = value;
      continue;
    }
    result._.push(token);
  }
  return result;
}

async function getAccessToken() {
  if (process.env.GCS_ACCESS_TOKEN) {
    return process.env.GCS_ACCESS_TOKEN;
  }
  const res = await fetch(METADATA_TOKEN_URL, {
    headers: { "Metadata-Flavor": "Google" },
  });
  if (!res.ok) {
    throw new Error(`metadata token failed: ${res.status}`);
  }
  const data = await res.json();
  return data.access_token;
}

function resolveBucket(cliBucket) {
  const bucket = cliBucket || process.env.OPENCLAW_BRAIN_BUCKET;
  if (!bucket) {
    throw new Error("Missing bucket. Set OPENCLAW_BRAIN_BUCKET or pass --bucket.");
  }
  return bucket;
}

function normalizeObject(pathInput) {
  const prefix = process.env.OPENCLAW_BRAIN_PREFIX || "";
  const cleaned = pathInput.replace(/^\/+/, "");
  return `${prefix}${cleaned}`;
}

function objectUrl(bucket, objectName, query = "") {
  const encoded = encodeURIComponent(objectName);
  const qs = query ? `?${query}` : "";
  return `https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encoded}${qs}`;
}

async function readObject({ bucket, objectName, outPath }) {
  const token = await getAccessToken();
  const url = objectUrl(bucket, objectName, "alt=media");
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`read failed: ${res.status}`);
  }
  const text = await res.text();
  if (outPath) {
    await fs.writeFile(outPath, text, "utf8");
    return;
  }
  process.stdout.write(text);
}

async function writeObject({ bucket, objectName, content }) {
  const token = await getAccessToken();
  const url = `https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o?uploadType=media&name=${encodeURIComponent(
    objectName,
  )}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "text/plain",
    },
    body: content,
  });
  if (!res.ok) {
    throw new Error(`write failed: ${res.status}`);
  }
  const data = await res.json();
  process.stdout.write(JSON.stringify(data, null, 2));
}

async function listVersions({ bucket, objectName }) {
  const token = await getAccessToken();
  const url = `https://storage.googleapis.com/storage/v1/b/${bucket}/o?prefix=${encodeURIComponent(
    objectName,
  )}&versions=true`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`versions failed: ${res.status}`);
  }
  const data = await res.json();
  const items = (data.items || []).filter((item) => item.name === objectName);
  process.stdout.write(JSON.stringify(items, null, 2));
}

async function rollbackObject({ bucket, objectName, generation }) {
  const token = await getAccessToken();
  const url = `https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(
    objectName,
  )}/rewriteTo/b/${bucket}/o/${encodeURIComponent(objectName)}?sourceGeneration=${encodeURIComponent(
    generation,
  )}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`rollback failed: ${res.status}`);
  }
  const data = await res.json();
  process.stdout.write(JSON.stringify(data, null, 2));
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const [command, pathInput] = args._;
  if (!command || !pathInput) {
    usage();
    process.exit(1);
  }

  const bucket = resolveBucket(args.bucket);
  const objectName = normalizeObject(pathInput);

  if (command === "read") {
    await readObject({ bucket, objectName, outPath: args.out });
    return;
  }

  if (command === "write") {
    let content = "";
    if (args.file) {
      content = await fs.readFile(args.file, "utf8");
    } else if (args.content) {
      content = args.content;
    } else {
      content = await readStdin();
    }
    await writeObject({ bucket, objectName, content });
    return;
  }

  if (command === "versions") {
    await listVersions({ bucket, objectName });
    return;
  }

  if (command === "rollback") {
    if (!args.generation) {
      throw new Error("Missing --generation");
    }
    await rollbackObject({ bucket, objectName, generation: args.generation });
    return;
  }

  usage();
  process.exit(1);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
