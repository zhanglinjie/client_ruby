# encoding: UTF-8

require 'prometheus/client/metric'

module Prometheus
  module Client
    # A Gauge is a metric that exposes merely an instantaneous value or some
    # snapshot thereof.
    class Gauge < Metric
      def type
        :gauge
      end

      # Sets the value for the given label set
      def set(labels, value)
        unless value.is_a?(Numeric)
          raise ArgumentError, 'value must be a number'
        end
        label_set = label_set_for(labels)
        super(label_set, value)
      end

      # Increments Gauge value by 1 or adds the given value to the Gauge.
      # (The value can be negative, resulting in a decrease of the Gauge.)
      def increment(labels = {}, by = 1)
        label_set = label_set_for(labels)
        set(label_set, get(label_set) + by)
      end

      # Decrements Gauge value by 1 or subtracts the given value from the Gauge.
      # (The value can be negative, resulting in a increase of the Gauge.)
      def decrement(labels = {}, by = 1)
        label_set = label_set_for(labels)
        set(label_set, get(label_set) - by)
      end
    end
  end
end
