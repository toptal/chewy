require 'spec_helper'

describe Chewy::Query::Nodes::And do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { name? & (email == 'email') }.should == {
      and: [{exists: {term: 'name'}}, {term: {'email' => 'email'}}]
    } }
  end
end
