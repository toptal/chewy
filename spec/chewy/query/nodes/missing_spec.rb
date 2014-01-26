require 'spec_helper'

describe Chewy::Query::Nodes::Missing do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { render { !name }.should == {missing: {term: 'name', existence: true, null_value: false}} }
    specify { render { !name? }.should == {missing: {term: 'name', existence: true, null_value: true}} }
    specify { render { name == nil }.should == {missing: {term: 'name', existence: false, null_value: true}} }

    specify { render { ~!name }.should == {missing: {term: 'name', existence: true, null_value: false}} }
  end
end
