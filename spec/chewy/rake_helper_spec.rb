require 'spec_helper'
require 'rake'

describe Chewy::RakeHelper, :orm do
  before { Chewy.massacre }

  before do
    described_class.instance_variable_set(:@journal_exists, journal_exists)

    stub_model(:city)
    stub_model(:country)

    stub_index(:cities) do
      index_scope City
      field :name
      field :updated_at, type: 'date'
    end
    stub_index(:countries) do
      index_scope Country
    end
    stub_index(:users)

    allow(described_class).to receive(:all_indexes) { [CitiesIndex, CountriesIndex, UsersIndex] }
  end

  let(:journal_exists) { true }
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
  Imported CitiesIndex in \\d+s, stats: index 3
  Applying journal to \\[CitiesIndex\\], 2 entries, stage 1
  Imported CitiesIndex in \\d+s, stats: index 2
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Resetting CountriesIndex
  Imported CountriesIndex in \\d+s, stats: index 2
  Applying journal to \\[CountriesIndex\\], 1 entries, stage 1
  Imported CountriesIndex in \\d+s, stats: index 1
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Resetting UsersIndex
  Imported UsersIndex in 1s, stats:\s
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(only: 'cities', output: output) }
        .to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting CitiesIndex
  Imported CitiesIndex in \\d+s, stats: index 3
  Applying journal to \\[CitiesIndex\\], 2 entries, stage 1
  Imported CitiesIndex in \\d+s, stats: index 2
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    specify do
      output = StringIO.new
      expect { described_class.reset(except: [CitiesIndex, CountriesIndex], output: output) }
        .not_to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported UsersIndex in 1s, stats:\s
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
      OUTPUT
    end

    context 'when journal is missing' do
      let(:journal_exists) { false }

      specify do
        output = StringIO.new
        expect { described_class.reset(only: [CitiesIndex], output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to include(
          "############################################################\n"\
          "WARN: You are risking to lose some changes during the reset.\n" \
          "      Please consider enabling journaling.\n" \
          '      See https://github.com/toptal/chewy#journaling'
        )
      end
    end
  end

  describe '.upgrade' do
    specify do
      output = StringIO.new
      expect { described_class.upgrade(output: output) }
        .to update_index(CitiesIndex)
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting CitiesIndex
  Imported CitiesIndex in \\d+s, stats: index 3
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Resetting CountriesIndex
  Imported CountriesIndex in \\d+s, stats: index 2
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Resetting UsersIndex
  Imported UsersIndex in 1s, stats:\s
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
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
  Imported UsersIndex in 1s, stats:\s
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.upgrade(except: [CitiesIndex, CountriesIndex], output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AResetting UsersIndex
  Imported UsersIndex in 1s, stats:\s
  Imported Chewy::Stash::Specification in \\d+s, stats: index 1
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
Skipping UsersIndex, it does not exists \\(use rake chewy:reset\\[users\\] to create and update it\\)
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
  Imported CitiesIndex in \\d+s, stats: index 3
Updating CountriesIndex
  Imported CountriesIndex in \\d+s, stats: index 2
Skipping UsersIndex, it does not exists \\(use rake chewy:reset\\[users\\] to create and update it\\)
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(only: 'countries', output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating CountriesIndex
  Imported CountriesIndex in \\d+s, stats: index 2
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.update(except: CountriesIndex, output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AUpdating CitiesIndex
  Imported CitiesIndex in \\d+s, stats: index 3
Skipping UsersIndex, it does not exists \\(use rake chewy:reset\\[users\\] to create and update it\\)
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
\\ASynchronizing CitiesIndex
  Imported CitiesIndex in \\d+s, stats: index 3
  Missing documents: \\[[^\\]]+\\]
  Took \\d+s
Synchronizing CountriesIndex
  CountriesIndex doesn't support outdated synchronization
  Imported CountriesIndex in \\d+s, stats: index 2
  Missing documents: \\[[^\\]]+\\]
  Took \\d+s
Synchronizing UsersIndex
  UsersIndex doesn't support outdated synchronization
  Skipping UsersIndex, up to date
  Took \\d+s
Total: \\d+s\\Z
      OUTPUT
    end

    context do
      before do
        CitiesIndex.import(cities.first(2))
        CountriesIndex.import

        cities.first.update(name: 'Name5')
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing CitiesIndex
  Imported CitiesIndex in \\d+s, stats: index 2
  Missing documents: \\["#{cities.last.id}"\\]
  Outdated documents: \\["#{cities.first.id}"\\]
  Took \\d+s
Synchronizing CountriesIndex
  CountriesIndex doesn't support outdated synchronization
  Skipping CountriesIndex, up to date
  Took \\d+s
Synchronizing UsersIndex
  UsersIndex doesn't support outdated synchronization
  Skipping UsersIndex, up to date
  Took \\d+s
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.sync(only: CitiesIndex, output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ASynchronizing CitiesIndex
  Imported CitiesIndex in \\d+s, stats: index 2
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
\\ASynchronizing CountriesIndex
  CountriesIndex doesn't support outdated synchronization
  Skipping CountriesIndex, up to date
  Took \\d+s
Synchronizing UsersIndex
  UsersIndex doesn't support outdated synchronization
  Skipping UsersIndex, up to date
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
  Applying journal to \\[CitiesIndex, CountriesIndex\\], 3 entries, stage 1
  Imported CitiesIndex in \\d+s, stats: index 2
  Imported CountriesIndex in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.journal_apply(time: 3.minutes.since, output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
  Applying journal to \\[CountriesIndex\\], 1 entries, stage 1
  Imported CountriesIndex in \\d+s, stats: index 1
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.journal_apply(time: Time.now, only: CitiesIndex, output: output) }
          .to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
  Applying journal to \\[CitiesIndex\\], 2 entries, stage 1
  Imported CitiesIndex in \\d+s, stats: index 2
Total: \\d+s\\Z
        OUTPUT
      end

      specify do
        output = StringIO.new
        expect { described_class.journal_apply(time: Time.now, except: CitiesIndex, output: output) }
          .not_to update_index(CitiesIndex)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\AApplying journal entries created after [+-:\\d\\s]+
  Applying journal to \\[CountriesIndex\\], 1 entries, stage 1
  Imported CountriesIndex in \\d+s, stats: index 1
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

    it 'executes asynchronously' do
      output = StringIO.new
      expect(Chewy.client).to receive(:delete_by_query).with(
        {
          body: {query: {match_all: {}}},
          index: ['chewy_journal'],
          refresh: false,
          requests_per_second: 10.0,
          scroll_size: 200,
          wait_for_completion: false
        }
      ).and_call_original
      described_class.journal_clean(
        output: output,
        delete_by_query_options: {
          wait_for_completion: false,
          requests_per_second: 10.0,
          scroll_size: 200
        }
      )

      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\ATask to cleanup the journal has been created, [^\\n]*
Total: \\d+s\\Z
      OUTPUT
    end

    context 'execute "chewy:journal:clean" rake task' do
      subject(:task) { Rake.application['chewy:journal:clean'] }
      before do
        Rake::DefaultLoader.new.load('lib/tasks/chewy.rake')
        Rake::Task.define_task(:environment)
      end
      it 'does not raise error' do
        expect { task.invoke }.to_not raise_error
      end
    end
  end

  describe '.journal_create' do
    specify do
      output = StringIO.new
      described_class.journal_create(output: output)
      expect(Chewy::Stash::Journal.exists?).to be_truthy
      expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
Total: \\d+s\\Z
      OUTPUT
    end
  end

  describe '.reindex' do
    before do
      journal
      CitiesIndex.create!
      CountriesIndex.create!
    end

    let(:source_index) { 'cities' }
    let(:dest_index) { 'countries' }

    context 'with correct arguments' do
      specify do
        output = StringIO.new
        described_class.reindex(source: source_index, dest: dest_index, output: output)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\Source index is cities
\\Destination index is countries
cities index successfully reindexed with countries index data
Total: \\d+s\\Z
        OUTPUT
      end
    end

    context 'with missing indexes' do
      context 'without dest index' do
        specify do
          output = StringIO.new
          expect { described_class.reindex(source: source_index, output: output) }
            .to raise_error ArgumentError
        end
      end

      context 'without source index' do
        specify do
          output = StringIO.new
          expect { described_class.reindex(dest: dest_index, output: output) }
            .to raise_error ArgumentError
        end
      end
    end
  end

  describe '.update_mapping' do
    before do
      journal
      CitiesIndex.create!
    end

    let(:index_name) { CitiesIndex.index_name }
    let(:nonexistent_index) { 'wrong_index' }

    context 'with existing index' do
      specify do
        output = StringIO.new
        described_class.update_mapping(name: index_name, output: output)
        expect(output.string).to match(Regexp.new(<<-OUTPUT, Regexp::MULTILINE))
\\Index name is cities
cities index successfully updated
Total: \\d+s\\Z
        OUTPUT
      end
    end

    context 'with non-existent index name' do
      specify do
        output = StringIO.new
        expect { described_class.update_mapping(name: nonexistent_index, output: output) }
          .to raise_error NameError
      end
    end
  end

  describe '.delete_by_query_options_from_env' do
    subject(:options) { described_class.delete_by_query_options_from_env(env) }
    let(:env) do
      {
        'WAIT_FOR_COMPLETION' => 'false',
        'REQUESTS_PER_SECOND' => '10',
        'SCROLL_SIZE' => '5000'
      }
    end

    it 'parses the options' do
      expect(options).to eq(
        wait_for_completion: false,
        requests_per_second: 10.0,
        scroll_size: 5000
      )
    end

    context 'with different boolean values' do
      it 'parses the option correctly' do
        %w[1 t true TRUE on ON].each do |v|
          expect(described_class.delete_by_query_options_from_env({'WAIT_FOR_COMPLETION' => v}))
            .to eq(wait_for_completion: true)
        end

        %w[0 f false FALSE off OFF].each do |v|
          expect(described_class.delete_by_query_options_from_env({'WAIT_FOR_COMPLETION' => v}))
            .to eq(wait_for_completion: false)
        end
      end
    end

    context 'with other env' do
      let(:env) { {'SOME_ENV' => '123', 'REQUESTS_PER_SECOND' => '15'} }

      it 'parses only the options' do
        expect(options).to eq(requests_per_second: 15.0)
      end
    end
  end

  describe '.subscribed_task_stats' do
    specify do
      block_output = described_class.subscribed_task_stats(StringIO.new) { 'expected output' }
      expect(block_output).to eq('expected output')
    end
  end
end
