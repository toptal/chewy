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

    let(:configuration) { subject.configuration }
    before { subject.settings = settings }

    describe 'custom settings' do

      let(:settings) { { indices_path: 'app/custom_indices_path'} }

      specify do
        expect(configuration).to include(indices_path: 'app/custom_indices_path')
      end
    end

    describe 'host value' do

      let(:settings) { { host: host } }

      context 'when host value is a string' do

        let(:host) { 'localhost:9200' }

        it 'returns the host value as is' do
          expect(configuration[:host]).to eq(host)
        end
      end

      context 'when host value is a Proc' do

        let(:host_lambda_value) { 'localhost:9222' }
        let(:host) { lambda { host_lambda_value } }

        it 'executes the lambda and sets host to the return value' do
          expect(configuration[:host]).to eq(host_lambda_value)
        end
      end
    end

    describe 'host value' do

      let(:settings) { { host: host } }

      context 'when host value is a string' do

        let(:host) { 'localhost:9200' }

        it 'returns the host value as is' do
          expect(configuration[:host]).to eq(host)
        end
      end

      context 'when host value is a lambda' do

        let(:host_lambda_value) { 'localhost:9222' }
        let(:host) { lambda { host_lambda_value } }

        it 'executes the lambda and sets host to the return value' do
          expect(configuration[:host]).to eq(host_lambda_value)
        end
      end
    end
  end

  describe '#client_key' do

    before { subject.settings = settings }

    context 'when instance_identifier is not set' do

      let(:settings) { {} }

      it 'returns :chewy_client' do
        expect(subject.client_key).to eq(:chewy_client)
      end
    end

    context 'when instance_identifier is a string' do

      let(:settings) { { instance_identifier: 'acme' } }

      it 'returns a client key that includes the instance_identifier' do
        expect(subject.client_key).to eq(:chewy_client_acme)
      end
    end

    context 'when instance_identifier is a Proc' do

      let(:settings) { { instance_identifier: lambda { 'acme_proc' } } }

      it 'returns a client key the value returned from the Proc' do
        expect(subject.client_key).to eq(:chewy_client_acme_proc)
      end
    end
  end
end
