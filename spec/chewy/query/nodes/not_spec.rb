require 'spec_helper'

describe Chewy::Query::Nodes::Not do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { !(email == 'email') }.should == {
      not: {term: {'email' => 'email'}}
    } }
  end
end
