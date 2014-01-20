require 'spec_helper'

describe Chewy::Query::Nodes::Range do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { age > nil }.should == {range: {'age' => {gt: nil}}} }
    specify { render { age == (nil..nil) }.should == {range: {'age' => {gt: nil, lt: nil}}} }

    specify { render { age > 42 }.should == {range: {'age' => {gt: 42}}} }
    specify { render { age == (42..45) }.should == {range: {'age' => {gt: 42, lt: 45}}} }
    specify { render { age == [42..45] }.should == {range: {'age' => {gte: 42, lte: 45}}} }
    specify { render { (age > 42) & (age <= 45) }.should == {range: {'age' => {gt: 42, lte: 45}}} }

    specify { render { ~age > 42 }.should == {range: {'age' => {gt: 42}, _cache: true}} }
    specify { render { ~age == (42..45) }.should == {range: {'age' => {gt: 42, lt: 45}, _cache: true}} }
    specify { render { ~age == [42..45] }.should == {range: {'age' => {gte: 42, lte: 45}, _cache: true}} }
    specify { render { (age > 42) & ~(age <= 45) }.should == {range: {'age' => {gt: 42, lte: 45}, _cache: true}} }
    specify { render { (~age > 42) & (age <= 45) }.should == {range: {'age' => {gt: 42, lte: 45}, _cache: true}} }

    specify { render { age(:i) > 42 }.should == {range: {'age' => {gt: 42}, execution: :index}} }
    specify { render { age(:index) > 42 }.should == {range: {'age' => {gt: 42}, execution: :index}} }
    specify { render { age(:f) > 42 }.should == {range: {'age' => {gt: 42}, execution: :fielddata}} }
    specify { render { age(:fielddata) > 42 }.should == {range: {'age' => {gt: 42}, execution: :fielddata}} }
    specify { render { (age(:f) > 42) & (age <= 45) }.should == {range: {'age' => {gt: 42, lte: 45}, execution: :fielddata}} }

    specify { render { ~age(:f) > 42 }.should == {range: {'age' => {gt: 42}, execution: :fielddata, _cache: true}} }
    specify { render { (age(:f) > 42) & (~age <= 45) }.should == {range: {'age' => {gt: 42, lte: 45}, execution: :fielddata, _cache: true}} }
  end
end
