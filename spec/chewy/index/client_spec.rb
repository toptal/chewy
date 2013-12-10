require 'spec_helper'

describe Chewy::Index::Client do
  include ClassHelpers

  describe '.client' do
    specify { stub_index(:dummies1).client.should == stub_index(:dummies2).client }

    context do
      before do
        stub_index(:dummies1)
        stub_index(:dummies2, Dummies1Index)
      end

      specify { Dummies1Index.client.should == Dummies2Index.client }
    end
  end
end
