import { supabase } from '../config/supabase';
import { PaymentRecord } from '../models/types';

export const PaymentsService = {
  async createPayment(rideId: string, passengerId: string, amount: number, method: PaymentRecord['payment_method']): Promise<PaymentRecord> {
    const { data, error } = await supabase
      .from('payments')
      .insert({ ride_id: rideId, passenger_id: passengerId, amount, payment_method: method, status: 'pending' })
      .select()
      .single();
    if (error) throw error;
    return data as PaymentRecord;
  },

  async updatePaymentStatus(paymentId: string, status: PaymentRecord['status']): Promise<PaymentRecord> {
    const { data, error } = await supabase
      .from('payments')
      .update({ status })
      .eq('id', paymentId)
      .select()
      .single();
    if (error) throw error;
    return data as PaymentRecord;
  },
};


