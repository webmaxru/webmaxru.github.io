import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const sourceDirectory = path.join(root, "src");
const outputDirectory = path.join(root, "dist");
const sourceAssetsDirectory = path.join(sourceDirectory, "assets");
const projects = JSON.parse(
  fs.readFileSync(path.join(root, "projects.json"), "utf8"),
);

const escapeHtml = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const slugify = (value) =>
  value
    .toLowerCase()
    .replaceAll(/[^a-z0-9]+/g, "-")
    .replaceAll(/^-|-$/g, "");

const getInitials = (name) => {
  const words = name.split(/\s+/).filter(Boolean);
  if (words.length === 1) {
    return words[0].slice(0, 2).toUpperCase();
  }

  return words
    .slice(0, 2)
    .map((word) => word[0])
    .join("")
    .toUpperCase();
};

const getThumbnailUrl = (project) => {
  const thumbnail = project.thumbnail ?? "generated";
  if (thumbnail === "generated") {
    return thumbnail;
  }

  if (
    path.isAbsolute(thumbnail) ||
    thumbnail.startsWith("//") ||
    /^[a-z][a-z\d+.-]*:/i.test(thumbnail)
  ) {
    throw new Error(`${project.name} must use a local thumbnail asset.`);
  }

  const thumbnailPath = path.resolve(sourceDirectory, thumbnail);
  const relativePath = path.relative(sourceDirectory, thumbnailPath);
  if (relativePath.startsWith("..") || path.isAbsolute(relativePath)) {
    throw new Error(`${project.name} thumbnail must stay inside src.`);
  }

  if (!fs.existsSync(thumbnailPath)) {
    throw new Error(`${project.name} thumbnail not found: ${thumbnail}`);
  }

  return thumbnail.replaceAll("\\", "/");
};

const groupedProjects = projects.reduce((groups, project) => {
  const group = groups.get(project.category) ?? [];
  group.push(project);
  groups.set(project.category, group);
  return groups;
}, new Map());

const categoryNavigation = [...groupedProjects.entries()]
  .map(
    ([category, categoryProjects], index) => `
      <a class="category-link" href="#${slugify(category)}">
        <span class="category-number">${String(index + 1).padStart(2, "0")}</span>
        <span>${escapeHtml(category)}</span>
        <span class="category-count">${categoryProjects.length}</span>
      </a>`,
  )
  .join("");

const renderGitHubIcon = () => `
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path fill="currentColor" d="M12 .75a11.25 11.25 0 0 0-3.56 21.92c.56.1.77-.24.77-.54v-2.1c-3.14.68-3.8-1.34-3.8-1.34-.51-1.3-1.25-1.65-1.25-1.65-1.02-.7.08-.68.08-.68 1.13.08 1.73 1.16 1.73 1.16 1 1.72 2.62 1.22 3.26.93.1-.72.4-1.22.71-1.5-2.5-.28-5.13-1.25-5.13-5.56 0-1.23.44-2.23 1.16-3.02-.12-.28-.5-1.43.11-2.98 0 0 .95-.3 3.1 1.15a10.75 10.75 0 0 1 5.64 0c2.15-1.46 3.1-1.15 3.1-1.15.61 1.55.23 2.7.11 2.98.72.79 1.16 1.79 1.16 3.02 0 4.32-2.63 5.28-5.14 5.56.41.36.76 1.08.76 2.18v3.24c0 .3.2.65.78.54A11.25 11.25 0 0 0 12 .75Z"/>
  </svg>`;

const renderProjectCard = (project) => {
  const repositoryUrl = `https://github.com/${project.repo}`;
  const thumbnailUrl = getThumbnailUrl(project);
  const useGeneratedThumbnail = thumbnailUrl === "generated";
  const liveUrl = project.live ?? repositoryUrl;
  const liveLabel = project.liveLabel ?? "Open live project";
  const fallbackLabel = getInitials(project.name);
  const thumbClass = useGeneratedThumbnail
    ? "project-thumb has-fallback"
    : "project-thumb";
  const imageMarkup = useGeneratedThumbnail
    ? ""
    : `
        <img
          src="${escapeHtml(thumbnailUrl)}"
          alt="${escapeHtml(project.name)} thumbnail"
          loading="lazy"
          decoding="async"
          onerror="this.hidden=true;this.parentElement.classList.add('has-fallback')"
        />`;

  return `
    <article class="project-card">
      <div class="${thumbClass}">
        <div class="thumb-fallback" aria-hidden="true">
          <span class="thumb-mark">${escapeHtml(fallbackLabel)}</span>
          <span class="thumb-fallback-name">${escapeHtml(project.name)}</span>
        </div>
        ${imageMarkup}
        <span class="thumb-label">${escapeHtml(project.category)}</span>
      </div>
      <div class="card-body">
        <div class="card-title-row">
          <h3>${escapeHtml(project.name)}</h3>
          <span class="repo-name">${escapeHtml(project.repo.split("/").at(-1))}</span>
        </div>
        <p>${escapeHtml(project.description)}</p>
        <div class="card-links">
          <a class="live-link" href="${escapeHtml(liveUrl)}" target="_blank" rel="noopener noreferrer">
            <span>${escapeHtml(liveLabel)}</span>
            <span aria-hidden="true">&rarr;</span>
          </a>
          <a class="github-link" href="${escapeHtml(repositoryUrl)}" target="_blank" rel="noopener noreferrer" aria-label="View ${escapeHtml(project.name)} on GitHub">
            ${renderGitHubIcon()}
          </a>
        </div>
      </div>
    </article>`;
};

const projectSections = [...groupedProjects.entries()]
  .map(
    ([category, categoryProjects]) => `
      <section class="project-section" id="${slugify(category)}" aria-labelledby="${slugify(category)}-heading">
        <div class="section-heading">
          <span class="section-index">${String([...groupedProjects.keys()].indexOf(category) + 1).padStart(2, "0")}</span>
          <h2 id="${slugify(category)}-heading">${escapeHtml(category)}</h2>
          <span class="section-rule" aria-hidden="true"></span>
          <span class="section-count">${categoryProjects.length} ${categoryProjects.length === 1 ? "project" : "projects"}</span>
        </div>
        <div class="project-grid">
          ${categoryProjects.map(renderProjectCard).join("")}
        </div>
      </section>`,
  )
  .join("");

const template = fs.readFileSync(
  path.join(sourceDirectory, "template.html"),
  "utf8",
);

const output = template
  .replaceAll("{{PROJECT_COUNT}}", String(projects.length))
  .replaceAll("{{CATEGORY_NAVIGATION}}", categoryNavigation)
  .replaceAll("{{PROJECT_SECTIONS}}", projectSections);

fs.rmSync(outputDirectory, { recursive: true, force: true });
fs.mkdirSync(outputDirectory, { recursive: true });
fs.writeFileSync(path.join(outputDirectory, "index.html"), output);
fs.copyFileSync(path.join(root, ".nojekyll"), path.join(outputDirectory, ".nojekyll"));
fs.cpSync(sourceAssetsDirectory, path.join(outputDirectory, "assets"), {
  recursive: true,
});

console.log(`Built ${projects.length} projects across ${groupedProjects.size} categories.`);
