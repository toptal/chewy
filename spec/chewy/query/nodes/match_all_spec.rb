require 'spec_helper'

describe Chewy::Query::Nodes::MatchAll do
  describe '#__render__' do
    def render &block
      Chewy::Query::Filters.new(&block).__render__
    end

    specify { render { match_all }.should == {match_all: {}} }
  end
end
