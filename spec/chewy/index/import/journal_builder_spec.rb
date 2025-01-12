# frozen_string_literal: true

require 'spec_helper'

describe Chewy::Index::Import::JournalBuilder, :orm do
  before do
    stub_model(:country)
    stub_index 'namespace/cities'
    stub_index 'namespace/countries' do
      index_scope Country
    end
    Timecop.freeze(time)
  end
  after { Timecop.return }

  let(:time) { Time.parse('2017-07-14 12:00Z') }

  let(:index) { Namespace::CitiesIndex }
  let(:to_index) { [] }
  let(:delete) { [] }
  subject { described_class.new(index, to_index: to_index, delete: delete) }

  describe '#bulk_body' do
    specify { expect(subject.bulk_body).to eq([]) }

    context do
      let(:to_index) { [{id: 1, name: 'City'}] }
      specify do
        expect(subject.bulk_body).to eq([{
          index: {
            _index: 'chewy_journal',
            data: {
              'index_name' => 'namespace/cities',
              'action' => 'index',
              'references' => [Base64.encode64('{"id":1,"name":"City"}')],
              'created_at' => time.as_json
            }
          }
        }])
      end
    end

    context do
      let(:delete) { [{id: 1, name: 'City'}] }
      specify do
        expect(subject.bulk_body).to eq([{
          index: {
            _index: 'chewy_journal',
            data: {
              'index_name' => 'namespace/cities',
              'action' => 'delete',
              'references' => [Base64.encode64('{"id":1,"name":"City"}')],
              'created_at' => time.as_json
            }
          }
        }])
      end
    end

    context do
      let(:index) { Namespace::CountriesIndex }
      let(:to_index) { [Country.new(id: 1, name: 'City')] }
      let(:delete) { [Country.new(id: 2, name: 'City')] }
      specify do
        expect(subject.bulk_body).to eq([{
          index: {
            _index: 'chewy_journal',
            data: {
              'index_name' => 'namespace/countries',
              'action' => 'index',
              'references' => [Base64.encode64('1')],
              'created_at' => time.as_json
            }
          }
        }, {
          index: {
            _index: 'chewy_journal',
            data: {
              'index_name' => 'namespace/countries',
              'action' => 'delete',
              'references' => [Base64.encode64('2')],
              'created_at' => time.as_json
            }
          }
        }])
      end
    end
  end
end
