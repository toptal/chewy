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
  its(:index_definition_path) { should == 'app/chewy' }

  describe '#transport_logger=' do
    let(:logger) { Logger.new('/dev/null') }
    after { subject.transport_logger = nil }

    specify { expect { subject.transport_logger = logger }
      .to change { Chewy.client.transport.logger }.to(logger) }
    specify { expect { subject.transport_logger = logger }
      .to change { subject.transport_logger }.to(logger) }
    specify { expect { subject.transport_logger = logger }
      .to change { subject.configuration[:logger] }.from(nil).to(logger) }
  end

  describe '#transport_tracer=' do
    let(:tracer) { Logger.new('/dev/null') }
    after { subject.transport_tracer = nil }

    specify { expect { subject.transport_tracer = tracer }
      .to change { Chewy.client.transport.tracer }.to(tracer) }
    specify { expect { subject.transport_tracer = tracer }
      .to change { subject.transport_tracer }.to(tracer) }
    specify { expect { subject.transport_tracer = tracer }
      .to change { subject.configuration[:tracer] }.from(nil).to(tracer) }
  end
end
