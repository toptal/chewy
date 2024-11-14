require 'chewy/runtime/version'

module Chewy
  module Runtime
    def self.version(hosts = nil)
      Chewy.current[:chewy_runtime_version] ||= Version.new(Chewy.client(hosts).info['version']['number'])
    end
  end
end
