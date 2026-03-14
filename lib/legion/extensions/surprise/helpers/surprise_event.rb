# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module Surprise
      module Helpers
        class SurpriseEvent
          attr_reader :id, :domain, :predicted, :actual, :magnitude, :valence, :timestamp, :orienting

          def initialize(domain:, predicted:, actual:, magnitude:, valence:, orienting: false) # rubocop:disable Metrics/ParameterLists
            @id        = SecureRandom.uuid
            @domain    = domain
            @predicted = predicted
            @actual    = actual
            @magnitude = magnitude.clamp(0.0, 1.0)
            @valence   = valence
            @orienting = orienting
            @timestamp = Time.now.utc
          end

          def to_h
            {
              id:        @id,
              domain:    @domain,
              predicted: @predicted,
              actual:    @actual,
              magnitude: @magnitude.round(4),
              valence:   @valence,
              orienting: @orienting,
              timestamp: @timestamp
            }
          end
        end
      end
    end
  end
end
