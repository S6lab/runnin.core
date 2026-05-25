import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { getCurrentWeather } from '../weather.service';

const QuerySchema = z.object({
  lat: z.coerce.number().gte(-90).lte(90),
  lng: z.coerce.number().gte(-180).lte(180),
});

export async function getCurrentWeatherHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const { lat, lng } = QuerySchema.parse(req.query);
    const weather = await getCurrentWeather(lat, lng);
    if (!weather) {
      res.status(204).send();
      return;
    }
    res.json(weather);
  } catch (err) {
    next(err);
  }
}
