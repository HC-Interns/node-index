###
  Trial implementation using a hash table as a storage backend for node-index
  Intended to eventually become a Holochain DHT storage

  Must implement
    read
    readRoot
    isPosition
    write
    writeRoot
    beforeCompact
    afterCompact
###

util = require 'util'
step = require 'step'


###
  Class @constructor
###
Storage = exports.Storage = (options) ->
  @hashtable = {}
  @linkTable = {}
  @root_hash
  @

###
  @constructor wrapper
###
exports.createStorage = (options) ->
  return new Storage options

################ fake DHT style functions

Storage::commit = (entry) -> 
  @hashtable[util.hash(entry)] = entry

Storage::get = (hash) -> 
  return hashtable[hash]

Storage::commitLinks = (baseHash, links) ->
  linkTable[baseHash] = links

Storage::getLinks = (hash) ->
  return linkTable[hash]

###############

Storage::isPosition = isPosition = (pos) ->
  return pos instanceof Position

Storage::read = (pos, callback) ->
  unless isPosition pos
    return callback 'pos should be a valid position'

  process.nextTick =>
    callback null, @data[pos.index]

Storage::write = (data, callback) ->
  process.nextTick =>
    callback null, new Position(@data.push(data) - 1)

Storage::readRoot = (callback) ->
  process.nextTick =>
    callback null, @data[@root_pos.index]

Storage::writeRoot = (root_pos, callback) ->
  unless isPosition root_pos
    return callback 'pos should be a valid position'

  process.nextTick =>
    @root_pos = root_pos
    callback null

Storage::inspect = ->
  @data.forEach (line, i) ->
    util.puts i + ': ' + JSON.stringify line

  util.puts 'Root : ' + JSON.stringify @root_pos

Position = exports.Position = (@index) ->
  @

###
  Storage state
###
Storage::getState = ->
  {}

Storage::setState = (state) ->
  true

###
  Compaction flow
###

Storage::beforeCompact = (callback) ->
  @_compactEdge = @data.push '--------'
  callback null

Storage::afterCompact = (callback) ->
  @data[i] = 0 for i in [0...@_compactEdge]
  callback null

