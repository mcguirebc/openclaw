import type { ChannelPlugin, OpenClawPluginApi } from "openclaw/plugin-sdk";
import { emptyPluginConfigSchema } from "openclaw/plugin-sdk";
import { telegramPlugin } from "./src/channel.js";
import { getTelegramWebhookHandler, setTelegramRuntime } from "./src/runtime.js";

const plugin = {
  id: "telegram",
  name: "Telegram",
  description: "Telegram channel plugin",
  configSchema: emptyPluginConfigSchema(),
  register(api: OpenClawPluginApi) {
    setTelegramRuntime(api.runtime);
    api.registerHttpHandler(async (req, res) => {
      const entry = getTelegramWebhookHandler();
      if (!entry) {
        return false;
      }
      const url = new URL(req.url ?? "/", "http://localhost");
      if (url.pathname !== entry.path) {
        return false;
      }
      if (req.method !== "POST") {
        res.statusCode = 405;
        res.setHeader("Allow", "POST");
        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        res.end("Method Not Allowed");
        return true;
      }
      await entry.handler(req, res);
      return true;
    });
    api.registerChannel({ plugin: telegramPlugin as ChannelPlugin });
  },
};

export default plugin;
