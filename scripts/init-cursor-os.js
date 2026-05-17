#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const force = process.argv.includes('--force');
const root = process.cwd();

const files = {};

console.log('This bootstrap script is intended to be replaced by the adam-os CLI installer.');
console.log('Run adam-os init in the repo root for the full experience.');
console.log('Current directory:', root);
console.log('Force mode:', force ? 'on' : 'off');
