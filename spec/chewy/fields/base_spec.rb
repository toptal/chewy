require 'spec_helper'

describe Chewy::Fields::Base do
  specify { expect(described_class.new('name').name).to eq(:name) }
  specify { expect(described_class.new('name', type: 'integer').options[:type]).to eq('integer') }

  describe '#compose' do
    let(:field) { described_class.new(:name, value: ->(o) { o.value }) }

    specify { expect(field.compose(double(value: 'hello'))).to eq(name: 'hello') }
    specify { expect(field.compose(double(value: %w[hello world]))).to eq(name: %w[hello world]) }

    specify do
      expect(described_class.new(:name, value: :last_name).compose(double(last_name: 'hello'))).to eq(name: 'hello')
    end
    specify do
      expect(described_class.new(:name, value: :last_name).compose('last_name' => 'hello')).to eq(name: 'hello')
    end
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
      let!(:country) do
        described_class.new(:name, value: lambda { |country, crutches|
                                            country.cities.map do |city|
                                              double(districts: city.districts, name: crutches.city_name)
                                            end
                                          })
      end
      let!(:city) do
        described_class.new(:name, value: lambda { |city, country, crutches|
                                            city.districts.map do |district|
                                              [district, country.name, crutches.suffix]
                                            end
                                          })
      end
      let(:district_value) { ->(district, city, country, crutches) { [district, city.name, country.name, crutches] } }
      let!(:district) do
        described_class.new(:name, value: district_value)
      end
      let(:crutches) { double(suffix: 'suffix', city_name: 'Bangkok') }

      before do
        country.children.push(city)
        city.children.push(district)
      end

      specify do
        expect(country.compose(double(name: 'Thailand', cities: [
          double(districts: %w[First Second])
        ]), crutches)).to eq(name: [
          {name: [
            {name: [%w[First Thailand suffix], 'Bangkok', 'Thailand', crutches]},
            {name: [%w[Second Thailand suffix], 'Bangkok', 'Thailand', crutches]}
          ]}
        ])
      end
    end

    context 'implicit values' do
      let(:field) { described_class.new(:name, type: 'integer') }
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
    let(:fields1) { Array.new(2) { |i| described_class.new("name#{i + 1}", type: "integer#{i + 1}") } }
    let(:fields2) { Array.new(2) { |i| described_class.new("name#{i + 3}", type: "integer#{i + 3}") } }
    before do
      fields1.each { |m| field.children.push(m) }
      fields2.each { |m| fields1[0].children.push(m) }
    end

    specify do
      expect(field.mappings_hash).to eq(name: {type: :object, properties: {
        name1: {type: 'integer1', fields: {
          name3: {type: 'integer3'}, name4: {type: 'integer4'}
        }}, name2: {type: 'integer2'}
      }})
    end

    context do
      let(:field) { described_class.new(:name, type: :integer) }
      let(:fields1) do
        [described_class.new(:name1), described_class.new(:name2, type: 'integer')]
      end

      specify do
        expect(field.mappings_hash).to eq(name: {type: :integer, fields: {
          name1: {type: 'object', properties: {
            name3: {type: 'integer3'}, name4: {type: 'integer4'}
          }}, name2: {type: 'integer'}
        }})
      end
    end
  end

  context 'integration' do
    context 'default field type' do
      before do
        stub_index(:events) do
          field :id
          field :category do
            field :id
            field :licenses do
              field :id
              field :created_at, type: 'time'
            end
          end
        end
      end

      around do |example|
        previous_type = Chewy.default_field_type
        Chewy.default_field_type = 'integer'
        example.run
        Chewy.default_field_type = previous_type
      end

      specify do
        expect(EventsIndex.mappings_hash).to eq(
          mappings: {
            properties: {
              id: {type: 'integer'},
              category: {
                type: 'object',
                properties: {
                  id: {type: 'integer'},
                  licenses: {
                    type: 'object',
                    properties: {
                      id: {type: 'integer'},
                      created_at: {type: 'time'}
                    }
                  }
                }
              }
            }
          }
        )
      end
    end

    context 'objects, hashes and arrays' do
      before do
        stub_index(:events) do
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

      specify do
        expect(
          EventsIndex.root.compose({id: 1, category: {id: 2, licenses: {id: 3, name: 'Name'}}})
        ).to eq('id' => 1, 'category' => {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}})
      end

      specify do
        expect(
          EventsIndex.root.compose({id: 1, category: [
            {id: 2, 'licenses' => {id: 3, name: 'Name1'}},
            {id: 4, licenses: nil}
          ]})
        ).to eq('id' => 1, 'category' => [
          {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name1'}},
          {'id' => 4, 'licenses' => nil.as_json}
        ])
      end

      specify do
        expect(
          EventsIndex.root.compose({
            'id' => 1,
            category: {
              id: 2, licenses: [
                {id: 3, name: 'Name1'},
                {id: 4, name: 'Name2'}
              ]
            }
          })
        ).to eq(
          'id' => 1,
          'category' => {
            'id' => 2,
            'licenses' => [
              {'id' => 3, 'name' => 'Name1'},
              {'id' => 4, 'name' => 'Name2'}
            ]
          }
        )
      end

      specify do
        expect(
          EventsIndex.root.compose({id: 1, category: [
            {id: 2, licenses: [
              {id: 3, 'name' => 'Name1'}, {id: 4, name: 'Name2'}
            ]},
            {id: 5, licenses: []}
          ]})
        ).to eq(
          'id' => 1,
          'category' => [
            {'id' => 2, 'licenses' => [
              {'id' => 3, 'name' => 'Name1'},
              {'id' => 4, 'name' => 'Name2'}
            ]},
            {'id' => 5, 'licenses' => []}
          ]
        )
      end
      specify do
        expect(
          EventsIndex.root.compose(double(id: 1, category: double(id: 2, licenses: double(id: 3, name: 'Name'))))
        ).to eq('id' => 1, 'category' => {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}})
      end

      specify do
        expect(
          EventsIndex.root.compose(double(id: 1, category: [
            double(id: 2, licenses: double(id: 3, name: 'Name1')),
            double(id: 4, licenses: nil)
          ]))
        ).to eq('id' => 1, 'category' => [
          {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name1'}},
          {'id' => 4, 'licenses' => nil.as_json}
        ])
      end

      specify do
        expect(
          EventsIndex.root.compose(double(id: 1, category: double(id: 2, licenses: [
            double(id: 3, name: 'Name1'), double(id: 4, name: 'Name2')
          ])))
        ).to eq('id' => 1, 'category' => {'id' => 2, 'licenses' => [
          {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
        ]})
      end

      specify do
        expect(
          EventsIndex.root.compose(double(id: 1, category: [
            double(id: 2, licenses: [
              double(id: 3, name: 'Name1'), double(id: 4, name: 'Name2')
            ]),
            double(id: 5, licenses: [])
          ]))
        ).to eq(
          'id' => 1, 'category' => [
            {'id' => 2, 'licenses' => [
              {'id' => 3, 'name' => 'Name1'}, {'id' => 4, 'name' => 'Name2'}
            ]},
            {'id' => 5, 'licenses' => []}
          ]
        )
      end
    end

    context 'custom methods' do
      before do
        stub_index(:events) do
          field :id, type: 'integer'
          field :category, value: -> { categories } do
            field :id, type: 'integer'
            field :licenses, value: -> { license } do
              field :id, type: 'integer'
              field :name
            end
          end
        end
      end

      specify do
        expect(
          EventsIndex.root.compose(
            double(
              id: 1, categories: double(
                id: 2, license: double(
                  id: 3, name: 'Name'
                )
              )
            )
          )
        ).to eq('id' => 1, 'category' => {'id' => 2, 'licenses' => {'id' => 3, 'name' => 'Name'}})
      end
    end

    context 'objects and multi_fields' do
      before do
        stub_index(:events) do
          field :id, type: 'integer'
          field :name, type: 'integer' do
            field :raw, analyzer: 'my_own'
          end
          field :category, type: 'object'
        end
      end

      specify do
        expect(EventsIndex.mappings_hash).to eq(
          mappings: {
            properties: {
              id: {type: 'integer'},
              name: {
                type: 'integer',
                fields: {
                  raw: {analyzer: 'my_own', type: Chewy.default_field_type}
                }
              },
              category: {type: 'object'}
            }
          }
        )
      end

      specify do
        expect(
          EventsIndex.root.compose(
            double(
              id: 1, name: 'Jonny', category: double(
                id: 2, as_json: {'name' => 'Borogoves'}
              )
            )
          )
        ).to eq(
          'id' => 1,
          'name' => 'Jonny',
          'category' => {'name' => 'Borogoves'}
        )
      end

      specify do
        expect(
          EventsIndex.root.compose(
            double(id: 1, name: 'Jonny', category: [
              double(id: 2, as_json: {'name' => 'Borogoves1'}),
              double(id: 3, as_json: {'name' => 'Borogoves2'})
            ])
          )
        ).to eq(
          'id' => 1,
          'name' => 'Jonny',
          'category' => [
            {'name' => 'Borogoves1'},
            {'name' => 'Borogoves2'}
          ]
        )
      end
    end

    context 'ignore_blank option for field method', :orm do
      before do
        stub_model(:location)
        stub_model(:city)
        stub_model(:country)

        City.belongs_to :country
        Location.belongs_to :city
        City.has_one :location, -> { order :id }
        Country.has_many :cities, -> { order :id }
      end

      context 'text fields with and without ignore_blank option' do
        before do
          stub_index(:countries) do
            index_scope Country
            field :id
            field :cities do
              field :id
              field :name
              field :historical_name, ignore_blank: false
              field :description, ignore_blank: true
            end
          end
        end

        let(:country_with_cities) do
          cities = [
            City.create!(id: 1, name: '', historical_name: '', description: ''),
            City.create!(id: 2, name: '', historical_name: '', description: '')
          ]

          Country.create!(id: 1, cities: cities)
        end

        specify do
          expect(CountriesIndex.root.compose(country_with_cities)).to eq(
            'id' => 1, 'cities' => [
              {'id' => 1, 'name' => '', 'historical_name' => ''},
              {'id' => 2, 'name' => '', 'historical_name' => ''}
            ]
          )
        end
      end

      context 'nested fields' do
        context 'with ignore_blank: true option' do
          before do
            stub_index(:countries) do
              index_scope Country
              field :id
              field :cities, ignore_blank: true do
                field :id
                field :name
                field :historical_name, ignore_blank: true
                field :description
              end
            end
          end

          let(:country) { Country.create!(id: 1, cities: cities) }
          context('without cities') do
            let(:cities) { [] }
            specify do
              expect(CountriesIndex.root.compose(country))
                .to eq('id' => 1)
            end
          end
          context('with cities') do
            let(:cities) { [City.create!(id: 1, name: '', historical_name: '')] }
            specify do
              expect(CountriesIndex.root.compose(country)).to eq(
                'id' => 1, 'cities' => [
                  {'id' => 1, 'name' => '', 'description' => nil}
                ]
              )
            end
          end
        end

        context 'with ignore_blank: false option' do
          before do
            stub_index(:countries) do
              index_scope Country
              field :id
              field :cities, ignore_blank: false do
                field :id
                field :name
                field :historical_name
                field :description
              end
            end
          end

          let(:country_with_cities) { Country.create!(id: 1) }

          specify do
            expect(CountriesIndex.root.compose(country_with_cities))
              .to eq('id' => 1, 'cities' => [])
          end
        end

        context 'without ignore_blank: true option' do
          before do
            stub_index(:countries) do
              index_scope Country
              field :id
              field :cities do
                field :id
                field :name
                field :historical_name
                field :description
              end
            end
          end

          let(:country_with_cities) { Country.create!(id: 1) }

          specify do
            expect(CountriesIndex.root.compose(country_with_cities))
              .to eq('id' => 1, 'cities' => [])
          end
        end
      end

      context 'geo_point field type' do
        context 'with ignore_blank: true option' do
          before do
            stub_index(:countries) do
              index_scope Country
              field :id
              field :cities do
                field :id
                field :name
                field :location, type: :geo_point, ignore_blank: true do
                  field :lat
                  field :lon
                end
              end
            end
          end

          specify do
            expect(
              CountriesIndex.root.compose({
                'id' => 1,
                'cities' => [
                  {'id' => 1, 'name' => 'City1', 'location' => {}},
                  {'id' => 2, 'name' => 'City2', 'location' => {}}
                ]
              })
            ).to eq(
              'id' => 1, 'cities' => [
                {'id' => 1, 'name' => 'City1'},
                {'id' => 2, 'name' => 'City2'}
              ]
            )
          end
        end

        context 'without ignore_blank option' do
          before do
            stub_index(:countries) do
              index_scope Country
              field :id
              field :cities do
                field :id
                field :name
                field :location, type: :geo_point do
                  field :lat
                  field :lon
                end
              end
            end
          end

          specify do
            expect(
              CountriesIndex.root.compose({
                'id' => 1,
                'cities' => [
                  {'id' => 1, 'name' => 'City1', 'location' => {}},
                  {'id' => 2, 'name' => 'City2', 'location' => {}}
                ]
              })
            ).to eq(
              'id' => 1, 'cities' => [
                {'id' => 1, 'name' => 'City1'},
                {'id' => 2, 'name' => 'City2'}
              ]
            )
          end
        end

        context 'with ignore_blank: false flag' do
          before do
            stub_index(:countries) do
              index_scope Country
              field :id
              field :cities do
                field :id
                field :name
                field :location, type: :geo_point, ignore_blank: false do
                  field :lat
                  field :lon
                end
              end
            end
          end

          specify do
            expect(
              CountriesIndex.root.compose({
                'id' => 1,
                'cities' => [
                  {'id' => 1, 'location' => {}, 'name' => 'City1'},
                  {'id' => 2, 'location' => '', 'name' => 'City2'}
                ]
              })
            ).to eq(
              'id' => 1, 'cities' => [
                {'id' => 1, 'location' => {}, 'name' => 'City1'},
                {'id' => 2, 'location' => '', 'name' => 'City2'}
              ]
            )
          end
        end
      end
    end

    context 'objects and scopes', :orm do
      before do
        stub_model(:city)
        stub_model(:country)

        City.belongs_to :country
        Country.has_many :cities, -> { order :id }

        stub_index(:countries) do
          index_scope Country
          field :id
          field :cities do
            field :id
            field :name
          end
        end
      end

      let(:country_with_cities) do
        cities = [City.create!(id: 1, name: 'City1'), City.create!(id: 2, name: 'City2')]

        Country.create!(id: 1, cities: cities)
      end

      specify do
        expect(CountriesIndex.root.compose(country_with_cities)).to eq('id' => 1, 'cities' => [
          {'id' => 1, 'name' => 'City1'}, {'id' => 2, 'name' => 'City2'}
        ])
      end

      context 'nested object' do
        before do
          stub_index(:cities) do
            index_scope City
            field :id
            field :country do
              field :id
              field :name
            end
          end
        end

        specify do
          expect(
            CitiesIndex.root.compose(City.create!(id: 1, country: Country.create!(id: 1, name: 'Country')))
          ).to eq('id' => 1, 'country' => {'id' => 1, 'name' => 'Country'})
        end
      end
    end
  end
end
