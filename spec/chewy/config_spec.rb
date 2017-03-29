require 'spec_helper'

describe Chewy::Config do
  subject { described_class.send(:new) }

  its(:logger) { should be_nil }
  its(:transport_logger) { should be_nil }
  its(:transport_logger) { should be_nil }
  its(:query_mode) { should == :must }
  its(:filter_mode) { should == :and }
  its(:post_filter_mode) { should be_nil }
  its(:root_strategy) { should == :base }
  its(:request_strategy) { should == :atomic }
  its(:use_after_commit_callbacks) { should == true }
  its(:indices_path) { should == 'app/chewy' }
  its(:reset_disable_refresh_interval) { should == false }
  its(:reset_no_replicas) { should == false }
  its(:disable_refresh_async) { should == false }

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

  describe '#configuration' do
    before { subject.settings = { indices_path: 'app/custom_indices_path' } }

    specify do
      expect(subject.configuration).to include(indices_path: 'app/custom_indices_path')
    end
  end
end
