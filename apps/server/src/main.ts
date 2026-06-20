import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { json } from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  // Limite de taille du body : une photo base64 fait quelques Mo.
  app.use(json({ limit: '12mb' }));
  app.enableShutdownHooks();
  const config = app.get(ConfigService);
  // Railway fournit le port via la variable d'env PORT.
  const port = config.get<number>('port') ?? 3000;
  // 0.0.0.0 obligatoire pour que Railway (et tout conteneur) route le trafic entrant.
  await app.listen(port, '0.0.0.0');
  // eslint-disable-next-line no-console
  console.log(`Lume nutrition service sur :${port}`);
}
bootstrap();
