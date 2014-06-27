require 'spec_helper'

describe Chewy::Fields::Base do
  specify { described_class.new('name').name.should == :name }
  specify { described_class.new('name', type: 'integer').options[:type].should == 'integer' }

  describe '#compose' do
    let(:field) { described_class.new(:name, value: ->(o){ o.value }) }

    specify { field.compose(double(value: 'hello')).should == {name: 'hello'} }
    specify { field.compose(double(value: ['hello', 'world'])).should == {name: ['hello', 'world']} }

    specify { described_class.new(:name).compose(double(name: 'hello')).should == {name: 'hello'} }

    context do
      before do
        field.nested(described_class.new(:subname1, value: ->(o){ o.subvalue1 }))
        field.nested(described_class.new(:subname2, value: ->{ subvalue2 }))
        field.nested(described_class.new(:subname3))
      end

      specify { field.compose(double(value: double(subvalue1: 'hello', subvalue2: 'value', subname3: 'world')))
        .should == {name: {'subname1' => 'hello', 'subname2' => 'value', 'subname3' => 'world'}} }
      specify { field.compose(double(value: [
        double(subvalue1: 'hello1', subvalue2: 'value1', subname3: 'world1'),
        double(subvalue1: 'hello2', subvalue2: 'value2', subname3: 'world2')
      ])).should == {name: [
        {'subname1' => 'hello1', 'subname2' => 'value1', 'subname3' => 'world1'},
        {'subname1' => 'hello2', 'subname2' => 'value2', 'subname3' => 'world2'}
      ]} }
    end

    context do
      let(:field) { described_class.new(:name, type: 'string') }
      before do
        field.nested(described_class.new(:name))
        field.nested(described_class.new(:untouched))
      end

      specify { field.compose(double(name: 'Alex')).should == {name: 'Alex'} }
    end

    context do
      let(:field) { described_class.new(:name, type: 'object') }
      let(:object) { double(name: { key1: 'value1', key2: 'value2' }) }

      before do
        field.nested(described_class.new(:key1, value: ->(h){ h[:key1] }))
        field.nested(described_class.new(:key2, value: ->(h){ h[:key2] }))
      end

      specify{ field.compose(object).should == { name: { 'key1' => 'value1', 'key2' => 'value2' } } }
    end
  end

  describe '#nested' do
    let(:field) { described_class.new(:name) }

    specify { expect { field.nested(described_class.new(:name1)) }
      .to change { field.nested[:name1] }.from(nil).to(an_instance_of(described_class))  }
  end

  describe '#mappings_hash' do
    let(:field) { described_class.new(:name, type: :object) }
    let(:fields1) { 2.times.map { |i| described_class.new("name#{i+1}", type: "string#{i+1}") } }
    let(:fields2) { 2.times.map { |i| described_class.new("name#{i+3}", type: "string#{i+3}") } }
    before do
      fields1.each { |m| field.nested(m) }
      fields2.each { |m| fields1[0].nested(m) }
    end

    specify { field.mappings_hash.should == {name: {type: :object, properties: {
      name1: {type: 'string1', fields: {
        name3: {type: 'string3'}, name4: {type: 'string4'}
      }}, name2: {type: 'string2'}
    }}} }

    context do
      let(:field) { described_class.new(:name, type: :string) }
      let(:fields1) { 2.times.map { |i| described_class.new("name#{i+1}") } }

      specify { field.mappings_hash.should == {name: {type: :string, fields: {
        name1: {type: 'object', properties: {
          name3: {type: 'string3'}, name4: {type: 'string4'}
        }}, name2: {type: 'string'}
      }}} }
    end
  end

  context 'integration' do
    context 'objects, hashes and arrays' do
      before do
        stub_index(:events) do
          define_type :event do
            field :id
            field :category do
              field :id
              field :licenses do
                field :id
                field :name
              end
            end
          end
        end
      end

      specify do
        EventsIndex::Event.mappings_hash.should == { event: {
          properties: {
            id: { type: 'string' },
            category: {
              type: 'object',
              properties: {
                id: { type: 'string' },
                licenses: {
                  type: 'object',
                  properties: {
                    id: { type: 'string' },
                    name: { type: 'string' } } } } } } } }
      end

      specify do
        EventsIndex::Event.root_object.compose(
          id: 1, category: { id: 2, licenses: { id: 3, name: 'Name' } }
        ).should == {
          event: { 'id' => 1, 'category' => { 'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}}}
        }
      end

      specify do
        EventsIndex::Event.root_object.compose(id: 1, category: [
          { id: 2, 'licenses' => { id: 3, name: 'Name1' } },
          { id: 4, licenses: nil}
        ]).should == {
          event: { 'id' => 1, 'category' => [
            { 'id' => 2, 'licenses' => { 'id' => 3, 'name' => 'Name1' } },
            {'id' => 4, 'licenses' => nil }
          ] }
        }
      end

      specify do
        EventsIndex::Event.root_object.compose('id' => 1, category: { id: 2, licenses: [
          { id: 3, name: 'Name1' }, { id: 4, name: 'Name2' }
        ] }).should == {
          event: { 'id' => 1, 'category' => { 'id' => 2, 'licenses' => [
            {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
          ] } }
        }
      end

      specify do
        EventsIndex::Event.root_object.compose(id: 1, category: [
          { id: 2, licenses: [
            { id: 3, 'name' => 'Name1' }, { id: 4, name: 'Name2' }
          ] },
          { id: 5, licenses: [] }
        ]).should == {
          event: { 'id' => 1, 'category' => [
            { 'id' => 2, 'licenses' => [
              { 'id' => 3, 'name' => 'Name1' }, { 'id' => 4, 'name' => 'Name2' }
            ] },
            {'id' => 5, 'licenses' => [] }
          ] }
        }
      end

      specify do
        EventsIndex::Event.root_object.compose(
          double(id: 1, category: double(id: 2, licenses: double(id: 3, name: 'Name')))
        ).should == {
          event: { 'id' => 1, 'category' => { 'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}}}
        }
      end

      specify do
        EventsIndex::Event.root_object.compose(double(id: 1, category: [
          double(id: 2, licenses: double(id: 3, name: 'Name1')),
          double(id: 4, licenses: nil)
        ])).should == {
          event: { 'id' => 1, 'category' => [
            { 'id' => 2, 'licenses' => { 'id' => 3, 'name' => 'Name1' } },
            {'id' => 4, 'licenses' => nil }
          ] }
        }
      end

      specify do
        EventsIndex::Event.root_object.compose(double(id: 1, category: double(id: 2, licenses: [
          double(id: 3, name: 'Name1'), double(id: 4, name: 'Name2')
        ]))).should == {
          event: { 'id' => 1, 'category' => { 'id' => 2, 'licenses' => [
            {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
          ] } }
        }
      end

      specify do
        EventsIndex::Event.root_object.compose(double(id: 1, category: [
          double(id: 2, licenses: [
            double(id: 3, name: 'Name1'), double(id: 4, name: 'Name2')
          ]),
          double(id: 5, licenses: [])
        ])).should == {
          event: { 'id' => 1, 'category' => [
            { 'id' => 2, 'licenses' => [
              { 'id' => 3, 'name' => 'Name1' }, { 'id' => 4, 'name' => 'Name2' }
            ] },
            {'id' => 5, 'licenses' => [] }
          ] }
        }
      end
    end

    context 'custom methods' do
      before do
        stub_index(:events) do
          define_type :event do
            field :id
            field :category, value: ->{ categories } do
              field :id
              field :licenses, value: ->{ license } do
                field :id
                field :name
              end
            end
          end
        end
      end

      specify do
        EventsIndex::Event.root_object.compose(
          double(id: 1, categories: double(id: 2, license: double(id: 3, name: 'Name')))
        ).should == {
          event: { 'id' => 1, 'category' => { 'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}}}
        }
      end
    end

    context 'objects and multi_fields' do
      before do
        stub_index(:events) do
          define_type :event do
            field :id
            field :name, type: 'string' do
              field :raw, analyzer: 'my_own'
            end
            field :category, type: 'object'
          end
        end
      end

      specify do
        EventsIndex::Event.mappings_hash.should == { event: {
          properties: {
            id: { type: 'string' },
            name: {
              type: 'string',
              fields: {
                raw: { analyzer: 'my_own', type: 'string' }
              }
            },
            category: { type: 'object' }
          }
        } }
      end

      specify do
        EventsIndex::Event.root_object.compose(
          double(id: 1, name: 'Jonny', category: double(id: 2, as_json: {name: 'Borogoves'}))
        ).should == {
          event: {
            'id' => 1,
            'name' => 'Jonny',
            'category' => { 'name' => 'Borogoves' }
          }
        }
      end

      specify do
        EventsIndex::Event.root_object.compose(
          double(id: 1, name: 'Jonny', category: [
            double(id: 2, as_json: { name: 'Borogoves1' }),
            double(id: 3, as_json: { name: 'Borogoves2' })
          ])
        ).should == {
          event: {
            'id' => 1,
            'name' => 'Jonny',
            'category' => [
              { 'name' => 'Borogoves1' },
              { 'name' => 'Borogoves2' }
            ]
          }
        }
      end
    end

    context 'objects and scopes' do
      before do
        stub_model(:city) do
          belongs_to :country
        end

        stub_model(:country) do
          has_many :cities
        end

        stub_index(:countries) do
          define_type Country do
            field :id
            field :cities do
              field :id
              field :name
            end
          end
        end
      end

      specify do
        CountriesIndex::Country.root_object.compose(
          Country.create!(cities: [City.create!(name: 'City1'), City.create!(name: 'City2')])
        ).should == {
          country: { 'id' => 1, 'cities' => [
            { 'id' => 1, 'name' => 'City1' }, { 'id' => 2, 'name' => 'City2' }
          ] }
        }
      end

      context 'nested object' do
        before do
          stub_index(:cities) do
            define_type City do
              field :id
              field :country do
                field :id
                field :name
              end
            end
          end
        end

        specify do
          CitiesIndex::City.root_object.compose(
            City.create!(country: Country.create!(name: 'Country'))
          ).should == {
            city: { 'id' => 1, 'country' => { 'id' => 1, 'name' => 'Country' } }
          }
        end
      end
    end
  end
end
