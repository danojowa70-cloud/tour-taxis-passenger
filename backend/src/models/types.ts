export type RideStatus = 'pending' | 'accepted' | 'in_progress' | 'completed' | 'canceled';

export interface Ride {
  id: string;
  passenger_id: string;
  driver_id: string | null;
  pickup_location: string;
  drop_location: string;
  fare: number | null;
  status: RideStatus;
  created_at?: string;
}

export interface PaymentRecord {
  id: string;
  ride_id: string;
  passenger_id: string;
  amount: number;
  payment_method: 'cash' | 'wallet' | 'online';
  status: 'paid' | 'pending' | 'failed';
  created_at?: string;
}


