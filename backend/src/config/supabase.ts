import { createClient } from 'supabase';
import { env } from './env';

export const supabase = createClient(env.supabaseUrl, env.supabaseKey, {
  auth: { persistSession: false },
});


