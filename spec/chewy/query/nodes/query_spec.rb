require 'spec_helper'

describe Chewy::Query::Nodes::Query do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { q(query_string: {query: 'name: hello'}) }.should == {query: {query_string: {query: 'name: hello'}}} }
  end
end
