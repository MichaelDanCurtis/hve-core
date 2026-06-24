// rpi-cockpit/src/events.ts
import { z } from "zod";

export const Phase = z.enum(["research", "plan", "implement", "review", "discover"]);
export type Phase = z.infer<typeof Phase>;

export const ValidationStatus = z.enum(["ok", "running", "fail", "pending"]);
export type ValidationStatus = z.infer<typeof ValidationStatus>;

export const OptionItem = z.object({
  id: z.string(),
  title: z.string(),
  detail: z.string().optional(),
  recommended: z.boolean().optional(),
});
export type OptionItem = z.infer<typeof OptionItem>;

export const Beat = z.discriminatedUnion("type", [
  z.object({ type: z.literal("session.begin"), task: z.string(), host: z.string() }),
  z.object({ type: z.literal("phase.enter"), phase: Phase }),
  z.object({ type: z.literal("subagent.start"), name: z.string(), role: z.string().optional() }),
  z.object({ type: z.literal("subagent.stop"), name: z.string(), result: z.string().optional() }),
  z.object({ type: z.literal("artifact.update"), path: z.string(), summary: z.string().optional() }),
  z.object({ type: z.literal("validate"), check: z.string(), status: ValidationStatus }),
]);
export type Beat = z.infer<typeof Beat>;
