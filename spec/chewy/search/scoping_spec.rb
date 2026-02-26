require 'spec_helper'

describe Chewy::Search::Scoping do
  before do
    stub_index(:cities) do
      field :name
    end
  end

  describe '#scoping' do
    let(:request) { CitiesIndex.query(match: {name: 'London'}) }

    it 'pushes and pops from the scopes stack' do
      expect(Chewy::Search::Request.scopes).to be_empty

      request.scoping do
        expect(Chewy::Search::Request.scopes.size).to eq(1)
        expect(Chewy::Search::Request.scopes.last).to eq(request)
      end

      expect(Chewy::Search::Request.scopes).to be_empty
    end

    it 'pops scope even when block raises' do
      expect do
        request.scoping { raise 'boom' }
      end.to raise_error('boom')

      expect(Chewy::Search::Request.scopes).to be_empty
    end

    it 'supports nesting' do
      inner = CitiesIndex.filter(term: {name: 'Bangkok'})

      request.scoping do
        expect(Chewy::Search::Request.scopes.size).to eq(1)

        inner.scoping do
          expect(Chewy::Search::Request.scopes.size).to eq(2)
          expect(Chewy::Search::Request.scopes.last).to eq(inner)
        end

        expect(Chewy::Search::Request.scopes.size).to eq(1)
      end
    end
  end
end
