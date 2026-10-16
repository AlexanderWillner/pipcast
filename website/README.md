# Pipcast website

This is the static website source; no Pipcast domain or deployment is configured.

```sh
npm ci
npm run dev
npm run build
npm run lint
```

Set `SITE_URL` to the deployment origin before a production build so metadata, the sitemap,
and documentation URLs use the correct host. Local development defaults to localhost:3000.
The shared vector logo is in `src/components/ui/icon.tsx`; the original artwork is
`../docs/branding/pipcast-logo.svg`. Historical Tinycast screenshots and donation checkout
were removed; add screenshots of Pipcast before publishing a new gallery.

Pipcast is an independent fork of [Tinycast](https://github.com/abue-ammar/tinycast),
created by Abue Ammar and contributors. See the repository LICENSE and NOTICE.md.
