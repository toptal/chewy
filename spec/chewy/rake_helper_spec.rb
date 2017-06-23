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
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 3
  Imported PlacesIndex::Country for [\\d\\.]+s, documents total: 2
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1
Resetting UsersIndex
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(only: 'places', output: output) }
        .to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting PlacesIndex
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 3
  Imported PlacesIndex::Country for [\\d\\.]+s, documents total: 2
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(except: PlacesIndex, output: output) }
        .not_to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1
      OUTPUT
    end
  end

  describe '.reset_changed' do
    specify do
      output = StringIO.new
      expect { described_class.reset_changed(output: output) }
        .to update_index(PlacesIndex::City)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting PlacesIndex
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 3
  Imported PlacesIndex::Country for [\\d\\.]+s, documents total: 2
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1
Resetting UsersIndex
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1
      OUTPUT
    end

    context do
      before { PlacesIndex.reset! }

      specify do
        output = StringIO.new
        expect { described_class.reset_changed(output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASkipping PlacesIndex, the specification didn't change
Resetting UsersIndex
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.reset_changed(except: PlacesIndex, output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported Chewy::Stash::Specification for [\\d\\.]+s, documents total: 1\\Z
        OUTPUT
      end

      context do
        before { UsersIndex.reset! }

        specify do
          output = StringIO.new
          expect { described_class.reset_changed(except: ['places'], output: output) }
            .not_to update_index(PlacesIndex::City)
          expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ANo index specification was changed\\Z
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
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 3
  Imported PlacesIndex::Country for [\\d\\.]+s, documents total: 2\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(only: 'places#country', output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating PlacesIndex
  Imported PlacesIndex::Country for [\\d\\.]+s, documents total: 2\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(except: PlacesIndex::Country, output: output) }
          .to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating PlacesIndex
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 3\\Z
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
\\ASynchronizing PlacesIndex
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 3
    Missing documents: \\[[^\\]]+\\]
  Imported PlacesIndex::Country for [\\d\\.]+s, documents total: 2
    Missing documents: \\[[^\\]]+\\]\\Z
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
\\ASynchronizing PlacesIndex
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 2
    Missing documents: \\["#{cities.last.id}"\\]
    Outdated documents: \\["#{cities.first.id}"\\]
  Skipping PlacesIndex::Country, up to date\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(only: PlacesIndex::City, output: output) }
          .to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing PlacesIndex
  Imported PlacesIndex::City for [\\d\\.]+s, documents total: 2
    Missing documents: \\["#{cities.last.id}"\\]
    Outdated documents: \\["#{cities.first.id}"\\]\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(except: ['places#city'], output: output) }
          .not_to update_index(PlacesIndex::City)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing PlacesIndex
  Skipping PlacesIndex::Country, up to date\\Z
        OUTPUT
      end
    end
  end
end
