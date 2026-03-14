# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Surprise::Helpers::SurpriseStore do
  subject(:store) { described_class.new }

  def make_event(domain: :test, magnitude: 0.5, valence: :neutral, orienting: false)
    Legion::Extensions::Surprise::Helpers::SurpriseEvent.new(
      domain:    domain,
      predicted: 0.5,
      actual:    0.8,
      magnitude: magnitude,
      valence:   valence,
      orienting: orienting
    )
  end

  describe '#record' do
    it 'adds the event to the store' do
      event = make_event
      store.record(event)
      expect(store.events.size).to eq(1)
    end

    it 'returns the recorded event' do
      event = make_event
      result = store.record(event)
      expect(result).to equal(event)
    end

    it 'updates the EMA baseline for the domain' do
      event = make_event(domain: :ema_domain, magnitude: 0.8)
      expect { store.record(event) }.to change { store.baseline_for(:ema_domain) }.from(0.0)
    end
  end

  describe '#recent' do
    it 'returns the last N events' do
      5.times { |i| store.record(make_event(domain: :"d#{i}")) }
      expect(store.recent(3).size).to eq(3)
    end

    it 'returns all events when N exceeds store size' do
      2.times { store.record(make_event) }
      expect(store.recent(10).size).to eq(2)
    end

    it 'defaults to 10 most recent' do
      15.times { store.record(make_event) }
      expect(store.recent.size).to eq(10)
    end

    it 'returns events in insertion order (oldest first in the slice)' do
      e1 = make_event(domain: :first)
      e2 = make_event(domain: :second)
      store.record(e1)
      store.record(e2)
      recent = store.recent(2)
      expect(recent.first.domain).to eq(:first)
      expect(recent.last.domain).to eq(:second)
    end
  end

  describe '#by_domain' do
    it 'returns only events matching the domain' do
      store.record(make_event(domain: :alpha))
      store.record(make_event(domain: :beta))
      store.record(make_event(domain: :alpha))
      expect(store.by_domain(:alpha).size).to eq(2)
    end

    it 'returns empty array for unknown domain' do
      expect(store.by_domain(:unknown)).to eq([])
    end
  end

  describe '#most_surprising' do
    it 'returns events sorted by magnitude descending' do
      store.record(make_event(magnitude: 0.3))
      store.record(make_event(magnitude: 0.9))
      store.record(make_event(magnitude: 0.5))
      top = store.most_surprising(2)
      expect(top.map(&:magnitude)).to eq([0.9, 0.5])
    end

    it 'returns at most N events' do
      3.times { store.record(make_event) }
      expect(store.most_surprising(2).size).to eq(2)
    end

    it 'returns all when N exceeds store size' do
      2.times { store.record(make_event) }
      expect(store.most_surprising(10).size).to eq(2)
    end
  end

  describe '#baseline_for' do
    it 'returns 0.0 for unknown domains' do
      expect(store.baseline_for(:never_seen)).to eq(0.0)
    end

    it 'converges toward recent magnitudes via EMA' do
      5.times { store.record(make_event(domain: :conv, magnitude: 0.8)) }
      baseline = store.baseline_for(:conv)
      expect(baseline).to be > 0.0
      expect(baseline).to be <= 0.8
    end

    it 'updates separately per domain' do
      store.record(make_event(domain: :d1, magnitude: 0.9))
      store.record(make_event(domain: :d2, magnitude: 0.1))
      expect(store.baseline_for(:d1)).to be > store.baseline_for(:d2)
    end
  end

  describe '#to_h' do
    it 'returns a hash with expected keys' do
      h = store.to_h
      expect(h.keys).to include(:total_events, :domain_count, :average_magnitude, :most_surprising_domain, :baselines)
    end

    it 'reports 0 total events when empty' do
      expect(store.to_h[:total_events]).to eq(0)
    end

    it 'reports correct total_events' do
      3.times { store.record(make_event) }
      expect(store.to_h[:total_events]).to eq(3)
    end

    it 'reports correct domain_count' do
      store.record(make_event(domain: :a))
      store.record(make_event(domain: :b))
      store.record(make_event(domain: :a))
      expect(store.to_h[:domain_count]).to eq(2)
    end

    it 'computes a sensible average_magnitude' do
      store.record(make_event(magnitude: 0.4))
      store.record(make_event(magnitude: 0.6))
      expect(store.to_h[:average_magnitude]).to eq(0.5)
    end

    it 'returns nil most_surprising_domain when empty' do
      expect(store.to_h[:most_surprising_domain]).to be_nil
    end

    it 'reports the domain of the highest magnitude event' do
      store.record(make_event(domain: :low,  magnitude: 0.1))
      store.record(make_event(domain: :high, magnitude: 0.9))
      expect(store.to_h[:most_surprising_domain]).to eq(:high)
    end
  end

  describe 'history trimming' do
    it 'keeps at most MAX_SURPRISE_HISTORY events' do
      max = Legion::Extensions::Surprise::Helpers::Constants::MAX_SURPRISE_HISTORY
      (max + 20).times { store.record(make_event) }
      expect(store.events.size).to eq(max)
    end

    it 'removes oldest events first when trimming' do
      max = Legion::Extensions::Surprise::Helpers::Constants::MAX_SURPRISE_HISTORY
      first = make_event(domain: :first_in)
      store.record(first)
      (max + 5).times { store.record(make_event) }
      expect(store.events.map(&:id)).not_to include(first.id)
    end
  end
end
