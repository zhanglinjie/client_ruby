# encoding: UTF-8

require 'quantile'
require 'prometheus/client/metric'

module Prometheus
  module Client
    # Summary is an accumulator for samples. It captures Numeric data and
    # provides an efficient quantile calculation mechanism.
    class Summary < Metric
      extend Gem::Deprecate

      # Value represents the state of a Summary at a given point.
      class Value < Hash
        attr_accessor :sum, :total

        def initialize(type, name, labels, estimator)
          @sum = ValueClass.new(type, name, name.to_s + '_sum', labels, estimator.sum)
          @total = ValueClass.new(type, name, name.to_s + '_count', labels, estimator.observations)

          estimator.invariants.each do |invariant|
            self[invariant.quantile] = ValueClass.new(type, name, name, labels, estimator.query(invariant.quantile))
          end
        end

        def get
          hash = {}
          each_key do |bucket|
            hash[bucket] = self[bucket].get()
          end
          hash
        end
      end

      def initialize(name, docstring, base_labels = {})
        if ValueClass.multiprocess
          raise ArgumentError, "Multiprocess mode does not support Summary metrics"
        end
        super(name, docstring, base_labels)
      end

      def type
        :summary
      end

      # Records a given value.
      def observe(labels, value)
        label_set = label_set_for(labels)
        synchronize { @values[label_set].observe(value) }
      end
      alias add observe
      deprecate :add, :observe, 2016, 10

      # Returns the value for the given label set
      def get(labels = {})
        @validator.valid?(labels)

        synchronize do
          Value.new(type, @name, labels, @values[labels])
        end
      end

      # Returns all label sets with their values
      def values
        synchronize do
          @values.each_with_object({}) do |(labels, value), memo|
            memo[labels] = Value.new(type, @name, labels, value)
          end
        end
      end

      private

      def default(labels)
        Quantile::Estimator.new
      end
    end
  end
end