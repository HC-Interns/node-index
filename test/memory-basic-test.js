require('coffee-script/register');
var vows = require('vows'),
    assert = require('assert'),
    coffee = require('coffee-script'),
    helpers = require('./helpers');
var index = require('../lib/index');

var options = {};

var suite = vows.describe('Node index/memory basic test');

helpers.memoryTest(suite, {}, options).export(module);
