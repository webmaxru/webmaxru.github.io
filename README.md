# webmaxru.github.io

Minimal portfolio site for Maxim's projects and experiments.

## Local development

The project catalog lives in [`projects.json`](projects.json). Edit the JSON, then build the static site:

```bash
npm run build
```

The generated site is written to `dist/`. Project metadata is rendered at build time; thumbnails are loaded from their GitHub social previews when the page is viewed.

Each project can set `thumbnail` to a verified social-preview or README image URL. Use `"generated"` when a repository has no useful image, which produces a neutral project-specific visual instead of a generic GitHub card.

## GitHub Pages

The workflow in `.github/workflows/pages.yml` builds the site and deploys `dist/` to GitHub Pages whenever `master` changes. Enable GitHub Actions as the repository's Pages source once, then pushes to `master` will publish the site.
