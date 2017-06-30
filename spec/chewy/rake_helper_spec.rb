require 'spec_helper'

describe Chewy::RakeHelper, :orm do
  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_model(:country)

    stub_index(:places) do
      define_type City do
        field :name
        field :updated_at, type: 'date'
      end
      define_type Country
    end
    stub_index(:users)

    allow(described_class).to receive(:all_indexes) { [PlacesIndex, UsersIndex] }
  end

  let!(:cities) { Array.new(3) { |i| City.create!(name: "Name#{i + 1}") } }
  let!(:countries) { Array.new(2) { |i| Country.create!(name: "Name#{i + 1}") } }

  describe '.reset' do
    specify do
      output = StringIO.new
      expect { described_class.reset(output: output) }
        .to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting PlacesIndex
  Imported PlacesIndex::City for \\d+s, stats: index 3
  Imported PlacesIndex::Country for \\d+s, stats: index 2
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Resetting UsersIndex
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(only: 'places', output: output) }
        .to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting PlacesIndex
  Imported PlacesIndex::City for \\d+s, stats: index 3
  Imported PlacesIndex::Country for \\d+s, stats: index 2
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(except: PlacesIndex, output: output) }
        .not_to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end
  end

  describe '.upgrade' do
    specify do
      output = StringIO.new
      expect { described_class.upgrade(output: output) }
        .to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting PlacesIndex
  Imported PlacesIndex::City for \\d+s, stats: index 3
  Imported PlacesIndex::Country for \\d+s, stats: index 2
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Resetting UsersIndex
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    context do
      before { PlacesIndex.reset! }

      specify do
        output = StringIO.new
        expect { described_class.upgrade(output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASkipping PlacesIndex, the specification didn't change
Resetting UsersIndex
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.upgrade(except: PlacesIndex, output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported Chewy::Stash::Specification for \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      context do
        before { UsersIndex.reset! }

        specify do
          output = StringIO.new
          expect { described_class.upgrade(except: ['places'], output: output) }
            .not_to update_index(PlacesIndex::City)
          expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ANo index specification was changed
Total: \\d+s\\Z
          OUTPUT
        end
      end
    end
  end

  describe '.update' do
    specify do
      output = StringIO.new
      expect { described_class.update(output: output) }
        .not_to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASkipping PlacesIndex, it does not exists \\(use rake chewy:reset\\[places\\] to create and update it\\)
      OUTPUT
    end

    context do
      before { PlacesIndex.reset! }

      specify do
        output = StringIO.new
        expect { described_class.update(output: output) }
          .to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating PlacesIndex
  Imported PlacesIndex::City for \\d+s, stats: index 3
  Imported PlacesIndex::Country for \\d+s, stats: index 2
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(only: 'places#country', output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating PlacesIndex
  Imported PlacesIndex::Country for \\d+s, stats: index 2
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(except: PlacesIndex::Country, output: output) }
          .to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating PlacesIndex
  Imported PlacesIndex::City for \\d+s, stats: index 3
Total: \\d+s\\Z
        OUTPUT
      end
    end
  end

  describe '.sync' do
    specify do
      output = StringIO.new
      expect { described_class.sync(output: output) }
        .to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing PlacesIndex::City
  Imported PlacesIndex::City for \\d+s, stats: index 3
  Missing documents: \\[[^\\]]+\\]
Synchronizing PlacesIndex::Country
  Imported PlacesIndex::Country for \\d+s, stats: index 2
  Missing documents: \\[[^\\]]+\\]
Total: \\d+s\\Z
      OUTPUT
    end

    context do
      before do
        PlacesIndex::City.import(cities.first(2))
        PlacesIndex::Country.import

        sleep(1) if ActiveSupport::VERSION::STRING < '4.1.0'
        cities.first.update(name: 'Name5')
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(output: output) }
          .to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing PlacesIndex::City
  Imported PlacesIndex::City for \\d+s, stats: index 2
  Missing documents: \\["#{cities.last.id}"\\]
  Outdated documents: \\["#{cities.first.id}"\\]
Synchronizing PlacesIndex::Country
  Skipping PlacesIndex::Country, up to date
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(only: PlacesIndex::City, output: output) }
          .to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing PlacesIndex::City
  Imported PlacesIndex::City for \\d+s, stats: index 2
  Missing documents: \\["#{cities.last.id}"\\]
  Outdated documents: \\["#{cities.first.id}"\\]
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(except: ['places#city'], output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing PlacesIndex::Country
  Skipping PlacesIndex::Country, up to date
Total: \\d+s\\Z
        OUTPUT
      end
    end
  end
end
