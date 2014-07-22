require 'spec_helper'

describe Chewy::Query::Nodes::Exists do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { render { name? }.should == {exists: {field: 'name'}} }

    specify { render { !!name? }.should == {exists: {field: 'name'}} }
    specify { render { !!name }.should == {exists: {field: 'name'}} }
    specify { render { name != nil }.should == {exists: {field: 'name'}} }
    specify { render { !(name == nil) }.should == {exists: {field: 'name'}} }

    specify { render { ~name? }.should == {exists: {field: 'name'}} }
  end
end
