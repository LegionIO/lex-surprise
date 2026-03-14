# frozen_string_literal: true

require_relative 'surprise/version'
require_relative 'surprise/helpers/constants'
require_relative 'surprise/helpers/surprise_event'
require_relative 'surprise/helpers/habituation_model'
require_relative 'surprise/helpers/surprise_store'
require_relative 'surprise/runners/surprise'
require_relative 'surprise/client'

module Legion
  module Extensions
    module Surprise
      extend Legion::Extensions::Core if defined?(Legion::Extensions::Core)
    end
  end
end
