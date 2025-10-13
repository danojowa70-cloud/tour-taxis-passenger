import { Request, Response } from 'express';
import { z } from 'zod';
import { PaymentsService } from '../services/payments.service';

const createPaymentSchema = z.object({
  rideId: z.string().min(1),
  passengerId: z.string().min(1),
  amount: z.number().positive(),
  method: z.enum(['cash', 'wallet', 'online']),
});

export async function createPayment(req: Request, res: Response) {
  try {
    const { rideId, passengerId, amount, method } = createPaymentSchema.parse(req.body);
    const payment = await PaymentsService.createPayment(rideId, passengerId, amount, method);
    return res.status(201).json(payment);
  } catch (e: any) {
    return res.status(400).json({ error: e.message || 'Invalid request' });
  }
}

export async function updatePaymentStatus(req: Request, res: Response) {
  try {
    const paymentId = z.string().min(1).parse(req.params.paymentId);
    const status = z.enum(['paid', 'pending', 'failed']).parse(req.body.status);
    const payment = await PaymentsService.updatePaymentStatus(paymentId, status);
    return res.json(payment);
  } catch (e: any) {
    return res.status(400).json({ error: e.message || 'Invalid request' });
  }
}


