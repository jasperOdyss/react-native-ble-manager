export class DataUtils {
  // MARK: - Hex String <-> Uint8Array Conversion

  static hexToUint8Array(hex: string): Uint8Array {
    const data = [];
    for (let i = 0; i < hex.length; i += 2) {
      data.push(parseInt(hex.substr(i, 2), 16));
    }
    return new Uint8Array(data);
  }

  static uint8ArrayToHex(data: Uint8Array): string {
    return Array.from(data)
      .map(byte => byte.toString(16).padStart(2, '0'))
      .join('');
  }

  static stringToUint8Array(text: string): Uint8Array {
    return new TextEncoder().encode(text);
  }

  static uint8ArrayToString(data: Uint8Array): string {
    return new TextDecoder().decode(data);
  }

  // MARK: - Numeric Conversions (Little Endian)

  static uint8ArrayToUint16LE(data: Uint8Array): number {
    return (data[1] << 8) | data[0];
  }

  static uint16LEToUint8Array(value: number): Uint8Array {
    return new Uint8Array([value & 0xff, (value >> 8) & 0xff]);
  }

  static uint8ArrayToUint32LE(data: Uint8Array): number {
    return (data[3] << 24) | (data[2] << 16) | (data[1] << 8) | data[0];
  }

  static uint32LEToUint8Array(value: number): Uint8Array {
    return new Uint8Array([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  static uint8ArrayToInt16LE(data: Uint8Array): number {
    const uint = this.uint8ArrayToUint16LE(data);
    return uint > 0x7fff ? uint - 0x10000 : uint;
  }

  static int16LEToUint8Array(value: number): Uint8Array {
    return this.uint16LEToUint8Array(value & 0xffff);
  }

  static uint8ArrayToInt32LE(data: Uint8Array): number {
    const uint = this.uint8ArrayToUint32LE(data);
    return uint > 0x7fffffff ? uint - 0x100000000 : uint;
  }

  static int32LEToUint8Array(value: number): Uint8Array {
    return this.uint32LEToUint8Array(value & 0xffffffff);
  }

  static uint8ArrayToFloat32LE(data: Uint8Array): number {
    const view = new DataView(data.buffer);
    return view.getFloat32(0, true);
  }

  static float32LEToUint8Array(value: number): Uint8Array {
    const buffer = new ArrayBuffer(4);
    const view = new DataView(buffer);
    view.setFloat32(0, value, true);
    return new Uint8Array(buffer);
  }

  static uint8ArrayToFloat64LE(data: Uint8Array): number {
    const view = new DataView(data.buffer);
    return view.getFloat64(0, true);
  }

  static float64LEToUint8Array(value: number): Uint8Array {
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setFloat64(0, value, true);
    return new Uint8Array(buffer);
  }

  // MARK: - Numeric Conversions (Big Endian)

  static uint8ArrayToUint16BE(data: Uint8Array): number {
    return (data[0] << 8) | data[1];
  }

  static uint16BEToUint8Array(value: number): Uint8Array {
    return new Uint8Array([(value >> 8) & 0xff, value & 0xff]);
  }

  static uint8ArrayToUint32BE(data: Uint8Array): number {
    return (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
  }

  static uint32BEToUint8Array(value: number): Uint8Array {
    return new Uint8Array([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }

  static uint8ArrayToInt16BE(data: Uint8Array): number {
    const uint = this.uint8ArrayToUint16BE(data);
    return uint > 0x7fff ? uint - 0x10000 : uint;
  }

  static int16BEToUint8Array(value: number): Uint8Array {
    return this.uint16BEToUint8Array(value & 0xffff);
  }

  static uint8ArrayToInt32BE(data: Uint8Array): number {
    const uint = this.uint8ArrayToUint32BE(data);
    return uint > 0x7fffffff ? uint - 0x100000000 : uint;
  }

  static int32BEToUint8Array(value: number): Uint8Array {
    return this.uint32BEToUint8Array(value & 0xffffffff);
  }

  static uint8ArrayToFloat32BE(data: Uint8Array): number {
    const view = new DataView(data.buffer);
    return view.getFloat32(0, false);
  }

  static float32BEToUint8Array(value: number): Uint8Array {
    const buffer = new ArrayBuffer(4);
    const view = new DataView(buffer);
    view.setFloat32(0, value, false);
    return new Uint8Array(buffer);
  }

  static uint8ArrayToFloat64BE(data: Uint8Array): number {
    const view = new DataView(data.buffer);
    return view.getFloat64(0, false);
  }

  static float64BEToUint8Array(value: number): Uint8Array {
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setFloat64(0, value, false);
    return new Uint8Array(buffer);
  }

  // MARK: - MTU Based Packetization

  static splitIntoPackets(data: Uint8Array, mtu: number, headerSize: number = 0): Uint8Array[] {
    const maxPayloadSize = mtu - headerSize;
    const packets: Uint8Array[] = [];

    for (let i = 0; i < data.length; i += maxPayloadSize) {
      const end = Math.min(i + maxPayloadSize, data.length);
      const packet = data.slice(i, end);
      packets.push(packet);
    }

    return packets;
  }

  static reassemblePackets(packets: Uint8Array[]): Uint8Array {
    const totalLength = packets.reduce((sum, packet) => sum + packet.length, 0);
    const result = new Uint8Array(totalLength);

    let offset = 0;
    for (const packet of packets) {
      result.set(packet, offset);
      offset += packet.length;
    }

    return result;
  }

  // MARK: - Helper Methods

  static validateHexString(hex: string): boolean {
    const hexPattern = /^[0-9a-fA-F]*$/;
    return hexPattern.test(hex) && hex.length % 2 === 0;
  }

  static parseManufacturerData(data: string, companyId: number): Uint8Array {
    const hexData = this.hexToUint8Array(data);
    const companyIdBytes = hexData.slice(0, 2);
    const parsedCompanyId = this.uint8ArrayToUint16LE(companyIdBytes);

    if (parsedCompanyId !== companyId) {
      throw new Error(`Invalid company ID: expected 0x${companyId.toString(16)}, got 0x${parsedCompanyId.toString(16)}`);
    }

    return hexData.slice(2);
  }

  static createManufacturerData(companyId: number, data: Uint8Array): string {
    const companyIdBytes = this.uint16LEToUint8Array(companyId);
    const result = new Uint8Array(companyIdBytes.length + data.length);
    result.set(companyIdBytes, 0);
    result.set(data, companyIdBytes.length);
    return this.uint8ArrayToHex(result);
  }
}

// MARK: - Common Constants

export const MTU_MIN = 23;
export const MTU_DEFAULT = 23;
export const MTU_MAX = 512;
export const DEFAULT_TIMEOUT = 30000;
