# lex-surprise

**Level 3 Leaf Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Gem**: `lex-surprise`
- **Version**: `0.1.0`
- **Namespace**: `Legion::Extensions::Surprise`

## Purpose

Tracks surprise magnitude per domain, adjusting for current habituation level and emotional valence. Repeated exposures to similar prediction errors habituate the surprise response (sensitivity decreases); novel patterns can sensitize it. An orienting response cooldown prevents the agent from repeatedly re-orienting to the same surprising domain within a short window. Integrates with `lex-tick` by reading resolved predictions from tick_results.

## Gem Info

- **Gem name**: `lex-surprise`
- **License**: MIT
- **Ruby**: >= 3.4
- **No runtime dependencies** beyond the Legion framework

## File Structure

```
lib/legion/extensions/surprise/
  version.rb                    # VERSION = '0.1.0'
  helpers/
    constants.rb                # thresholds, habituation/sensitization rates, valence weights, labels
    habituation_model.rb        # HabituationModel class — per-domain sensitivity tracking
    surprise_store.rb           # SurpriseStore class — surprise event records with EMA baseline
  runners/
    surprise.rb                 # Runners::Surprise module — all public runner methods
  client.rb                     # Client class including Runners::Surprise
```

## Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `SURPRISE_THRESHOLD` | 0.4 | Surprise magnitude above this triggers an orienting response |
| `HABITUATION_RATE` | 0.05 | Sensitivity decrease per `habituate` call |
| `SENSITIZATION_RATE` | 0.02 | Sensitivity increase per `sensitize` call + recovery rate |
| `SURPRISE_DECAY` | 0.1 | Per-tick decay for stored surprise magnitudes |
| `MAX_SURPRISE_HISTORY` | 200 | Maximum surprise event records |
| `SURPRISE_ALPHA` | 0.15 | EMA alpha for baseline prediction error per domain |
| `VALENCE_WEIGHTS` | hash | Multipliers: `positive: 0.6, negative: 1.0, neutral: 0.3` |
| `MAX_DOMAINS` | 50 | Maximum domains tracked for habituation |
| `ORIENTING_COOLDOWN` | 3 | Ticks between orienting responses for the same domain |

## Helpers

### `Helpers::HabituationModel`

Per-domain sensitivity tracking.

- `initialize` — sensitivities hash defaulting to 1.0 per domain
- `sensitivity_for(domain)` — returns current sensitivity; defaults to 1.0 if unseen
- `habituate(domain)` — decrements sensitivity by HABITUATION_RATE; floors at 0.1
- `sensitize(domain)` — increments sensitivity by SENSITIZATION_RATE; caps at 1.0
- `decay_all` — all sensitivities recover gently: `sensitivity + SENSITIZATION_RATE * 0.5` (passive sensitization toward 1.0)

### `Helpers::SurpriseStore`

Surprise event records with per-domain EMA baseline.

- `initialize` — events array, baselines hash (EMA of prediction error per domain)
- `record(domain:, magnitude:, predicted:, actual:, valence: :neutral)` — appends event; updates EMA baseline: `baseline = baseline + SURPRISE_ALPHA * (magnitude - baseline)`; trims to MAX_SURPRISE_HISTORY
- `recent(limit: 10)` — last N events
- `by_domain(domain)` — all events for a domain
- `most_surprising(limit: 5)` — sorted by magnitude descending
- `baseline_for(domain)` — current EMA baseline prediction error for domain

## Runners

All runners are in `Runners::Surprise`. The `Client` includes this module and owns a `HabituationModel` and `SurpriseStore` instance.

| Runner | Parameters | Returns |
|---|---|---|
| `evaluate_surprise` | `domain:, predicted:, actual:, valence: :neutral` | `{ success:, domain:, magnitude:, orienting_response:, sensitivity: }` |
| `update_surprise` | `tick_results: {}` | `{ success:, surprises: }` — reads `tick_results[:predictions]`, evaluates each prediction, calls habituation decay + tick_cooldowns |
| `surprise_stats` | (none) | Total events, most surprising domain, mean baseline, habituation distribution |
| `domain_sensitivity` | `domain:` | `{ success:, domain:, sensitivity: }` |
| `recent_surprises` | `limit: 10` | `{ success:, surprises:, count: }` |
| `reset_habituation` | `domain:` | `{ success:, domain: }` — calls `sensitize` + resets cooldown |

### `evaluate_surprise` Details

Computes: `magnitude = |predicted - actual| * sensitivity * valence_weight`
- `sensitivity` = `@habituation_model.sensitivity_for(domain)`
- `valence_weight` = VALENCE_WEIGHTS[valence] (negative surprises weighted 1.0, positive 0.6, neutral 0.3)
- If `magnitude >= SURPRISE_THRESHOLD` AND `cooldowns[domain].nil? || cooldowns[domain] <= 0`: sets `orienting_response: true` and `cooldowns[domain] = ORIENTING_COOLDOWN`
- Calls `habituate(domain)` regardless of magnitude threshold
- Records event via `@store.record`

### `update_surprise` Details

Reads `tick_results.dig(:predictions)` (array of `{ domain:, predicted:, actual:, valence: }` hashes), evaluates each via `evaluate_surprise`, then:
1. Calls `@habituation_model.decay_all` (passive recovery)
2. Decrements all cooldown counters by 1 (tick_cooldowns)

## Integration Points

- **lex-tick / lex-cortex**: `update_surprise` wired as a tick handler reads prediction outcomes and fires orienting responses automatically
- **lex-prediction**: resolved predictions from lex-prediction provide the `predicted` and `actual` values for surprise evaluation
- **lex-sensory-gating**: orienting response from `evaluate_surprise` should trigger `sensitize!` on the relevant sensory filter
- **lex-emotion**: high-magnitude negative surprises (`valence: :negative, magnitude >= SURPRISE_THRESHOLD`) can drive emotional valence updates
- **lex-attention**: orienting response is the trigger for attention shifting; the domain with the surprise is where attention should redirect

## Development Notes

- `VALENCE_WEIGHTS[:negative] = 1.0` vs `[:positive] = 0.6` — negative surprises carry full weight, modeling the negativity bias in orienting responses
- `cooldowns` is a plain hash on the runner instance; it is ticked down in `update_surprise` each cycle, not in real time
- `ORIENTING_COOLDOWN = 3` ticks means the same domain won't trigger repeated orienting within 3 consecutive ticks
- Habituation floors at 0.1, not 0.0 — the agent can always be minimally surprised by a domain
- `decay_all` on the habituation model applies `+SENSITIZATION_RATE * 0.5` gentle recovery — this ensures domains not recently stimulated slowly return to full sensitivity (forgetting habituation)
