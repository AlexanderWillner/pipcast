// Single source of truth for links, install commands, and metadata used across
// the site. Update these in one place rather than hunting through components.

// The page title and meta description, shared by the layout and /llms.txt. Google truncates a
// description near 160 characters, so `summary` is written to land under it rather than be cut.
export const pageTitle = "Pipcast: a free, native launcher for macOS";
export const summary =
  "A free, open source macOS launcher with app search, clipboard history, snippets, custom commands, window management, your own AI keys and Raycast extensions.";

export const site = {
  name: "Pipcast",
  repo: "https://github.com/mSarheed/pipcast",
  url: process.env.SITE_URL ?? "http://localhost:3000",
  // Shown only until the build-time release lookup resolves, and if it fails.
  fallbackVersion: "v0.1.0-beta.3",
  platform: "macOS 26+",
  license: "AGPL-3.0",
  licenseUrl: "https://github.com/mSarheed/pipcast/blob/main/LICENSE",
  community: {
    issues: "https://github.com/mSarheed/pipcast/issues",
  },
  support: "/support",
} as const;

// The hero, in as few words as possible — headline plus one punchy line.
export const hero = {
  // One entry per line: the break falls between the two sentences at every
  // width. The last line ends bare, because the hero draws a caret after it.
  headlineLines: ["Everything on your Mac.", "One keystroke away"],
  sub: "A small, native launcher for your apps, clipboard, snippets and windows. Free and open source, with no account and no telemetry.",
  // The mono line under the buttons. Each fact is stated in the docs.
  facts: ["Under 100 MB of memory", "Zero dependencies", "Free & open source"],
} as const;

export const nav = [
  { label: "Features", href: "/#features" },
  { label: "Privacy", href: "/#privacy" },
  { label: "Docs", href: "/docs" },
  { label: "Changelog", href: "/changelog" },
] as const;

// The hero's two lines. Every other channel lives in docs/install.md, which is
// where both install CTAs point.
export const brewTrustCommand = "brew trust --tap mSarheed/pipcast";
export const brewInstallCommand =
  "brew install --cask mSarheed/pipcast/pipcast@beta";

// The logo wall under the hero, in render order. The track starts at the first
// entry with the left edge under the mask, so the two least-known names lead
// and the ones worth reading land mid-viewport on load.
export const companies = [
  "voidzero",
  "bytedance",
  "apple",
  "google",
  "microsoft",
  "openai",
  "anthropic",
  "stripe",
  "cloudflare",
  "github",
  "samsung",
  "alibaba",
  "oracle",
  "redhat",
] as const;

export type Company = (typeof companies)[number];
