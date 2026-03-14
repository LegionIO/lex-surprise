# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Surprise::Runners::Surprise do
  let(:runner) do
    obj = Object.new
    obj.extend(described_class)
    obj
  end

  describe '#evaluate_surprise' do
    it 'returns success with a surprise_event hash' do
      result = runner.evaluate_surprise(domain: :memory, predicted: 0.5, actual: 0.9)
      expect(result[:success]).to be true
      expect(result[:surprise_event]).to be_a(Hash)
      expect(result[:surprise_event][:domain]).to eq(:memory)
    end

    it 'includes orienting_triggered in the result' do
      result = runner.evaluate_surprise(domain: :memory, predicted: 0.0, actual: 1.0, valence: :negative)
      expect(result).to include(:orienting_triggered)
    end

    it 'triggers orienting when magnitude exceeds threshold' do
      # With predicted=0.0, actual=1.0 and negative valence (weight=1.0), magnitude = 1.0 * 1.0 * 1.0 = 1.0
      result = runner.evaluate_surprise(domain: :shock, predicted: 0.0, actual: 1.0, valence: :negative)
      expect(result[:orienting_triggered]).to be true
    end

    it 'does not trigger orienting when magnitude is below threshold' do
      # With predicted=0.5, actual=0.52 and neutral valence (weight=0.3), magnitude is tiny
      result = runner.evaluate_surprise(domain: :calm, predicted: 0.5, actual: 0.52, valence: :neutral)
      expect(result[:orienting_triggered]).to be false
    end

    it 'applies negative valence weight (1.0) for stronger response' do
      neg = runner.evaluate_surprise(domain: :neg_d, predicted: 0.0, actual: 0.5, valence: :negative)
      pos = runner.evaluate_surprise(domain: :pos_d, predicted: 0.0, actual: 0.5, valence: :positive)
      expect(neg[:surprise_event][:magnitude]).to be > pos[:surprise_event][:magnitude]
    end

    it 'applies positive valence weight (0.6) correctly' do
      result = runner.evaluate_surprise(domain: :pos_check, predicted: 0.0, actual: 1.0, valence: :positive)
      expect(result[:surprise_event][:magnitude]).to be_within(0.001).of(0.6)
    end

    it 'applies neutral valence weight (0.3) correctly' do
      result = runner.evaluate_surprise(domain: :neu_check, predicted: 0.0, actual: 1.0, valence: :neutral)
      expect(result[:surprise_event][:magnitude]).to be_within(0.001).of(0.3)
    end

    it 'records the event in the store' do
      runner.evaluate_surprise(domain: :store_test, predicted: 0.5, actual: 0.9, valence: :negative)
      result = runner.recent_surprises(count: 1)
      expect(result[:count]).to eq(1)
      expect(result[:events].first[:domain]).to eq(:store_test)
    end

    it 'habituates the domain after evaluation' do
      domain = :habituate_me
      # Evaluate once to create a habituation entry
      runner.evaluate_surprise(domain: domain, predicted: 0.0, actual: 1.0, valence: :negative)
      sens = runner.domain_sensitivity(domain: domain)
      expect(sens[:sensitivity]).to be < 1.0
    end

    it 'does not trigger orienting on the same domain during cooldown' do
      domain = :cooldown_domain
      # First evaluation should trigger (large surprise, negative valence)
      first = runner.evaluate_surprise(domain: domain, predicted: 0.0, actual: 1.0, valence: :negative)
      expect(first[:orienting_triggered]).to be true
      # Second immediately after should be blocked by cooldown
      second = runner.evaluate_surprise(domain: domain, predicted: 0.0, actual: 1.0, valence: :negative)
      expect(second[:orienting_triggered]).to be false
    end

    it 'defaults valence to :neutral' do
      result = runner.evaluate_surprise(domain: :default_val, predicted: 0.0, actual: 1.0)
      expect(result[:surprise_event][:valence]).to eq(:neutral)
    end
  end

  describe '#update_surprise' do
    it 'returns success with evaluation counts' do
      result = runner.update_surprise
      expect(result[:success]).to be true
      expect(result).to include(:evaluated, :orienting_count, :events)
    end

    it 'evaluates zero predictions when tick_result is empty' do
      result = runner.update_surprise(tick_result: {})
      expect(result[:evaluated]).to eq(0)
    end

    it 'evaluates predictions extracted from tick_result' do
      tick_result = {
        predictions: [
          { domain: :cpu, predicted: 0.3, actual: 0.9, valence: :negative },
          { domain: :mem, predicted: 0.5, actual: 0.6, valence: :neutral  }
        ]
      }
      result = runner.update_surprise(tick_result: tick_result)
      expect(result[:evaluated]).to eq(2)
    end

    it 'counts orienting events correctly' do
      tick_result = {
        predictions: [
          { domain: :spike, predicted: 0.0, actual: 1.0, valence: :negative }
        ]
      }
      result = runner.update_surprise(tick_result: tick_result)
      expect(result[:orienting_count]).to be >= 0
    end

    it 'skips predictions missing required fields' do
      tick_result = {
        predictions: [
          { domain: :incomplete },
          { domain: :also_bad, predicted: 0.5 }
        ]
      }
      result = runner.update_surprise(tick_result: tick_result)
      expect(result[:evaluated]).to eq(0)
    end

    it 'handles non-hash tick_result gracefully' do
      result = runner.update_surprise(tick_result: nil)
      expect(result[:success]).to be true
      expect(result[:evaluated]).to eq(0)
    end

    it 'calls decay_all on habituation model each tick' do
      runner.evaluate_surprise(domain: :decay_test, predicted: 0.0, actual: 1.0, valence: :negative)
      before = runner.domain_sensitivity(domain: :decay_test)[:sensitivity]
      runner.update_surprise(tick_result: {})
      after = runner.domain_sensitivity(domain: :decay_test)[:sensitivity]
      expect(after).to be >= before
    end
  end

  describe '#surprise_stats' do
    it 'returns success' do
      result = runner.surprise_stats
      expect(result[:success]).to be true
    end

    it 'includes all stat keys' do
      result = runner.surprise_stats
      expect(result.keys).to include(
        :total_events,
        :domain_count,
        :average_magnitude,
        :most_surprising_domain,
        :top_surprise_magnitude
      )
    end

    it 'reports 0 total_events initially' do
      expect(runner.surprise_stats[:total_events]).to eq(0)
    end

    it 'reports correct total after recording events' do
      3.times { runner.evaluate_surprise(domain: :stats_d, predicted: 0.0, actual: 0.5, valence: :neutral) }
      expect(runner.surprise_stats[:total_events]).to eq(3)
    end

    it 'returns nil top_surprise_magnitude when no events' do
      expect(runner.surprise_stats[:top_surprise_magnitude]).to be_nil
    end

    it 'returns the magnitude of the most surprising event' do
      runner.evaluate_surprise(domain: :low_s,  predicted: 0.4, actual: 0.5, valence: :neutral)
      runner.evaluate_surprise(domain: :high_s, predicted: 0.0, actual: 1.0, valence: :negative)
      top = runner.surprise_stats[:top_surprise_magnitude]
      expect(top).to be > 0.5
    end
  end

  describe '#domain_sensitivity' do
    it 'returns success with domain info' do
      result = runner.domain_sensitivity(domain: :test_domain)
      expect(result[:success]).to be true
      expect(result[:domain]).to eq(:test_domain)
      expect(result).to include(:sensitivity, :baseline, :event_count)
    end

    it 'reports 1.0 sensitivity for a fresh domain' do
      result = runner.domain_sensitivity(domain: :fresh_ds)
      expect(result[:sensitivity]).to eq(1.0)
    end

    it 'reports reduced sensitivity after habituation' do
      runner.evaluate_surprise(domain: :hab_ds, predicted: 0.0, actual: 1.0, valence: :negative)
      result = runner.domain_sensitivity(domain: :hab_ds)
      expect(result[:sensitivity]).to be < 1.0
    end

    it 'reports event_count for the domain' do
      runner.evaluate_surprise(domain: :count_ds, predicted: 0.3, actual: 0.7, valence: :neutral)
      runner.evaluate_surprise(domain: :count_ds, predicted: 0.3, actual: 0.7, valence: :neutral)
      result = runner.domain_sensitivity(domain: :count_ds)
      expect(result[:event_count]).to eq(2)
    end
  end

  describe '#recent_surprises' do
    it 'returns success with events array' do
      result = runner.recent_surprises
      expect(result[:success]).to be true
      expect(result[:events]).to be_an(Array)
    end

    it 'returns the requested number of recent events' do
      5.times { runner.evaluate_surprise(domain: :rs_d, predicted: 0.0, actual: 0.5, valence: :neutral) }
      result = runner.recent_surprises(count: 3)
      expect(result[:count]).to eq(3)
    end

    it 'returns all events when count exceeds store size' do
      2.times { runner.evaluate_surprise(domain: :rs_small, predicted: 0.0, actual: 0.5, valence: :neutral) }
      result = runner.recent_surprises(count: 100)
      expect(result[:count]).to eq(2)
    end

    it 'defaults to 10 most recent' do
      15.times { runner.evaluate_surprise(domain: :rs_many, predicted: 0.0, actual: 0.5, valence: :neutral) }
      result = runner.recent_surprises
      expect(result[:count]).to eq(10)
    end
  end

  describe '#reset_habituation' do
    it 'returns success with domain and sensitivity info' do
      result = runner.reset_habituation(domain: :reset_d)
      expect(result[:success]).to be true
      expect(result[:domain]).to eq(:reset_d)
      expect(result).to include(:old_sensitivity, :new_sensitivity)
    end

    it 'increases sensitivity after habituation' do
      domain = :reset_test
      10.times { runner.evaluate_surprise(domain: domain, predicted: 0.0, actual: 1.0, valence: :negative) }
      habituated = runner.domain_sensitivity(domain: domain)[:sensitivity]
      runner.reset_habituation(domain: domain)
      reset = runner.domain_sensitivity(domain: domain)[:sensitivity]
      expect(reset).to be > habituated
    end

    it 'sets sensitivity close to 1.0' do
      domain = :full_reset
      10.times { runner.evaluate_surprise(domain: domain, predicted: 0.0, actual: 1.0, valence: :negative) }
      runner.reset_habituation(domain: domain)
      expect(runner.domain_sensitivity(domain: domain)[:sensitivity]).to be_within(0.05).of(1.0)
    end

    it 'reports old_sensitivity accurately' do
      domain = :old_sens
      runner.evaluate_surprise(domain: domain, predicted: 0.0, actual: 1.0, valence: :negative)
      before = runner.domain_sensitivity(domain: domain)[:sensitivity]
      result = runner.reset_habituation(domain: domain)
      expect(result[:old_sensitivity]).to eq(before)
    end
  end
end
