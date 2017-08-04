# encoding: UTF-8

require 'prometheus/client/registry'
require 'prometheus/client/configuration'

module Prometheus
  # Client is a ruby implementation for a Prometheus compatible client.
  module Client
    # Returns a default registry object
    def self.registry
      @registry ||= Registry.new
    end

    def self.config
      yield configuration
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.clear
      redis = configuration.redis
      if redis.present?
        redis.del(redis.keys)
      end
    end
  end
end
