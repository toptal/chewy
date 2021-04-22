require 'spec_helper'

describe Chewy::Index::Import do
  before { Chewy.massacre }

  before do
    stub_model(:city)
  end

  before do
    stub_index(:cities) do
      index_scope City
      field :name
    end
  end

  def imported_cities
    CitiesIndex.all.map do |city|
      city.attributes.except('_score', '_explanation')
    end
  end

  def subscribe_notification
    outer_payload = {}
    ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, _start, _finish, _id, payload|
      outer_payload.merge!(payload)
    end
    outer_payload
  end

  let!(:dummy_cities) { Array.new(3) { |i| City.create(id: i + 1, name: "name#{i}") } }

  describe 'index creation on import' do
    let(:dummy_city) { City.create }

    specify 'lazy (default)' do
      expect(CitiesIndex).to receive(:exists?).and_call_original
      expect(CitiesIndex).to receive(:create!).and_call_original
      CitiesIndex.import(dummy_city)
    end

    specify 'lazy without objects' do
      expect(CitiesIndex).not_to receive(:exists?)
      expect(CitiesIndex).not_to receive(:create!)
      CitiesIndex.import([])
    end

    context 'skip' do
      before do
        # To avoid flaky issues when previous specs were run
        expect(Chewy::Index).to receive(:descendants).and_return([CitiesIndex])
        Chewy.create_indices
        Chewy.config.settings[:skip_index_creation_on_import] = true
      end
      after { Chewy.config.settings[:skip_index_creation_on_import] = nil }

      specify do
        expect(CitiesIndex).not_to receive(:exists?)
        expect(CitiesIndex).not_to receive(:create!)
        CitiesIndex.import(dummy_city)
      end
    end
  end

  shared_examples 'importing' do
    specify { expect(import).to eq(true) }
    specify { expect(import([])).to eq(true) }
    specify { expect(import(dummy_cities)).to eq(true) }
    specify { expect(import(dummy_cities.map(&:id))).to eq(true) }

    specify { expect { import([]) }.not_to update_index(CitiesIndex) }
    specify { expect { import }.to update_index(CitiesIndex).and_reindex(dummy_cities) }
    specify { expect { import dummy_cities }.to update_index(CitiesIndex).and_reindex(dummy_cities) }
    specify { expect { import dummy_cities.map(&:id) }.to update_index(CitiesIndex).and_reindex(dummy_cities) }

    describe 'criteria-driven importing' do
      let(:names) { %w[name0 name1] }

      context 'active record', :active_record do
        specify do
          expect { import(City.where(name: names)) }
            .to update_index(CitiesIndex).and_reindex(dummy_cities.first(2))
        end
        specify do
          expect { import(City.where(name: names).map(&:id)) }
            .to update_index(CitiesIndex).and_reindex(dummy_cities.first(2))
        end
      end
    end

    specify do
      dummy_cities.first.destroy
      expect { import dummy_cities }
        .to update_index(CitiesIndex).and_reindex(dummy_cities.from(1)).and_delete(dummy_cities.first)
    end

    specify do
      dummy_cities.first.destroy
      expect { import dummy_cities.map(&:id) }
        .to update_index(CitiesIndex).and_reindex(dummy_cities.from(1)).and_delete(dummy_cities.first)
    end

    specify do
      dummy_cities.first.destroy

      imported = []
      allow(CitiesIndex.client).to receive(:bulk) { |params|
        imported << params[:body]
        nil
      }

      import dummy_cities.map(&:id), batch_size: 2
      expect(imported.flatten).to match_array([
        {index: {_id: 2, data: {'name' => 'name1'}}},
        {index: {_id: 3, data: {'name' => 'name2'}}},
        {delete: {_id: dummy_cities.first.id}}
      ])
    end

    context ':bulk_size' do
      let!(:dummy_cities) { Array.new(3) { |i| City.create(id: i + 1, name: "name#{i}" * 20) } }

      specify do
        expect { import(dummy_cities, bulk_size: 1.2.kilobyte) }
          .to update_index(CitiesIndex).and_reindex(dummy_cities)
      end

      context do
        before { expect(Chewy.client).to receive(:bulk).exactly(3).times.and_call_original }
        specify { expect(import(dummy_cities, bulk_size: 1.2.kilobyte)).to eq(true) }
      end
    end

    context 'scoped' do
      before do
        names = %w[name0 name1]

        criteria = {name: names}

        stub_index(:cities) do
          index_scope City.where(criteria)
          field :name
        end
      end

      specify { expect { import }.to update_index(CitiesIndex).and_reindex(dummy_cities.first(2)) }

      context 'active record', :active_record do
        specify do
          expect { import City.where(id: dummy_cities.first.id) }
            .to update_index(CitiesIndex).and_reindex(dummy_cities.first).only
        end

        specify do
          allow(CitiesIndex).to receive(:import_linear).and_return(double(present?: false))
          allow(CitiesIndex).to receive(:import_parallel).and_return(double(present?: false))

          expects_no_query(except: /SELECT\s+1\s+AS\s+one\s+FROM/) do
            import City.where(id: dummy_cities.first.id)
          end
        end
      end
    end

    context 'instrumentation payload' do
      specify do
        payload = subscribe_notification
        dummy_cities.first.destroy
        import dummy_cities
        expect(payload).to eq(index: CitiesIndex, import: {delete: 1, index: 2})
      end

      specify do
        payload = subscribe_notification
        dummy_cities.first.destroy
        import dummy_cities, batch_size: 2
        expect(payload).to eq(index: CitiesIndex, import: {delete: 1, index: 2})
      end

      specify do
        payload = subscribe_notification
        import dummy_cities, batch_size: 2
        expect(payload).to eq(index: CitiesIndex, import: {index: 3})
      end

      context do
        before do
          stub_index(:cities) do
            index_scope City
            field :name, type: 'object'
          end
        end

        let(:mapper_parsing_exception) do
          {
            'type' => 'mapper_parsing_exception',
            'reason' => 'object mapping for [name] tried to parse field [name] as object, but found a concrete value'
          }
        end

        specify do
          payload = subscribe_notification
          import dummy_cities, batch_size: 2
          expect(payload).to eq(index: CitiesIndex,
            errors: {index: {mapper_parsing_exception => %w[1 2 3]}},
            import: {index: 3})
        end
      end
    end

    context 'fields' do
      before { CitiesIndex.import!(dummy_cities.first(2)) }

      context do
        before { expect(Chewy.client).to receive(:bulk).twice.and_call_original }
        specify { expect(import(dummy_cities, update_fields: [:name])).to eq(true) }
      end

      context do
        before { CitiesIndex.import!(dummy_cities.last) }
        before { expect(Chewy.client).to receive(:bulk).once.and_call_original }
        specify { expect(import(dummy_cities, update_fields: [:name])).to eq(true) }
      end
    end

    context 'fields integrational' do
      before do
        stub_index(:cities) do
          field :name
          field :object, type: 'object'
        end
      end

      let(:objects) do
        [
          double('Name1', id: 1, name: 'Name11', object: {foo: 11}),
          double('Name2', id: 2, name: 'Name12', object: 'foo'),
          double('Name3', id: 3, name: 'Name13', object: {foo: 13}),
          double('Name4', id: 4, name: 'Name14', object: 'foo'),
          double('Name5', id: 5, name: 'Name15', object: {foo: 15}),
          double('Name6', id: '', name: 'Name16', object: {foo: 16})
        ]
      end

      let(:old_objects) do
        Array.new(6) do |i|
          double("Name#{i + 1}", id: i + 1, name: "Name#{i + 1}", object: {foo: i + 1})
        end
      end

      specify do
        payload = subscribe_notification

        expect(Chewy.client).to receive(:bulk).twice.and_call_original
        import(objects, update_fields: %i[name])

        expect(payload).to eq(
          errors: {
            index: {{
              'type' => 'mapper_parsing_exception',
              'reason' => 'object mapping for [object] tried to parse field [object] as object, but found a concrete value'
            } => %w[2 4]}
          },
          import: {index: 6},
          index: CitiesIndex
        )
        expect(imported_cities).to match_array([
          {'id' => '1', 'name' => 'Name11', 'object' => {'foo' => 11}},
          {'id' => '3', 'name' => 'Name13', 'object' => {'foo' => 13}},
          {'id' => '5', 'name' => 'Name15', 'object' => {'foo' => 15}}
        ])
      end

      specify do
        payload = subscribe_notification

        expect(Chewy.client).to receive(:bulk).at_least(4).at_most(6).times.and_call_original
        import(objects, batch_size: 2, update_fields: %i[name])

        expect(payload).to eq(
          errors: {
            index: {{
              'type' => 'mapper_parsing_exception',
              'reason' => 'object mapping for [object] tried to parse field [object] as object, but found a concrete value'
            } => %w[2 4]}
          },
          import: {index: 6},
          index: CitiesIndex
        )
        expect(imported_cities).to match_array([
          {'id' => '1', 'name' => 'Name11', 'object' => {'foo' => 11}},
          {'id' => '3', 'name' => 'Name13', 'object' => {'foo' => 13}},
          {'id' => '5', 'name' => 'Name15', 'object' => {'foo' => 15}}
        ])
      end

      context do
        before { CitiesIndex.import!(objects[4]) }

        specify do
          payload = subscribe_notification

          expect(Chewy.client).to receive(:bulk).at_least(3).at_most(5).times.and_call_original
          import(objects, batch_size: 2, update_fields: %i[name])

          expect(payload).to eq(
            errors: {
              index: {{
                'type' => 'mapper_parsing_exception',
                'reason' => 'object mapping for [object] tried to parse field [object] as object, but found a concrete value'
              } => %w[2 4]}
            },
            import: {index: 6},
            index: CitiesIndex
          )
          expect(imported_cities).to match_array([
            {'id' => '1', 'name' => 'Name11', 'object' => {'foo' => 11}},
            {'id' => '3', 'name' => 'Name13', 'object' => {'foo' => 13}},
            {'id' => '5', 'name' => 'Name15', 'object' => {'foo' => 15}}
          ])
        end
      end

      context do
        before { CitiesIndex.import!(old_objects[1], old_objects[3], objects[4]) }

        specify do
          payload = subscribe_notification

          expect(Chewy.client).to receive(:bulk).twice.and_call_original
          import(objects, update_fields: %i[name])

          expect(payload).to eq(
            import: {index: 6},
            index: CitiesIndex
          )
          expect(imported_cities).to match_array([
            {'id' => '1', 'name' => 'Name11', 'object' => {'foo' => 11}},
            {'id' => '2', 'name' => 'Name12', 'object' => {'foo' => 2}},
            {'id' => '3', 'name' => 'Name13', 'object' => {'foo' => 13}},
            {'id' => '4', 'name' => 'Name14', 'object' => {'foo' => 4}},
            {'id' => '5', 'name' => 'Name15', 'object' => {'foo' => 15}}
          ])
        end

        specify do
          payload = subscribe_notification

          expect(Chewy.client).to receive(:bulk).at_least(3).at_most(5).times.and_call_original
          import(objects, batch_size: 2, update_fields: %i[name])

          expect(payload).to eq(
            import: {index: 6},
            index: CitiesIndex
          )
          expect(imported_cities).to match_array([
            {'id' => '1', 'name' => 'Name11', 'object' => {'foo' => 11}},
            {'id' => '2', 'name' => 'Name12', 'object' => {'foo' => 2}},
            {'id' => '3', 'name' => 'Name13', 'object' => {'foo' => 13}},
            {'id' => '4', 'name' => 'Name14', 'object' => {'foo' => 4}},
            {'id' => '5', 'name' => 'Name15', 'object' => {'foo' => 15}}
          ])
        end

        specify do
          payload = subscribe_notification

          expect(Chewy.client).to receive(:bulk).once.and_call_original
          import(objects, update_fields: %i[name], update_failover: false)

          # Full match doesn't work here.
          expect(payload[:errors][:update].keys).to match([
            hash_including('type' => 'document_missing_exception', 'reason' => '[_doc][1]: document missing'),
            hash_including('type' => 'document_missing_exception', 'reason' => '[_doc][3]: document missing')
          ])
          expect(payload[:errors][:update].values).to eq([['1'], ['3']])
          expect(imported_cities).to match_array([
            {'id' => '2', 'name' => 'Name12', 'object' => {'foo' => 2}},
            {'id' => '4', 'name' => 'Name14', 'object' => {'foo' => 4}},
            {'id' => '5', 'name' => 'Name15', 'object' => {'foo' => 15}}
          ])
        end
      end

      context do
        before { CitiesIndex.import!(old_objects) }

        specify do
          payload = subscribe_notification

          expect(Chewy.client).to receive(:bulk).once.and_call_original
          import(objects, update_fields: %i[name])

          expect(payload).to eq(
            import: {index: 6},
            index: CitiesIndex
          )
          expect(imported_cities).to match_array([
            {'id' => '1', 'name' => 'Name11', 'object' => {'foo' => 1}},
            {'id' => '2', 'name' => 'Name12', 'object' => {'foo' => 2}},
            {'id' => '3', 'name' => 'Name13', 'object' => {'foo' => 3}},
            {'id' => '4', 'name' => 'Name14', 'object' => {'foo' => 4}},
            {'id' => '5', 'name' => 'Name15', 'object' => {'foo' => 5}},
            {'id' => '6', 'name' => 'Name6', 'object' => {'foo' => 6}}
          ])
        end
      end

      context do
        before { CitiesIndex.import!(old_objects) }

        specify do
          payload = subscribe_notification

          expect(Chewy.client).to receive(:bulk).once.and_call_original
          import(objects, update_fields: %i[object])

          expect(payload).to eq(
            errors: {
              update: {{
                'type' => 'mapper_parsing_exception',
                'reason' => 'object mapping for [object] tried to parse field [object] as object, but found a concrete value'
              } => %w[2 4]}
            },
            import: {index: 6},
            index: CitiesIndex
          )
          expect(imported_cities).to match_array([
            {'id' => '1', 'name' => 'Name1', 'object' => {'foo' => 11}},
            {'id' => '2', 'name' => 'Name2', 'object' => {'foo' => 2}},
            {'id' => '3', 'name' => 'Name3', 'object' => {'foo' => 13}},
            {'id' => '4', 'name' => 'Name4', 'object' => {'foo' => 4}},
            {'id' => '5', 'name' => 'Name5', 'object' => {'foo' => 15}},
            {'id' => '6', 'name' => 'Name6', 'object' => {'foo' => 6}}
          ])
        end
      end
    end

    context 'error handling' do
      context do
        before do
          stub_index(:cities) do
            index_scope City
            field :name, type: 'object'
          end
        end

        specify { expect(import(dummy_cities)).to eq(false) }
        specify { expect(import(dummy_cities.map(&:id))).to eq(false) }
        specify { expect(import(dummy_cities, batch_size: 1)).to eq(false) }
      end

      context do
        before do
          stub_index(:cities) do
            index_scope City
            field :name, type: 'object', value: -> { name == 'name1' ? name : {name: name} }
          end
        end

        specify { expect(import(dummy_cities)).to eq(false) }
        specify { expect(import(dummy_cities.map(&:id))).to eq(false) }
        specify { expect(import(dummy_cities, batch_size: 2)).to eq(false) }
      end
    end

    context 'default_import_options are set' do
      before do
        CitiesIndex.default_import_options(batch_size: 500)
      end

      specify do
        expect(CitiesIndex.adapter).to receive(:import).with(any_args, hash_including(batch_size: 500))
        CitiesIndex.import
      end
    end
  end

  describe '.import', :orm do
    def import(*args)
      CitiesIndex.import(*args)
    end

    it_behaves_like 'importing'

    context 'parallel' do
      def import(*args)
        options = args.extract_options!
        options[:parallel] = 0
        CitiesIndex.import(*args, options)
      end

      it_behaves_like 'importing'
    end
  end

  describe '.import!', :orm do
    specify { expect { CitiesIndex.import! }.not_to raise_error }

    context do
      before do
        stub_index(:cities) do
          index_scope City
          field :name, type: 'object'
        end
      end

      specify { expect { CitiesIndex.import!(dummy_cities) }.to raise_error Chewy::ImportFailed }
    end

    context 'progressbar output' do
      let(:mocked_progressbar) { Struct.new(:progress, :total).new(0, 100) }
      context 'options values' do
        specify do
          expect(ProgressBar).to receive(:create).and_return(mocked_progressbar)
          expect(mocked_progressbar).to receive(:progress).at_least(:once).and_call_original
          expect(CitiesIndex).to receive(:import_parallel).and_call_original
          CitiesIndex.import(parallel: true, progressbar: 'true')
          expect(mocked_progressbar.progress).to eq(3)
          expect(mocked_progressbar.total).to eq(3)
        end
      end
    end
  end

  describe '.compose' do
    before do
      stub_index(:cities) do
        crutch :names do |collection|
          collection.map { |o| [o.name, "#{o.name}42"] }.to_h
        end
        field :name, value: ->(o, c) { c.names[o.name] }
        field :rating
      end
    end

    specify do
      expect(CitiesIndex.compose(double(name: 'Name', rating: 42)))
        .to eq('name' => 'Name42', 'rating' => 42)
    end

    specify do
      expect(CitiesIndex.compose(double(name: 'Name', rating: 42), fields: %i[name]))
        .to eq('name' => 'Name42')
    end

    context 'witchcraft' do
      before { CitiesIndex.witchcraft! }

      specify do
        expect(CitiesIndex.compose(double(name: 'Name', rating: 42)))
          .to eq('name' => 'Name42', 'rating' => 42)
      end

      specify do
        expect(CitiesIndex.compose(double(name: 'Name', rating: 42), fields: %i[name]))
          .to eq('name' => 'Name42')
      end
    end

    context 'custom crutches' do
      let(:crutches) { double(names: {'Name' => 'Name43'}) }

      specify do
        expect(CitiesIndex.compose(double(name: 'Name', rating: 42), crutches))
          .to eq('name' => 'Name43', 'rating' => 42)
      end

      specify do
        expect(CitiesIndex.compose(double(name: 'Name', rating: 42), crutches, fields: %i[name]))
          .to eq('name' => 'Name43')
      end
    end
  end
end
