require 'spec_helper'

describe Chewy::Query::Nodes::Range do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { age > 42 }.should == {range: {'age' => {gt: 42}}} }
    specify { render { age == (42..45) }.should == {range: {'age' => {gt: 42, lt: 45}}} }
    specify { render { age == [42..45] }.should == {range: {'age' => {gte: 42, lte: 45}}} }
  end
end
