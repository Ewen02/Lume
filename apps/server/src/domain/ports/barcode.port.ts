import { Food } from '../value-objects/food.vo';

export const BARCODE_PORT = Symbol('BARCODE_PORT');

export interface BarcodePort {
  lookup(code: string): Promise<Food | null>;
}
