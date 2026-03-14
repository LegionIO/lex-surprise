# frozen_string_literal: true

module Legion
  module Extensions
    module Surprise
      module Helpers
        class HabituationModel
          def initialize
            @levels = {}
          end

          def sensitivity_for(domain)
            @levels.fetch(domain, 1.0)
          end

          def habituate(domain)
            current = sensitivity_for(domain)
            floor   = Constants::DOMAIN_HABITUATION_FLOOR
            updated = [current - Constants::HABITUATION_RATE, floor].max
            @levels[domain] = updated
            enforce_domain_limit
            updated
          end

          def sensitize(domain)
            current = sensitivity_for(domain)
            updated = [current + Constants::SENSITIZATION_RATE, 1.0].min
            @levels[domain] = updated
            updated
          end

          def decay_all
            @levels.each_key do |domain|
              current = @levels[domain]
              @levels[domain] = [current + (Constants::SENSITIZATION_RATE * 0.5), 1.0].min
            end
          end

          def to_h
            {
              domains:       @levels.size,
              sensitivities: @levels.transform_values { |v| v.round(4) }
            }
          end

          private

          def enforce_domain_limit
            return unless @levels.size > Constants::MAX_DOMAINS

            oldest_key = @levels.keys.first
            @levels.delete(oldest_key)
          end
        end
      end
    end
  end
end
