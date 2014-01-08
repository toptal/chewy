require 'spec_helper'

describe Chewy::Query::Nodes::Script do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { s('var = val') }.should == {script: {script: 'var = val'}} }
  end
end
