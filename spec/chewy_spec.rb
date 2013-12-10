require 'spec_helper'

describe Chewy do
  include ClassHelpers

  it 'should have a version number' do
    expect(Chewy::VERSION).not_to be nil
  end

  describe '.derive_type' do
    before do
      stub_const('SomeIndex', Class.new)

      stub_index(:developers) do
        define_type do
        end
      end

      stub_index('namespace/autocomplete') do
        define_type :developer do
        end

        define_type :company do
        end
      end
    end

    specify { expect { described_class.derive_type('developers_index#developers') }.to raise_error Chewy::UnderivableType, /DevelopersIndexIndex/ }
    specify { expect { described_class.derive_type('some#developers') }.to raise_error Chewy::UnderivableType, /SomeIndex/ }
    specify { expect { described_class.derive_type('borogoves#developers') }.to raise_error Chewy::UnderivableType, /Borogoves/ }
    specify { expect { described_class.derive_type('developers#borogoves') }.to raise_error Chewy::UnderivableType, /DevelopersIndex.*borogoves/ }
    specify { expect { described_class.derive_type('namespace/autocomplete') }.to raise_error Chewy::UnderivableType, /AutocompleteIndex.*namespace\/autocomplete#type_name/ }

    specify { described_class.derive_type(DevelopersIndex.developer).should == DevelopersIndex.developer }
    specify { described_class.derive_type('developers').should == DevelopersIndex.developer }
    specify { described_class.derive_type('developers#developer').should == DevelopersIndex.developer }
    specify { described_class.derive_type('namespace/autocomplete#developer').should == Namespace::AutocompleteIndex.developer }
    specify { described_class.derive_type('namespace/autocomplete#company').should == Namespace::AutocompleteIndex.company }
  end
end
