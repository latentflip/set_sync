require_relative '../lib/set_sync.rb'
require 'rspec'

class Remote < Struct.new(:remote_id, :title)
end

class Local < Struct.new(:local_id, :title, :their_id)
end



describe SetSync do
  let(:set_sync) { SetSync.new(local_set, remote_set, :local_binding => :their_id, :remote_binding => :remote_id) }
  let(:local_set) { [] }
  let(:remote_set) { [] }
  subject { set_sync }

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

  context "block calling" do
    describe "entering" do
      let(:local_a) { Local.new(:a, "OldFoo", 1) }
      let(:local_b) { Local.new(:b, "OldBar", 2) }
      let(:local_set) { [local_a, local_b] }

      let(:remote_2) { Remote.new(2, "Bar") }
      let(:remote_3) { Remote.new(3, "Baz") }
      let(:remote_set) { [remote_2, remote_3] }
        
      it "should call enter on the entering stuff" do
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
