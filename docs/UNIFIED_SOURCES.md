# KikoFlu Unified Sources

This branch adds a source-agnostic discovery and playback layer on top of the existing KikoFlu player.

## Sources

- ASMR.one — reuses the existing `KikoeruApiService`.
- HentaiASMR — isolated HTML adapter.
- EroVoice — isolated Blogger-feed/HTML adapter with HTTPS → HTTP fallback.

A source failure must not make the other sources unusable.

## Search flow

`SearchResultNotifier` performs federated search for ordinary keyword/RJ queries. Advanced Kikoeru-only syntax containing `$` and direct VA/tag searches stay on the existing Kikoeru backend.

Results are normalized into `SourceWorkCandidate` and grouped into one logical `UnifiedWorkBundle`.

Deduplication rules are deliberately conservative:

1. Merge only when an exact DLsite-style RJ/BJ/VJ identity can be extracted and normalized.
2. Zero-padding differences in the same RJ/BJ/VJ identity are treated as the same work.
3. If no canonical identity is available, keep results namespaced to their provider/local id even when title and creator/circle match.

False merges are more damaging than duplicates, so title/creator similarity is never sufficient by itself to combine works.

## Playback flow

The unified detail page resolves a source before handing tracks to the existing KikoFlu audio player.

Source priority in Auto mode:

1. ASMR.one
2. HentaiASMR
3. EroVoice

A user can choose a preferred source. If that source cannot return playable tracks, resolution falls back to the next available source. The existing player, queue, speed controls, sleep timer and background playback are reused instead of introducing a second player.

Fallback currently happens while resolving/loading a work. Mid-track network failure does not silently switch to a different provider because track alignment and playback-position equivalence cannot be guaranteed safely without additional validation.

## State and identity

Unified identity is provider-order independent. Exact RJ identity maps to the numeric RJ id used by legacy Kikoeru/ASMR.one state, so History/Favorites/playlists that already key by `Work.id` keep the same identity in the normal RJ case. BJ/VJ and provider-local works use deterministic namespaced negative ids to avoid collisions and source-order changes.

`UnifiedSourceRegistry` is keyed by both stable `Work.id` and canonical key. Old development ids are retained as in-memory aliases when encountered. Normal All/Popular/Recommended grids opt out of unified rendering, so a prior federated search cannot accidentally turn a normal Kikoeru card into a unified card merely because an integer id is present in the registry.

Multi-source references are persisted only for works the user actually opens or plays. On restart the resolver hydrates those mirrors before detail/playback resolution, preserving fallback availability without permanently caching every search result.

## Health isolation

Each source reports `HEALTHY`, `DEGRADED`, `BROKEN` or `UNKNOWN` at the adapter layer. Federated search catches source-specific failures independently; a broken EroVoice or HentaiASMR request does not discard successful ASMR.one results, and vice versa.

ASMR.one health probes the configured API rather than generic device connectivity.

## Network notes

The existing Android project already permits clear-text traffic, and the existing iOS configuration already allows arbitrary network loads. EroVoice therefore can attempt its HTTP endpoint when HTTPS is unavailable without adding broader permissions in this branch. Those broad settings predate Unified Sources and are intentionally not tightened here because KikoFlu also supports user-configured/local HTTP Kikoeru servers.

## Runtime verification boundary

ASMR.one uses the established API path already used by KikoFlu. HentaiASMR's current public catalog exposes RJ-linked work pages, matching the adapter's catalog parser. Work-page media markup remains isolated behind its adapter because it can change independently of KikoFlu.

EroVoice is treated as optional and fail-closed. When its HTTPS/HTTP endpoint or Blogger feed cannot be reached, its search/health state becomes unavailable while ASMR.one and HentaiASMR continue independently.

## Promotion gate

Do not merge this branch to `main` merely because source parsing compiles. Before promotion, require:

- focused unit tests green;
- Flutter analysis green for touched code;
- Android build/smoke test green;
- search test where one provider is unavailable;
- duplicate RJ test across at least two providers;
- playback test from each currently reachable provider;
- confirmation that existing ASMR.one-only search/player behavior still works.

The original full multi-platform `Build test` workflow must remain present. Development-only focused/test-signing workflows must not be promoted into `main` unless explicitly adopted as a permanent CI policy.
