require 'spec_helper'

describe Chewy::Query::Nodes::Equal do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { name == 'name' }.should == {term: {'name' => 'name'}} }
    specify { render { name != 'name' }.should == {not: {term: {'name' => 'name'}}} }
    specify { render { name == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2']}} }
    specify { render { name != ['name1', 'name2'] }.should == {not: {terms: {'name' => ['name1', 'name2']}}} }

    specify { render { name(:bool) == 'name' }.should == {term: {'name' => 'name'}} }
    specify { render { name(:borogoves) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2']}} }

    specify { render { name(:|) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :or}} }
    specify { render { name(:or) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :or}} }
    specify { render { name(:&) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :and}} }
    specify { render { name(:and) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :and}} }
    specify { render { name(:b) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :bool}} }
    specify { render { name(:bool) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :bool}} }
    specify { render { name(:f) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :fielddata}} }
    specify { render { name(:fielddata) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :fielddata}} }

    specify { render { ~name == 'name' }.should == {term: {'name' => 'name', _cache: true}} }
    specify { render { ~(name == 'name') }.should == {term: {'name' => 'name', _cache: true}} }
    specify { render { ~name != 'name' }.should == {not: {term: {'name' => 'name', _cache: true}}} }
    specify { render { ~name(:|) == ['name1', 'name2'] }.should == {terms: {'name' => ['name1', 'name2'], execution: :or, _cache: true}} }
    specify { render { ~name != ['name1', 'name2'] }.should == {not: {terms: {'name' => ['name1', 'name2'], _cache: true}}} }
  end
end
