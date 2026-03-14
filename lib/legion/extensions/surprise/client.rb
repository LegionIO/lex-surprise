# frozen_string_literal: true

module Legion
  module Extensions
    module Surprise
      class Client
        include Runners::Surprise

        attr_reader :store, :habituation_model

        def initialize(store: nil, habituation_model: nil, **)
          @store             = store || Helpers::SurpriseStore.new
          @habituation_model = habituation_model || Helpers::HabituationModel.new
        end
      end
    end
  end
end
