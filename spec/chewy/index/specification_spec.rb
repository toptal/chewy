require 'spec_helper'

describe Chewy::Index::Specification do
  before { Chewy.massacre }

  let(:index1) do
    stub_index(:places) do
      define_type(:city) do
        field :name, type: 'text'
      end
    end
  end

  let(:index2) do
    stub_index(:places) do
      settings analyzer: {}
      define_type(:city) do
        field :name, type: 'text'
      end
    end
  end

  let(:index3) do
    stub_index(:places) do
      define_type(:city) do
        field :name, type: 'text'
        field :population, type: 'integer'
      end
    end
  end

  let(:index4) do
    stub_index(:places) do
      define_type(:city) do
        field :population, type: 'integer'
        field :name, type: 'text'
      end
    end
  end

  let(:index5) do
    stub_index('namespace/cities') do
      define_type(:city) do
        field :population, type: 'integer'
      end
    end
  end

  let(:specification1) { described_class.new(index1) }
  let(:specification2) { described_class.new(index2) }
  let(:specification3) { described_class.new(index3) }
  let(:specification4) { described_class.new(index4) }
  let(:specification5) { described_class.new(index5) }

  describe '#lock!' do
    specify do
      expect { specification1.lock! }.to change { Chewy::Stash::Specification.all.hits }.from([]).to([{
        '_index' => 'chewy_stash',
        '_type' => 'specification',
        '_id' => 'places',
        '_score' => 1.0,
        '_source' => {'specification' => JSON.dump(
          'settings' => {'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
          'mappings' => {'city' => {'properties' => {'name' => {'type' => 'text'}}}}
        ), 'value' => nil}
      }])
    end

    context do
      before { specification1.lock! }

      specify do
        expect { specification5.lock! }.to change { Chewy::Stash::Specification.all.hits }.to([
          {
            '_index' => 'chewy_stash',
            '_type' => 'specification',
            '_id' => 'places',
            '_score' => 1.0,
            '_source' => {
              'value' => nil,
              'specification' => "{\"settings\":{\"index\":{\"number_of_shards\":1,\"number_of_replicas\":0}},\"mappings\":{\"city\":{\"properties\":{\"name\":{\"type\":\"text\"}}}}}"
            }
          }, {
            '_index' => 'chewy_stash',
            '_type' => 'specification',
            '_id' => 'namespace/cities',
            '_score' => 1.0,
            '_source' => {
              'value' => nil,
              'specification' => "{\"settings\":{\"index\":{\"number_of_shards\":1,\"number_of_replicas\":0}},\"mappings\":{\"city\":{\"properties\":{\"population\":{\"type\":\"integer\"}}}}}"
            }
          }
        ])
      end
    end
  end

  describe '#locked' do
    specify do
      expect { specification1.lock! }.to change { specification1.locked }.from('{}').to(JSON.dump(
        'settings' => {'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
        'mappings' => {'city' => {'properties' => {'name' => {'type' => 'text'}}}}
      ))
    end

    specify do
      expect { specification5.lock! }.to change { specification5.locked }.from('{}').to(JSON.dump(
        'settings' => {'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
        'mappings' => {'city' => {'properties' => {'population' => {'type' => 'integer'}}}}
      ))
    end

    context do
      before { specification1.lock! }

      specify do
        expect { specification2.lock! }.to change { specification2.locked }.from(JSON.dump(
          'settings' => {'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
          'mappings' => {'city' => {'properties' => {'name' => {'type' => 'text'}}}}
        )).to(JSON.dump(
          'settings' => {'analyzer' => {}, 'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
          'mappings' => {'city' => {'properties' => {'name' => {'type' => 'text'}}}}
        ))
      end

      specify do
        expect { specification3.lock! }.to change { specification3.locked }.from(JSON.dump(
          'settings' => {'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
          'mappings' => {'city' => {'properties' => {'name' => {'type' => 'text'}}}}
        )).to(JSON.dump(
          'settings' => {'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
          'mappings' => {'city' => {'properties' => {'name' => {'type' => 'text'}, 'population' => {'type' => 'integer'}}}}
        ))
      end
    end
  end

  describe '#current' do
    specify do
      expect(specification2.current).to eq(JSON.dump(
        'settings' => {'analyzer' => {}, 'index' => {'number_of_shards' => 1, 'number_of_replicas' => 0}},
        'mappings' => {'city' => {'properties' => {'name' => {'type' => 'text'}}}}
      ))
    end
  end

  describe '#changed?' do
    specify { expect(specification1.changed?).to eq(true) }
    specify { expect { specification1.lock! }.to change { specification1.changed? }.to(false) }

    context do
      before { specification1.lock! }
      specify { expect { specification2.lock! }.to change { specification2.changed? }.from(true).to(false) }
    end

    context do
      before { specification1.lock! }
      specify { expect { specification3.lock! }.to change { specification3.changed? }.from(true).to(false) }
    end

    context do
      before { specification1.lock! }
      specify { expect { specification5.lock! }.to change { specification5.changed? }.from(true) }
    end

    context do
      before { specification3.lock! }
      specify { expect { specification4.lock! }.not_to change { specification4.changed? }.from(false) }
    end
  end
end
