# encoding: UTF-8

module Prometheus
  module Client
    # LabelSetValidator ensures that all used label sets comply with the
    # Prometheus specification.
    class LabelSetValidator
      # TODO: we might allow setting :instance in the future
      RESERVED_LABELS = [:job, :instance].freeze

      class LabelSetError < StandardError; end
      class InvalidLabelSetError < LabelSetError; end
      class InvalidLabelError < LabelSetError; end
      class ReservedLabelError < LabelSetError; end

      def initialize
        @redis = ::Prometheus::Client.configuration.redis
        @validated = {}
      end

      def valid?(labels)
        unless labels.respond_to?(:all?)
          raise InvalidLabelSetError, "#{labels} is not a valid label set"
        end

        labels.all? do |key, _|
          validate_symbol(key)
          validate_name(key)
          validate_reserved_key(key)
        end
      end

      def validate(labels)
        sorted_labels = labels.to_a.sort_by{|k| k[0]}.to_h
        key = sorted_labels.hash
        return sorted_labels if key_exists?(key)

        valid?(sorted_labels)

        # unless @validated.empty? || match?(labels, @validated.first.last)
        #   raise InvalidLabelSetError, 'labels must have the same signature'
        # end

        set_key(key, sorted_labels)
        sorted_labels
      end

      private

      def key_exists?(key)
        if @redis.present?
          @redis.hexists("prometheus_validated_keys", key)
        else
          @validated.key?(key)
        end
      end

      def set_key(key, labels)
        if @redis.present?
          @redis.hset("prometheus_validated_keys", key, labels.to_json)
        else
          @validated[key] = labels
        end
      end

      def match?(a, b)
        a.keys.sort == b.keys.sort
      end

      def validate_symbol(key)
        return true if key.is_a?(Symbol)

        raise InvalidLabelError, "label #{key} is not a symbol"
      end

      def validate_name(key)
        return true unless key.to_s.start_with?('__')

        raise ReservedLabelError, "label #{key} must not start with __"
      end

      def validate_reserved_key(key)
        return true unless RESERVED_LABELS.include?(key)

        raise ReservedLabelError, "#{key} is reserved"
      end
    end
  end
end
