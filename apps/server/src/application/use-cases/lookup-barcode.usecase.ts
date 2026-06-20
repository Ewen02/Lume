import { BarcodePort } from '../../domain/ports/barcode.port';

export class LookupBarcodeUseCase {
  constructor(private readonly barcode: BarcodePort) {}
  execute(code: string) { return this.barcode.lookup(code); }
}
