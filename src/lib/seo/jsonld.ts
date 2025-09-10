export function sanitizeJsonLd(obj: unknown): string {
  // Minimal XSS-safe stringifier (no functions, no prototypes)
  return JSON.stringify(obj, (_k, v) => (typeof v === 'string' ? v : v));
}
