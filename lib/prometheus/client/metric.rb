# encoding: UTF-8

require 'thread'
require 'prometheus/client/label_set_validator'
require 'oj'

module Prometheus
  module Client
    # Metric
    class Metric
      attr_reader :name, :docstring, :base_labels

      def initialize(name, docstring, base_labels = {})
        @mutex = Mutex.new
        @validator = LabelSetValidator.new
        @values = Hash.new { |hash, key| hash[key] = default }

        validate_name(name)
        validate_docstring(docstring)
        @validator.valid?(base_labels)

        @name = name
        @docstring = docstring
        @base_labels = base_labels

        @redis = ::Prometheus::Client.configuration.redis
      end

      # Returns the value for the given label set
      def get(labels = {})
        @validator.valid?(labels)
        if @redis.present?
          @redis.hget(name, labels.to_json).to_f
        else
          @values[labels] || default
        end
      end

      def set(labels, value)
        if @redis.present?
          @redis.hset(name, labels.to_json, value)
        else
          synchronize { @values[labels] = value }
        end
      end

      # Returns all label sets with their values
      def values
        if @redis.present?
          all = @redis.hgetall(name)
          all.map { |key, value| [Oj.load(key).symbolize_keys, value] }.to_h
        else
          synchronize do
            @values.each_with_object({}) do |(labels, value), memo|
              memo[labels] = value
            end
          end
        end
      end

      private

      def default
        nil
      end

      def validate_name(name)
        unless name.is_a?(Symbol)
          raise ArgumentError, 'metric name must be a symbol'
        end
        unless name.to_s =~ /\A[a-zA-Z_:][a-zA-Z0-9_:]*\Z/
          msg = 'metric name must match /[a-zA-Z_:][a-zA-Z0-9_:]*/'
          raise ArgumentError, msg
        end
      end

      def validate_docstring(docstring)
        return true if docstring.respond_to?(:empty?) && !docstring.empty?

        raise ArgumentError, 'docstring must be given'
      end

      def label_set_for(labels)
        @validator.validate(labels)
      end

      def synchronize
        @mutex.synchronize { yield }
      end
    end
  end
end
