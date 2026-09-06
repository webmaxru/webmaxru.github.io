import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const outputDirectory = path.join(root, "dist");
const projects = JSON.parse(
  fs.readFileSync(path.join(root, "projects.json"), "utf8"),
);

const readOutput = (relativePath) =>
  fs.readFileSync(path.join(outputDirectory, relativePath), "utf8");

const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message);
  }
};

const countMatches = (value, pattern) => [...value.matchAll(pattern)].length;

const getPngDimensions = (relativePath) => {
  const data = fs.readFileSync(path.join(outputDirectory, relativePath));
  const signature = "89504e470d0a1a0a";
  assert(
    data.subarray(0, 8).toString("hex") === signature,
    `${relativePath} is not a PNG file.`,
  );
  return {
    width: data.readUInt32BE(16),
    height: data.readUInt32BE(20),
  };
};

const assertOutputFile = (relativePath) => {
  assert(
    fs.existsSync(path.join(outputDirectory, relativePath)),
    `Missing output file: ${relativePath}`,
  );
};

const html = readOutput("index.html");
const notFoundHtml = readOutput("404.html");
const robots = readOutput("robots.txt");
const sitemap = readOutput("sitemap.xml");
const llms = readOutput("llms.txt");
const llmsFull = readOutput("llms-full.txt");
const manifest = JSON.parse(readOutput("site.webmanifest"));

for (const requiredFile of [
  ".nojekyll",
  "404.html",
  "robots.txt",
  "sitemap.xml",
  "site.webmanifest",
  "llms.txt",
  "llms-full.txt",
  "assets/brand/favicon.svg",
  "assets/brand/favicon.ico",
  "assets/brand/apple-touch-icon.png",
  "assets/brand/icon-192.png",
  "assets/brand/icon-512.png",
  "assets/brand/icon-maskable-512.png",
  "assets/brand/social-card.png",
]) {
  assertOutputFile(requiredFile);
}

assert(!html.includes("{{"), "Unresolved template placeholder in index.html.");
assert(
  countMatches(html, /<h1\b/gi) === 1,
  "index.html must contain exactly one h1.",
);
assert(
  countMatches(notFoundHtml, /<h1\b/gi) === 1,
  "404.html must contain exactly one h1.",
);
assert(
  /<meta name="robots" content="noindex, follow"\s*\/>/.test(notFoundHtml),
  "404.html must be excluded from indexing.",
);

for (const pattern of [
  /<link rel="canonical" href="https:\/\/webmaxru\.github\.io\/"\s*\/>/,
  /<meta name="author" content="Maxim Salnikov"\s*\/>/,
  /<meta\s+name="robots"\s+content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"\s*\/>/,
  /<meta\s+name="googlebot"\s+content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"\s*\/>/,
  /<meta property="og:type" content="website"\s*\/>/,
  /<meta property="og:image" content="https:\/\/webmaxru\.github\.io\/assets\/brand\/social-card\.png"\s*\/>/,
  /<meta name="twitter:card" content="summary_large_image"\s*\/>/,
  /<link rel="manifest" href="\/site\.webmanifest"\s*\/>/,
]) {
  assert(pattern.test(html), `Missing required head markup: ${pattern}`);
}

const titleMatch = html.match(/<title>([^<]+)<\/title>/);
assert(titleMatch, "Missing page title.");
assert(
  titleMatch[1] === "Maxim Salnikov | Projects and Experiments",
  "Unexpected page title.",
);

const descriptionMatch = html.match(
  /<meta name="description" content="([^"]+)"\s*\/>/,
);
assert(descriptionMatch, "Missing meta description.");
assert(
  descriptionMatch[1].length >= 140 && descriptionMatch[1].length <= 165,
  "Meta description should be approximately 150-160 characters.",
);

