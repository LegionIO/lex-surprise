# frozen_string_literal: true

module Legion
  module Extensions
    module Surprise
      module Helpers
        module Constants
          SURPRISE_THRESHOLD = 0.4

          HABITUATION_RATE = 0.05

          SENSITIZATION_RATE = 0.02

          SURPRISE_DECAY = 0.1

          MAX_SURPRISE_HISTORY = 200

          SURPRISE_ALPHA = 0.15

          VALENCE_WEIGHTS = { positive: 0.6, negative: 1.0, neutral: 0.3 }.freeze

          DOMAIN_HABITUATION_FLOOR = 0.1

          MAX_DOMAINS = 50

          ORIENTING_COOLDOWN = 3
        end
      end
    end
  end
end
