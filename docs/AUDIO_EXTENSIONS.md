# Hiraukan Audio Extension Contract

Status: P0 foundation (schema v1).

Hiraukan audio extensions are source providers, not MP3-only parsers. A provider may expose direct MP3/M4A/AAC/FLAC/Opus URLs or HLS playback, and may require request headers.

## Goals

- Core Hiraukan can browse and play audio without knowing site-specific parsing.
- One provider failure must not break other providers.
- Authentication is declared per extension: `none`, `optional`, or `required`.
- The core application must not require a global login before opening.
- Existing ASMR.one/HentaiASMR/EroVoice adapters remain usable while migration happens incrementally.
- ASR/transcription/translation is outside this contract and remains unchanged.

## Manifest v1

Example:

```json
{
  "schemaVersion": 1,
  "id": "miyorare.audio.example",
  "name": "Example Audio",
  "version": "1.0.0",
  "type": "audio",
  "auth": "none",
  "capabilities": ["catalog", "search", "detail", "playback", "download"],
  "languages": ["ja"],
  "minHiraukanVersion": "3.8.2"
}
```

The stable extension id is the cache and persistence namespace. It must not be changed merely because a provider changes domain.

## Runtime contract

An audio extension exposes:

1. `browse`
2. `search`
3. `getDetail`
4. `getTracks`
5. `resolvePlayback`
6. `checkHealth`

Playback resolution is intentionally separate from track metadata. This allows expiring URLs, HLS playlists, cookies, referer/origin headers, and gateway resolution to be refreshed immediately before playback.

## Authentication

- `none`: the provider must work without a Hiraukan account.
- `optional`: anonymous access is valid, but optional credentials/cookies can unlock more features.
- `required`: the extension may request its own authentication flow.

Global application login must never be used as a prerequisite for launching Hiraukan.

## Miyorare Pack direction

Miyorare should distinguish extension media type explicitly. Audio extensions use `type: "audio"`; manga extensions retain their own media type and runtime contract.

The first integration milestone is:

`install audio extension -> browse -> detail -> tracks -> playback`

Pack signing, compatibility, rollback, and last-known-good behavior should remain aligned with the existing Miyorare Source Pack trust model instead of introducing an unsigned side channel.

## Migration plan

- P0: freeze this contract and add validation/tests.
- P1: remove global login gate; keep authentication available as an optional account feature.
- P2: wrap one existing source as the reference audio extension.
- P3: add Miyorare Pack discovery/install/update/remove support for `type: audio`.
- P4: migrate ASMR.one, HentaiASMR, and EroVoice incrementally.
- P5: harden cache, fallback, health, compatibility, rollback, and failure isolation.

Do not delete the existing Unified Sources layer during P0-P2. It is the compatibility bridge while extensions are introduced.


## Sealed Miyorare catalog discovery

Hiraukan schema v1 discovers audio extension metadata from the latest stable
`Noirero/Miyorare-Source-Packs` release when that release includes
`miyorare-audio-extensions.json`.

Before accepting the catalog, Hiraukan requires:

- the stable Source Pack tag format;
- `miyorare-release-lock.json`;
- `miyorare-release-lock.sha256`;
- an immutable lock created before stable publication;
- a lock entry for the audio catalog with matching byte size and SHA-256.

A validated catalog is stored locally as last-known-good. Network failure, API
rate limiting, or a later release temporarily omitting the audio asset does not
erase the last-known-good catalog. If no validated remote/LKG catalog exists,
Hiraukan falls back to the compatible runtimes bundled in the application.

Schema v1 still uses `delivery.kind = "builtin"`. A remote catalog can
announce a newer extension version, but Hiraukan only enables it when the
bundled runtime has compatible version/auth/capabilities. Unknown runtimes are
shown as requiring an application update instead of being downloaded or
executed.
