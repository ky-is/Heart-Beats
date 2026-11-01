# Heart Beats site

The landing page at https://heartbeats.ky.is: Vite+, Vue Vapor, TypeScript, deployed to Cloudflare Workers static assets with `cf`.

- `pnpm run dev` serves it locally, `pnpm run deploy` builds and deploys.
- `public/covers` are cut from the Mac App Store screenshot by `pnpm run covers`, `public/og.png` is drawn by `pnpm run og`. Both need ImageMagick.
- `public/screens` are the App Store screenshots from `../fastlane/screenshots`, converted to WebP.
