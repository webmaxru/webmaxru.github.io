# webmaxru.github.io

Minimal portfolio site for Maxim's projects and experiments.

## Local development

The project catalog lives in [`projects.json`](projects.json). Edit the JSON, then build the static site:

```bash
npm run build
```

The generated site is written to `dist/`. Project metadata is rendered at build time; thumbnails are loaded from their GitHub social previews when the page is viewed.

## GitHub Pages

The workflow in `.github/workflows/pages.yml` builds the site and deploys `dist/` to GitHub Pages whenever `master` changes. Enable GitHub Actions as the repository's Pages source once, then pushes to `master` will publish the site.
