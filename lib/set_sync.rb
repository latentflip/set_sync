require 'set'
class SetSync

  class << self
    def local_binding(binding=nil)
      if binding
        @local_binding = binding
      else
        @local_binding
      end
    end
    def remote_binding(binding=nil)
      if binding
        @remote_binding = binding
      else
        @remote_binding
      end
    end
    def on_enter(&blk)
      blk ? @on_enter=blk : @on_enter
    end
    def on_exit(&blk)
      blk ? @on_exit=blk : @on_enter
    end
    def on_update(&blk)
      blk ? @on_update=blk : @on_update
    end
  end

  attr_accessor :local_binding, :remote_binding
  def initialize(local, remote, options={}, &blk)
    @local = local
    @remote = remote
    
    @local_binding = options[:local_binding] || self.class.local_binding || :id
    @remote_binding = options[:remote_binding] || self.class.remote_binding || :id

    sync_block(blk) if blk
  end

  def local_hash
    @local_hash ||= begin
                      h = {}
                      @local.each do |l|
                        if local_binding.respond_to? :call
                          h[ local_binding.call(l) ] = l
                        elsif l.respond_to? local_binding #is an objecty thing
                          h[l.send(local_binding)] = l
                        elsif l.respond_to? :[]      #is a hashy thing
                          h[ l[local_binding] ] = l
                        end
                      end
                      h
                    end
  end

  def remote_hash
    @remote_hash ||= begin
                      h = {}
                      @remote.each do |r|
                        if remote_binding.respond_to? :call
                          h[ remote_binding.call(r) ] = r
                        elsif r.respond_to? remote_binding
                          h[ r.send(remote_binding) ] = r
                        elsif r.respond_to? :[]
                          h[ r[remote_binding] ] = r
                        end
                      end
                      h
                    end
  end

  def sync_block(blk)
    blk.call(self)
    do_sync
  end

  def sync_with_delegate(delegate)
    on_enter { |remote| delegate.on_enter(remote) }
    on_update { |local, remote| delegate.on_update(local, remote) }
    on_exit { |local| delegate.on_exit(local) }
    do_sync
  end

  def do_sync
    do_entering
    do_exiting
    do_updating
  end

  def do_entering
    entering.each do |binding|
      do_enter remote_hash[binding]
    end
  end

  def do_exiting
    exiting.each do |binding|
      do_exit local_hash[binding]
    end
  end

  def do_updating
    updating.each do |binding|
      do_update local_hash[binding], remote_hash[binding]
    end
  end

  def do_enter(remote)
    blk = @on_enter || self.class.on_enter
    blk.call remote
  end
  def do_exit(local)
    blk = @on_exit || self.class.on_exit
    blk.call local
  end
  def do_update(local, remote)
    blk = @on_update || self.class.on_update
    blk.call local, remote
  end

  def on_enter(&blk)
    @on_enter = blk
  end
  def on_exit(&blk)
    @on_exit = blk
  end
  def on_update(&blk)
    @on_update = blk
  end

  def select_remotes(ids)
    remote.select { |r| ids.include? r.send(remote_binding) }
  end
  def select_locals(ids)
    local.select { |r| ids.include? r.send(local_binding) }
  end

  def remote_bindings
    Set.new remote_hash.keys
  end

  def local_bindings
    Set.new local_hash.keys
  end

  def entering
    remote_bindings - local_bindings
  end

  def updating
    remote_bindings & local_bindings
  end

  def exiting
    local_bindings - remote_bindings
  end

end
