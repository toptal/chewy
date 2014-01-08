require 'spec_helper'

describe Chewy::Query::Nodes::Missing do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { !name }.should == {missing: {term: 'name'}} }
  end
end
