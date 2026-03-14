# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Surprise::Client do
  subject(:client) { described_class.new }

  describe '#initialize' do
    it 'creates a default store' do
      expect(client.store).to be_a(Legion::Extensions::Surprise::Helpers::SurpriseStore)
    end

    it 'creates a default habituation_model' do
      expect(client.habituation_model).to be_a(Legion::Extensions::Surprise::Helpers::HabituationModel)
    end

    it 'accepts an injected store' do
      custom = Legion::Extensions::Surprise::Helpers::SurpriseStore.new
      c = described_class.new(store: custom)
      expect(c.store).to equal(custom)
    end

    it 'accepts an injected habituation_model' do
      custom = Legion::Extensions::Surprise::Helpers::HabituationModel.new
      c = described_class.new(habituation_model: custom)
      expect(c.habituation_model).to equal(custom)
    end
  end

  describe 'full orienting response workflow' do
    it 'detects surprise, habituates, and recovers sensitivity' do
      # Phase 1: Fresh domain — max sensitivity
      sens_before = client.domain_sensitivity(domain: :cpu_load)[:sensitivity]
      expect(sens_before).to eq(1.0)

      # Phase 2: Large unexpected event fires orienting response
      first = client.evaluate_surprise(domain: :cpu_load, predicted: 0.2, actual: 0.95, valence: :negative)
      expect(first[:success]).to be true
      expect(first[:orienting_triggered]).to be true

      # Phase 3: Sensitivity reduced (habituation)
      sens_after = client.domain_sensitivity(domain: :cpu_load)[:sensitivity]
      expect(sens_after).to be < sens_before

      # Phase 4: Repeated surprises continue to habituate
      5.times { client.evaluate_surprise(domain: :cpu_load, predicted: 0.2, actual: 0.95, valence: :negative) }
      sens_habituated = client.domain_sensitivity(domain: :cpu_load)[:sensitivity]
      expect(sens_habituated).to be < sens_after

      # Phase 5: Tick decay slightly recovers sensitivity
      client.update_surprise(tick_result: {})
      sens_recovered = client.domain_sensitivity(domain: :cpu_load)[:sensitivity]
      expect(sens_recovered).to be >= sens_habituated

      # Phase 6: Stats reflect accumulated history (1 initial + 5 repeated = 6 events)
      stats = client.surprise_stats
      expect(stats[:total_events]).to be >= 6
      expect(stats[:domain_count]).to be >= 1

      # Phase 7: Manual reset restores full sensitivity
      client.reset_habituation(domain: :cpu_load)
      sens_reset = client.domain_sensitivity(domain: :cpu_load)[:sensitivity]
      expect(sens_reset).to be > sens_habituated
    end

    it 'tracks multiple domains independently' do
      client.evaluate_surprise(domain: :memory,   predicted: 0.0, actual: 1.0, valence: :negative)
      client.evaluate_surprise(domain: :disk_io,  predicted: 0.0, actual: 1.0, valence: :negative)
      client.evaluate_surprise(domain: :network,  predicted: 0.3, actual: 0.4, valence: :neutral)

      stats = client.surprise_stats
      expect(stats[:domain_count]).to eq(3)

      # Memory and disk_io were strongly surprising; network was not
      mem_sens  = client.domain_sensitivity(domain: :memory)[:sensitivity]
      net_sens  = client.domain_sensitivity(domain: :network)[:sensitivity]
      expect(mem_sens).to be < 1.0
      expect(net_sens).to be < 1.0
    end

    it 'processes tick predictions end-to-end' do
      tick = {
        predictions: [
          { domain: :error_rate, predicted: 0.01, actual: 0.45, valence: :negative },
          { domain: :latency,    predicted: 0.1,  actual: 0.15, valence: :neutral  }
        ]
      }
      result = client.update_surprise(tick_result: tick)
      expect(result[:success]).to be true
      expect(result[:evaluated]).to eq(2)

      # Events should appear in recent surprises
      recent = client.recent_surprises(count: 5)
      domains = recent[:events].map { |e| e[:domain] }
      expect(domains).to include(:error_rate, :latency)
    end

    it 'positive surprise is less alarming than negative surprise for the same delta' do
      client.evaluate_surprise(domain: :pos_outcome, predicted: 0.5, actual: 1.0, valence: :positive)
      client.evaluate_surprise(domain: :neg_outcome, predicted: 0.5, actual: 0.0, valence: :negative)

      pos_event = client.recent_surprises(count: 2)[:events].find { |e| e[:domain] == :pos_outcome }
      neg_event = client.recent_surprises(count: 2)[:events].find { |e| e[:domain] == :neg_outcome }

      expect(neg_event[:magnitude]).to be > pos_event[:magnitude]
    end

    it 'cooldown prevents orienting spam from the same domain' do
      domain = :noisy_sensor
      results = 5.times.map { client.evaluate_surprise(domain: domain, predicted: 0.0, actual: 1.0, valence: :negative) }
      orienting_count = results.count { |r| r[:orienting_triggered] }
      # Only the first should fire (cooldown blocks subsequent)
      expect(orienting_count).to eq(1)
    end

    it 'reports most surprising domain in stats' do
      client.evaluate_surprise(domain: :low,  predicted: 0.4, actual: 0.5, valence: :neutral)
      client.evaluate_surprise(domain: :high, predicted: 0.0, actual: 1.0, valence: :negative)
      expect(client.surprise_stats[:most_surprising_domain]).to eq(:high)
    end
  end
end
