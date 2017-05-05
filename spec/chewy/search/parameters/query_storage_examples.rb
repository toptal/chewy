require 'spec_helper'

shared_examples :query_storage do |param_name|
  subject { described_class.new(must: { foo: 'bar' }, should: { moo: 'baz' }) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq(must: [], should: [], must_not: []) }
    specify { expect(described_class.new(nil).value).to eq(must: [], should: [], must_not: []) }
    specify { expect(described_class.new(foobar: {}).value).to eq(must: [{ foobar: {} }], should: [], must_not: []) }
    specify { expect(described_class.new(must: {}, should: {}, must_not: {}).value).to eq(must: [], should: [], must_not: []) }
    specify { expect(described_class.new(must: { foo: 'bar' }, should: { foo: 'bar' }, foobar: {}).value).to eq(must: [{ foo: 'bar' }], should: [{ foo: 'bar' }], must_not: []) }
    specify { expect(subject.value).to eq(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: []) }
    specify { expect(described_class.new(proc { match foo: 'bar' }).value).to eq(must: [match: { foo: 'bar' }], should: [], must_not: []) }
    specify { expect(described_class.new(must: proc { match foo: 'bar' }).value).to eq(must: [match: { foo: 'bar' }], should: [], must_not: []) }
    specify do
      expect(described_class.new(must: [proc { match foo: 'bar' }, { moo: 'baz' }]).value)
        .to eq(must: [{ match: { foo: 'bar' } }, { moo: 'baz' }], should: [], must_not: [])
    end
  end

  describe '#replace' do
    specify do
      expect { subject.replace(must: proc { match foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [match: { foo: 'bar' }], should: [], must_not: [])
    end

    specify do
      expect { subject.replace(should: { foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [], should: [{ foo: 'bar' }], must_not: [])
    end

    specify do
      expect { subject.replace(foobar: { foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foobar: { foo: 'bar' } }], should: [], must_not: [])
    end

    specify do
      expect { subject.replace(nil) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [], should: [], must_not: [])
    end
  end

  describe '#update' do
    specify do
      expect { subject.update(must: proc { match foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }, { match: { foo: 'bar' } }], should: [{ moo: 'baz' }], must_not: [])
    end

    specify do
      expect { subject.update(must_not: { moo: 'baz' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [{ moo: 'baz' }])
    end

    specify do
      expect { subject.update(foobar: { foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }, { foobar: { foo: 'bar' } }], should: [{ moo: 'baz' }], must_not: [])
    end

    specify do
      expect { subject.update(nil) }
        .not_to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
    end
  end

  describe '#must' do
    specify do
      expect { subject.must(moo: 'baz') }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }, { moo: 'baz' }], should: [{ moo: 'baz' }], must_not: [])
    end

    specify do
      expect { subject.must(nil) }
        .not_to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
    end
  end

  describe '#should' do
    specify do
      expect { subject.should(foo: 'bar') }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }, { foo: 'bar' }], must_not: [])
    end

    specify do
      expect { subject.should(nil) }
        .not_to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
    end
  end

  describe '#must_not' do
    specify do
      expect { subject.must_not(moo: 'baz') }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [{ moo: 'baz' }])
    end

    specify do
      expect { subject.must_not(nil) }
        .not_to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
    end
  end

  describe '#and' do
    specify do
      expect { subject.and(moo: 'baz') }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }, { moo: 'baz' }], should: [], must_not: [])
    end

    specify do
      expect { subject.and(nil) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }], should: [], must_not: [])
    end

    specify do
      expect { subject.and(should: { foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }, { foo: 'bar' }], should: [], must_not: [])
    end

    context do
      subject { described_class.new(must: { foo: 'bar' }) }

      specify do
        expect { subject.and(moo: 'baz') }
          .to change { subject.value }
          .from(must: [{ foo: 'bar' }], should: [], must_not: [])
          .to(must: [{ foo: 'bar' }, { moo: 'baz' }], should: [], must_not: [])
      end
    end
  end

  describe '#or' do
    specify do
      expect { subject.or(moo: 'baz') }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [], should: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }, { moo: 'baz' }], must_not: [])
    end

    specify do
      expect { subject.or(nil) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [], should: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }], must_not: [])
    end

    specify do
      expect { subject.or(should: { foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [], should: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }, { foo: 'bar' }], must_not: [])
    end

    context do
      subject { described_class.new(must: { foo: 'bar' }) }

      specify do
        expect { subject.or(moo: 'baz') }
          .to change { subject.value }
          .from(must: [{ foo: 'bar' }], should: [], must_not: [])
          .to(must: [], should: [{ foo: 'bar' }, { moo: 'baz' }], must_not: [])
      end
    end
  end

  describe '#not' do
    specify do
      expect { subject.not(moo: 'baz') }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [{ moo: 'baz' }])
    end

    specify do
      expect { subject.not(nil) }
        .not_to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
    end

    specify do
      expect { subject.not(should: { foo: 'bar' }) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [{ foo: 'bar' }])
    end

    context do
      subject { described_class.new(must: { foo: 'bar' }) }

      specify do
        expect { subject.not(moo: 'baz') }
          .to change { subject.value }
          .from(must: [{ foo: 'bar' }], should: [], must_not: [])
          .to(must: [{ foo: 'bar' }], should: [], must_not: [{ moo: 'baz' }])
      end
    end
  end

  describe '#merge' do
    specify do
      expect { subject.merge(described_class.new(moo: 'baz')) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }, { moo: 'baz' }], should: [], must_not: [])
    end

    specify do
      expect { subject.merge(described_class.new) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }], should: [], must_not: [])
    end

    specify do
      expect { subject.merge(described_class.new(should: { foo: 'bar' })) }
        .to change { subject.value }
        .from(must: [{ foo: 'bar' }], should: [{ moo: 'baz' }], must_not: [])
        .to(must: [{ bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } }, { foo: 'bar' }], should: [], must_not: [])
    end

    context do
      subject { described_class.new(must: { foo: 'bar' }) }

      specify do
        expect { subject.merge(described_class.new(moo: 'baz')) }
          .to change { subject.value }
          .from(must: [{ foo: 'bar' }], should: [], must_not: [])
          .to(must: [{ foo: 'bar' }, { moo: 'baz' }], should: [], must_not: [])
      end
    end
  end

  describe '#render' do
    specify { expect(described_class.new.render).to be_nil }

    specify do
      expect(described_class.new(must: [{ foo: 'bar' }]).render)
        .to eq(param_name => { foo: 'bar' })
    end

    specify do
      expect(described_class.new(must: [{ foo: 'bar' }, { moo: 'baz' }]).render)
        .to eq(param_name => { bool: { must: [{ foo: 'bar' }, { moo: 'baz' }] } })
    end

    specify do
      expect(subject.render)
        .to eq(param_name => { bool: { must: { foo: 'bar' }, should: { moo: 'baz' } } })
    end
  end
end
