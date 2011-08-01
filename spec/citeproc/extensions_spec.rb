require 'spec_helper'

describe Hash do
  let(:hash) { { :a => { :b => { :c => :d } } } }
  

  describe '#deep_copy' do
    it { hash.should respond_to(:deep_copy) }

    it 'returns a copy equal to the hash' do
      hash.deep_copy.should == hash
    end
    
    it 'returns a copy that is not identical to the hash' do
      hash.deep_copy.should_not equal(hash)
    end
    
    it 'returns a deep copy' do
      hash.deep_copy[:a].should == hash[:a]
      hash.deep_copy[:a].should_not equal(hash[:a])
      hash.deep_copy[:a][:b].should == hash[:a][:b]
      hash.deep_copy[:a][:b].should_not equal(hash[:a][:b])
      hash.deep_copy[:a][:b][:c].should == hash[:a][:b][:c]
    end
  end
  
  describe '#deep_fetch' do
    # it 'behaves like normal for two arguments' do
    #   hash.fetch(:b, 42).should == 42
    # end
    # 
    # it 'behaves like normal for one argument and a block' do
    #   hash.fetch(:b) {42}.should == 42
    # end
    
    it 'returns the value of all the arguments applied as keys' do
      hash.deep_fetch(:a, :b, :c).should == :d
    end
    
    it 'returns nil if any of the values did not exist' do
      hash.deep_fetch(:x, :b, :c).should be nil
      hash.deep_fetch(:a, :x, :c).should be nil
      hash.deep_fetch(:a, :b, :x).should be nil
    end

  end
end