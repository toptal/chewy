require 'spec_helper'

describe Chewy::Query::Nodes::Regexp do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { names.first == /nam.*/ }.should == {regexp: {'names.first' => 'nam.*'}} }
    specify { render { name != /nam.*/ }.should == {not: {regexp: {'name' => 'nam.*'}}} }
  end
end
