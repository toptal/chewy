require 'spec_helper'

describe Chewy::Fields::Default do
  specify { described_class.new('name').options[:type].should == 'string' }
  # TODO: add 'should_behave_like base_field'
end
