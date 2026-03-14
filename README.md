# lex-surprise

Surprise detection and habituation for LegionIO cognitive agents. Tracks prediction errors per domain with habituation (repeated surprises become less impactful) and orienting response management.

## What It Does

`lex-surprise` evaluates how surprising a prediction outcome is, adjusted for the agent's current sensitivity to that domain. Surprise magnitude is computed as `|predicted - actual| * sensitivity * valence_weight`. When magnitude crosses the threshold, an orienting response fires — but only if the domain's cooldown has elapsed, preventing repeated re-orienting to the same domain.

- **Habituation**: sensitivity decreases on each surprise in a domain (floors at 0.1)
- **Recovery**: sensitivity slowly recovers toward 1.0 each tick when no surprises occur
- **Valence weighting**: negative surprises (1.0x), positive surprises (0.6x), neutral (0.3x)
- **Orienting cooldown**: 3 ticks between orienting responses for the same domain
- **EMA baseline**: per-domain running average of prediction error magnitude

## Usage

```ruby
require 'legion/extensions/surprise'

client = Legion::Extensions::Surprise::Client.new

# Evaluate a surprise event
client.evaluate_surprise(
  domain: :weather,
  predicted: 0.2,
  actual: 0.9,
  valence: :negative
)
# => { magnitude: 0.7, orienting_response: true, sensitivity: 1.0 }

# Same domain, next tick — sensitivity has decreased
client.evaluate_surprise(domain: :weather, predicted: 0.2, actual: 0.9, valence: :negative)
# => { magnitude: 0.665, orienting_response: false, sensitivity: 0.95 }
# (orienting_response: false because cooldown hasn't elapsed)

# Check current domain sensitivity
client.domain_sensitivity(domain: :weather)
# => { sensitivity: 0.9 }

# Recent surprises
client.recent_surprises(limit: 5)

# Reset habituation for a domain (e.g., after significant context change)
client.reset_habituation(domain: :weather)

# Per-tick integration (reads tick_results[:predictions])
client.update_surprise(tick_results: tick_output)

# Stats
client.surprise_stats
# => { total_events:, most_surprising_domain:, mean_baseline:, habituation_distribution: }
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
