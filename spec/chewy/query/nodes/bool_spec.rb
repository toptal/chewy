require 'spec_helper'

describe Chewy::Query::Nodes::Bool do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { must(name == 'name', email == 'email') }.should == {
      bool: {must: [{term: {'name' => 'name'}}, {term: {'email' => 'email'}}]
    } } }
    specify { render { must(name == 'name').must_not(email == 'email') }.should == {
      bool: {must: [{term: {'name' => 'name'}}], must_not: [{term: {'email' => 'email'}}]
    } } }
    specify { render { must(name == 'name').should(email == 'email') }.should == {
      bool: {must: [{term: {'name' => 'name'}}], should: [{ term: {'email' => 'email'}}]
    } } }
  end
end
