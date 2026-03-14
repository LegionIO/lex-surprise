# frozen_string_literal: true

module Legion
  module Extensions
    module Surprise
      module Runners
        module Surprise
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          # Evaluate a single prediction-outcome pair and compute surprise magnitude.
          # magnitude = |predicted - actual| * sensitivity * valence_weight, clamped to [0,1]
          def evaluate_surprise(domain:, predicted:, actual:, valence: :neutral, **)
            sensitivity = habituation_model.sensitivity_for(domain)
            valence_weight = Helpers::Constants::VALENCE_WEIGHTS.fetch(valence, 0.3)
            raw_diff       = (predicted.to_f - actual.to_f).abs
            magnitude      = (raw_diff * sensitivity * valence_weight).clamp(0.0, 1.0)

            threshold    = Helpers::Constants::SURPRISE_THRESHOLD
            orienting    = should_orient?(domain, magnitude, threshold)

            event = Helpers::SurpriseEvent.new(
              domain:    domain,
              predicted: predicted,
              actual:    actual,
              magnitude: magnitude,
              valence:   valence,
              orienting: orienting
            )

            store.record(event)
            habituation_model.habituate(domain)

            if orienting
              record_cooldown(domain)
              Legion::Logging.debug "[surprise] orienting response triggered: domain=#{domain} magnitude=#{magnitude.round(3)}"
            else
              Legion::Logging.debug "[surprise] surprise recorded: domain=#{domain} magnitude=#{magnitude.round(3)} orienting=false"
            end

            { success: true, surprise_event: event.to_h, orienting_triggered: orienting }
          end

          # Per-tick update: extract domain predictions from tick_result, compute surprise for each,
          # decay the store's baseline tracking, and return a summary.
          def update_surprise(tick_result: {}, **)
            predictions = extract_predictions(tick_result)
            events      = []

            predictions.each do |pred|
              next unless pred[:domain] && !pred[:predicted].nil? && !pred[:actual].nil?

              result = evaluate_surprise(
                domain:    pred[:domain],
                predicted: pred[:predicted],
                actual:    pred[:actual],
                valence:   pred.fetch(:valence, :neutral)
              )
              events << result[:surprise_event] if result[:success]
            end

            habituation_model.decay_all
            tick_cooldowns

            orienting_count = events.count { |e| e[:orienting] }
            Legion::Logging.debug "[surprise] tick update: evaluated=#{events.size} orienting=#{orienting_count}"

            {
              success:         true,
              evaluated:       events.size,
              orienting_count: orienting_count,
              events:          events
            }
          end

          def surprise_stats(**)
            stats   = store.to_h
            top     = store.most_surprising(1).first
            avg_mag = stats[:average_magnitude]

            Legion::Logging.debug "[surprise] stats: total=#{stats[:total_events]} domains=#{stats[:domain_count]}"

            {
              success:                true,
              total_events:           stats[:total_events],
              domain_count:           stats[:domain_count],
              average_magnitude:      avg_mag,
              most_surprising_domain: stats[:most_surprising_domain],
              top_surprise_magnitude: top&.magnitude&.round(4)
            }
          end

          def domain_sensitivity(domain:, **)
            sensitivity = habituation_model.sensitivity_for(domain)
            baseline    = store.baseline_for(domain)
            domain_events = store.by_domain(domain)

            Legion::Logging.debug "[surprise] domain_sensitivity: domain=#{domain} sensitivity=#{sensitivity.round(3)}"

            {
              success:     true,
              domain:      domain,
              sensitivity: sensitivity.round(4),
              baseline:    baseline.round(4),
              event_count: domain_events.size
            }
          end

          def recent_surprises(count: 10, **)
            events = store.recent(count)
            Legion::Logging.debug "[surprise] recent_surprises: count=#{events.size}"
            { success: true, events: events.map(&:to_h), count: events.size }
          end

          def reset_habituation(domain:, **)
            old_sensitivity = habituation_model.sensitivity_for(domain)
            # Sensitize repeatedly to push back toward 1.0
            steps = ((1.0 - old_sensitivity) / Helpers::Constants::SENSITIZATION_RATE).ceil
            steps.times { habituation_model.sensitize(domain) }
            new_sensitivity = habituation_model.sensitivity_for(domain)

            Legion::Logging.debug "[surprise] reset_habituation: domain=#{domain} #{old_sensitivity.round(3)} -> #{new_sensitivity.round(3)}"

            { success: true, domain: domain, old_sensitivity: old_sensitivity.round(4), new_sensitivity: new_sensitivity.round(4) }
          end

          private

          def store
            @store ||= Helpers::SurpriseStore.new
          end

          def habituation_model
            @habituation_model ||= Helpers::HabituationModel.new
          end

          def cooldowns
            @cooldowns ||= {}
          end

          def tick_cooldowns
            cooldowns.each_key { |domain| cooldowns[domain] -= 1 }
            cooldowns.reject! { |_, ticks_left| ticks_left <= 0 }
          end

          def record_cooldown(domain)
            cooldowns[domain] = Helpers::Constants::ORIENTING_COOLDOWN
          end

          def on_cooldown?(domain)
            (cooldowns[domain] || 0).positive?
          end

          def should_orient?(domain, magnitude, threshold)
            return false if magnitude < threshold
            return false if on_cooldown?(domain)

            true
          end

          def extract_predictions(tick_result)
            return [] unless tick_result.is_a?(Hash)

            tick_result.fetch(:predictions, [])
          end
        end
      end
    end
  end
end
