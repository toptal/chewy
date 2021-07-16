require 'chewy/runtime/version'

module Chewy
  module Runtime
    def self.version
      Chewy.thread_local_data[:chewy_runtime_version] ||= Version.new(Chewy.client.info['version']['number'])
    end
  end
end
