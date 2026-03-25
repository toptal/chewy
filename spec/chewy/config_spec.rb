require 'spec_helper'

describe Chewy::Config do
  subject { described_class.send(:new) }

  specify { expect(subject.logger).to be_nil }
  specify { expect(subject.transport_logger).to be_nil }
  specify { expect(subject.root_strategy).to eq(:base) }
  specify { expect(subject.request_strategy).to eq(:atomic) }
  specify { expect(subject.console_strategy).to eq(:urgent) }
  specify { expect(subject.use_after_commit_callbacks).to eq(true) }
  specify { expect(subject.indices_path).to eq('app/chewy') }
  specify { expect(subject.reset_disable_refresh_interval).to eq(false) }
  specify { expect(subject.reset_no_replicas).to eq(false) }
  specify { expect(subject.disable_refresh_async).to eq(false) }
  specify { expect(subject.search_class).to be < Chewy::Search::Request }

  describe '#transport_logger=' do
    let(:logger) { Logger.new('/dev/null') }
    after { subject.transport_logger = nil }

    specify do
      expect { subject.transport_logger = logger }
        .to change { Chewy.client.transport.logger }.to(logger)
    end
    specify do
      expect { subject.transport_logger = logger }
        .to change { subject.transport_logger }.to(logger)
    end
    specify do
      expect { subject.transport_logger = logger }
        .to change { subject.configuration[:logger] }.from(nil).to(logger)
    end
  end

  describe '#transport_tracer=' do
    let(:tracer) { Logger.new('/dev/null') }
    after { subject.transport_tracer = nil }

    specify do
      expect { subject.transport_tracer = tracer }
        .to change { Chewy.client.transport.tracer }.to(tracer)
    end
    specify do
      expect { subject.transport_tracer = tracer }
        .to change { subject.transport_tracer }.to(tracer)
    end
    specify do
      expect { subject.transport_tracer = tracer }
        .to change { subject.configuration[:tracer] }.from(nil).to(tracer)
    end
  end

  describe '#search_class' do
    context 'nothing is defined' do
      before do
        hide_const('Kaminari')
      end

      specify do
        expect(subject.search_class.included_modules)
          .not_to include(Chewy::Search::Pagination::Kaminari)
      end
    end

    context 'kaminari' do
      specify do
        expect(subject.search_class.included_modules)
          .to include(Chewy::Search::Pagination::Kaminari)
      end
    end
  end

  describe '#configuration' do
    before { subject.settings = {indices_path: 'app/custom_indices_path'} }

    specify do
      expect(subject.configuration).to include(indices_path: 'app/custom_indices_path')
    end

    context 'when Rails::VERSION constant is defined' do
      it 'looks for configuration in "config/chewy.yml"' do
        module Rails
          VERSION = '5.1.1'.freeze

          def self.root
            Pathname.new(__dir__)
          end
        end

        expect(File).to receive(:exist?)
          .with(Pathname.new(__dir__).join('config', 'chewy.yml'))
        subject.configuration
      end
    end
  end

  describe '.console_strategy' do
    context 'sets .console_strategy' do
      let(:default_strategy) { subject.console_strategy }
      let(:new_strategy) { :atomic }
      after { subject.console_strategy = default_strategy }

      specify do
        expect { subject.console_strategy = new_strategy }
          .to change { subject.console_strategy }.to(new_strategy)
      end
    end
  end
end
