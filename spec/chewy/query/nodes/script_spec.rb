require 'spec_helper'

describe Chewy::Query::Nodes::Script do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { render { s('var = val') }.should == {script: {script: 'var = val'}} }
    specify { render { s('var = val', val: 42) }.should == {script: {script: 'var = val', params: {val: 42}}} }

    specify { render { ~s('var = val') }.should == {script: {script: 'var = val', _cache: true}} }
    specify { render { ~s('var = val', val: 42) }.should == {script: {script: 'var = val', params: {val: 42}, _cache: true}} }
  end
end
