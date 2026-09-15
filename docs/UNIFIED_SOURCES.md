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

1. DLsite-style RJ/BJ/VJ identity when available.
2. Otherwise normalized title + creator/circle when both are known.
3. Otherwise keep items separate. Title-only fuzzy matching is intentionally not used.

This avoids merging unrelated works that happen to share a title.

## Playback flow

The unified detail page resolves a source before handing tracks to the existing KikoFlu audio player.

Source priority in Auto mode:

1. ASMR.one
2. HentaiASMR
3. EroVoice

A user can choose a preferred source. If that source cannot return playable tracks, resolution falls back to the next available source. The existing player, queue, speed controls, sleep timer and background playback are reused instead of introducing a second player.

Fallback currently happens while resolving/loading a work. Mid-track network failure does not silently switch to a different provider because track alignment and playback-position equivalence cannot be guaranteed safely without additional validation.

## State and identity

`UnifiedSourceRegistry` associates the displayed `Work.id` with all provider references for that logical work. External-only results use deterministic negative IDs to avoid colliding with Kikoeru integer IDs. When ASMR.one is present it remains the preferred primary representation so existing KikoFlu behavior is preserved as much as possible.

## Health isolation

Each source reports `HEALTHY`, `DEGRADED`, `BROKEN` or `UNKNOWN` at the adapter layer. Federated search catches source-specific failures independently; a broken EroVoice or HentaiASMR request does not discard successful ASMR.one results, and vice versa.

## Network notes

The existing Android project already permits clear-text traffic, and the existing iOS configuration already allows arbitrary network loads. EroVoice therefore can attempt its HTTP endpoint when HTTPS is unavailable without adding broader permissions in this branch.

## Known runtime-verification boundary

ASMR.one uses the established API path already used by KikoFlu. HentaiASMR's current public catalog exposes RJ-linked work pages, but the exact work-page audio markup can change, so its isolated parser needs device smoke testing. EroVoice has recently been intermittently unreachable from external probes, so its adapter is designed to fail closed while the other providers continue working.

## Safety rule for promotion

Do not merge this branch to `main` merely because source parsing compiles. Before promotion, require:

- focused unit tests green;
- Flutter analysis green for touched code;
- Android build/smoke test green;
- search test where one provider is unavailable;
- duplicate RJ test across at least two providers;
- playback test from each currently reachable provider;
- confirmation that existing ASMR.one-only search/player behavior still works.
