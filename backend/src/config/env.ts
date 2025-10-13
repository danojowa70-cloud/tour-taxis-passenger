import dotenv from 'dotenv';
dotenv.config();

export const env = {
  port: parseInt(process.env.PORT || '4000', 10),
  supabaseUrl: process.env.SUPABASE_URL || '',
  supabaseKey: process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '',
  corsOrigin: process.env.CORS_ORIGIN || '*',
};

if (!env.supabaseUrl || !env.supabaseKey) {
  // eslint-disable-next-line no-console
  console.warn('[env] Missing Supabase credentials. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
}


