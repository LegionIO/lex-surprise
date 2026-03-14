# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Surprise::Helpers::HabituationModel do
  subject(:model) { described_class.new }

  let(:floor) { Legion::Extensions::Surprise::Helpers::Constants::DOMAIN_HABITUATION_FLOOR }
  let(:habituation_rate) { Legion::Extensions::Surprise::Helpers::Constants::HABITUATION_RATE }
  let(:sensitization_rate) { Legion::Extensions::Surprise::Helpers::Constants::SENSITIZATION_RATE }

  describe '#sensitivity_for' do
    it 'returns 1.0 for unknown domains (fully sensitive)' do
      expect(model.sensitivity_for(:new_domain)).to eq(1.0)
    end

    it 'returns the stored sensitivity for a known domain' do
      model.habituate(:known)
      expect(model.sensitivity_for(:known)).to be < 1.0
    end
  end

  describe '#habituate' do
    it 'reduces sensitivity by HABITUATION_RATE' do
      initial = model.sensitivity_for(:domain_a)
      model.habituate(:domain_a)
      expect(model.sensitivity_for(:domain_a)).to be_within(0.0001).of(initial - habituation_rate)
    end

    it 'never goes below DOMAIN_HABITUATION_FLOOR' do
      100.times { model.habituate(:floor_domain) }
      expect(model.sensitivity_for(:floor_domain)).to be >= floor
    end

    it 'returns the updated sensitivity' do
      result = model.habituate(:returning_domain)
      expect(result).to eq(model.sensitivity_for(:returning_domain))
    end

    it 'habituates different domains independently' do
      model.habituate(:domain_x)
      expect(model.sensitivity_for(:domain_y)).to eq(1.0)
    end
  end

  describe '#sensitize' do
    it 'increases sensitivity toward 1.0' do
      model.habituate(:sens_domain)
      before = model.sensitivity_for(:sens_domain)
      model.sensitize(:sens_domain)
      expect(model.sensitivity_for(:sens_domain)).to be > before
    end

    it 'never exceeds 1.0' do
      100.times { model.sensitize(:fresh_domain) }
      expect(model.sensitivity_for(:fresh_domain)).to be <= 1.0
    end

    it 'returns the updated sensitivity' do
      model.habituate(:ret_domain)
      result = model.sensitize(:ret_domain)
      expect(result).to eq(model.sensitivity_for(:ret_domain))
    end

    it 'increases by SENSITIZATION_RATE when below 1.0' do
      model.habituate(:rate_domain)
      before = model.sensitivity_for(:rate_domain)
      model.sensitize(:rate_domain)
      expect(model.sensitivity_for(:rate_domain)).to be_within(0.0001).of(before + sensitization_rate)
    end
  end

  describe '#decay_all' do
    it 'slightly recovers sensitivity across all domains' do
      model.habituate(:d1)
      model.habituate(:d2)
      before_d1 = model.sensitivity_for(:d1)
      before_d2 = model.sensitivity_for(:d2)
      model.decay_all
      expect(model.sensitivity_for(:d1)).to be > before_d1
      expect(model.sensitivity_for(:d2)).to be > before_d2
    end

    it 'does not push sensitivity above 1.0' do
      model.decay_all
      expect(model.sensitivity_for(:d1)).to be <= 1.0
    end

    it 'has no effect when no domains are tracked' do
      expect { model.decay_all }.not_to raise_error
    end
  end

  describe '#to_h' do
    it 'returns a hash with domains and sensitivities keys' do
      model.habituate(:d1)
      h = model.to_h
      expect(h).to include(:domains, :sensitivities)
    end

    it 'reports correct domain count' do
      model.habituate(:alpha)
      model.habituate(:beta)
      expect(model.to_h[:domains]).to eq(2)
    end

    it 'rounds sensitivity values to 4 decimal places' do
      model.habituate(:precision_domain)
      h = model.to_h
      h[:sensitivities].each_value do |v|
        expect(v.to_s.length).to be <= 7
      end
    end

    it 'returns 0 domains when nothing tracked' do
      expect(model.to_h[:domains]).to eq(0)
    end
  end

  describe 'domain limit enforcement' do
    it 'does not exceed MAX_DOMAINS tracked domains' do
      max = Legion::Extensions::Surprise::Helpers::Constants::MAX_DOMAINS
      (max + 10).times { |i| model.habituate(:"domain_#{i}") }
      expect(model.to_h[:domains]).to be <= max
    end
  end
end
