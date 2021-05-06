# Rspec helper `build_query`
# To use it - add `require 'chewy/rspec/build_query'` to the `spec_helper.rb`
# Simple usage - just pass expected response as argument
# and then call needed query.
#
#   expect { method1.method2...methodN }.to build_query(expected_query)
#
RSpec::Matchers.define :build_query do |expected_query = {}|
  match do |request|
    request.render == expected_query
  end
end
