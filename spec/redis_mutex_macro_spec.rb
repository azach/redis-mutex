require 'spec_helper'

class C
  include Redis::Mutex::Macro
  auto_mutex :run_singularly, :block => 0, :after_failure => lambda {|id| return "failure: #{id}" }

  def run_singularly(id)
    sleep 0.1
    return "success: #{id}"
  end

  auto_mutex :run_singularly_on_args, :block => 0, :on => [:id, :bar], :after_failure => lambda {|id, *others| return "failure: #{id}" }
  def run_singularly_on_args(id, foo, bar)
    sleep 0.1
    return "success: #{id}"
  end

  auto_mutex :run_singularly_on_keyword_args, :block => 0, :on => [:id, :bar], :after_failure => lambda {|id: 1, **others| return "failure: #{id}" }
  def run_singularly_on_keyword_args(id: 1, foo: 1, bar: 1)
    sleep 0.1
    return "success: #{id}"
  end
end

describe Redis::Mutex::Macro do

  def race(a, b)
    t1 = Thread.new(&a)
    # In most cases t1 wins, but make sure to give it a head start,
    # not exceeding the sleep inside the method.
    sleep 0.01
    t2 = Thread.new(&b)
    t1.join
    t2.join
  end

  let(:object_arg) { Object.new }

  it 'adds auto_mutex' do
    race(
      proc { C.new.run_singularly(1).should == "success: 1" },
      proc { C.new.run_singularly(2).should == "failure: 2" })
  end

  it 'adds auto_mutex on different args' do
    race(
      proc { C.new.run_singularly_on_args(1, :'2', object_arg).should == "success: 1" },
      proc { C.new.run_singularly_on_args(2, :'2', object_arg).should == "success: 2" })
  end

  it 'adds auto_mutex on same args' do
    race(
      proc { C.new.run_singularly_on_args(1, :'2', object_arg).should == "success: 1" },
      proc { C.new.run_singularly_on_args(1, :'2', object_arg).should == "failure: 1" })
  end

  it 'adds auto_mutex on different keyword args' do
    race(
      proc { C.new.run_singularly_on_keyword_args(id: 1, foo: :'2', bar: object_arg).should == "success: 1" },
      proc { C.new.run_singularly_on_keyword_args(id: 2, foo: :'2', bar: object_arg).should == "success: 2" })
  end

  it 'adds auto_mutex on same keyword args' do
    race(
      proc { C.new.run_singularly_on_keyword_args(id: 1, foo: :'2', bar: object_arg).should == "success: 1" },
      proc { C.new.run_singularly_on_keyword_args(id: 1, foo: :'2', bar: object_arg).should == "failure: 1" })
  end

  it 'raise exception if there is no such argument' do
    expect {
      class C
        auto_mutex :run_without_such_args, :block => 0, :on => [:missing_arg]
        def run_without_such_args(id)
          return "success: #{id}"
        end
      end
    }.to raise_error(ArgumentError) { |error|
      expect(error.message).to eq 'You are trying to lock on unknown arguments: missing_arg'
    }
  end
end
