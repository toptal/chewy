require 'spec_helper'

describe Chewy::Query::Nodes::Regexp do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { expect(render { names.first == /nam.*/ }).to eq(regexp: { 'names.first' => 'nam.*' }) }
    specify { expect(render { names.first =~ /nam.*/ }).to eq(regexp: { 'names.first' => 'nam.*' }) }
    specify { expect(render { name != /nam.*/ }).to eq(not: { regexp: { 'name' => 'nam.*' } }) }
    specify { expect(render { name !~ /nam.*/ }).to eq(not: { regexp: { 'name' => 'nam.*' } }) }

    specify { expect(render { names.first(flags: [:anystring, :intersection, :borogoves]) == /nam.*/ })
      .to eq(regexp: { 'names.first' => { value: 'nam.*', flags: 'ANYSTRING|INTERSECTION' } }) }
    specify { expect(render { names.first(:anystring, :intersection, :borogoves) == /nam.*/ })
      .to eq(regexp: { 'names.first' => { value: 'nam.*', flags: 'ANYSTRING|INTERSECTION' } }) }

    specify { expect(render { names.first(flags: [:anystring, :intersection, :borogoves]) =~ /nam.*/ })
      .to eq(regexp: { 'names.first' => { value: 'nam.*', flags: 'ANYSTRING|INTERSECTION' } }) }
    specify { expect(render { names.first(:anystring, :intersection, :borogoves) =~ /nam.*/ })
      .to eq(regexp: { 'names.first' => { value: 'nam.*', flags: 'ANYSTRING|INTERSECTION' } }) }

    specify { expect(render { ~names.first == /nam.*/ }).to eq(regexp: { 'names.first' => 'nam.*', _cache: true, _cache_key: 'nam.*' }) }
    specify { expect(render { names.first(cache: 'name') == /nam.*/ }).to eq(regexp: { 'names.first' => 'nam.*', _cache: true, _cache_key: 'name' }) }
    specify { expect(render { ~names.first(:anystring) =~ /nam.*/ })
      .to eq(regexp: { 'names.first' => { value: 'nam.*', flags: 'ANYSTRING' }, _cache: true, _cache_key: 'nam.*' }) }
    specify { expect(render { names.first(:anystring, cache: 'name') =~ /nam.*/ })
      .to eq(regexp: { 'names.first' => { value: 'nam.*', flags: 'ANYSTRING' }, _cache: true, _cache_key: 'name' }) }
  end
end
