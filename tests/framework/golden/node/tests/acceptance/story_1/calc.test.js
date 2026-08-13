// Acceptance contract fixture (node convention): tests/acceptance/story_<nr>/.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { add } from '../../../src/calc.js';

test('AC-1: adds two positive integers', () => {
  assert.equal(add(2, 3), 5);
});

test('AC-2: adds with zero identity', () => {
  assert.equal(add(0, 7), 7);
});
