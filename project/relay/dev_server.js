// Локальный посредник для проверки (тот же RoomCore, но на обычном Node без внешних библиотек).
// Запуск: node dev_server.js [порт]
import http from "node:http";
import crypto from "node:crypto";
import { RoomCore } from "./relay_core.js";

const port = Number(process.argv[2] || 8787);
const rooms = new Map();
const GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

function frame(opcode, payload) {
  const len = payload.length;
  let head;
  if (len < 126) head = Buffer.from([0x80 | opcode, len]);
  else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x80 | opcode; head[1] = 126; head.writeUInt16BE(len, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x80 | opcode; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
  return Buffer.concat([head, Buffer.from(payload)]);
}

const server = http.createServer((req, res) => { res.end("Dacha relay (dev) OK"); });
server.on("upgrade", (req, socket) => {
  const url = new URL(req.url, "http://x");
  const m = url.pathname.match(/^\/ws\/([A-Za-z0-9]{4,8})$/);
  if (!m) { socket.destroy(); return; }
  const code = m[1].toUpperCase();
  const role = url.searchParams.get("role") === "host" ? "host" : "join";
  const key = req.headers["sec-websocket-key"];
  const accept = crypto.createHash("sha1").update(key + GUID).digest("base64");
  socket.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n");
  let room = rooms.get(code);
  if (!room) { room = new RoomCore(); rooms.set(code, room); }
  const sock = {
    send: (u8) => { if (!socket.destroyed) socket.write(frame(2, u8)); },
    close: () => { if (!socket.destroyed) { socket.write(frame(8, Buffer.alloc(0))); socket.end(); } },
  };
  let buf = Buffer.alloc(0);
  room.onOpen(role, sock);
  socket.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    for (;;) {
      if (buf.length < 2) return;
      const op = buf[0] & 0x0f;
      let len = buf[1] & 0x7f;
      let off = 2;
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
      const masked = (buf[1] & 0x80) !== 0;
      if (buf.length < off + (masked ? 4 : 0) + len) return;
      let payload;
      if (masked) {
        const mask = buf.subarray(off, off + 4);
        payload = Buffer.from(buf.subarray(off + 4, off + 4 + len));
        for (let i = 0; i < len; i++) payload[i] ^= mask[i % 4];
        off += 4;
      } else payload = Buffer.from(buf.subarray(off, off + len));
      buf = buf.subarray(off + len);
      if (op === 2) room.onMessage(sock, new Uint8Array(payload));
      else if (op === 8) { sock.close(); return; }
      else if (op === 9) socket.write(frame(10, payload));
    }
  });
  const gone = () => { room.onClose(sock); if (room.empty) rooms.delete(code); };
  socket.on("close", gone);
  socket.on("error", () => {});
});
server.listen(port, () => console.log("relay dev on", port));
