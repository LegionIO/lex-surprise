# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Surprise::Helpers::Constants do
  describe 'SURPRISE_THRESHOLD' do
    it 'is a float between 0 and 1' do
      expect(described_class::SURPRISE_THRESHOLD).to be_a(Float)
      expect(described_class::SURPRISE_THRESHOLD).to be_between(0.0, 1.0).exclusive
    end

    it 'is 0.4' do
      expect(described_class::SURPRISE_THRESHOLD).to eq(0.4)
    end
  end

  describe 'HABITUATION_RATE' do
    it 'is a positive float less than 1' do
      expect(described_class::HABITUATION_RATE).to be_a(Float)
      expect(described_class::HABITUATION_RATE).to be_between(0.0, 1.0).exclusive
    end
  end

  describe 'SENSITIZATION_RATE' do
    it 'is a positive float less than HABITUATION_RATE' do
      expect(described_class::SENSITIZATION_RATE).to be < described_class::HABITUATION_RATE
    end
  end

  describe 'SURPRISE_DECAY' do
    it 'is a positive float between 0 and 1' do
      expect(described_class::SURPRISE_DECAY).to be_a(Float)
      expect(described_class::SURPRISE_DECAY).to be_between(0.0, 1.0).exclusive
    end
  end

  describe 'MAX_SURPRISE_HISTORY' do
    it 'is a positive integer' do
      expect(described_class::MAX_SURPRISE_HISTORY).to be_a(Integer)
      expect(described_class::MAX_SURPRISE_HISTORY).to be > 0
    end

    it 'is 200' do
      expect(described_class::MAX_SURPRISE_HISTORY).to eq(200)
    end
  end

  describe 'SURPRISE_ALPHA' do
    it 'is an EMA alpha between 0 and 1' do
      expect(described_class::SURPRISE_ALPHA).to be_a(Float)
      expect(described_class::SURPRISE_ALPHA).to be_between(0.0, 1.0).exclusive
    end
  end

  describe 'VALENCE_WEIGHTS' do
    it 'contains positive, negative, and neutral keys' do
      expect(described_class::VALENCE_WEIGHTS.keys).to contain_exactly(:positive, :negative, :neutral)
    end

    it 'weights negative surprise higher than positive' do
      expect(described_class::VALENCE_WEIGHTS[:negative]).to be > described_class::VALENCE_WEIGHTS[:positive]
    end

    it 'weights negative surprise highest' do
      expect(described_class::VALENCE_WEIGHTS[:negative]).to eq(described_class::VALENCE_WEIGHTS.values.max)
    end

    it 'is frozen' do
      expect(described_class::VALENCE_WEIGHTS).to be_frozen
    end

    it 'has all positive float values' do
      described_class::VALENCE_WEIGHTS.each_value do |v|
        expect(v).to be_a(Float)
        expect(v).to be > 0.0
      end
    end
  end

  describe 'DOMAIN_HABITUATION_FLOOR' do
    it 'is a positive float less than 1' do
      expect(described_class::DOMAIN_HABITUATION_FLOOR).to be_a(Float)
      expect(described_class::DOMAIN_HABITUATION_FLOOR).to be_between(0.0, 1.0).exclusive
    end

    it 'is less than SURPRISE_THRESHOLD' do
      expect(described_class::DOMAIN_HABITUATION_FLOOR).to be < described_class::SURPRISE_THRESHOLD
    end
  end

  describe 'MAX_DOMAINS' do
    it 'is a positive integer' do
      expect(described_class::MAX_DOMAINS).to be_a(Integer)
      expect(described_class::MAX_DOMAINS).to be > 0
    end

    it 'is 50' do
      expect(described_class::MAX_DOMAINS).to eq(50)
    end
  end

  describe 'ORIENTING_COOLDOWN' do
    it 'is a positive integer' do
      expect(described_class::ORIENTING_COOLDOWN).to be_a(Integer)
      expect(described_class::ORIENTING_COOLDOWN).to be > 0
    end

    it 'is 3' do
      expect(described_class::ORIENTING_COOLDOWN).to eq(3)
    end
  end
end
