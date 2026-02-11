import type { IncomingMessage, ServerResponse } from "node:http";
import type { PluginRuntime } from "openclaw/plugin-sdk";

let runtime: PluginRuntime | null = null;

type TelegramWebhookHandler = {
  path: string;
  handler: (req: IncomingMessage, res: ServerResponse) => Promise<void> | void;
  stop?: () => Promise<void> | void;
};
let webhookHandler: TelegramWebhookHandler | null = null;

export function setTelegramRuntime(next: PluginRuntime) {
  runtime = next;
}

export function getTelegramRuntime(): PluginRuntime {
  if (!runtime) {
    throw new Error("Telegram runtime not initialized");
  }
  return runtime;
}

export function setTelegramWebhookHandler(next: TelegramWebhookHandler | null) {
  webhookHandler = next;
}

export function getTelegramWebhookHandler(): TelegramWebhookHandler | null {
  return webhookHandler;
}
