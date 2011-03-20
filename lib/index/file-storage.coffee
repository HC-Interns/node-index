###
  File storage for Node Index Module

  Copyright Fedor Indutny, 2011.

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to permit
  persons to whom the Software is furnished to do so, subject to the
  following conditions:

  The above copyright notice and this permission notice shall be included
  in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
  NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
  USE OR OTHER DEALINGS IN THE SOFTWARE.
###

utils = require './utils'
step = require 'step'
fs = require 'fs'
path = require 'path'
Buffer = require('buffer').Buffer

###
  Default storage options
###
DEFAULT_OPTIONS =
  filename: ''
  padding: 64
  sizeLimit: 10240

###
  Class @constructor
###
Storage = exports.Storage = (options, callback) ->
  options = utils.merge DEFAULT_OPTIONS, options
  @files = []

  unless options.filename
    return callback 'Filename is required'

  {@filename, @padding, @sizeLimit} = options

  @openFile (err) =>
    if err
      return callback err

    if @files.length <= 0
      # If no files - create one
      @createFile callback
    else
      callback null, @

  # Return instance of self
  @

###
  @constructor wrapper
###
exports.createStorage = (options, callback) ->
  return new Storage options, callback

###
  pos = {
    f: file-index or undefined
    s: start-offset,
    l: length
  }
###
Storage::isPosition = isPosition = (pos) ->
  pos.s and pos.l and ok

###
  Adds index to the end of file
  and return next (unopened) filename
###
Storage::nextFilename = (i) ->
  index = i || @files.length
  if index > 0
    @filename + '.' + index
  else
    @filename

###
  Add index to the end of filename,
  open it if exists and store size
###
Storage::openFile = (callback) ->
  that = @

  filename = @nextFilename()

  step (->
    _callback = @parallel()
    path.exists filename, (exists) ->
      _callback null, exists
    return
  ), ((err, exists) ->
    if err
      callback err
      return
    
    unless exists
      callback(null)
      return

    fs.open filename, 'a+', 0666, @parallel()
    fs.stat filename, @parallel()

    return
  ), ((err, fd, stat) ->
    if err
      callback err
      return

    index = that.files.push file
    index -= 1

    file =
      fd: fd
      size: stat.size
      index: index

    that.openFile that.filename @parallel()
    return
  ), callback

###
  Create file
###
Storage::createFile = (writeRoot, callback) ->
  filename = @nextFilename()

  unless callback?
    callback = writeRoot
    writeRoot = true

  fs.open filename, 'w+', 0666, (err, fd) =>
    if err
      return callback err

    file =
      fd: fd
      size: 0
      index: 0

    @files.push file

    unless writeRoot
      return callback null, @
    
    # Write new root
    @write [], (err, pos) =>
      if err
        return callback err

      @writeRoot pos, (err) =>
        if err
          return callback err

        callback null, @

###
  Read data from position
###
Storage::read = (pos, callback) ->
  unless isPosition pos
    return callback 'pos should be a valid position'

  file = @files[pos.f || 0]
  buff = new Buffer pos.l

  fs.read file, buff, 0, pos.l, pos.s, (err, bytesRead) ->
    if err
      return callback err

    unless bytesRead == pos.l
      return callback 'Read less bytes than expected'

    try
      buff = JSON.parse buff.toString()
      err = null
    catch e
      err = 'Data is not a valid json'

    callback err buff

###
  Write data and return position
###
Storage::write = (data, callback) ->
  data = @convertToBlock data
  @_fsWrite data, callback

###
  Read root page
###
Storage::readRoot = (callback) ->
  @readRootPos (err, pos) =>
    if err
      return callback err
    @read pos, callback

###
  Find last root in files and return it to callback

  it will be synchronous for now
  TODO: make it asynchronous
###
Storage::readRootPos = (callback) ->
  iterate = (index, callback) =>
    file = @files[index]
    unless file
      return callback 'root not found'

    buff = new Buffer @padding

    while offset -= @padding >=0
      bytesRead = fs.readSync file.fd, buff, 0, @padding, offset
      unless bytesRead == @padding
        # Header not found
        offset = -1
        break

      if checkHash buff
        root = buff.slice(utils.hash.length).toString()
        root = root.split(/\n/, 1)[0]
        try
          root = JSON.parse root
        catch e
          # Header is not JSON
          # Try in previous file
          offset = -1
          break
        return callback null, root

    process.nextTick () ->
      iterate (index - 1) callback
  
  checkHash = (buff) ->
    hash = buff.slice(0, utils.hash.length).toString()
    rest = buff.slice(utils.hash.length)
    hash == utils.hash rest

  iterate (@files.length - 1) callback

###
  Write root page
###
Storage::writeRoot = (root_pos, callback) ->
  unless isPosition root_pos
    return callback 'pos should be a valid position'

  _root_pos = [JSON.stringify root_pos,].join '\n'
  buff = new Buffer @padding
  buff.write _root_pos, utils.hash.length

  hash = utils.hash buff.slice utils.hash.length
  buff.write hash, 0, 'binary'

  @_fsWrite buff, (err) =>
    if err
      return callback err

    @root_pos = root_pos
    callback null

###
  Add padding to block
  data should be a JS object
###
Storage::convertToBlock = (data) ->
  data = JSON.stringify data
  length = Buffer.byteLength data
  length += @padding - length % @padding
  buff = new Buffer length

  buff.write data
  buff

###
  Low-level write

  buff - is Buffer
###
Storage::_fsWrite = (buff, callback) ->
  file = @currentFile()
  fd = file.fd
  fs.write fd, buff, 0, buff.length, null, (err, bytesWritten) =>
    if err or bytesWritten isnt buff.length
      @_fsCheckSize (err2) ->
        callback err2 || err || 'Written less bytes than expected'
      return

    pos =
      f: file.index,
      s: file.size,
      l: buff.length

    file.size += buff.length

    if file.size > @sizeLimit
      @createFile false, (err) ->
        if err
          return callback err

        callback null, pos
    else
      callback null, pos

###
  Recheck current file's length
###
Storage::_fsCheckSize = (callback)->
  file = @currentFile()
  filename = @nextFilename @file.index
  fs.stat filename, (err, stat) =>
    if err
      return callback err
    
    file.size = stat.size
    callback null

###
  Current file
###
Storage::currentFile = ->
  @files[@files.length - 1]

###
  Compaction flow actions
###
Storage::beforeCompact = ->
  "before compact"

Storage::afterCompact = ->
  "after compact"

