require 'set'
class SetSync
  attr_accessor :local_binding, :remote_binding

  def initialize(local, remote, options={}, &blk)
    @local = local
    @remote = remote
    
    @local_binding = options[:local_binding] || :id
    @remote_binding = options[:remote_binding] || :id

    sync_block(blk) if blk
  end

  def local_hash
    @local_hash ||= begin
                      h = {}
                      @local.each { |l| h[l.send(local_binding)] = l }
                      h
                    end
  end

  def remote_hash
    @remote_hash ||= begin
                      h = {}
                      @remote.each { |l| h[l.send(remote_binding)] = l }
                      h
                    end
  end

  def sync_block(blk)
    blk.call(self)
    do_sync
  end

  def do_sync
    do_entering
    do_exiting
    do_updating
  end

  def do_entering
    entering.each do |binding|
      @on_enter.call remote_hash[binding]
    end
  end

  def do_exiting
    exiting.each do |binding|
      @on_exit.call local_hash[binding]
    end
  end

  def do_updating
    updating.each do |binding|
      @on_update.call local_hash[binding], remote_hash[binding]
    end
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
