# frozen_string_literal: true

require 'rspec'

# Stub Legion modules for standalone testing
module Legion
  module Extensions
    module Helpers
      module Lex; end
    end

    module Core; end
  end

  module Logging
    def self.debug(*); end
    def self.info(*); end
    def self.warn(*); end
    def self.error(*); end
  end
end

require 'legion/extensions/surprise'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end
