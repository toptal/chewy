require 'spec_helper'

describe Chewy::Query::Nodes::Regexp do
  describe '#__render__' do
    def render &block
      Chewy::Query::Context.new(&block).__render__
    end

    specify { render { names.first == /nam.*/ }.should == {regexp: {'names.first' => 'nam.*'}} }
    specify { render { names.first =~ /nam.*/ }.should == {regexp: {'names.first' => 'nam.*'}} }
    specify { render { name != /nam.*/ }.should == {not: {regexp: {'name' => 'nam.*'}}} }
    specify { render { name !~ /nam.*/ }.should == {not: {regexp: {'name' => 'nam.*'}}} }

    specify { render { names.first(flags: [:anystring, :intersection, :borogoves]) == /nam.*/ }
      .should == {regexp: {'names.first' => {value: 'nam.*', flags: 'ANYSTRING|INTERSECTION'}}} }
    specify { render { names.first(:anystring, :intersection, :borogoves) == /nam.*/ }
      .should == {regexp: {'names.first' => {value: 'nam.*', flags: 'ANYSTRING|INTERSECTION'}}} }

    specify { render { names.first(flags: [:anystring, :intersection, :borogoves]) =~ /nam.*/ }
      .should == {regexp: {'names.first' => {value: 'nam.*', flags: 'ANYSTRING|INTERSECTION'}}} }
    specify { render { names.first(:anystring, :intersection, :borogoves) =~ /nam.*/ }
      .should == {regexp: {'names.first' => {value: 'nam.*', flags: 'ANYSTRING|INTERSECTION'}}} }
  end
end
