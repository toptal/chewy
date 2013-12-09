require 'spec_helper'

describe Chewy::Fields::Root do
  specify { described_class.new('name').value.should be_a(Proc) }
  # TODO: add 'should_behave_like base_field'
end
