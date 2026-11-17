import { RealtimeService } from './realtime.service.js';

describe('RealtimeService', () => {
  it('evictFromTeam rời room đội và ngắt socket để không còn nhận chat match cũ', () => {
    const sockets = {
      socketsLeave: vi.fn(),
      disconnectSockets: vi.fn(),
    };
    const server = { in: vi.fn().mockReturnValue(sockets) };
    const service = new RealtimeService();
    service.attach(server as never);

    service.evictFromTeam('u1', 't1');

    expect(server.in).toHaveBeenCalledWith('user:u1');
    expect(sockets.socketsLeave).toHaveBeenCalledWith('team:t1');
    expect(sockets.disconnectSockets).toHaveBeenCalledWith(true);
  });
});
