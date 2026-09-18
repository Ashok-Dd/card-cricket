import { describe, expect, it } from 'vitest';
import { generateRoomCode } from './room-code.util.js';

describe('generateRoomCode', () => {
  it('generates a 6-character code from the unambiguous alphabet', () => {
    for (let i = 0; i < 50; i++) {
      const code = generateRoomCode();
      expect(code).toHaveLength(6);
      expect(code).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]+$/);
      expect(code).not.toMatch(/[0O1IL]/);
    }
  });
});
