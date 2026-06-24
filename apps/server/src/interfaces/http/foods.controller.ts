import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { TokenGuard } from '../../common/auth/token.guard';
import { SearchFoodsUseCase } from '../../application/use-cases/search-foods.usecase';
import { LookupBarcodeUseCase } from '../../application/use-cases/lookup-barcode.usecase';

/** Bornes de sécurité sur les entrées texte (évite des requêtes externes abusives). */
const MAX_QUERY_LEN = 120;
const MAX_BARCODE_LEN = 32;

// Search/barcode ne touchent pas Claude → seule la fenêtre « global » s'applique.
@Controller('foods')
@UseGuards(TokenGuard)
@SkipThrottle({ analyze: true })
export class FoodsController {
  constructor(
    private readonly searchFoods: SearchFoodsUseCase,
    private readonly lookupBarcode: LookupBarcodeUseCase,
  ) {}

  @Get('search')
  async search(@Query('q') q: string) {
    const query = (q ?? '').slice(0, MAX_QUERY_LEN);
    return { results: await this.searchFoods.execute(query) };
  }

  @Get('barcode/:code')
  async barcode(@Param('code') code: string) {
    const c = (code ?? '').slice(0, MAX_BARCODE_LEN);
    return { product: await this.lookupBarcode.execute(c) };
  }
}
