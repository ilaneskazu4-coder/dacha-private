Как поднять бесплатный сервер для игры по коду (Cloudflare Workers)
1. dash.cloudflare.com -> Workers & Pages -> Create -> Create Worker -> назови dacha-relay -> Deploy.
2. Edit code: удали всё, вставь содержимое файла relay/worker_single.js (один файл), Deploy.
3. Settings -> Bindings -> Add -> Durable Object: имя переменной ROOMS, класс Room. (Для бесплатного плана нужен SQLite-класс.)
4. Скопируй адрес вида https://dacha-relay.ИМЯ.workers.dev и введи в игре: Играть вместе -> Имя и сервер -> Адрес сервера.
Пароли и токены никому не отправляй.
