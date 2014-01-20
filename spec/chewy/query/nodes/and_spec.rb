require 'spec_helper'

describe Chewy::Query::Nodes::And do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { name? & (email == 'email') }.should == {
      and: [{exists: {term: 'name'}}, {term: {'email' => 'email'}}]
    } }
    specify { render { ~(name? & (email == 'email')) }.should == {
      and: {filters: [{exists: {term: 'name'}}, {term: {'email' => 'email'}}], _cache: true}
    } }
  end
end
