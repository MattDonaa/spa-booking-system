/**
 * Structured application logger.
 *
 * Emits JSON in production (machine-parseable for log aggregation) and
 * human-readable output in development. This is the single logging entry
 * point for the application — never use `console.log` directly.
 *
 * Sensitive data (medical info, secrets, payment details) must NEVER be
 * passed to the logger. Callers are responsible for redaction.
 */

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

type LogContext = Record<string, unknown>;

const LEVEL_PRIORITY: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

const isProduction = process.env.NODE_ENV === 'production';
const minLevel: LogLevel = isProduction ? 'info' : 'debug';

function shouldLog(level: LogLevel): boolean {
  return LEVEL_PRIORITY[level] >= LEVEL_PRIORITY[minLevel];
}

function serializeError(error: unknown): LogContext {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: isProduction ? undefined : error.stack,
    };
  }
  return { error: String(error) };
}

function write(level: LogLevel, message: string, context?: LogContext) {
  if (!shouldLog(level)) return;

  const entry = {
    level,
    message,
    timestamp: new Date().toISOString(),
    ...context,
  };

  const line = isProduction ? JSON.stringify(entry) : formatDev(entry);

  if (level === 'error') {
    console.error(line);
  } else if (level === 'warn') {
    console.warn(line);
  } else {
    // eslint-disable-next-line no-console
    console.log(line);
  }
}

function formatDev(entry: Record<string, unknown>): string {
  const { level, message, timestamp, ...rest } = entry;
  const context = Object.keys(rest).length ? ` ${JSON.stringify(rest)}` : '';
  return `[${timestamp}] ${String(level).toUpperCase()} ${message}${context}`;
}

export const logger = {
  debug: (message: string, context?: LogContext) =>
    write('debug', message, context),
  info: (message: string, context?: LogContext) =>
    write('info', message, context),
  warn: (message: string, context?: LogContext) =>
    write('warn', message, context),
  error: (message: string, error?: unknown, context?: LogContext) =>
    write('error', message, {
      ...context,
      ...(error ? serializeError(error) : {}),
    }),
};
