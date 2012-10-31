# Set Sync

Takes two lists/sets of things, and binds them together by a data binding. Similar in concept to d3.js

Worst description ever, see below instead:

phil@latentflip.com

MIT


```
  require 'set_sync'

  class RemoteThing < Struct.new(:id, :title)
  end

  class LocalThing < Struct.new(:id, :title, :remote_id)
  end

  remotes = [
    RemoteThing.new(2, "bar"),
    RemoteThing.new(3, "baz")
  ]

  locals = [
    LocalThing.new(101, "old_foo", 1),
    LocalThing.new(102, "old_bar", 2)
  ]

  SetSync.new(locals, remotes) do |s|
    #define how the two sets are bound together
    s.local_binding = :remote_id
    s.remote_binding = :id

    s.on_enter do |remote|
      puts "We will add #{remote}"
    end

    s.on_exit do |local|
      puts "We will delete #{local}"
    end

    s.on_update do |local, remote|
      puts "We will update #{local} with #{remote}"
    end
  end

  #=> We will add #<struct RemoteThing id=3, title="baz">
  #=> We will delete #<struct LocalThing id=101, title="old_foo", remote_id=1>
  #=> We will update #<struct LocalThing id=102, title="old_bar", remote_id=2> with #<struct RemoteThing id=2, title="bar">
```
