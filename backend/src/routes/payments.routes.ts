import { Router } from 'express';
import { createPayment, updatePaymentStatus } from '../controllers/payments.controller';

export const paymentsRouter = Router();

paymentsRouter.post('/', createPayment);
paymentsRouter.patch('/:paymentId', updatePaymentStatus);


