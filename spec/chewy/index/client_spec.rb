require 'spec_helper'

describe Chewy::Index::Client do
  include ClassHelpers

  describe '.client' do
    specify { index_class.client.should == index_class.client }

    context do
      let(:index1) { index_class }
      let(:index2) { index_class(index1) }

      specify { index1.client.should == index2.client }
    end
  end
end
