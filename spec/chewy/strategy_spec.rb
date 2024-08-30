require 'spec_helper'

describe Chewy::Strategy do
  before { drop_indices }
  subject(:strategy) { Chewy::Strategy.new }

  describe '#current' do
    specify { expect(strategy.current).to be_a(Chewy::Strategy::Base) }

    context do
      before { allow(Chewy).to receive_messages(root_strategy: :bypass) }
      specify { expect(strategy.current).to be_a(Chewy::Strategy::Bypass) }
    end
  end

  describe '#push' do
    specify do
      expect { strategy.push(:unexistant) }
        .to raise_error(RuntimeError).with_message("Can't find update strategy `unexistant`")
    end

    specify do
      expect { strategy.push(:atomic) }
        .to change { strategy.current }
        .to(an_instance_of(Chewy::Strategy::Atomic))
    end
  end

  describe '#pop' do
    specify { expect { strategy.pop }.to raise_error(RuntimeError).with_message(/Can't pop root strategy/) }

    specify do
      strategy.push(:urgent)
      expect { strategy.pop }
        .to change { strategy.current }
        .to(an_instance_of(Chewy::Strategy::Base))
    end
  end

  describe '#wrap' do
    specify do
      expect { strategy.wrap(:unexistant) {} }
        .to raise_error(RuntimeError).with_message("Can't find update strategy `unexistant`")
    end

    specify do
      expect do
        strategy.wrap(:urgent) do
          expect(strategy.current).to be_a(Chewy::Strategy::Urgent)
        end
      end.not_to change { strategy.current }
    end
  end

  context 'nesting', :orm do
    before do
      stub_model(:city) do
        update_index('cities') { self }
      end

      stub_index(:cities) do
        index_scope City
      end
    end

    let(:city) { City.create!(name: 'hello') }
    let(:other_city) { City.create!(name: 'world') }

    context do
      around { |example| Chewy.strategy(:bypass) { example.run } }

      specify do
        expect(CitiesIndex).not_to receive(:import!)
        [city, other_city].map(&:save!)
      end

      specify do
        expect(CitiesIndex).to receive(:import!).with([city.id, other_city.id]).once
        Chewy.strategy(:atomic) { [city, other_city].map(&:save!) }
      end
    end

    context do
      around { |example| Chewy.strategy(:urgent) { example.run } }

      specify do
        expect(CitiesIndex).to receive(:import!).at_least(2).times
        [city, other_city].map(&:save!)
      end

      specify do
        expect(CitiesIndex).to receive(:import!).with([city.id, other_city.id]).once
        Chewy.strategy(:atomic) { [city, other_city].map(&:save!) }
      end

      context 'hash passed to urgent' do
        before do
          stub_index(:cities)

          stub_model(:city) do
            update_index('cities') { {name: name} }
          end
        end

        specify do
          [city, other_city].map(&:save!)
          expect(CitiesIndex.total_count).to eq(4)
        end

        context do
          before do
            stub_model(:city) do
              update_index('cities') { {id: id.to_s, name: name} }
            end
          end

          specify do
            [city, other_city].map(&:save!)
            expect(CitiesIndex.total_count).to eq(2)
          end
        end
      end
    end
  end
end
