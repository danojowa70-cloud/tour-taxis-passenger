import { Router } from 'express';
import { createRide, getRideHistory, acceptRide } from '../controllers/rides.controller';

export const ridesRouter = Router();

ridesRouter.post('/', createRide);
ridesRouter.get('/history/:passengerId', getRideHistory);
ridesRouter.post('/:rideId/accept', acceptRide);

