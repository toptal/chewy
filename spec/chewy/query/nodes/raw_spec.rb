require 'spec_helper'

describe Chewy::Query::Nodes::Raw do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { r(term: {name: 'name'}) }.should == {term: {name: 'name'}} }
  end
end
