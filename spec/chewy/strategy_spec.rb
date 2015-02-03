require 'spec_helper'

describe Chewy::Strategy do
  subject(:strategy) { Chewy::Strategy.new }

  describe '#current' do
    specify { expect(strategy.current).to be_a(Chewy::Strategy::Base) }

    context do
      before { allow(Chewy).to receive_messages(root_strategy: :bypass) }
      specify { expect(strategy.current).to be_a(Chewy::Strategy::Bypass) }
    end
  end

  describe '#push' do
    specify { expect { strategy.push(:unexistant) }.to raise_error }

    specify do
      expect { strategy.push(:atomic) }
        .to change { strategy.current }
        .to(an_instance_of(Chewy::Strategy::Atomic))
    end
  end

  describe '#pop' do
    specify { expect { strategy.pop }.to raise_error }

    specify do
      strategy.push(:urgent)
      expect { strategy.pop }
        .to change { strategy.current }
        .to(an_instance_of(Chewy::Strategy::Base))
    end
  end

  context 'nesting', :orm do
    before do
      stub_model(:city) do
        update_index('cities#city') { self }
      end

      stub_index(:cities) do
        define_type City
      end
    end

    let(:city) { City.create! }
    let(:other_city) { City.create! }

    context do
      around { |example| Chewy.strategy(:bypass) { example.run } }

      specify do
        expect(CitiesIndex::City).not_to receive(:import)
        [city, other_city].map(&:save!)
      end

      specify do
        expect(CitiesIndex::City).to receive(:import).with([city.id, other_city.id]).once
        Chewy.strategy(:atomic) { [city, other_city].map(&:save!) }
      end
    end

    context do
      around { |example| Chewy.strategy(:urgent) { example.run } }

      specify do
        expect(CitiesIndex::City).to receive(:import).at_least(2).times
        [city, other_city].map(&:save!)
      end

      specify do
        expect(CitiesIndex::City).to receive(:import).with([city.id, other_city.id]).once
        Chewy.strategy(:atomic) { [city, other_city].map(&:save!) }
      end
    end

    context "urgent strategy when type has a default scope", :active_record do
      around { |example| Chewy.strategy(:bypass) { example.run } }

      before do
        stub_index(:cities) do
          define_type City.where(rating: 0)
        end
      end

      let!(:poorly_rated_city) { City.create(rating: 0) }
      let!(:highly_rated_city) { City.create(rating: 100) }

      it "only imports the records in scope" do
        Chewy.strategy(:urgent) { [poorly_rated_city, highly_rated_city].map(&:save!) }
        expect(CitiesIndex::City.limit(2)).to contain_exactly(poorly_rated_city)
      end
    end
  end
end
