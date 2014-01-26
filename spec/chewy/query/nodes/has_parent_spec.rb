require 'spec_helper'

describe Chewy::Query::Nodes::HasParent do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { render { has_parent('child') }.should == {has_parent: {type: 'child'}} }


    specify { render { has_parent('child').filter(term: {name: 'name'}) }
      .should == {has_parent: {type: 'child', filter: {term: {name: 'name'}}}} }
    specify { render { has_parent('child').filter{ name == 'name' } }
      .should == {has_parent: {type: 'child', filter: {term: {'name' => 'name'}}}} }
    specify { render { has_parent('child').filter(term: {name: 'name'}).filter{ age < 42 } }
      .should == {has_parent: {type: 'child', filter: {and: [{term: {name: 'name'}}, range: {'age' => {lt: 42}}]}}} }
    specify { render { has_parent('child').filter(term: {name: 'name'}).filter{ age < 42 }.filter_mode(:or) }
      .should == {has_parent: {type: 'child', filter: {or: [{term: {name: 'name'}}, range: {'age' => {lt: 42}}]}}} }

    specify { render { has_parent('child').query(match: {name: 'name'}) }
      .should == {has_parent: {type: 'child', query: {match: {name: 'name'}}}} }
    specify { render { has_parent('child').query(match: {name: 'name'}).query(match: {surname: 'surname'}) }
      .should == {has_parent: {type: 'child', query: {bool: {must: [{match: {name: 'name'}}, {match: {surname: 'surname'}}]}}}} }
    specify { render { has_parent('child').query(match: {name: 'name'}).query(match: {surname: 'surname'}).query_mode(:should) }
      .should == {has_parent: {type: 'child', query: {bool: {should: [{match: {name: 'name'}}, {match: {surname: 'surname'}}]}}}} }

    specify { render { has_parent('child').filter{ name == 'name' }.query(match: {name: 'name'}) }
      .should == {has_parent: {type: 'child', query: {filtered: {query: {match: {name: 'name'}}, filter: {term: {'name' => 'name'}}}}}} }
    specify { render { has_parent('child').filter{ name == 'name' }.query(match: {name: 'name'}).filter{ age < 42 } }
      .should == {has_parent: {type: 'child', query: {filtered: {query: {match: {name: 'name'}}, filter: {and: [{term: {'name' => 'name'}}, range: {'age' => {lt: 42}}]}}}}} }

    context do
      let(:name) { 'Name' }

      specify { render { has_parent('child').filter{ name == o{name} } }
       .should == {has_parent: {type: 'child', filter: {term: {'name' => 'Name'}}}} }
    end
  end
end
