require 'spec_helper'

describe Chewy::Search::Parameters::Load do
  subject { described_class.new(foo: '42') }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq(load_options: {}, loaded_objects: false) }
    specify { expect(described_class.new(nil).value).to eq(load_options: {}, loaded_objects: false) }
    specify { expect(subject.value).to eq(load_options: { foo: '42' }, loaded_objects: false) }
    specify { expect(described_class.new(load_options: { foo: '42' }).value).to eq(load_options: { foo: '42' }, loaded_objects: false) }
    specify { expect(described_class.new(loaded_objects: true, foo: '42').value).to eq(load_options: {}, loaded_objects: true) }
    specify { expect(described_class.new(load_options: { foo: '42' }, loaded_objects: true, bar: '42').value).to eq(load_options: { foo: '42' }, loaded_objects: true) }
  end

  describe '#replace' do
    specify do
      expect { subject.replace(bar: '43') }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { bar: '43' }, loaded_objects: false)
    end
    specify do
      expect { subject.replace(foo: '43') }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { foo: '43' }, loaded_objects: false)
    end
    specify do
      expect { subject.replace(loaded_objects: true) }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: {}, loaded_objects: true)
    end

    context do
      subject { described_class.new(loaded_objects: true) }

      specify do
        expect { subject.replace(loaded_objects: false) }
          .to change { subject.value }
          .from(load_options: {}, loaded_objects: true)
          .to(load_options: {}, loaded_objects: false)
      end

      specify do
        expect { subject.replace(foo: '42') }
          .to change { subject.value }
          .from(load_options: {}, loaded_objects: true)
          .to(load_options: { foo: '42' }, loaded_objects: false)
      end
    end
  end

  describe '#update' do
    specify do
      expect { subject.update(bar: '43') }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { foo: '42', bar: '43' }, loaded_objects: false)
    end
    specify do
      expect { subject.update(foo: '43') }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { foo: '43' }, loaded_objects: false)
    end
    specify do
      expect { subject.update(loaded_objects: true) }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { foo: '42' }, loaded_objects: true)
    end

    context do
      subject { described_class.new(loaded_objects: true) }

      specify do
        expect { subject.update(loaded_objects: false) }
          .not_to change { subject.value }
      end

      specify do
        expect { subject.update(foo: '42') }
          .to change { subject.value }
          .from(load_options: {}, loaded_objects: true)
          .to(load_options: { foo: '42' }, loaded_objects: true)
      end
    end
  end

  describe '#merge' do
    specify do
      expect { subject.merge(described_class.new(bar: '43')) }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { foo: '42', bar: '43' }, loaded_objects: false)
    end
    specify do
      expect { subject.merge(described_class.new(foo: '43')) }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { foo: '43' }, loaded_objects: false)
    end
    specify do
      expect { subject.merge(described_class.new(loaded_objects: true)) }
        .to change { subject.value }
        .from(load_options: { foo: '42' }, loaded_objects: false)
        .to(load_options: { foo: '42' }, loaded_objects: true)
    end

    context do
      subject { described_class.new(loaded_objects: true) }
      specify do
        expect { subject.merge(described_class.new(loaded_objects: false)) }
          .not_to change { subject.value }
      end
    end
  end

  describe '#render' do
    specify { expect(described_class.new.render).to be_nil }
    specify { expect(described_class.new(foo: 'bar').render).to be_nil }
  end
end
