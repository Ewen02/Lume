import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { TokenGuard } from '../../common/auth/token.guard';
import { SearchFoodsUseCase } from '../../application/use-cases/search-foods.usecase';
import { LookupBarcodeUseCase } from '../../application/use-cases/lookup-barcode.usecase';

@Controller('foods')
@UseGuards(TokenGuard)
export class FoodsController {
  constructor(
    private readonly searchFoods: SearchFoodsUseCase,
    private readonly lookupBarcode: LookupBarcodeUseCase,
  ) {}

  @Get('search')
  async search(@Query('q') q: string) {
    return { results: await this.searchFoods.execute(q ?? '') };
  }

  @Get('barcode/:code')
  async barcode(@Param('code') code: string) {
    return { product: await this.lookupBarcode.execute(code) };
  }
}
