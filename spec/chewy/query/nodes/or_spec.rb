require 'spec_helper'

describe Chewy::Query::Nodes::Or do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { name? | (email == 'email') }.should == {
      or: [{exists: {term: 'name'}}, {term: {'email' => 'email'}}]
    } }
    specify { render { ~(name? | (email == 'email')) }.should == {
      or: {filters: [{exists: {term: 'name'}}, {term: {'email' => 'email'}}], _cache: true}
    } }
  end
end
