# frozen_string_literal: true

require_relative 'lib/legion/extensions/surprise/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-surprise'
  spec.version       = Legion::Extensions::Surprise::VERSION
  spec.authors       = ['Matthew Iverson']
  spec.email         = ['matt@legionIO.com']
  spec.summary       = 'Orienting response and surprise detection for LegionIO cognitive agents'
  spec.description   = 'Detects when reality deviates from expectations using Bayesian surprise (KL divergence). ' \
                       'Tracks habituation, generates orienting signals, and adapts sensitivity per domain.'
  spec.homepage      = 'https://github.com/LegionIO/lex-surprise'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.add_development_dependency 'legion-gaia'
end
