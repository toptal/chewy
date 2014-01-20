require 'spec_helper'

describe Chewy::Query::Nodes::Exists do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { name? }.should == {exists: {term: 'name'}} }

    specify { render { !!name? }.should == {exists: {term: 'name'}} }
    specify { render { !!name }.should == {exists: {term: 'name'}} }
    specify { render { name != nil }.should == {exists: {term: 'name'}} }
    specify { render { !(name == nil) }.should == {exists: {term: 'name'}} }

    specify { render { ~name? }.should == {exists: {term: 'name'}} }
  end
end
