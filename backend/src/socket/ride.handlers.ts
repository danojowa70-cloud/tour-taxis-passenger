import { Server, Socket } from 'socket.io';
import { RidesService } from '../services/rides.service';

export function registerRideHandlers(io: Server, socket: Socket) {
  // Passenger emits ride:request
  socket.on('ride:request', async (payload: { passengerId: string; pickup: string; drop: string }) => {
    try {
      const ride = await RidesService.createRide(payload.passengerId, payload.pickup, payload.drop);
      // Broadcast to drivers namespace/room (placeholder: all)
      io.emit('ride:new', ride);
      socket.emit('ride:requested', ride);
    } catch (e: any) {
      socket.emit('error', { event: 'ride:request', message: e.message });
    }
  });

  // Driver emits ride:accept
  socket.on('ride:accept', async (payload: { rideId: string; driverId: string }) => {
    try {
      const ride = await RidesService.updateRideStatus(payload.rideId, 'accepted', { driver_id: payload.driverId });
      io.emit('ride:accepted', ride); // passenger listens
    } catch (e: any) {
      socket.emit('error', { event: 'ride:accept', message: e.message });
    }
  });

  // Driver emits ride:update for live location
  socket.on('ride:update', (payload: { rideId: string; lat: number; lng: number }) => {
    io.emit(`ride:${payload.rideId}:location`, { lat: payload.lat, lng: payload.lng });
  });

  // Driver emits ride:end
  socket.on('ride:end', async (payload: { rideId: string; fare: number }) => {
    try {
      const ride = await RidesService.updateRideStatus(payload.rideId, 'completed', { fare: payload.fare });
      io.emit('ride:completed', ride);
      io.emit('ride:fare', { rideId: payload.rideId, fare: payload.fare });
    } catch (e: any) {
      socket.emit('error', { event: 'ride:end', message: e.message });
    }
  });
}


