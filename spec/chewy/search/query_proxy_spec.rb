require 'spec_helper'

describe Chewy::Search::QueryProxy do
  before { stub_index(:products) }
  let(:request) { Chewy::Search::Request.new(ProductsIndex).query(match: {foo: 'bar'}) }
  let(:scope) { Chewy::Search::Request.new(ProductsIndex).query.must_not(match: {foo: 'bar'}) }
  subject { described_class.new(:query, request) }

  describe '#must' do
    specify { expect { subject.must }.to raise_error ArgumentError }
    specify do
      expect(subject.must(multi_match: {foo: 'bar'}).render[:body])
        .to eq(query: {bool: {must: [{match: {foo: 'bar'}}, {multi_match: {foo: 'bar'}}]}})
    end
  end

  describe '#should' do
    specify { expect { subject.should }.to raise_error ArgumentError }
    specify do
      expect(subject.should(multi_match: {foo: 'bar'}).render[:body])
        .to eq(query: {bool: {must: {match: {foo: 'bar'}}, should: {multi_match: {foo: 'bar'}}}})
    end
  end

  describe '#must_not' do
    specify { expect { subject.must_not }.to raise_error ArgumentError }
    specify do
      expect(subject.must_not(multi_match: {foo: 'bar'}).render[:body])
        .to eq(query: {bool: {must: {match: {foo: 'bar'}}, must_not: {multi_match: {foo: 'bar'}}}})
    end
  end

  describe '#and' do
    specify { expect { subject.and }.to raise_error ArgumentError }
    specify do
      expect(subject.and(multi_match: {foo: 'bar'}).render[:body])
        .to eq(query: {bool: {must: [{match: {foo: 'bar'}}, {multi_match: {foo: 'bar'}}]}})
    end
    specify do
      expect(subject.and(scope).render[:body])
        .to eq(query: {bool: {must: [{match: {foo: 'bar'}}, {bool: {must_not: {match: {foo: 'bar'}}}}]}})
    end
  end

  describe '#or' do
    specify { expect { subject.or }.to raise_error ArgumentError }
    specify do
      expect(subject.or(multi_match: {foo: 'bar'}).render[:body])
        .to eq(query: {bool: {should: [{match: {foo: 'bar'}}, {multi_match: {foo: 'bar'}}]}})
    end
    specify do
      expect(subject.or(scope).render[:body])
        .to eq(query: {bool: {should: [{match: {foo: 'bar'}}, {bool: {must_not: {match: {foo: 'bar'}}}}]}})
    end
  end

  describe '#not' do
    specify { expect { subject.not }.to raise_error ArgumentError }
    specify do
      expect(subject.not(multi_match: {foo: 'bar'}).render[:body])
        .to eq(query: {bool: {must: {match: {foo: 'bar'}}, must_not: {multi_match: {foo: 'bar'}}}})
    end
    specify do
      expect(subject.not(scope).render[:body])
        .to eq(query: {bool: {must: {match: {foo: 'bar'}}, must_not: {bool: {must_not: {match: {foo: 'bar'}}}}}})
    end
  end

  describe '#minimum_should_match' do
    specify { expect(subject.minimum_should_match('100%').render[:body]).to eq(query: {match: {foo: 'bar'}}) }

    context do
      let(:request) do
        Chewy::Search::Request.new(ProductsIndex)
          .query.should(match: {foo: 'bar'})
      end
      specify do
        expect(subject.minimum_should_match('100%').render[:body])
          .to eq(query: {bool: {should: {match: {foo: 'bar'}}, minimum_should_match: '100%'}})
      end
    end

    context do
      let(:request) do
        Chewy::Search::Request.new(ProductsIndex)
          .query.should(match: {foo: 'bar'})
          .query.minimum_should_match(2)
      end
      specify do
        expect(subject.minimum_should_match(nil).render[:body])
          .to eq(query: {bool: {should: {match: {foo: 'bar'}}}})
      end
    end
  end
end
