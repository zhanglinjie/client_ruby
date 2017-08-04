# encoding: UTF-8

require 'prometheus/client/metric'
require "oj"

module Prometheus
  module Client
    # A histogram samples observations (usually things like request durations
    # or response sizes) and counts them in configurable buckets. It also
    # provides a sum of all observed values.
    class Histogram < Metric
      # Value represents the state of a Histogram at a given point.
      class Value < Hash
        attr_accessor :sum, :total

        def initialize(buckets)
          @sum = 0.0
          @total = 0.0

          buckets.each do |bucket|
            self[bucket] = 0.0
          end
        end

        def observe(value)
          @sum += value
          @total += 1

          each_key do |bucket|
            self[bucket] += 1 if value <= bucket
          end
        end
      end

      class ValueInRedis < Hash
        attr_accessor :sum, :total
        def initialize(value)
          object = Oj.load(value)
          @sum = object["sum"]
          @total = object["total"]
          object.except("sum", "total").keys.each do |bucket|
            self[bucket.to_f] = object[bucket]
          end
        end
      end

      # DEFAULT_BUCKETS are the default Histogram buckets. The default buckets
      # are tailored to broadly measure the response time (in seconds) of a
      # network service. (From DefBuckets client_golang)
      DEFAULT_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1,
                         2.5, 5, 10].freeze

      # Offer a way to manually specify buckets
      def initialize(name, docstring, base_labels = {},
                     buckets = DEFAULT_BUCKETS)
        raise ArgumentError, 'Unsorted buckets, typo?' unless sorted? buckets

        @buckets = buckets
        super(name, docstring, base_labels)
      end

      def type
        :histogram
      end

      def observe(labels, value)
        if labels[:le]
          raise ArgumentError, 'Label with name "le" is not permitted'
        end

        label_set = label_set_for(labels)
        if @redis.present?
          object = Oj.load(@redis.hget(name, label_set.to_json) || "{}")
          object["sum"] ||= 0.0
          object["total"] ||= 0.0
          object["sum"] += value
          object["total"] += 1
          @buckets.each do |bucket|
            object[bucket.to_s] ||= 0.0
            object[bucket.to_s] += 1 if value <= bucket
          end
          @redis.hset(name, label_set.to_json, object.to_json)
        else
          synchronize {
            @values[label_set] ||= Value.new(@buckets)
            @values[label_set].observe(value)
          }
        end
      end

      def values
        if @redis.present?
          all = @redis.hgetall(name)
          all.map do |key, value|
            [Oj.load(key).symbolize_keys, ValueInRedis.new(value)]
          end.to_h
        else
          synchronize do
            @values.each_with_object({}) do |(labels, value), memo|
              memo[labels] = value
            end
          end
        end
      end

      private

      def sorted?(bucket)
        bucket.each_cons(2).all? { |i, j| i <= j }
      end
    end
  end
end
