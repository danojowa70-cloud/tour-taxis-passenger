# TOURTAXI Passenger Backend

Node.js backend for the TOURTAXI Passenger App using Express, Socket.IO, and Supabase.

## Features
- Ride management (create, status updates, passenger history)
- Real-time ride events via Socket.IO
- Payments API (cash, wallet, online)
- Modular structure with services/controllers/routes/socket handlers

## API
- POST /api/rides { passengerId, pickup, drop }
- GET /api/rides/history/:passengerId
- POST /api/payments { rideId, passengerId, amount, method }
- PATCH /api/payments/:paymentId { status }

## Socket.IO Events
- ride:request { passengerId, pickup, drop }
- ride:accepted -> broadcast with ride
- ride:update { rideId, lat, lng }
- ride:end { rideId, fare }
- ride:fare { rideId, fare }

## Environment
Create `.env`:
```
PORT=4000
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
CORS_ORIGIN=*
```

## Development
```
cd backend
npm install
npm run dev
```

## Build
```
npm run build
npm start
```

## Deployment to Render

### Prerequisites
1. GitHub account
2. Render account (render.com)
3. Supabase project with database tables set up

### Steps
1. Push this repository to GitHub
2. Connect your GitHub repository to Render
3. Use the `render.yaml` configuration file in the root directory
4. Set the following environment variables in Render dashboard:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key
   - `NODE_ENV`: production
   - `PORT`: 10000 (default for Render)
   - `CORS_ORIGIN`: * (or your specific domain)

### Environment Variables
Copy `.env.example` to `.env` for local development:
```bash
cp .env.example .env
# Edit .env with your actual values
```

### Health Check
The server includes a health check endpoint at `/health` for monitoring.
