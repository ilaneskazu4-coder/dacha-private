// Логика комнаты посредника «Дача вместе». Не зависит от среды: работает и в Cloudflare, и в Node.
// Сообщения (бинарные, числа big-endian):
//   от посредника: 1 ASSIGN [1][id u32] | 2 PEER_JOIN [2][id] | 3 PEER_LEAVE [3][id]
//                  4 DATA [4][от кого u32][режим][данные...] | 5 ERR [5][код]  (1 нет комнаты, 2 код занят, 3 комната полна, 4 хозяин вышел)
//   к посреднику:  4 DATA [4][кому u32 (0 = всем)][режим][данные...] | 6 KICK [6][id u32] (только хозяин)
const MAX_CLIENTS = 3;

function u32(v) {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setUint32(0, v >>> 0, false);
  return b;
}
function msg(type, ...parts) {
  let len = 1;
  for (const p of parts) len += p.length;
  const out = new Uint8Array(len);
  out[0] = type;
  let o = 1;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

class RoomCore {
  constructor() {
    this.host = null;
    this.clients = new Map(); // id -> sock
    this.next = 2;
  }

  // sock: { send(Uint8Array), close() }
  onOpen(role, sock) {
    if (role === "host") {
      if (this.host) { sock.send(msg(5, Uint8Array.of(2))); sock.close(); return; }
      this.host = sock;
      sock._id = 1;
      sock.send(msg(1, u32(1)));
    } else {
      if (!this.host) { sock.send(msg(5, Uint8Array.of(1))); sock.close(); return; }
      if (this.clients.size >= MAX_CLIENTS) { sock.send(msg(5, Uint8Array.of(3))); sock.close(); return; }
      const id = this.next++;
      sock._id = id;
      this.clients.set(id, sock);
      sock.send(msg(1, u32(id)));
      this.host.send(msg(2, u32(id)));
    }
  }

  onMessage(sock, d) {
    if (!d || d.length < 1) return;
    if (d[0] === 4 && d.length >= 6) {
      const mode = d.slice(5, 6);
      const payload = d.slice(6);
      if (sock === this.host) {
        const target = new DataView(d.buffer, d.byteOffset, d.byteLength).getUint32(1, false);
        const out = msg(4, u32(1), mode, payload);
        if (target === 0) { for (const c of this.clients.values()) c.send(out); }
        else { const c = this.clients.get(target); if (c) c.send(out); }
      } else if (this.host && sock._id) {
        this.host.send(msg(4, u32(sock._id), mode, payload));
      }
    } else if (d[0] === 6 && sock === this.host && d.length >= 5) {
      const id = new DataView(d.buffer, d.byteOffset, d.byteLength).getUint32(1, false);
      const c = this.clients.get(id);
      if (c) { this.clients.delete(id); this.host.send(msg(3, u32(id))); c.close(); }
    }
  }

  onClose(sock) {
    if (sock === this.host) {
      this.host = null;
      for (const c of this.clients.values()) { c.send(msg(5, Uint8Array.of(4))); c.close(); }
      this.clients.clear();
      this.next = 2;
    } else if (sock._id && this.clients.get(sock._id) === sock) {
      this.clients.delete(sock._id);
      if (this.host) this.host.send(msg(3, u32(sock._id)));
    }
  }

  get empty() { return !this.host && this.clients.size === 0; }
}

// Cloudflare Worker: посредник для игры «Дача Михалыча вместе».
// Одна комната = один Durable Object, имя — короткий код. Игроки соединяются через него по WebSocket.

export class Room {
  constructor(state, env) {
    this.core = new RoomCore();
  }

  async fetch(request) {
    const url = new URL(request.url);
    const role = url.searchParams.get("role") === "host" ? "host" : "join";
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    const sock = {
      send: (u8) => { try { server.send(u8); } catch (e) {} },
      close: () => { try { server.close(1000, "bye"); } catch (e) {} },
    };
    this.core.onOpen(role, sock);
    server.addEventListener("message", (e) => {
      if (e.data instanceof ArrayBuffer) this.core.onMessage(sock, new Uint8Array(e.data));
    });
    server.addEventListener("close", () => this.core.onClose(sock));
    server.addEventListener("error", () => this.core.onClose(sock));
    return new Response(null, { status: 101, webSocket: client });
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const m = url.pathname.match(/^\/ws\/([A-Za-z0-9]{4,8})$/);
    if (!m) return new Response("Dacha relay OK", { status: 200 });
    if (request.headers.get("Upgrade") !== "websocket") return new Response("Expected websocket", { status: 426 });
    const id = env.ROOMS.idFromName(m[1].toUpperCase());
    return env.ROOMS.get(id).fetch(request);
  },
};
