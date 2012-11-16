require_relative '../lib/set_sync.rb'
require 'rspec'

class Remote < Struct.new(:remote_id, :title)
end

class Local < Struct.new(:local_id, :title, :their_id)
end

class MySyncer < SetSync

end


describe SetSync do
  let(:set_sync) { SetSync.new(local_set, remote_set, :local_binding => :their_id, :remote_binding => :remote_id) }
  let(:local_set) { [] }
  let(:remote_set) { [] }
  subject { set_sync }

  context "local/remote binding" do
    it 'defaults to id' do
      set = SetSync.new([], [])
      set.local_binding.should ==  :id
      set.remote_binding.should == :id
    end
    it 'accepts on initialize' do
      set = SetSync.new([], [], :local_binding => :foo, :remote_binding => :bar)
      set.local_binding.should == :foo
      set.remote_binding.should == :bar
    end
    it 'accepts as class method' do
      class MySet < SetSync
        local_binding :baz
        remote_binding :bux
      end

      set = MySet.new([], [])
      set.local_binding.should == :baz
      set.remote_binding.should == :bux
    end

    it 'accepts a proc' do
      remote = Remote.new(1, "foo")
      local_updated = Local.new(100, "foo", 100) #for some reason there is a factor of 100 (to test the proc behaviour)
      local_exited = Local.new(1, "not foo", 1)

      local_exited.should_receive(:do_exit)
      local_updated.should_receive(:update).with(remote)


      SetSync.new([local_updated, local_exited], [remote]) do |s|

        s.local_binding = ->(local) { local.their_id/50.0 }
        s.remote_binding = ->(remote) { remote.remote_id*2.0 }

        s.on_enter do |remote|
          throw "Should not be called"
        end

        s.on_exit do |local|
          local.do_exit
        end

        s.on_update do |local, remote|
          local.update(remote)
        end
      end
      
    end
  end

  context "on_enter etc" do
    it 'accepts as class method' do
      class MySet < SetSync
        on_enter { |r| r }
        on_exit { |l| l }
        on_update { |l,r| [l,r] }
      end

      set = MySet.new([], [])
      set.do_enter('a').should == 'a'
      set.do_exit('b').should == 'b'
      set.do_update('c', 'd').should == ['c','d']
    end
  end
  

  context "local set empty" do
    let(:remote_set) { [
      Remote.new(1, "Foo"), Remote.new(2, "Bar"), Remote.new(3, "Baz")
    ]}

    its(:entering) { should == Set.new([1,2,3]) }
    its(:updating) { should be_empty }
    its(:exiting) { should be_empty }
  end

  context "remote set empty" do
    let(:local_set) {[
      Local.new(:a, "Foo", 1), Local.new(:b, "Bar", 2), Local.new(:c, "Baz", 3)
    ]}

    its(:entering) { should be_empty }
    its(:updating) { should be_empty }
    its(:exiting) { should == Set.new([1,2,3]) }
  end

  context "updated set" do
    let(:local_set) {[
      Local.new(:a, "OldFoo", 1), Local.new(:b, "OldBar", 2), Local.new(:c, "OldBaz", 3)
    ]}
    let(:remote_set) {[
      Remote.new(1, "Foo"), Remote.new(2, "Bar"), Remote.new(3, "Baz")
    ]}

    its(:entering) { should be_empty }
    its(:updating) { should == Set.new([1,2,3]) }
    its(:exiting) { should be_empty }
  end

  context "added one" do
    let(:local_set) {[
      Local.new(:a, "Foo", 1), Local.new(:b, "Bar", 2), Local.new(:c, "Baz", 3)
    ]}
    let(:remote_set) {[
      Remote.new(1, "Foo"), Remote.new(2, "Bar"), Remote.new(3, "Baz"), Remote.new(4, "Bux")
    ]}

    its(:entering) { should == Set.new([4]) }
    its(:updating) { should == Set.new([1,2,3]) }
    its(:exiting) { should be_empty }
  end

  context "removed one" do
    let(:local_set) {[
      Local.new(:a, "Foo", 1), Local.new(:b, "Bar", 2), Local.new(:c, "Baz", 3)
    ]}
    let(:remote_set) {[
      Remote.new(1, "Foo"), Remote.new(3, "Baz")
    ]}

    its(:entering) { should be_empty }
    its(:updating) { should == Set.new([1,3]) }
    its(:exiting) { should == Set.new([2]) }
  end


  context "with delegate object" do
    let(:local_a) { Local.new(:a, "OldFoo", 1) }
    let(:local_b) { Local.new(:b, "OldBar", 2) }
    let(:local_set) { [local_a, local_b] }

    let(:remote_2) { {:remote_id => 2, :title => "Bar"} }
    let(:remote_3) { {:remote_id => 3, :title => "Baz"} }
    let(:remote_set) { [remote_2, remote_3] }

    before {
      class Delegate
        def on_update(local_remote)
        end
      end
    }

    it 'should sync the sets' do
      delegate = stub
      delegate.should_receive(:on_enter).with(remote_3)
      delegate.should_receive(:on_exit).with(local_a)
      delegate.should_receive(:on_update).with(local_b, remote_2)

      syncer = SetSync.new(local_set, remote_set, :local_binding => :their_id, :remote_binding => :remote_id)
      syncer.sync_with_delegate(delegate)
    end
  end

  context "syncing" do
    let(:local_a) { Local.new(:a, "OldFoo", 1) }
    let(:local_b) { Local.new(:b, "OldBar", 2) }
    let(:local_set) { [local_a, local_b] }

    let(:remote_2) { {:remote_id => 2, :title => "Bar"} }
    let(:remote_3) { {:remote_id => 3, :title => "Baz"} }
    let(:remote_set) { [remote_2, remote_3] }

    context "block calling" do
        
      it "should sync the sets" do
        local_repo = stub

        local_repo.should_receive(:create).with remote_3
        local_repo.should_receive(:destroy).with local_a
        local_repo.should_receive(:update).with local_b, remote_2

        SetSync.new(local_set, remote_set) do |sync|
          sync.local_binding = :their_id
          sync.remote_binding = :remote_id
          
          sync.on_enter do |remote|
            local_repo.create(remote)
          end

          sync.on_exit do |local|
            local_repo.destroy(local)
          end

          sync.on_update do |local, remote|
            local_repo.update(local, remote)
          end
        end
      end
    end

  end
end
