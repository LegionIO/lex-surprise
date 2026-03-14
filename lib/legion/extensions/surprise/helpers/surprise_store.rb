# frozen_string_literal: true

module Legion
  module Extensions
    module Surprise
      module Helpers
        class SurpriseStore
          attr_reader :events

          def initialize
            @events    = []
            @baselines = {}
          end

          def record(event)
            @events << event
            update_baseline(event.domain, event.magnitude)
            trim
            event
          end

          def recent(count = 10)
            @events.last(count)
          end

          def by_domain(domain)
            @events.select { |e| e.domain == domain }
          end

          def most_surprising(count = 5)
            @events.sort_by { |e| -e.magnitude }.first(count)
          end

          def baseline_for(domain)
            @baselines.fetch(domain, 0.0)
          end

          def to_h
            total    = @events.size
            domains  = @events.map(&:domain).uniq
            avg_mag  = total.positive? ? (@events.sum(&:magnitude) / total).round(4) : 0.0
            top      = most_surprising(1).first

            {
              total_events:           total,
              domain_count:           domains.size,
              average_magnitude:      avg_mag,
              most_surprising_domain: top&.domain,
              baselines:              @baselines.transform_values { |v| v.round(4) }
            }
          end

          private

          def update_baseline(domain, magnitude)
            prior = @baselines.fetch(domain, magnitude)
            alpha = Constants::SURPRISE_ALPHA
            @baselines[domain] = ((1 - alpha) * prior) + (alpha * magnitude)
          end

          def trim
            return unless @events.size > Constants::MAX_SURPRISE_HISTORY

            @events.shift(@events.size - Constants::MAX_SURPRISE_HISTORY)
          end
        end
      end
    end
  end
end
