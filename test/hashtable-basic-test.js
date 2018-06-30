require('coffee-script/register');
var vows = require('vows'),
    assert = require('assert'),
    coffee = require('coffee-script'),
    helpers = require('./helpers');
var index = require('../lib/index');

var storage = require('../lib/index/hashtable-storage');

var options = {};
var index_options = {storage: storage.createStorage()};

var suite = vows.describe('Node index/hashtable basic test');

helpers.memoryTest(suite, index_options, options).export(module);
