require 'spec_helper'

describe Chewy::RakeHelper, :orm do
  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_model(:country)

    stub_index(:cities) do
      define_type City do
        field :name
        field :updated_at, type: 'date'
      end
    end
    stub_index(:countries) do
      define_type Country
    end
    stub_index(:users)

    allow(described_class).to receive(:all_indexes) { [CitiesIndex, CountriesIndex, UsersIndex] }
  end

  let!(:cities) { Array.new(3) { |i| City.create!(name: "Name#{i + 1}") } }
  let!(:countries) { Array.new(2) { |i| Country.create!(name: "Name#{i + 1}") } }
  let(:journal) do
    Chewy::Stash::Journal.import([
      {
        index_name: 'cities',
        type_name: 'city',
        action: 'index',
        references: cities.first(2).map(&:id).map(&:to_s)
                      .map(&:to_json).map(&Base64.method(:encode64)),
        created_at: 2.minutes.since
      },
      {
        index_name: 'countries',
        type_name: 'country',
        action: 'index',
        references: [Base64.encode64(countries.first.id.to_s.to_json)],
        created_at: 4.minutes.since
      }
    ])
  end

  describe '.reset' do
    before { journal }

    specify do
      output = StringIO.new
      expect { described_class.reset(output: output) }
        .to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting CitiesIndex
  Imported CitiesIndex::City in \\d+s, stats: index 3
  Applying journal to \\[CitiesIndex::City\\], 2 entries, stage 1
  Imported CitiesIndex::City in \\d+s, stats: index 2
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Resetting CountriesIndex
  Imported CountriesIndex::Country in \\d+s, stats: index 2
  Applying journal to \\[CountriesIndex::Country\\], 1 entries, stage 1
  Imported CountriesIndex::Country in \\d+s, stats: index 1
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Resetting UsersIndex
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(only: 'cities', output: output) }
        .to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting CitiesIndex
  Imported CitiesIndex::City in \\d+s, stats: index 3
  Applying journal to \\[CitiesIndex::City\\], 2 entries, stage 1
  Imported CitiesIndex::City in \\d+s, stats: index 2
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(except: [CitiesIndex, CountriesIndex], output: output) }
        .not_to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end
  end

  describe '.upgrade' do
    specify do
      output = StringIO.new
      expect { described_class.upgrade(output: output) }
        .to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting CitiesIndex
  Imported CitiesIndex::City in \\d+s, stats: index 3
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Resetting CountriesIndex
  Imported CountriesIndex::Country in \\d+s, stats: index 2
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Resetting UsersIndex
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    context do
      before do
        CitiesIndex.reset!
        CountriesIndex.reset!
      end

      specify do
        output = StringIO.new
        expect { described_class.upgrade(output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASkipping CitiesIndex, the specification didn't change
Skipping CountriesIndex, the specification didn't change
Resetting UsersIndex
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.upgrade(except: [CitiesIndex, CountriesIndex], output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported Chewy::Stash::Specification::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      context do
        before { UsersIndex.reset! }

        specify do
          output = StringIO.new
          expect { described_class.upgrade(except: %w[cities countries], output: output) }
            .not_to update_index(CitiesIndex)
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
        .not_to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASkipping CitiesIndex, it does not exists \\(use rake chewy:reset\\[cities\\] to create and update it\\)
Skipping CountriesIndex, it does not exists \\(use rake chewy:reset\\[countries\\] to create and update it\\)
Total: \\d+s\\Z
      OUTPUT
    end

    context do
      before do
        CitiesIndex.reset!
        CountriesIndex.reset!
      end

      specify do
        output = StringIO.new
        expect { described_class.update(output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating CitiesIndex
  Imported CitiesIndex::City in \\d+s, stats: index 3
Updating CountriesIndex
  Imported CountriesIndex::Country in \\d+s, stats: index 2
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(only: 'countries', output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating CountriesIndex
  Imported CountriesIndex::Country in \\d+s, stats: index 2
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(except: CountriesIndex, output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating CitiesIndex
  Imported CitiesIndex::City in \\d+s, stats: index 3
Total: \\d+s\\Z
        OUTPUT
      end
    end
  end

  describe '.sync' do
    specify do
      output = StringIO.new
      expect { described_class.sync(output: output) }
        .to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing CitiesIndex::City
  Imported CitiesIndex::City in \\d+s, stats: index 3
  Missing documents: \\[[^\\]]+\\]
  Took \\d+s
Synchronizing CountriesIndex::Country
  CountriesIndex::Country doesn't support outdated synchronization
  Imported CountriesIndex::Country in \\d+s, stats: index 2
  Missing documents: \\[[^\\]]+\\]
  Took \\d+s
Total: \\d+s\\Z
      OUTPUT
    end

    context do
      before do
        CitiesIndex.import(cities.first(2))
        CountriesIndex.import

        sleep(1) if ActiveSupport::VERSION::STRING < '4.1.0'
        cities.first.update(name: 'Name5')
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing CitiesIndex::City
  Imported CitiesIndex::City in \\d+s, stats: index 2
  Missing documents: \\["#{cities.last.id}"\\]
  Outdated documents: \\["#{cities.first.id}"\\]
  Took \\d+s
Synchronizing CountriesIndex::Country
  CountriesIndex::Country doesn't support outdated synchronization
  Skipping CountriesIndex::Country, up to date
  Took \\d+s
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(only: CitiesIndex, output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing CitiesIndex::City
  Imported CitiesIndex::City in \\d+s, stats: index 2
  Missing documents: \\["#{cities.last.id}"\\]
  Outdated documents: \\["#{cities.first.id}"\\]
  Took \\d+s
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(except: ['cities'], output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing CountriesIndex::Country
  CountriesIndex::Country doesn't support outdated synchronization
  Skipping CountriesIndex::Country, up to date
  Took \\d+s
Total: \\d+s\\Z
        OUTPUT
      end
    end
  end

  describe '.journal_apply' do
    specify { expect { described_class.journal_apply }.to raise_error ArgumentError }
    specify do
      output = StringIO.new
      described_class.journal_apply(time: Time.now, output: output)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
No journal entries were created after the specified time
Total: \\d+s\\Z
      OUTPUT
    end

    context do
      before { journal }

      specify do
        output = StringIO.new
        expect { described_class.journal_apply(time: Time.now, output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
  Applying journal to \\[CitiesIndex::City, CountriesIndex::Country\\], 3 entries, stage 1
  Imported CitiesIndex::City in \\d+s, stats: index 2
  Imported CountriesIndex::Country in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.journal_apply(time: 3.minutes.since, output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
  Applying journal to \\[CountriesIndex::Country\\], 1 entries, stage 1
  Imported CountriesIndex::Country in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.journal_apply(time: Time.now, only: CitiesIndex, output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
  Applying journal to \\[CitiesIndex::City\\], 2 entries, stage 1
  Imported CitiesIndex::City in \\d+s, stats: index 2
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.journal_apply(time: Time.now, except: CitiesIndex, output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
  Applying journal to \\[CountriesIndex::Country\\], 1 entries, stage 1
  Imported CountriesIndex::Country in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end
    end
  end

  describe '.journal_clean' do
    before { journal }

    specify do
      output = StringIO.new
      described_class.journal_clean(output: output)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ACleaned up 2 journal entries
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      described_class.journal_clean(time: 3.minutes.since, output: output)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ACleaning journal entries created before [+-:\\d\\s]+
Cleaned up 1 journal entries
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      described_class.journal_clean(only: CitiesIndex, output: output)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ACleaned up 1 journal entries
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      described_class.journal_clean(except: CitiesIndex, output: output)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ACleaned up 1 journal entries
Total: \\d+s\\Z
      OUTPUT
    end
  end

  describe '._reindex' do
    before do
      journal
      CitiesIndex.create!
      CountriesIndex.create!
    end

    let(:source_index) { 'cities' }
    let(:dest_index) { 'countries' }
    let(:indexes_array) { [source_index, dest_index] }

    context 'with right arguments' do
      specify do
        output = StringIO.new
        described_class._reindex(only: indexes_array, output: output)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\Source index is cities
\\Destination index is countries
cities index successfully reindexed with countries index data
Total: \\d+s\\Z
        OUTPUT
      end
    end

    context 'with wrong count of arguments' do
      specify do
        output = StringIO.new
        expect { described_class._reindex(only: [source_index], output: output) }
          .to raise_error ArgumentError
      end
    end
  end
end
