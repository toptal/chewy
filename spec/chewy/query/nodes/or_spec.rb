require 'spec_helper'

describe Chewy::Query::Nodes::Or do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { render { name? | (email == 'email') }.should == {
      or: [{exists: {field: 'name'}}, {term: {'email' => 'email'}}]
    } }
    specify { render { ~(name? | (email == 'email')) }.should == {
      or: {filters: [{exists: {field: 'name'}}, {term: {'email' => 'email'}}], _cache: true}
    } }
  end
end
