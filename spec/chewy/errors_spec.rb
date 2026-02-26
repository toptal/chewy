require 'spec_helper'

describe Chewy::UndefinedUpdateStrategy do
  specify do
    error = described_class.new('SomeIndex')
    expect(error.message).to include('Index update strategy is undefined')
  end
end

describe Chewy::ImportFailed do
  specify do
    errors = {
      index: {
        'mapper_parsing_exception' => %w[1 2 3]
      }
    }
    error = described_class.new('CitiesIndex', errors)
    expect(error.message).to include('Import failed for `CitiesIndex`')
    expect(error.message).to include('mapper_parsing_exception')
    expect(error.message).to include('3 documents')
  end
end

describe Chewy::InvalidJoinFieldType do
  specify do
    error = described_class.new('invalid_type', 'hierarchy_link', %i[question answer])
    expect(error.message).to include('invalid_type')
    expect(error.message).to include('hierarchy_link')
    expect(error.message).to include(':relations list')
  end
end
