# frozen_string_literal: true

require 'chewy/runtime/version'

module Chewy
  module Runtime
    def self.version
      Chewy.current[:chewy_runtime_version] ||= Version.new(Chewy.client.info['version']['number'])
    end
  end
end
