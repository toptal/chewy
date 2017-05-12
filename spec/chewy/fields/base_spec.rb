require 'spec_helper'

describe Chewy::Fields::Base do
  specify { expect(described_class.new('name').name).to eq(:name) }
  specify { expect(described_class.new('name', type: 'integer').options[:type]).to eq('integer') }

  describe '#compose' do
    let(:field) { described_class.new(:name, value: ->(o) { o.value }) }

    specify { expect(field.compose(double(value: 'hello'))).to eq(name: 'hello') }
    specify { expect(field.compose(double(value: %w[hello world]))).to eq(name: %w[hello world]) }

    specify { expect(described_class.new(:name).compose(double(name: 'hello'))).to eq(name: 'hello') }
    specify { expect(described_class.new(:false_value).compose(false_value: false)).to eq(false_value: false) }
    specify { expect(described_class.new(:true_value).compose(true_value: true)).to eq(true_value: true) }
    specify { expect(described_class.new(:nil_value).compose(nil_value: nil)).to eq(nil_value: nil) }

    context 'nested fields' do
      before do
        field.children.push(described_class.new(:subname1, value: ->(o) { o.subvalue1 }))
        field.children.push(described_class.new(:subname2, value: -> { subvalue2 }))
        field.children.push(described_class.new(:subname3))
      end

      specify do
        expect(field.compose(double(value: double(subvalue1: 'hello', subvalue2: 'value', subname3: 'world'))))
          .to eq(name: {subname1: 'hello', subname2: 'value', subname3: 'world'})
      end
      specify do
        expect(field.compose(double(value: [
          double(subvalue1: 'hello1', subvalue2: 'value1', subname3: 'world1'),
          double(subvalue1: 'hello2', subvalue2: 'value2', subname3: 'world2')
        ]))).to eq(name: [
          {subname1: 'hello1', subname2: 'value1', subname3: 'world1'},
          {subname1: 'hello2', subname2: 'value2', subname3: 'world2'}
        ])
      end
    end

    context 'parent objects' do
      let!(:country) { described_class.new(:name, value: ->(country) { country.cities }) }
      let!(:city) { described_class.new(:name, value: ->(city, country) { city.districts.map { |district| [district, country.name] } }) }
      let!(:district) { described_class.new(:name, value: ->(district, city, country) { [district, city.name, country.name] }) }

      before do
        country.children.push(city)
        city.children.push(district)
      end

      specify do
        expect(country.compose(double(name: 'Thailand', cities: [
          double(name: 'Bangkok', districts: %w[First Second])
        ]))).to eq(name: [
          {name: [
            {name: [%w[First Thailand], 'Bangkok', 'Thailand']},
            {name: [%w[Second Thailand], 'Bangkok', 'Thailand']}
          ]}
        ])
      end
    end

    context 'implicit values' do
      let(:field) { described_class.new(:name, type: 'string') }
      before do
        field.children.push(described_class.new(:name))
        field.children.push(described_class.new(:untouched))
      end

      specify { expect(field.compose(double(name: 'Alex'))).to eq(name: 'Alex') }
    end

    context 'hash values' do
      let(:field) { described_class.new(:name, type: 'object') }
      let(:object) { double(name: {key1: 'value1', key2: 'value2'}) }

      before do
        field.children.push(described_class.new(:key1, value: ->(h) { h[:key1] }))
        field.children.push(described_class.new(:key2, value: ->(h) { h[:key2] }))
      end

      specify { expect(field.compose(object)).to eq(name: {key1: 'value1', key2: 'value2'}) }
    end
  end

  describe '#mappings_hash' do
    let(:field) { described_class.new(:name, type: :object) }
    let(:fields1) { Array.new(2) { |i| described_class.new("name#{i + 1}", type: "string#{i + 1}") } }
    let(:fields2) { Array.new(2) { |i| described_class.new("name#{i + 3}", type: "string#{i + 3}") } }
    before do
      fields1.each { |m| field.children.push(m) }
      fields2.each { |m| fields1[0].children.push(m) }
    end

    specify do
      expect(field.mappings_hash).to eq(name: {type: :object, properties: {
                                          name1: {type: 'string1', fields: {
                                            name3: {type: 'string3'}, name4: {type: 'string4'}
                                          }}, name2: {type: 'string2'}
                                        }})
    end

    context do
      let(:field) { described_class.new(:name, type: :string) }
      let(:fields1) { Array.new(2) { |i| described_class.new("name#{i + 1}") } }

      specify do
        expect(field.mappings_hash).to eq(name: {type: :string, fields: {
                                            name1: {type: 'object', properties: {
                                              name3: {type: 'string3'}, name4: {type: 'string4'}
                                            }}, name2: {type: 'string'}
                                          }})
      end
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
        expect(EventsIndex::Event.mappings_hash).to eq(event: {
                                                         properties: {
                                                           id: {type: 'string'},
                                                           category: {
                                                             type: 'object',
                                                             properties: {
                                                               id: {type: 'string'},
                                                               licenses: {
                                                                 type: 'object',
                                                                 properties: {
                                                                   id: {type: 'string'},
                                                                   name: {type: 'string'}
                                                                 }
                                                               }
                                                             }
                                                           }
                                                         }
                                                       })
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(
                 id: 1, category: {id: 2, licenses: {id: 3, name: 'Name'}}
        )).to eq('event' => {'id' => 1, 'category' => {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}}})
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(id: 1, category: [
          {id: 2, 'licenses' => {id: 3, name: 'Name1'}},
          {id: 4, licenses: nil}
        ])).to eq('event' => {'id' => 1, 'category' => [
          {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name1'}},
          {'id' => 4, 'licenses' => nil.as_json}
        ]})
      end

      specify do
        expect(EventsIndex::Event.root_object.compose('id' => 1, category: {id: 2, licenses: [
          {id: 3, name: 'Name1'}, {id: 4, name: 'Name2'}
        ]})).to eq('event' => {'id' => 1, 'category' => {'id' => 2, 'licenses' => [
          {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
        ]}})
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(id: 1, category: [
          {id: 2, licenses: [
            {id: 3, 'name' => 'Name1'}, {id: 4, name: 'Name2'}
          ]},
          {id: 5, licenses: []}
        ])).to eq('event' => {'id' => 1, 'category' => [
          {'id' => 2, 'licenses' => [
            {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
          ]},
          {'id' => 5, 'licenses' => []}
        ]})
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(
                 double(id: 1, category: double(id: 2, licenses: double(id: 3, name: 'Name')))
        )).to eq('event' => {'id' => 1, 'category' => {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}}})
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(double(id: 1, category: [
          double(id: 2, licenses: double(id: 3, name: 'Name1')),
          double(id: 4, licenses: nil)
        ]))).to eq('event' => {'id' => 1, 'category' => [
          {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name1'}},
          {'id' => 4, 'licenses' => nil.as_json}
        ]})
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(double(id: 1, category: double(id: 2, licenses: [
          double(id: 3, name: 'Name1'), double(id: 4, name: 'Name2')
        ])))).to eq('event' => {'id' => 1, 'category' => {'id' => 2, 'licenses' => [
          {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
        ]}})
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(double(id: 1, category: [
          double(id: 2, licenses: [
            double(id: 3, name: 'Name1'), double(id: 4, name: 'Name2')
          ]),
          double(id: 5, licenses: [])
        ]))).to eq('event' => {'id' => 1, 'category' => [
          {'id' => 2, 'licenses' => [
            {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
          ]},
          {'id' => 5, 'licenses' => []}
        ]})
      end
    end

    context 'custom methods' do
      before do
        stub_index(:events) do
          define_type :event do
            field :id
            field :category, value: -> { categories } do
              field :id
              field :licenses, value: -> { license } do
                field :id
                field :name
              end
            end
          end
        end
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(
                 double(id: 1, categories: double(id: 2, license: double(id: 3, name: 'Name')))
        )).to eq('event' => {'id' => 1, 'category' => {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}}})
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
        expect(EventsIndex::Event.mappings_hash).to eq(event: {
                                                         properties: {
                                                           id: {type: 'string'},
                                                           name: {
                                                             type: 'string',
                                                             fields: {
                                                               raw: {analyzer: 'my_own', type: 'string'}
                                                             }
                                                           },
                                                           category: {type: 'object'}
                                                         }
                                                       })
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(
                 double(id: 1, name: 'Jonny', category: double(id: 2, as_json: {'name' => 'Borogoves'}))
        )).to eq('event' => {
                   'id' => 1,
                   'name' => 'Jonny',
                   'category' => {'name' => 'Borogoves'}
                 })
      end

      specify do
        expect(EventsIndex::Event.root_object.compose(
                 double(id: 1, name: 'Jonny', category: [
                   double(id: 2, as_json: {'name' => 'Borogoves1'}),
                   double(id: 3, as_json: {'name' => 'Borogoves2'})
                 ])
        )).to eq('event' => {
                   'id' => 1,
                   'name' => 'Jonny',
                   'category' => [
                     {'name' => 'Borogoves1'},
                     {'name' => 'Borogoves2'}
                   ]
                 })
      end
    end

    context 'objects and scopes', :orm do
      before do
        stub_model(:city)
        stub_model(:country)

        case adapter
        when :active_record
          City.belongs_to :country
          if ActiveRecord::VERSION::MAJOR >= 4
            Country.has_many :cities, -> { order :id }
          else
            Country.has_many :cities, order: :id
          end
        when :mongoid
          if Mongoid::VERSION.start_with?('6')
            City.belongs_to :country, optional: true
          else
            City.belongs_to :country
          end
          Country.has_many :cities, order: :id.asc
        when :sequel
          City.many_to_one :country
          Country.one_to_many :cities, order: :id
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

      let(:country_with_cities) do
        cities = [City.create!(id: 1, name: 'City1'), City.create!(id: 2, name: 'City2')]

        if adapter == :sequel
          Country.create(id: 1).tap do |country|
            cities.each { |city| country.add_city(city) }
          end
        else
          Country.create!(id: 1, cities: cities)
        end
      end

      specify do
        expect(CountriesIndex::Country.root_object.compose(country_with_cities)).to eq('country' => {'id' => 1, 'cities' => [
          {'id' => 1, 'name' => 'City1'}, {'id' => 2, 'name' => 'City2'}
        ]})
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
          expect(CitiesIndex::City.root_object.compose(
                   City.create!(id: 1, country: Country.create!(id: 1, name: 'Country'))
          )).to eq('city' => {'id' => 1, 'country' => {'id' => 1, 'name' => 'Country'}})
        end
      end
    end
  end
end
