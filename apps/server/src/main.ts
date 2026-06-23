import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { json } from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  // Limite de taille du body : une photo base64 fait quelques Mo.
  app.use(json({ limit: '16mb' }));
  app.enableShutdownHooks();
  const config = app.get(ConfigService);
  // CORS : restreint à l'origine configurée (App native → '*' par défaut, sans cookie).
  app.enableCors({ origin: config.get<string>('corsOrigin') ?? '*' });
  // Avertissement si le jeton d'API est resté à sa valeur par défaut (oubli de config en prod).
  if ((config.get<string>('apiToken') ?? '') === 'change-me') {
    new Logger('Bootstrap').warn('API_TOKEN non configuré (valeur par défaut « change-me »).');
  }
  // Railway fournit le port via la variable d'env PORT.
  const port = config.get<number>('port') ?? 3000;
  // 0.0.0.0 obligatoire pour que Railway (et tout conteneur) route le trafic entrant.
  await app.listen(port, '0.0.0.0');
  new Logger('Bootstrap').log(`Lume nutrition service sur :${port}`);
}
bootstrap();
