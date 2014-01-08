require 'spec_helper'

describe Chewy::Query::Nodes::Equal do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { name == 'name' }.should == {term: {'name' => 'name'}} }
    specify { render { name != 'name' }.should == {not: {term: {'name' => 'name'}}} }
    specify { render { name == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2']}} }
    specify { render { name != ['name1', 'name2'] }.should == {not: {terms: {'name' => ['name1', 'name2']}}} }
  end
end
