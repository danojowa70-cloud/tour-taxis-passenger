import express from 'express';
import cors from 'cors';
import http from 'http';
import { Server } from 'socket.io';
import { env } from './config/env';
import { logger } from './utils/logger';
import { ridesRouter } from './routes/rides.routes';
import { paymentsRouter } from './routes/payments.routes';
import { boardingPassesRouter } from './routes/boarding-passes.routes';
import { registerRideHandlers } from './socket/ride.handlers';

const app = express();
app.use(cors({ origin: env.corsOrigin }));
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true }));
app.use('/api/rides', ridesRouter);
app.use('/api/payments', paymentsRouter);
app.use('/api/boarding-passes', boardingPassesRouter);

// Error handler
// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error({ err }, 'Unhandled error');
  res.status(500).json({ error: 'Internal server error' });
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: env.corsOrigin },
});

io.on('connection', (socket) => {
  logger.info({ id: socket.id }, 'Socket connected');
  registerRideHandlers(io, socket);
  socket.on('disconnect', () => logger.info({ id: socket.id }, 'Socket disconnected'));
});

server.listen(env.port, () => {
  logger.info(`Server listening on :${env.port}`);
});


