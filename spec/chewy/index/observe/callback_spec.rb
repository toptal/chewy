require 'spec_helper'

describe Chewy::Index::Observe::Callback do
  subject(:callback) { described_class.new(executable) }

  before do
    stub_model(:city) do
      attr_accessor :population
    end
  end

  let(:city) { City.create!(population: 100) }

  describe '#call' do
    context 'when executable is has arity 0' do
      let(:executable) { -> { population } }

      it 'calls exectuable within context' do
        expect(callback.call(city)).to eq(city.population)
      end
    end

    context 'when executable is has arity 1' do
      let(:executable) { lambda(&:population) }

      it 'calls exectuable within context' do
        expect(callback.call(city)).to eq(city.population)
      end
    end

    describe 'filters' do
      let(:executable) { ->(_) {} }

      describe 'if' do
        subject(:callback) { described_class.new(executable, if: filter) }

        shared_examples 'an if filter' do
          context 'when condition is true' do
            let(:condition) { true }

            specify do
              expect(executable).to receive(:call).with(city)

              callback.call(city)
            end
          end

          context 'when condition is false' do
            let(:condition) { false }

            specify do
              expect(executable).not_to receive(:call)

              callback.call(city)
            end
          end
        end

        context 'when filter is symbol' do
          let(:filter) { :condition }

          before do
            allow(city).to receive(:condition).and_return(condition)
          end

          include_examples 'an if filter'
        end

        context 'when filter is proc' do
          let(:filter) { -> { condition_state } }

          before do
            allow_any_instance_of(City).to receive(:condition_state).and_return(condition)
          end

          include_examples 'an if filter'
        end

        context 'when filter is literal' do
          let(:filter) { condition }

          include_examples 'an if filter'
        end
      end

      describe 'unless' do
        subject(:callback) { described_class.new(executable, unless: filter) }

        shared_examples 'an unless filter' do
          context 'when condition is true' do
            let(:condition) { true }

            specify do
              expect(executable).not_to receive(:call)

              callback.call(city)
            end
          end

          context 'when condition is false' do
            let(:condition) { false }

            specify do
              expect(executable).to receive(:call).with(city)

              callback.call(city)
            end
          end
        end

        context 'when filter is symbol' do
          let(:filter) { :condition }

          before do
            allow(city).to receive(:condition).and_return(condition)
          end

          include_examples 'an unless filter'
        end

        context 'when filter is proc' do
          let(:filter) { -> { condition_state } }

          before do
            allow_any_instance_of(City).to receive(:condition_state).and_return(condition)
          end

          include_examples 'an unless filter'
        end

        context 'when filter is literal' do
          let(:filter) { condition }

          include_examples 'an unless filter'
        end
      end
    end
  end
end