const jsonLdBlocks = [
  ...html.matchAll(
    /<script type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/g,
  ),
];
assert(jsonLdBlocks.length === 1, "Expected exactly one JSON-LD block.");
const structuredData = JSON.parse(jsonLdBlocks[0][1]);
assert(
  structuredData["@context"] === "https://schema.org",
  "JSON-LD must use schema.org.",
);
const structuredTypes = structuredData["@graph"].map((item) => item["@type"]);
assert(structuredTypes.includes("Person"), "JSON-LD must include Person.");
assert(structuredTypes.includes("WebSite"), "JSON-LD must include WebSite.");

const imageSources = [
  ...html.matchAll(/<img\b[^>]*\bsrc="([^"]+)"/g),
].map((match) => match[1]);
assert(
  imageSources.length === projects.length,
  "Every project must render one thumbnail image.",
);
for (const source of imageSources) {
  assert(
    !/^(?:https?:)?\/\//i.test(source),
    `Remote image reference found: ${source}`,
  );
  assertOutputFile(source.replace(/^\//, ""));
}

assert(
  !/<script\b[^>]*\bsrc="https?:\/\//i.test(html),
  "External script reference found.",
);
assert(
  !/<link\b[^>]*\brel="stylesheet"[^>]*\bhref="https?:\/\//i.test(html),
  "External stylesheet reference found.",
);

assert(manifest.name === "Maxim Salnikov | Projects and Experiments");
assert(manifest.start_url === "/" && manifest.scope === "/");
assert(manifest.icons.length === 3, "Manifest must define three app icons.");
for (const icon of manifest.icons) {
  assertOutputFile(icon.src.replace(/^\//, ""));
}

const expectedImageSizes = new Map([
  ["assets/brand/apple-touch-icon.png", [180, 180]],
  ["assets/brand/icon-192.png", [192, 192]],
  ["assets/brand/icon-512.png", [512, 512]],
  ["assets/brand/icon-maskable-512.png", [512, 512]],
  ["assets/brand/social-card.png", [1200, 630]],
]);
for (const [relativePath, expected] of expectedImageSizes) {
  const actual = getPngDimensions(relativePath);
  assert(
    actual.width === expected[0] && actual.height === expected[1],
    `${relativePath} has ${actual.width}x${actual.height}, expected ${expected[0]}x${expected[1]}.`,
  );
}

const favicon = fs.readFileSync(
  path.join(outputDirectory, "assets/brand/favicon.ico"),
);
assert(favicon.readUInt16LE(0) === 0, "Invalid favicon.ico reserved field.");
assert(favicon.readUInt16LE(2) === 1, "favicon.ico must contain icons.");
assert(
  favicon.readUInt16LE(4) === 3,
  "favicon.ico must contain 16, 32, and 48 pixel entries.",
);
const faviconSizes = [0, 1, 2].map((index) => favicon[6 + index * 16]);
assert(
  faviconSizes.join(",") === "16,32,48",
  "favicon.ico entries must be 16, 32, and 48 pixels.",
);

assert(
  sitemap.includes("<loc>https://webmaxru.github.io/</loc>"),
  "Sitemap must contain the canonical home URL.",
);
assert(
  robots.includes("Sitemap: https://webmaxru.github.io/sitemap.xml"),
  "robots.txt must reference the sitemap.",
);
for (const crawler of [
  "GPTBot",
  "OAI-SearchBot",
  "ChatGPT-User",
  "ClaudeBot",
  "Claude-User",
  "anthropic-ai",
  "PerplexityBot",
  "Perplexity-User",
  "Google-Extended",
  "Applebot-Extended",
  "CCBot",
  "cohere-ai",
  "Amazonbot",
  "meta-externalagent",
]) {
  assert(
    robots.includes(`User-agent: ${crawler}`),
    `robots.txt is missing ${crawler}.`,
  );
}

for (const project of projects) {
  assert(llmsFull.includes(`### ${project.name}`), `${project.name} missing from llms-full.txt.`);
}
assert(
  llms.includes("https://webmaxru.github.io/"),
  "llms.txt must link to the canonical site.",
);
assert(
  llms.includes("https://webmaxru.github.io/llms-full.txt"),
  "llms.txt must link to the full project catalog.",
);

console.log(
  `Validated ${projects.length} projects, complete metadata, discovery files, and local brand assets.`,
);
