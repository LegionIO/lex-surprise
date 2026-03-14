# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Surprise::Helpers::SurpriseEvent do
  let(:event) do
    described_class.new(
      domain:    :sensor,
      predicted: 0.5,
      actual:    0.9,
      magnitude: 0.6,
      valence:   :negative
    )
  end

  describe '#initialize' do
    it 'assigns a uuid id' do
      expect(event.id).to be_a(String)
      expect(event.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'assigns domain' do
      expect(event.domain).to eq(:sensor)
    end

    it 'assigns predicted value' do
      expect(event.predicted).to eq(0.5)
    end

    it 'assigns actual value' do
      expect(event.actual).to eq(0.9)
    end

    it 'clamps magnitude to [0.0, 1.0]' do
      expect(event.magnitude).to be_between(0.0, 1.0)
    end

    it 'assigns valence' do
      expect(event.valence).to eq(:negative)
    end

    it 'defaults orienting to false' do
      expect(event.orienting).to be false
    end

    it 'sets timestamp to current UTC time' do
      expect(event.timestamp).to be_a(Time)
    end

    it 'clamps magnitude above 1.0 down to 1.0' do
      e = described_class.new(domain: :x, predicted: 0.0, actual: 0.0, magnitude: 5.0, valence: :neutral)
      expect(e.magnitude).to eq(1.0)
    end

    it 'clamps magnitude below 0.0 up to 0.0' do
      e = described_class.new(domain: :x, predicted: 0.0, actual: 0.0, magnitude: -1.0, valence: :neutral)
      expect(e.magnitude).to eq(0.0)
    end

    it 'accepts orienting: true' do
      e = described_class.new(domain: :x, predicted: 0.1, actual: 0.9, magnitude: 0.8, valence: :negative, orienting: true)
      expect(e.orienting).to be true
    end
  end

  describe '#to_h' do
    subject(:hash) { event.to_h }

    it 'includes all required keys' do
      expect(hash.keys).to contain_exactly(:id, :domain, :predicted, :actual, :magnitude, :valence, :orienting, :timestamp)
    end

    it 'rounds magnitude to 4 decimal places' do
      e = described_class.new(domain: :d, predicted: 0.1, actual: 0.2, magnitude: 0.123456789, valence: :neutral)
      expect(e.to_h[:magnitude]).to eq(0.1235)
    end

    it 'preserves domain as-is' do
      expect(hash[:domain]).to eq(:sensor)
    end

    it 'preserves valence as symbol' do
      expect(hash[:valence]).to eq(:negative)
    end

    it 'returns false for orienting when not set' do
      expect(hash[:orienting]).to be false
    end

    it 'each call produces the same id' do
      expect(event.to_h[:id]).to eq(event.to_h[:id])
    end
  end

  describe 'unique ids' do
    it 'generates unique ids for different events' do
      e1 = described_class.new(domain: :d, predicted: 0.0, actual: 1.0, magnitude: 1.0, valence: :negative)
      e2 = described_class.new(domain: :d, predicted: 0.0, actual: 1.0, magnitude: 1.0, valence: :negative)
      expect(e1.id).not_to eq(e2.id)
    end
  end
end
