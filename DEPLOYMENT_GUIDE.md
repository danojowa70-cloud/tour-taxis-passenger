# TourTaxi Passenger App - Deployment Guide

## 📁 Project Structure
```
tour_taxis/
├── backend/                 # Node.js backend server
│   ├── src/                # TypeScript source code
│   ├── package.json        # Node.js dependencies
│   ├── tsconfig.json       # TypeScript configuration
│   ├── .env.example        # Environment variables template
│   └── README.md           # Backend documentation
├── lib/                    # Flutter app source code
├── render.yaml             # Render deployment configuration
├── .gitignore             # Git ignore rules
└── DEPLOYMENT_GUIDE.md    # This file

## 🚀 Quick Deployment to Render

### Step 1: Upload to GitHub
1. Create new repository on GitHub.com: `tour-taxis-passenger`
2. Either:
   - Install Git and push files (recommended)
   - Upload files via GitHub web interface

### Step 2: Deploy to Render
1. Sign up at render.com with your GitHub account
2. Create "New Web Service"
3. Connect your `tour-taxis-passenger` repository
4. Use these settings:
   - **Name**: `tourtaxi-passenger-backend`
   - **Runtime**: `Node`
   - **Build Command**: `cd backend && npm install && npm run build`
   - **Start Command**: `cd backend && npm start`
   - **Plan**: Free

### Step 3: Environment Variables
Add these in Render dashboard:
```
NODE_ENV=production
PORT=10000
SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
CORS_ORIGIN=*
```

### Step 4: Database Schema
Run the SQL schemas provided for:
- passengers table
- boarding_passes table  
- deliveries tables
- wallet tables
- scheduled_rides table

## 📱 Update Flutter App
Update your Flutter app base URL to use the deployed backend:
```dart
const String BASE_URL = 'https://your-app-name.onrender.com';
```

## 🎯 Your Deployed URLs
- Backend API: `https://tourtaxi-passenger-backend.onrender.com`
- Health Check: `https://tourtaxi-passenger-backend.onrender.com/health`

## 📋 Files Ready for Deployment
✅ Backend server with TypeScript
✅ Socket.IO real-time functionality  
✅ Supabase integration
✅ Payment system APIs
✅ Ride management APIs
✅ Deployment configuration (render.yaml)
✅ Environment template (.env.example)
✅ Updated .gitignore
✅ Documentation

## 🔧 Local Development
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your Supabase credentials
npm run dev
```

## 📞 Support
Your backend includes:
- Health check endpoint
- CORS configuration
- Error handling
- Logging with Pino
- Production-ready build process