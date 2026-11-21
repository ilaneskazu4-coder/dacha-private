// Cloudflare Worker: посредник для игры «Дача Михалыча вместе».
// Одна комната = один Durable Object, имя — короткий код. Игроки соединяются через него по WebSocket.
import { RoomCore } from "./relay_core.js";

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
