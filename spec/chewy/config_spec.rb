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

  describe '#transport_logger=' do
    let(:logger) { Logger.new('/dev/null') }
    after { subject.transport_logger = nil }

    specify { expect { subject.transport_logger = logger }
      .to change { Chewy.client.transport.logger }.to(logger) }
    specify { expect { subject.transport_logger = logger }
      .to change { subject.transport_logger }.to(logger) }
  end

  describe '#transport_tracer=' do
    let(:logger) { Logger.new('/dev/null') }
    after { subject.transport_tracer = nil }

    specify { expect { subject.transport_tracer = logger }
      .to change { Chewy.client.transport.tracer }.to(logger) }
    specify { expect { subject.transport_tracer = logger }
      .to change { subject.transport_tracer }.to(logger) }
  end
end
