require 'spec_helper'

describe Chewy::Query::Nodes::Not do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { render { !(email == 'email') }.should == {
      not: {term: {'email' => 'email'}}
    } }
    specify { render { ~!(email == 'email') }.should == {
      not: {filter: {term: {'email' => 'email'}}, _cache: true}
    } }
  end
end
